import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/dark_sheet_header.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import 'profile_screen.dart' show profileCoverImage;

/// Whether an account can actually be deleted. Live since 2026-11-03, when
/// `DELETE /users/me` shipped.
const accountDeleteEnabled = true;

/// ลบบัญชี — reached from the foot of จัดการบัญชี.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;

  /// Set when the server answers `400` — this account has a password and the
  /// request went without one.
  bool _passwordDemanded = false;

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirm.dispose();
    _password.dispose();
    super.dispose();
  }

  /// An account with no email never signed in with Google, so it must have a
  /// password. One *with* an email may be Google-only or may also have a
  /// password — unknowable from the user model, so the field stays optional
  /// and the server decides with its `400`.
  bool _passwordRequired(AuthSession session) =>
      session.email.isEmpty || _passwordDemanded;

  /// The username without its leading `@`, which is what has to be typed.
  String _usernameOf(String handle) => handle.replaceFirst('@', '');

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final username = session == null ? '' : _usernameOf(session.handle);
    final typedMatches =
        _confirm.text.trim() == username && username.isNotEmpty;
    final needsPassword = session != null && _passwordRequired(session);
    final hasPassword = _password.text.isNotEmpty;
    final armed = typedMatches && (!needsPassword || hasPassword) && !_busy;

    return AppFrame(
      background: AppColors.screen,
      child: Column(
        children: [
          DarkSheetHeader(
            title: 'ลบบัญชี',
            coverImage: profileCoverImage,
            onBack: _close,
          ),
          Expanded(
            child: session == null
                ? const _DeleteNotice(
                    message: 'เข้าสู่ระบบก่อน จึงจะลบบัญชีได้')
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    children: [
                      // Said before the form, not after it: nobody should type
                      // their username to steel themselves and only then be
                      // told it was never going to work.
                      if (!accountDeleteEnabled) const _UnavailableBanner(),
                      const Text(
                        'การลบบัญชีจะเอาสิ่งเหล่านี้ออกถาวร',
                        style: TextStyle(
                          color: AppColors.foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const _LossRow(
                        icon: Icons.luggage_outlined,
                        text: 'แผนทริปและโพสต์ทั้งหมดของคุณ',
                      ),
                      const _LossRow(
                        icon: Icons.smart_display_outlined,
                        text: 'คลิป Puntok และรูปที่อัปโหลดไว้',
                      ),
                      const _LossRow(
                        icon: Icons.bookmark_border,
                        text: 'ทริปที่บันทึกไว้และตำแหน่งที่ตั้ง',
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'เมื่อลบแล้วกู้คืนไม่ได้ และชื่อผู้ใช้เดิมอาจถูกคนอื่นใช้',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'พิมพ์ "$username" เพื่อยืนยัน',
                        style: const TextStyle(
                          color: AppColors.foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _confirm,
                        enabled: accountDeleteEnabled,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          hintText: username,
                          filled: true,
                          fillColor: AppColors.optionIconBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      if (needsPassword) ...[
                        const SizedBox(height: 18),
                        const Text(
                          'รหัสผ่าน',
                          style: TextStyle(
                            color: AppColors.foreground,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _password,
                          enabled: accountDeleteEnabled && !_busy,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            hintText: 'รหัสผ่านของบัญชีนี้',
                            filled: true,
                            fillColor: AppColors.optionIconBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _DeleteButton(
                        enabled: accountDeleteEnabled && armed,
                        busy: _busy,
                        onTap: _delete,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(authSessionProvider.notifier).deleteAccount(
            password: _password.text.isEmpty ? null : _password.text,
          );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('ลบบัญชีแล้ว')));
      // The sessions are gone server-side, so there is nothing to go back to.
      context.goNamed(AppRoute.login.name);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // 400 is the server saying this account does have a password.
        if (error.statusCode == 400) _passwordDemanded = true;
      });
      messenger.showSnackBar(SnackBar(content: Text(_reasonFor(error))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('ลบบัญชีไม่สำเร็จ ลองอีกครั้ง')),
      );
    }
  }

  /// `403` is a wrong password, never an expired token — the API uses it
  /// precisely so this screen does not mistake one for the other.
  String _reasonFor(ApiException error) => switch (error.statusCode) {
        400 => 'บัญชีนี้ตั้งรหัสผ่านไว้ กรอกรหัสผ่านเพื่อยืนยัน',
        403 => 'รหัสผ่านไม่ถูกต้อง',
        401 => 'เซสชันหมดอายุ เข้าสู่ระบบใหม่แล้วลองอีกครั้ง',
        _ => 'ลบบัญชีไม่สำเร็จ ลองอีกครั้ง',
      };

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.profileAccount.name);
    }
  }
}

class _UnavailableBanner extends StatelessWidget {
  const _UnavailableBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.optionIconBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 20,
            color: AppColors.brandOrangeDeep,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'ยังลบบัญชีจากในแอปไม่ได้ ระบบหลังบ้านยังไม่เปิดให้ลบ '
              'ถ้าต้องการลบตอนนี้ กรุณาติดต่อทีมงาน',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LossRow extends StatelessWidget {
  const _LossRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.navIconMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.brandOrangeDeep : AppColors.optionIconBg,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'ลบบัญชีถาวร',
                    style: TextStyle(
                      color: enabled ? Colors.white : AppColors.navIconMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _DeleteNotice extends StatelessWidget {
  const _DeleteNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 48),
      child: Column(
        children: [
          const Icon(Icons.lock_outline,
              size: 34, color: AppColors.navIconMuted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
