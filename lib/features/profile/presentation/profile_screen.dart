import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/create_sheet.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/presentation/providers/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// The header photo behind the avatar. The API has no cover-image field, so
  /// every profile shows the same bundled shot until one exists.
  static const _coverImage = 'assets/images/puntok_osaka.jpg';

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
          'ทริปที่บันทึกไว้จะยังอยู่ในเครื่องของคุณ',
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

    if (confirmed != true) return;
    ref.read(authSessionProvider.notifier).signOut();
    messenger.showSnackBar(const SnackBar(content: Text('ออกจากระบบแล้ว')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);

    void unavailable(String message) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

    return AppFrame(
      background: AppColors.screen,
      child: Stack(
        children: [
          ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: AppBottomNav.heightOf(context) + 16,
            ),
            children: [
              ProfileHero(
                session: session,
                coverImage: _coverImage,
                onEditAvatar: () =>
                    unavailable('แก้ไขรูปโปรไฟล์ยังไม่เปิดใช้งาน'),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ProfileMenuRow(
                      icon: Icons.luggage_outlined,
                      label: 'ทริปของฉัน',
                      onTap: () => context.goNamed(AppRoute.savedTrips.name),
                    ),
                    ProfileMenuRow(
                      icon: Icons.grid_view_outlined,
                      label: 'โพสต์ของฉัน',
                      onTap: () => unavailable('โพสต์ของฉันยังไม่เปิดใช้งาน'),
                    ),
                    ProfileMenuRow(
                      icon: Icons.shuffle,
                      label: 'รีมิกซ์ของฉัน',
                      onTap: () => unavailable('รีมิกซ์ของฉันยังไม่เปิดใช้งาน'),
                    ),
                    ProfileMenuRow(
                      icon: Icons.bookmark_border,
                      label: 'บุ๊กมาร์คสถานที่',
                      onTap: () =>
                          unavailable('บุ๊กมาร์คสถานที่ยังไม่เปิดใช้งาน'),
                    ),
                    ProfileMenuRow(
                      icon: Icons.settings_outlined,
                      label: 'ตั้งค่าระบบ',
                      onTap: () => unavailable('ตั้งค่าระบบยังไม่เปิดใช้งาน'),
                    ),
                    const SizedBox(height: 8),
                    // Not in the Figma frame, but the reference has no other
                    // way out of the account, so the session control stays.
                    if (session != null)
                      ProfileMenuRow(
                        icon: Icons.logout,
                        label: 'ออกจากระบบ',
                        tint: AppColors.brandOrangeDeep,
                        onTap: () => _confirmSignOut(context, ref),
                      )
                    else
                      ProfileMenuRow(
                        icon: Icons.login,
                        label: 'เข้าสู่ระบบ',
                        tint: AppColors.primary,
                        onTap: () => context.goNamed(AppRoute.login.name),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNav(
              active: AppRoute.profile,
              onTap: (route) => context.goNamed(route.name),
              onCreate: () => openCreateSheet(
                context,
                onOwnPlan: () => context.goNamed(AppRoute.createTrip.name),
                onUnavailable: unavailable,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cover photo, avatar, name and the counts strip — the dark card the profile
/// opens on. Falls back to a guest presentation when there is no session.
class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.session,
    required this.coverImage,
    required this.onEditAvatar,
  });

  final AuthSession? session;
  final String coverImage;
  final VoidCallback onEditAvatar;

  static const double avatarSize = 92;

  @override
  Widget build(BuildContext context) {
    final session = this.session;
    final signedIn = session != null;
    final avatarImage = session?.avatarImage;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Stack(
        children: [
          Positioned.fill(
            child: CoverImage(source: coverImage, fit: BoxFit.cover),
          ),
          // The reference card is nearly black; the photo only shows through
          // as texture, which is what keeps the white type readable.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.86),
                    Colors.black.withValues(alpha: 0.76),
                    Colors.black.withValues(alpha: 0.90),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 16,
              20,
              18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Avatar(
                  avatarImage: avatarImage,
                  showEdit: signedIn,
                  onEdit: onEditAvatar,
                ),
                const SizedBox(height: 12),
                Text(
                  session?.displayName ?? 'ผู้เยี่ยมชม',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  session?.handle ?? 'ยังไม่ได้เข้าสู่ระบบ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (signedIn) ...[
                  const SizedBox(height: 16),
                  const ProfileStatsStrip(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.avatarImage,
    required this.showEdit,
    required this.onEdit,
  });

  final String? avatarImage;
  final bool showEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    const size = ProfileHero.avatarSize;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: avatarImage != null && avatarImage!.isNotEmpty
                ? CoverImage(source: avatarImage!, fit: BoxFit.cover)
                : const Icon(Icons.person, color: Colors.white, size: 44),
          ),
          if (showEdit)
            Positioned(
              right: -2,
              bottom: 4,
              child: GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Remix / Like / Follower / Following on one frosted strip.
///
/// The API returns none of these counts yet, so the figures are the ones from
/// the design and are not read from the session.
class ProfileStatsStrip extends StatelessWidget {
  const ProfileStatsStrip({super.key});

  static const stats = <(String, String)>[
    ('2.9K', 'Remix'),
    ('1K', 'Like'),
    ('828', 'Follower'),
    ('342', 'Following'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final (value, label) in stats)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One tappable row of the profile menu: icon, label, chevron.
class ProfileMenuRow extends StatelessWidget {
  const ProfileMenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Colours the icon and label — used by the session row so the destructive
  /// action does not read as one more navigation row.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final tint = this.tint;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
              child: Row(
                children: [
                  Icon(icon, size: 21, color: tint ?? AppColors.navIconIdle),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tint ?? AppColors.foreground,
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
          ),
        ),
      ),
    );
  }
}
