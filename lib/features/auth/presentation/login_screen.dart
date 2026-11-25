import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import '../domain/google_authenticator.dart';
import 'providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.then});

  /// Where to go once signed in — or once the screen is dismissed. Set when
  /// the screen opens the app rather than being asked for, so the launch
  /// sequence carries on to the next step instead of dropping onto Home.
  final String? then;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isSubmitting = false;

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
    _continue(router);
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

  void _continue(GoRouter router) {
    final then = widget.then;
    if (then != null) {
      router.go(then);
    } else {
      router.goNamed(AppRoute.home.name);
    }
  }

  void _close() {
    if (widget.then != null) {
      // Opened at launch: closing skips signing in, not the rest of the
      // sequence.
      _continue(GoRouter.of(context));
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.goNamed(AppRoute.home.name);
    }
  }

  /// Apple sign-in has no endpoint yet: the API exchanges a Firebase token at
  /// `POST /auth/firebase`, and only Google is enabled on that project.
  void _appleNotReady() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('เข้าสู่ระบบด้วย Apple ยังไม่เปิดให้ใช้งาน')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The artwork runs under the status bar, so its icons have to be light.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: AppFrame(
        background: _LoginPalette.background,
        child: Stack(
          children: [
            // Pinned to the top at its own aspect ratio rather than cropped to
            // fit: the artwork occupies the upper part of the image and the
            // rest is the same black as the screen, so the seam never shows.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/login_background.jpg',
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: _CloseButton(onTap: _close),
                  ),
                  const Spacer(),
                  const Text(
                    'Welcome!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 21),
                    child: Column(
                      children: [
                        _AuthButton(
                          label: 'เข้าสู่ระบบด้วย Google',
                          leading: Image.asset(
                            'assets/icons/google.png',
                            width: 22,
                            height: 22,
                          ),
                          busy: _isSubmitting,
                          onPressed:
                              _isSubmitting ? null : _signInWithGoogle,
                        ),
                        const SizedBox(height: 13),
                        _AuthButton(
                          label: 'เข้าสู่ระบบด้วย Apple',
                          leading: SvgPicture.asset(
                            'assets/icons/apple.svg',
                            width: 19,
                            height: 22,
                          ),
                          onPressed: _isSubmitting ? null : _appleNotReady,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Google creates the account on first use, so signing up and
                  // signing in are the same tap.
                  _SignUpRow(
                    onPressed: _isSubmitting ? null : _signInWithGoogle,
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginPalette {
  const _LoginPalette._();

  /// Matches the flat black the artwork fades into.
  static const background = Color(0xFF000000);
  static const buttonLabel = Color(0xFF232323);
  static const mutedLabel = Color(0xFFB9B4B4);
}

/// Not in the reference, which is a first-run welcome screen — but the login
/// route is also reachable from Profile and is skippable at launch, so there
/// has to be a way out.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'ปิด',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.only(right: 8, top: 4),
          alignment: Alignment.center,
          child: Icon(
            Icons.close,
            size: 22,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}

/// The white pill both providers share.
class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.leading,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(23),
        child: SizedBox(
          height: 46,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _LoginPalette.buttonLabel,
                      ),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      leading,
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _LoginPalette.buttonLabel,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SignUpRow extends StatelessWidget {
  const _SignUpRow({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'ยังไม่มีบัญชี?',
          style: TextStyle(
            color: _LoginPalette.mutedLabel,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'สมัครสมาชิก',
            style: TextStyle(
              color: AppColors.brandOrange,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
