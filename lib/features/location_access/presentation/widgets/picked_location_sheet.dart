import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/picked_location.dart';

/// The card under the map: which place the pin is on, and the button that
/// settles it.
class PickedLocationSheet extends StatelessWidget {
  const PickedLocationSheet({
    super.key,
    required this.location,
    required this.onConfirm,
  });

  /// Null while nothing is pinned yet — the row then says so and the button
  /// goes inert, because confirming would set an origin nobody chose.
  final PickedLocation? location;

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final place = location;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.chipBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              _PlaceRow(place: place),
              const SizedBox(height: 16),
              _ConfirmButton(
                onTap: place == null ? null : onConfirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place});

  final PickedLocation? place;

  @override
  Widget build(BuildContext context) {
    final subtitle = place?.subtitle ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.postIconWell,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.screen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              size: 21,
              color: AppColors.locationPin,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  place?.name ?? 'ยังไม่ได้เลือกตำแหน่ง',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: enabled
            ? AppColors.locationAction
            : AppColors.locationAction.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: const Center(
            child: Text(
              'ยืนยันตำแหน่งนี้',
              style: TextStyle(
                color: Colors.white,
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
