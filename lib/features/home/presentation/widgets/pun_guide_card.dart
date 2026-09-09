import 'package:flutter/material.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/extensions/currency_extensions.dart';
import '../../../../shared/widgets/cover_image.dart';

/// Compact two-per-row trip card used by the "Top PunGuide" grid.
///
/// Reads a feed row straight from the API, so every optional field the backend
/// may omit — cover, schedule, creator — has to degrade rather than blank the
/// card.
class PunGuideCard extends StatelessWidget {
  const PunGuideCard({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onSave,
  });

  final TripListItem trip;
  final VoidCallback onTap;
  final VoidCallback onSave;

  /// The cover runs to the card edges, so its width is the card width. Only
  /// the cover has a fixed shape — the card itself is as tall as whatever the
  /// text under it needs.
  static const double coverAspectRatio = 0.950;

  @override
  Widget build(BuildContext context) {
    final cover = trip.coverImage?.urls.large;

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
                  if (cover != null)
                    CoverImage(source: cover, fit: BoxFit.cover)
                  else
                    const _MissingCover(),
                  if (trip.remixCount > 0)
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
                      Expanded(child: _CreatorChip(creator: trip.creator)),
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
                                label: _compact(trip.remixCount),
                              ),
                              const SizedBox(width: 8),
                              _Stat(
                                icon: Icons.favorite_border,
                                label: _compact(trip.likeCount),
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

String _compact(int value) {
  if (value < 1000) return '$value';
  final thousands = value / 1000;
  return thousands >= 10
      ? '${thousands.round()}k'
      : '${thousands.toStringAsFixed(1)}k';
}

class _MissingCover extends StatelessWidget {
  const _MissingCover();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFEDEAE6),
      child: Center(
        child: Icon(Icons.photo_outlined, color: Color(0xFFB4ADA6), size: 26),
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
///
/// Duration and price are dropped rather than shown as zero — a feed row can
/// arrive with no schedule, and a trip with no costed plan totals 0.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.trip});

  final TripListItem trip;

  @override
  Widget build(BuildContext context) {
    final days = trip.schedule.durationDays;
    final facts = <String>[
      if (days != null && days > 0) '$days วัน',
      if (trip.totalBudget > 0) '${trip.totalBudget.asBaht} /คน',
    ];

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
          for (final fact in facts) ...[
            const TextSpan(text: ' • '),
            TextSpan(text: fact),
          ],
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

class _CreatorChip extends StatelessWidget {
  const _CreatorChip({required this.creator});

  /// Absent once the owner deletes their account.
  final TripCreator? creator;

  @override
  Widget build(BuildContext context) {
    final avatar = creator?.avatarUrl;

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
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.handleChipRing, width: 1.5),
              ),
              child: avatar != null
                  ? CoverImage(source: avatar, fit: BoxFit.cover)
                  : const Icon(
                      Icons.person,
                      size: 11,
                      color: AppColors.navIconMuted,
                    ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                creator?.name ?? 'ผู้ใช้ที่ถูกลบ',
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
