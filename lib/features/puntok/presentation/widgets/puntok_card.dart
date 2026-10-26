import 'package:flutter/material.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';

/// A clip's card on a wall of trips.
///
/// Deliberately plainer than [PunGuideCard]: a Puntok has no itinerary, no
/// budget and no schedule to print, so the card is the still, the title and
/// where it was shot. Tapping it opens the clip full screen rather than the
/// trip page.
class PuntokCard extends StatelessWidget {
  const PuntokCard({super.key, required this.trip, required this.onTap});

  final TripListItem trip;
  final VoidCallback onTap;

  /// Matches [PunGuideCard.coverAspectRatio] so clips and plans line up when
  /// a wall holds both.
  static const double coverAspectRatio = 0.97;

  @override
  Widget build(BuildContext context) {
    // Null when the server had no poster to cut and filled `large` with the
    // video file itself — the placeholder stands in rather than a broken box.
    final still = trip.coverImage?.stillUrl;

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
              child: still == null
                  ? const ColoredBox(
                      color: AppColors.optionIconBg,
                      child: Center(
                        child: Icon(
                          Icons.videocam_outlined,
                          size: 28,
                          color: AppColors.navIconMuted,
                        ),
                      ),
                    )
                  : CoverImage(source: still, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          trip.destination,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
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
