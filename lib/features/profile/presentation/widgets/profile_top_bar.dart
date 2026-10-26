import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The bar pinned above the profile: back on the left, จัดการบัญชี on the
/// right, and the traveller's name once the hero has scrolled out from under
/// it.
///
/// It sits over the hero rather than above it, so at rest the glyphs read as
/// part of the cover photo exactly as the design has them. [progress] drives
/// the hand-off — 0 while the hero is in view, 1 once it is gone — which is
/// what lets the glyphs flip from white to dark without ever being invisible
/// against the wall behind them.
class ProfileTopBar extends StatelessWidget {
  const ProfileTopBar({
    super.key,
    required this.progress,
    required this.title,
    required this.onBack,
    required this.onMenu,
  });

  /// 0 = over the hero, 1 = over the wall. Anything between crossfades.
  final double progress;

  final String title;
  final VoidCallback onBack;
  final VoidCallback onMenu;

  /// Height of the bar itself, above the status bar.
  static const double barHeight = 48;

  static double heightOf(BuildContext context) =>
      MediaQuery.of(context).padding.top + barHeight;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final glyph = Color.lerp(Colors.white, AppColors.foreground, t)!;

    return Container(
      height: heightOf(context),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 10,
        right: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: t),
        border: Border(
          bottom: BorderSide(
            color: AppColors.line.withValues(alpha: t),
          ),
        ),
      ),
      child: Row(
        children: [
          _BarButton(
            icon: Icons.chevron_left,
            tooltip: 'ย้อนกลับ',
            color: glyph,
            // The disc only earns its keep over the photo; once the bar is
            // solid it would be a grey blob around a dark glyph.
            discOpacity: (1 - t) * 0.18,
            size: 26,
            onTap: onBack,
          ),
          Expanded(
            child: Opacity(
              opacity: t,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _BarButton(
            icon: Icons.menu,
            tooltip: 'จัดการบัญชี',
            color: glyph,
            discOpacity: 0,
            size: 22,
            onTap: onMenu,
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.discOpacity,
    required this.size,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final double discOpacity;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: discOpacity),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: size),
        ),
      ),
    );
  }
}
