import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The card that rises over the illustration on the Location Access page:
/// why the app wants the traveller's position, and the two ways out of it.
///
/// The OS dialog in the design sits *above* this — iOS draws it itself, so
/// there is nothing here to build for it.
class LocationPermissionSheet extends StatelessWidget {
  const LocationPermissionSheet({
    super.key,
    required this.onAllow,
    required this.onLater,
    this.busy = false,
  });

  final VoidCallback onAllow;
  final VoidCallback onLater;

  /// While the permission request is in flight. The buttons go inert rather
  /// than disappearing, so the sheet does not resize under the thumb.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'อนุญาติการเข้าถึงตำแหน่ง\nเพื่อดูทริปใกล้ตัวคุณ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 20,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'เพื่อแสดงการค้นหาทริป และสถานที่ท่องเที่ยวที่อยู่ใกล้คุณ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              _SheetButton(
                label: 'อนุญาต',
                background: AppColors.locationAction,
                foreground: Colors.white,
                onTap: busy ? null : onAllow,
              ),
              const SizedBox(height: 12),
              _SheetButton(
                label: 'ไว้ทีหลังนะ',
                background: AppColors.locationLater,
                foreground: AppColors.locationAction,
                onTap: busy ? null : onLater,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;

  /// Null while the sheet is busy — the fill dims to say so.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: enabled ? background : background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
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
