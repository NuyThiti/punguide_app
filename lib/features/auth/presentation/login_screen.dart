import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import '../domain/google_authenticator.dart';
import 'providers/auth_providers.dart';

/// The screen does double duty: the API's register endpoint issues no token,
/// so signing up is sign-in with one extra call in front of it.
enum _AuthMode { signIn, register }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  _AuthMode _mode = _AuthMode.signIn;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isSubmitting = false;

  /// Errors stay quiet until the first submit, then follow every keystroke.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  bool get _isRegistering => _mode == _AuthMode.register;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// The API identifies accounts by username, never by email: 3–30 characters
  /// of letters, digits, `.` or `_`.
  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';
    if (username.isEmpty) return 'กรอกชื่อผู้ใช้ของคุณ';
    if (username.length < 3 || username.length > 30) {
      return 'ชื่อผู้ใช้ต้องยาว 3-30 ตัวอักษร';
    }
    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(username)) {
      return 'ใช้ได้เฉพาะ a-z 0-9 จุด และขีดล่าง';
    }
    return null;
  }

  /// Checked on sign-in too, not just on sign-up: every account has at least
  /// eight characters by the API's own rule, and login is rate limited to five
  /// attempts a minute — no sense spending one on a password that cannot match.
  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'กรอกรหัสผ่าน';
    if (password.length < 8) return 'รหัสผ่านอย่างน้อย 8 ตัวอักษร';
    if (password.length > 72) return 'รหัสผ่านยาวเกิน 72 ตัวอักษร';
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() => _isSubmitting = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(authSessionProvider.notifier);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final registering = _isRegistering;

    try {
      // Registering does not issue a token, so the controller signs in
      // straight after — one tap, two calls.
      if (registering) {
        await controller.register(username: username, password: password);
      } else {
        await controller.signIn(username: username, password: password);
      }
    } on ApiException catch (failure) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(_errorMessage(failure, registering))),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(registering ? 'สมัครสมาชิกแล้ว' : 'เข้าสู่ระบบแล้ว'),
      ),
    );
    router.goNamed(AppRoute.home.name);
  }

  /// The server's own wording is the fallback — it explains the password rules
  /// and which field failed better than anything hardcoded here. Only the two
  /// cases where it is terse get replaced.
  String _errorMessage(ApiException failure, bool registering) {
    if (registering && failure.isConflict) return 'ชื่อผู้ใช้นี้ถูกใช้แล้ว';
    if (!registering && failure.isUnauthorized) {
      return 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง';
    }
    if (failure.isRateLimited) {
      return 'ลองบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่';
    }
    return failure.message;
  }

  /// The Google path: Firebase issues an ID token, the backend swaps it for a
  /// session. The ID token is spent on that one call and never reused.
  Future<void> _signInWithGoogle() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(authSessionProvider.notifier);

    try {
      final idToken = await ref.read(googleAuthenticatorProvider).signIn();
      // A cancelled picker is not a failure — leave the screen untouched.
      if (idToken == null) {
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }
      await controller.signInWithFirebase(idToken);
    } on GoogleSignInUnavailable catch (failure) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    } on ApiException catch (failure) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(_googleErrorMessage(failure))),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    messenger.showSnackBar(const SnackBar(content: Text('เข้าสู่ระบบแล้ว')));
    router.goNamed(AppRoute.home.name);
  }

  /// A rejected Firebase token and an unconfigured server both surface here,
  /// and neither is the traveller's fault — say so rather than echoing
  /// "unauthorized".
  String _googleErrorMessage(ApiException failure) {
    if (failure.isUnauthorized) {
      return 'Google ปฏิเสธการเข้าสู่ระบบ กรุณาลองใหม่อีกครั้ง';
    }
    if (failure.isNotConfigured) {
      return 'เซิร์ฟเวอร์ยังไม่ได้เปิดใช้งาน Google Sign-In';
    }
    return failure.message;
  }

  void _switchMode() {
    setState(() {
      _mode = _isRegistering ? _AuthMode.signIn : _AuthMode.register;
      // The rules differ between the two, so carrying old errors across
      // would be misleading — but keep whatever was already typed.
      _autovalidate = AutovalidateMode.disabled;
    });
  }

  void _continueAsGuest() {
    ref.read(authSessionProvider.notifier).signOut();
    context.goNamed(AppRoute.home.name);
  }

  void _notYet(String what) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$what ยังไม่เปิดให้ใช้งาน')));
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.goNamed(AppRoute.home.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFrame(
      background: AppColors.screen,
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          children: [
            _LoginHeader(
              onClose: _close,
              subtitle: _isRegistering
                  ? 'สร้างบัญชีใหม่ เก็บทริปของคุณไว้\nและปันไกด์ให้เพื่อน ๆ'
                  : 'ยินดีต้อนรับกลับ เข้าสู่ระบบเพื่อบันทึกทริป\nและปันไกด์ให้เพื่อน ๆ',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('ชื่อผู้ใช้'),
                  TextFormField(
                    controller: _usernameController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.username],
                    enabled: !_isSubmitting,
                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    validator: _validateUsername,
                    style: _inputTextStyle,
                    decoration: _fieldDecoration(
                      hintText: 'somchai',
                      icon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('รหัสผ่าน'),
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: [
                      _isRegistering
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    enabled: !_isSubmitting,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: _validatePassword,
                    style: _inputTextStyle,
                    decoration: _fieldDecoration(
                      hintText: 'อย่างน้อย 8 ตัวอักษร',
                      icon: Icons.lock_outline,
                      suffix: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: AppColors.navIconMuted,
                        ),
                        tooltip: _obscurePassword
                            ? 'แสดงรหัสผ่าน'
                            : 'ซ่อนรหัสผ่าน',
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_isRegistering)
                    const _PasswordHint()
                  else
                    _RememberRow(
                      remember: _rememberMe,
                      onChanged: (value) => setState(() => _rememberMe = value),
                      onForgot: () => _notYet('การกู้รหัสผ่าน'),
                    ),
                  const SizedBox(height: 18),
                  _PrimaryButton(
                    label: _isRegistering ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ',
                    busy: _isSubmitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 22),
                  const _OrDivider(),
                  const SizedBox(height: 16),
                  _SocialButton(
                    label: 'ดำเนินการต่อด้วย Google',
                    leading: const _GoogleGlyph(),
                    onPressed: _isSubmitting ? null : _signInWithGoogle,
                  ),
                  const SizedBox(height: 10),
                  _SocialButton(
                    label: 'ดำเนินการต่อด้วย Apple',
                    leading: const Icon(
                      Icons.apple,
                      size: 22,
                      color: AppColors.foreground,
                    ),
                    onPressed:
                        _isSubmitting ? null : () => _notYet('Apple Sign-In'),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton(
                      onPressed: _isSubmitting ? null : _continueAsGuest,
                      child: const Text(
                        'เข้าใช้แบบผู้เยี่ยมชม',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _SwitchModeRow(
                    registering: _isRegistering,
                    onPressed: _isSubmitting ? null : _switchMode,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _inputTextStyle = TextStyle(
  color: AppColors.foreground,
  fontSize: 15,
  fontWeight: FontWeight.w600,
);

/// One decoration for every field so focus, error and rest states stay in step.
InputDecoration _fieldDecoration({
  required String hintText,
  required IconData icon,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: AppColors.navIconMuted,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    prefixIcon: Icon(icon, size: 20, color: AppColors.navIconMuted),
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.softScreen,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: border(AppColors.chipBorder, 1),
    enabledBorder: border(AppColors.chipBorder, 1),
    disabledBorder: border(AppColors.chipBorder, 1),
    focusedBorder: border(AppColors.brandOrange, 1.6),
    errorBorder: border(AppColors.brandOrangeDeep, 1),
    focusedErrorBorder: border(AppColors.brandOrangeDeep, 1.6),
    errorStyle: const TextStyle(
      color: AppColors.brandOrangeDeep,
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
    ),
  );
}

/// Brand-orange cap that carries the wordmark, matching the profile hero.
class _LoginHeader extends StatelessWidget {
  const _LoginHeader({required this.onClose, required this.subtitle});

  final VoidCallback onClose;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        20,
        30,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandOrange, AppColors.brandOrangeDeep],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'ป',
              style: TextStyle(
                color: AppColors.brandOrange,
                fontSize: 26,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'PunGuide',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.foreground,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RememberRow extends StatelessWidget {
  const _RememberRow({
    required this.remember,
    required this.onChanged,
    required this.onForgot,
  });

  final bool remember;
  final ValueChanged<bool> onChanged;
  final VoidCallback onForgot;

  @override
  Widget build(BuildContext context) {
    // The checkbox side is flexible so a long label ellipsizes instead of
    // pushing the link off a narrow phone.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!remember),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: remember ? AppColors.brandOrange : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: remember
                            ? AppColors.brandOrange
                            : AppColors.chipBorder,
                        width: 1.5,
                      ),
                    ),
                    child: remember
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'จำฉันไว้',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onForgot,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'ลืมรหัสผ่าน?',
            style: TextStyle(
              color: AppColors.brandOrange,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onPressed,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brandOrange, AppColors.brandOrangeDeep],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandOrange.withValues(alpha: busy ? 0.15 : 0.38),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    const line = Expanded(
      child: Divider(height: 1, thickness: 1, color: AppColors.line),
    );

    return const Row(
      children: [
        line,
        Flexible(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'หรือดำเนินการต่อด้วย',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        line,
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.leading,
    required this.onPressed,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.chipBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stands in for the Google mark — the app ships no brand SVG for it yet.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.softScreen,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 13,
          height: 1.1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Spells out the API's password rule while signing up, where the traveller is
/// choosing one rather than recalling it.
class _PasswordHint extends StatelessWidget {
  const _PasswordHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(2, 6, 0, 2),
      child: Text(
        'ตั้งรหัสผ่าน 8-72 ตัวอักษร และชื่อผู้ใช้จะเปลี่ยนภายหลังไม่ได้',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 11.5,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Flips between signing in and signing up. Both live on this one screen
/// because the API's register call has to be followed by a login anyway.
class _SwitchModeRow extends StatelessWidget {
  const _SwitchModeRow({required this.registering, required this.onPressed});

  final bool registering;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Wraps rather than a Row: on a 320pt phone the label and the link do not
    // share one line.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          registering ? 'มีบัญชีอยู่แล้ว?' : 'ยังไม่มีบัญชี?',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            registering ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก',
            style: const TextStyle(
              color: AppColors.brandPurple,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
