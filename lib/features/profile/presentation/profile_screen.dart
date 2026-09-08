import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/presentation/providers/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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

    return AppFrame(
      background: AppColors.screen,
      child: Stack(
        children: [
          Column(
            children: [
              const _ProfileHeader(),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    AppBottomNav.heightOf(context) + 16,
                  ),
                  children: [
                    _ProfileHero(session: session),
                    const SizedBox(height: 16),
                    const _StatsRow(),
                    const SizedBox(height: 22),
                    const _ProfileSection(
                      title: 'สไตล์การเที่ยว',
                      children: [
                        _PreferenceTile(
                          icon: Icons.beach_access,
                          title: 'ทะเลและเกาะ',
                          subtitle: 'เช้าสบาย ๆ น้ำใส และจุดชมพระอาทิตย์ตก',
                          color: AppColors.brandOrange,
                        ),
                        _PreferenceTile(
                          icon: Icons.restaurant,
                          title: 'สายกิน',
                          subtitle: 'ตลาดท้องถิ่น คาเฟ่ และเส้นทางชิมของอร่อย',
                          color: AppColors.brandPurple,
                        ),
                        _PreferenceTile(
                          icon: Icons.terrain,
                          title: 'ผจญภัยเบา ๆ',
                          subtitle: 'เดินเที่ยวได้ทั้งวัน กับหนึ่งกิจกรรมที่จำไม่ลืม',
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _ProfileSection(
                      title: 'บัญชี',
                      children: [
                        _PreferenceTile(
                          icon: Icons.sync,
                          title: 'พร้อมเชื่อมต่อระบบหลังบ้าน',
                          subtitle: 'ต่อ Supabase หรือ Firebase ได้จากตรงนี้',
                          color: AppColors.primary,
                        ),
                        _PreferenceTile(
                          icon: Icons.settings_outlined,
                          title: 'การตั้งค่า',
                          subtitle: 'ภาษา ความเป็นส่วนตัว และการแจ้งเตือน',
                          color: AppColors.navIcon,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _AuthSection(
                      session: session,
                      onSignIn: () => context.goNamed(AppRoute.login.name),
                      onSignOut: () => _confirmSignOut(context, ref),
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
              onCreate: () => context.goNamed(AppRoute.createTrip.name),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 12,
        16,
        14,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'โปรไฟล์',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 22,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.chipBorder),
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: AppColors.navIcon,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar, name and role, on the brand-orange card that echoes the create FAB.
/// Falls back to a guest presentation when there is no session.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.session});

  final AuthSession? session;

  @override
  Widget build(BuildContext context) {
    final session = this.session;
    final signedIn = session != null;
    final avatarImage = session?.avatarImage;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandOrange, AppColors.brandOrangeDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandOrange.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: signedIn ? null : Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 2,
              ),
            ),
            child: avatarImage != null
                ? CoverImage(source: avatarImage, fit: BoxFit.cover)
                : const Icon(Icons.person, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (signedIn) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'นักปันไกด์',
                      style: TextStyle(
                        color: AppColors.brandOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
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

/// Sign in / sign out, kept in its own section so the destructive action never
/// sits next to the ordinary settings rows.
class _AuthSection extends StatelessWidget {
  const _AuthSection({
    required this.session,
    required this.onSignIn,
    required this.onSignOut,
  });

  final AuthSession? session;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final session = this.session;

    return _ProfileSection(
      title: 'การเข้าสู่ระบบ',
      children: [
        if (session != null)
          _PreferenceTile(
            icon: Icons.logout,
            title: 'ออกจากระบบ',
            subtitle: 'ออกจากบัญชี ${session.handle} บนเครื่องนี้',
            color: AppColors.brandOrangeDeep,
            titleColor: AppColors.brandOrangeDeep,
            showChevron: false,
            onTap: onSignOut,
          )
        else
          _PreferenceTile(
            icon: Icons.login,
            title: 'เข้าสู่ระบบ',
            subtitle: 'บันทึกทริปและปันไกด์ให้เพื่อน ๆ ได้',
            color: AppColors.primary,
            titleColor: AppColors.primary,
            onTap: onSignIn,
          ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _StatCard(value: '12', label: 'ทริป')),
        SizedBox(width: 10),
        Expanded(child: _StatCard(value: '8', label: 'บันทึกไว้')),
        SizedBox(width: 10),
        Expanded(child: _StatCard(value: '4', label: 'รีมิกซ์')),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 0, 10),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          // Clipped so a tile's ink splash stops at the card's rounded edge.
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: _withDividers(children)),
        ),
      ],
    );
  }

  /// Hairlines between tiles only, so the card keeps one unbroken outer edge.
  List<Widget> _withDividers(List<Widget> tiles) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 14,
            endIndent: 14,
            color: Colors.black.withValues(alpha: 0.06),
          ),
        );
      }
      rows.add(tiles[i]);
    }
    return rows;
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.titleColor = AppColors.foreground,
    this.showChevron = true,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color titleColor;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.08),
        highlightColor: color.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.navIconMuted,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
