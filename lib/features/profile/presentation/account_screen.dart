import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/dark_sheet_header.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import 'profile_screen.dart' show profileCoverImage;

/// จัดการบัญชี — the sheet behind the profile's menu button (Figma 1539-8068).
///
/// The rows that used to sit on the profile itself live here now, which is
/// what frees the profile up to be the wall of trips the design wants.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'ออกจากระบบ',
          style: TextStyle(
            color: AppColors.foreground,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'ทริปที่บันทึกไว้จะยังอยู่ในบัญชีของคุณ',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'ยกเลิก',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'ออกจากระบบ',
              style: TextStyle(
                color: AppColors.brandOrangeDeep,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    ref.read(authSessionProvider.notifier).signOut();
    messenger.showSnackBar(const SnackBar(content: Text('ออกจากระบบแล้ว')));
    context.goNamed(AppRoute.home.name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authSessionProvider) != null;

    void unavailable(String message) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

    return AppFrame(
      background: AppColors.screen,
      child: Column(
        children: [
          DarkSheetHeader(
            title: 'จัดการบัญชี',
            coverImage: profileCoverImage,
            onBack: () => context.canPop()
                ? context.pop()
                : context.goNamed(AppRoute.profile.name),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Drafts are only ever listed by GET /trips/mine, so this is
                // the shelf they come from.
                AccountRow(
                  icon: Icons.edit_note,
                  label: 'Save Draft',
                  onTap: () => context.goNamed(AppRoute.myTrips.name),
                ),
                const _RowDivider(),
                AccountRow(
                  icon: Icons.bookmark_border,
                  label: 'บุ๊คมาร์คสถานที่',
                  onTap: () => unavailable('บุ๊คมาร์คสถานที่ยังไม่เปิดใช้งาน'),
                ),
                const _RowDivider(),
                AccountRow(
                  icon: Icons.settings_outlined,
                  label: 'ตั้งค่าระบบ',
                  onTap: () => unavailable('ตั้งค่าระบบยังไม่เปิดใช้งาน'),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.of(context).padding.bottom + 20,
            ),
            child: signedIn
                ? AccountFooterButton(
                    icon: Icons.logout,
                    label: 'ออกจากระบบ',
                    onTap: () => _confirmSignOut(context, ref),
                  )
                : AccountFooterButton(
                    icon: Icons.login,
                    label: 'เข้าสู่ระบบ',
                    onTap: () => context.goNamed(AppRoute.login.name),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One row of จัดการบัญชี: icon in a soft tile, label, chevron.
class AccountRow extends StatelessWidget {
  const AccountRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.optionIconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.foreground),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 15,
                  height: 1.2,
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
    );
  }
}

/// The pill at the foot of จัดการบัญชี.
class AccountFooterButton extends StatelessWidget {
  const AccountFooterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.optionIconBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppColors.foreground),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
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
