import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  Widget build(BuildContext context) {
    return AppFrame(
      background: AppColors.screen,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _LoginHeader(onClose: _close),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: _LoginIntro()),
                const SizedBox(height: 28),
                _SocialButton(
                  label: 'เข้าสู่ระบบด้วย Google',
                  leading: const _GoogleGlyph(),
                  onPressed: _isSubmitting ? null : _signInWithGoogle,
                ),
                if (_isSubmitting) ...[
                  const SizedBox(height: 20),
                  const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.brandOrange),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
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
