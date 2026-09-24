import 'package:flutter/material.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/trip_facts.dart';
import '../../../../shared/widgets/cover_image.dart';

/// Two-per-row trip card, from Figma node 1834-5085.
///
/// The creator rides on the cover rather than under it, and the row beneath
/// the title leads with how far away the trip is. Every optional field the
/// feed may omit — cover, distance, schedule, creator — drops out of the
/// layout rather than blanking the card.
///
/// [distanceLabel] and [featured] are passed in already resolved so the card
/// stays a pure view: Home and the ไปกัน board work them out from the same
/// feed, and Search leaves both off.
class PunGuideCard extends StatelessWidget {
  const PunGuideCard({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onSave,
    this.distanceLabel,
    this.featured = false,
    this.saved,
  });

  final TripListItem trip;
  final VoidCallback onTap;
  final VoidCallback onSave;

  /// "2.3 Km", or null when the destination has no coordinates.
  final String? distanceLabel;

  /// Whether this row wears the Top PunGuide badge.
  final bool featured;

  /// The bookmark as it stands now, when something outside the row is keeping
  /// track — the board flips one on a card that sits in two walls at once.
  /// Null falls back to what the row itself came back with.
  final bool? saved;

  /// Only the cover has a fixed shape; the card is as tall as its own text.
  static const double coverAspectRatio = 0.9;

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
                  // Keeps the creator legible over a bright sky or a beach.
                  const _CoverScrim(),
                  if (featured)
                    const Positioned(
                      top: 10,
                      left: 10,
                      child: _FeaturedBadge(),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _SaveButton(
                      saved: saved ?? trip.isSaved,
                      onTap: onSave,
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: _CreatorLine(creator: trip.creator),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PlaceLine(
                    destination: trip.destination,
                    distanceLabel: distanceLabel,
                  ),
                  const SizedBox(height: 9),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                  const SizedBox(height: 9),
                  _StatsLine(trip: trip),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "3.5K" — compact enough for a card half a phone wide.
///
/// A round thousand loses its decimal: the design prints "2K", not "2.0K".
String compactCount(int value) {
  if (value < 1000) return '$value';
  final thousands = value / 1000;
  if (thousands >= 10) return '${thousands.round()}K';

  final text = thousands.toStringAsFixed(1);
  return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}K';
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

class _CoverScrim extends StatelessWidget {
  const _CoverScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const [0, 0.38, 1],
          colors: [
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.12),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _FeaturedBadge extends StatelessWidget {
  const _FeaturedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 9, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Text(
        'Top PunGuide',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
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
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          shape: BoxShape.circle,
        ),
        child: Icon(
          saved ? Icons.bookmark : Icons.bookmark_border,
          size: 16,
          color: saved ? AppColors.brandOrange : AppColors.navIcon,
        ),
      ),
    );
  }
}

/// Avatar and handle over the foot of the cover.
class _CreatorLine extends StatelessWidget {
  const _CreatorLine({required this.creator});

  /// Absent once the owner deletes their account.
  final TripCreator? creator;

  @override
  Widget build(BuildContext context) {
    final avatar = creator?.avatarUrl;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: avatar != null
              ? CoverImage(source: avatar, fit: BoxFit.cover)
              : const Icon(
                  Icons.person,
                  size: 13,
                  color: AppColors.navIconMuted,
                ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            creator?.name ?? 'ผู้ใช้ที่ถูกลบ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
            ),
          ),
        ),
      ],
    );
  }
}

/// The violet distance chip and where the trip goes.
class _PlaceLine extends StatelessWidget {
  const _PlaceLine({required this.destination, this.distanceLabel});

  final String destination;
  final String? distanceLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (distanceLabel case final label?) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.paigunDistance,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        const Icon(Icons.location_on, size: 11, color: AppColors.muted),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            destination,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// What the trip is made of on the left, remixes and saves on the right.
///
/// The left half is [tripFactsLine], so a post prints its places where a plan
/// prints its days and budget rather than leaving the line blank.
class _StatsLine extends StatelessWidget {
  const _StatsLine({required this.trip});

  final TripListItem trip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            tripFactsLine(trip),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 6),
        ConstrainedBox(
          // Capped so a long duration + budget run can never push the counts
          // off a 320pt phone.
          constraints: const BoxConstraints(maxWidth: 76),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Stat(
                  icon: Icons.shuffle,
                  label: compactCount(trip.remixCount),
                ),
                const SizedBox(width: 10),
                _Stat(
                  icon: Icons.bookmark_border,
                  label: compactCount(trip.likeCount),
                ),
              ],
            ),
          ),
        ),
      ],
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
        Icon(icon, size: 12, color: AppColors.muted),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
