import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/extensions/currency_extensions.dart';
import '../../../../shared/models/trip_social_meta.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../trips/domain/models/trip.dart';

/// Compact two-per-row trip card used by the "Top PunGuide" grid.
class PunGuideCard extends StatelessWidget {
  const PunGuideCard({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onSave,
  });

  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback onSave;

  /// Cover proportions, and the fixed height of everything below it. The cover
  /// runs to the card edges, so its width is the tile width.
  ///
  /// [contentHeight] must clear a two-line title: 115 overflows such a tile by
  /// 7pt. Lowering it further means capping the title at one line first.
  static const double coverAspectRatio = 0.950;
  static const double contentHeight = 124;

  /// Tile height the grid should give a card of [tileWidth].
  static double tileExtentFor(double tileWidth) =>
      tileWidth / coverAspectRatio + contentHeight;

  @override
  Widget build(BuildContext context) {
    final meta = TripSocialMeta.fromTrip(trip);

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: coverAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverImage(source: trip.coverImage, fit: BoxFit.cover),
                  const Positioned(top: 10, left: 10, child: _RemixBadge()),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _SaveButton(saved: trip.isSaved, onTap: onSave),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.all(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _MetaLine(trip: trip),
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // The chip takes whatever the stats leave, and the stats
                      // are capped so a long handle can never push them out.
                      Expanded(child: _HandleChip(meta: meta)),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        // Capped low enough that the chip still clears its own
                        // minimum width on a 320pt phone.
                        constraints: const BoxConstraints(maxWidth: 64),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Stat(
                                icon: Icons.shuffle,
                                label: '${meta.remixes}',
                              ),
                              const SizedBox(width: 8),
                              _Stat(
                                icon: Icons.bookmark_border,
                                label: meta.saves,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemixBadge extends StatelessWidget {
  const _RemixBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 8, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shuffle, size: 9, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Top Remix',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saved, required this.onTap});

  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          saved ? Icons.bookmark : Icons.bookmark_border,
          size: 15,
          color: saved ? AppColors.brandOrange : AppColors.navIcon,
        ),
      ),
    );
  }
}

/// Location, duration and price on one run of text, split by bullets.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(right: 3),
              child: Icon(
                Icons.location_on,
                size: 11,
                color: AppColors.primary,
              ),
            ),
          ),
          TextSpan(text: trip.destination),
          const TextSpan(text: ' • '),
          TextSpan(text: '${trip.duration} วัน'),
          const TextSpan(text: ' • '),
          TextSpan(text: '${trip.budget.asBaht} /คน'),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 10,
        height: 1.3,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _HandleChip extends StatelessWidget {
  const _HandleChip({required this.meta});

  final TripSocialMeta meta;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(2, 2, 9, 2),
        decoration: BoxDecoration(
          color: AppColors.handleChip,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.handleChipRing, width: 1.5),
              ),
              child: Text(meta.avatar, style: const TextStyle(fontSize: 9)),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                meta.handle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.muted),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
