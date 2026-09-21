import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';

/// Bottom navigation drawn from the `Union` shape in Figma: a rounded bar with
/// a bump in the middle that cradles the create-trip button.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.active,
    required this.onTap,
    required this.onCreate,
  });

  final AppRoute active;
  final ValueChanged<AppRoute> onTap;
  final VoidCallback onCreate;

  static const double bumpHeight = 14;
  static const double barHeight = 64;
  static const double fabSize = 56;

  /// Height the nav occupies, so scroll views can reserve room for it.
  static double heightOf(BuildContext context) =>
      bumpHeight + barHeight + MediaQuery.of(context).padding.bottom;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: bumpHeight + barHeight + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: const _NotchedBarPainter()),
          ),
          Positioned(
            top: bumpHeight,
            left: 0,
            right: 0,
            height: barHeight,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset > 0 ? 0 : 6),
              child: Row(
                children: [
                  _NavItem(
                    asset: active == AppRoute.home
                        ? 'assets/icons/nav_home_filled.svg'
                        : 'assets/icons/nav_home.svg',
                    label: 'Home',
                    selected: active == AppRoute.home,
                    onTap: () => onTap(AppRoute.home),
                  ),
                  _NavItem(
                    asset: 'assets/icons/nav_paigun.svg',
                    label: 'Paigun',
                    // Search is the ไปกัน board's own filter surface, so the tab
                    // stays lit while the traveller is over there.
                    selected:
                        active == AppRoute.paigun || active == AppRoute.search,
                    onTap: () => onTap(AppRoute.paigun),
                  ),
                  const SizedBox(width: fabSize + 24),
                  _NavItem(
                    asset: 'assets/icons/nav_puntok.svg',
                    label: 'Puntok',
                    selected: active == AppRoute.puntok ||
                        active == AppRoute.discover,
                    onTap: () => onTap(AppRoute.puntok),
                  ),
                  _NavItem(
                    asset: 'assets/icons/nav_profile.svg',
                    label: 'Profile',
                    selected: active == AppRoute.profile,
                    onTap: () => onTap(AppRoute.profile),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            // Sits a little below the bump crest so it reads level with the
            // icon row rather than floating above the bar.
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: onCreate,
                child: Container(
                  width: fabSize,
                  height: fabSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.brandOrange,
                        AppColors.brandOrangeDeep,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandOrange.withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brandOrange : AppColors.navIconMuted;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              asset,
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the bar body plus the outward bump that the FAB sits in.
class _NotchedBarPainter extends CustomPainter {
  const _NotchedBarPainter();

  static const double _cornerRadius = 26;
  static const double _bumpSpan = 84;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.35), 12, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  Path _buildPath(Size size) {
    const bump = AppBottomNav.bumpHeight;
    final width = size.width;
    final centerX = width / 2;
    final left = centerX - _bumpSpan / 2;
    final right = centerX + _bumpSpan / 2;

    return Path()
      ..moveTo(0, size.height)
      ..lineTo(0, bump + _cornerRadius)
      ..quadraticBezierTo(0, bump, _cornerRadius, bump)
      ..lineTo(left, bump)
      // Fillet into the bump, over the crest, and back down the other side.
      ..cubicTo(left + 14, bump, left + 12, 0, centerX, 0)
      ..cubicTo(right - 12, 0, right - 14, bump, right, bump)
      ..lineTo(width - _cornerRadius, bump)
      ..quadraticBezierTo(width, bump, width, bump + _cornerRadius)
      ..lineTo(width, size.height)
      ..close();
  }

  @override
  bool shouldRepaint(_NotchedBarPainter oldDelegate) => false;
}
