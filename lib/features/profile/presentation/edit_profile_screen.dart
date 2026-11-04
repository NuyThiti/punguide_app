import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../../shared/widgets/dark_sheet_header.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../location_access/data/location_sync.dart';
import 'profile_screen.dart' show profileCoverImage;

/// The place stored on the account, for the ตำแหน่งที่ตั้ง row.
///
/// Its own read rather than a shared one: this is the only screen that prints
/// the saved place by name, and it has to re-read after the picker returns.
final accountLocationProvider = FutureProvider.autoDispose<UserLocation?>(
  (ref) => ref.read(locationSyncProvider).pull(),
);

/// จัดการโปรไฟล์ — the one place a traveller edits who they are.
///
/// Only three things on an account can actually change: the picture, the
/// display name and the stored place. Username and email have no endpoint, so
/// they are shown as facts rather than as fields that would fail on save.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController();
  final _picker = ImagePicker();

  /// The name as the session had it when this page opened, so the Save button
  /// can tell "edited" from "retyped the same thing".
  String _savedName = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The *raw* name, not displayName: an account that never set one falls
    // back to its username for display, and pre-filling that would let a tap
    // on Save turn the username into the name without anyone typing it.
    final session = ref.read(authSessionProvider);
    _savedName = session?.name ?? '';
    _name.text = _savedName;
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _dirty => _name.text.trim() != _savedName.trim();
  bool get _canSave => _dirty && _name.text.trim().isNotEmpty && !_busy;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    return AppFrame(
      background: AppColors.screen,
      child: Column(
        children: [
          DarkSheetHeader(
            title: 'จัดการโปรไฟล์',
            coverImage: profileCoverImage,
            onBack: _close,
          ),
          Expanded(
            child: session == null
                ? const _EditNotice(message: 'เข้าสู่ระบบเพื่อแก้ไขโปรไฟล์')
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    children: [
                      Center(
                        child: _AvatarPicker(
                          avatar: session.avatarImage,
                          busy: _busy,
                          onTap: _pickAvatar,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _FieldLabel('ชื่อที่แสดง'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _name,
                        enabled: !_busy,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _canSave ? _saveName() : null,
                        decoration: InputDecoration(
                          // An account with no name shows its username
                          // everywhere, so that is what the hint promises.
                          hintText: session.name == null
                              ? session.handle.replaceFirst('@', '')
                              : 'ชื่อที่คนอื่นเห็น',
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
                      const SizedBox(height: 22),
                      _FieldLabel('ข้อมูลบัญชี'),
                      const SizedBox(height: 8),
                      // No endpoint changes either of these, so they are
                      // printed rather than offered as fields that would only
                      // fail on save.
                      _ReadOnlyRow(
                        icon: Icons.alternate_email,
                        label: 'ชื่อผู้ใช้',
                        value: session.handle,
                      ),
                      const _RowDivider(),
                      _ReadOnlyRow(
                        icon: Icons.mail_outline,
                        label: 'อีเมล',
                        value: session.email.isEmpty ? '—' : session.email,
                      ),
                      const SizedBox(height: 22),
                      _FieldLabel('ตำแหน่งที่ตั้ง'),
                      const SizedBox(height: 8),
                      _LocationRow(onTap: _pickLocation),
                      const SizedBox(height: 28),
                      _SaveButton(enabled: _canSave, onTap: _saveName),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar() async {
    if (_busy) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('เลือกจากคลังรูป'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('ถ่ายรูปใหม่'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      // The server caps an avatar at 5 MB; a phone photo is well past that
      // untouched, and nothing shows it larger than a small circle.
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    await _run(
      () => ref.read(authSessionProvider.notifier).updateAvatar(
            filePath: picked.path,
            filename: picked.name,
          ),
      done: 'อัปเดตรูปโปรไฟล์แล้ว',
    );
  }

  Future<void> _saveName() async {
    if (!_canSave) return;
    final name = _name.text.trim();
    await _run(
      () => ref.read(authSessionProvider.notifier).updateDisplayName(name),
      done: 'บันทึกชื่อแล้ว',
      onSuccess: () => _savedName = name,
    );
  }

  Future<void> _pickLocation() async {
    await context.pushNamed(AppRoute.locationPicker.name);
    if (!mounted) return;
    // The picker writes straight to the account, so the row re-reads rather
    // than trusting what it was showing before.
    ref.invalidate(accountLocationProvider);
  }

  /// One place for the spinner, the success line and the failure wording, so
  /// the two actions on this page cannot drift apart.
  Future<void> _run(
    Future<void> Function() action, {
    required String done,
    VoidCallback? onSuccess,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      onSuccess?.call();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.statusCode == 401
                ? 'เข้าสู่ระบบก่อน จึงจะแก้ไขโปรไฟล์ได้'
                : error.message,
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('บันทึกไม่สำเร็จ ลองอีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.profile.name);
    }
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.avatar,
    required this.busy,
    required this.onTap,
  });

  final String? avatar;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = this.avatar;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 104,
        height: 104,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 104,
              height: 104,
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.optionIconBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line, width: 2),
              ),
              child: avatar != null && avatar.isNotEmpty
                  ? CoverImage(source: avatar, fit: BoxFit.cover)
                  : const Icon(
                      Icons.person,
                      size: 48,
                      color: AppColors.navIconMuted,
                    ),
            ),
            if (busy)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 2,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(
                  Icons.photo_camera,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends ConsumerWidget {
  const _LocationRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(accountLocationProvider);
    final name = location.valueOrNull?.place.name;

    return Material(
      color: AppColors.optionIconBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 20,
                color: AppColors.foreground,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  location.isLoading
                      ? 'กำลังโหลด…'
                      : name ?? 'ยังไม่ได้ตั้งตำแหน่ง',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: name == null
                        ? AppColors.muted
                        : AppColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.navIconMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.navIconMuted),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.brandOrange : AppColors.optionIconBg,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17),
          child: Center(
            child: Text(
              'บันทึก',
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.foreground,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.black.withValues(alpha: 0.06),
    );
  }
}

class _EditNotice extends StatelessWidget {
  const _EditNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 48),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, size: 34, color: AppColors.navIconMuted),
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
