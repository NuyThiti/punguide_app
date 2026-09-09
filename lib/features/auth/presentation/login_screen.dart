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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: _LoginIntro()),
                  const SizedBox(height: 28),
                  const _FieldLabel('อีเมลหรือชื่อผู้ใช้'),
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
                      hintText: 'name@example.com',
                      icon: Icons.mail_outline,
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
                      hintText: 'กรอกรหัสผ่าน',
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
                        tooltip:
                            _obscurePassword ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                      ),
                    ),
                  ),
                  if (_isRegistering) const _PasswordHint(),
                  const SizedBox(height: 18),
                  _PrimaryButton(
                    label: _isRegistering ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ',
                    busy: _isSubmitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 24),
                  const _OrDivider(),
                  const SizedBox(height: 20),
                  _SocialButton(
                    label: 'เข้าสู่ระบบด้วย Google',
                    leading: const _GoogleGlyph(),
                    onPressed: _isSubmitting ? null : _signInWithGoogle,
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: AppColors.line),
                  const SizedBox(height: 14),
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
    focusedBorder: border(AppColors.primary, 1.4),
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
  const _LoginHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 14, 20, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('บัญชีผู้ใช้',
                    style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('โปรไฟล์ การตั้งค่า และการเข้าสู่ระบบ',
                    style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: Color(0xFFF4F6F5), shape: BoxShape.circle),
              child: const Icon(Icons.close, color: AppColors.muted, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginIntro extends StatelessWidget {
  const _LoginIntro();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              color: Color(0xFFE7F5EF), shape: BoxShape.circle),
          child: const Icon(Icons.login, color: Color(0xFF159566), size: 28),
        ),
        const SizedBox(height: 16),
        const Text('เข้าสู่ระบบ',
            style: TextStyle(
                color: AppColors.foreground,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text(
          'เข้าสู่ระบบเพื่อบันทึกทริป สร้างแพลน และจัดการโปรไฟล์',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w400),
        ),
      ],
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
          color: AppColors.primary,
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
              'หรือ',
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
            border: Border.all(color: const Color(0xFFEBCF9E)),
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

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: Text('G',
            style: TextStyle(
                color: Color(0xFF4285F4),
                fontSize: 16,
                fontWeight: FontWeight.w900)),
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
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
