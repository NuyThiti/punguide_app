import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/trip_facts.dart';
import '../../../../shared/widgets/cover_image.dart';

/// Two-per-row trip card, from Figma node 2480-48940.
///
/// The type and the creator ride on the cover; the row beneath the title
/// leads with how far away the trip is. Every optional field the feed may
/// omit — cover, distance, schedule, creator — drops out of the layout rather
/// than blanking the card.
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
  static const double coverAspectRatio = 0.97;

  @override
  Widget build(BuildContext context) {
    final cover = trip.coverImage?.urls.large;
    final guide = trip.type == TripType.content;
    // One accent per card: the chip in front of the type label and the
    // distance pill are the same colour, so the type reads at a glance.
    final accent =
        guide ? AppColors.cardGuideAccent : AppColors.cardPlanAccent;

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
                  // Keeps the pills legible over a bright sky or a beach.
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
                    left: 8,
                    right: 8,
                    bottom: 10,
                    child: Row(
                      children: [
                        _TypePill(guide: guide, accent: accent),
                        const SizedBox(width: 6),
                        Flexible(child: _CreatorPill(creator: trip.creator)),
                      ],
                    ),
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
                      color: AppColors.cardTitle,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PlaceLine(
                    destination: trip.destination,
                    distanceLabel: distanceLabel,
                    accent: accent,
                    onAccent: guide
                        ? AppColors.cardTitle
                        : Colors.white,
                  ),
                  const SizedBox(height: 10),
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
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(
          saved ? Icons.bookmark : Icons.bookmark_border,
          size: 16,
          color: AppColors.cardPlanAccent,
        ),
      ),
    );
  }
}

/// The dark pill the cover's two labels share.
class _CoverPill extends StatelessWidget {
  const _CoverPill({required this.leading, required this.label});

  final Widget leading;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(3, 3, 9, 3),
      decoration: BoxDecoration(
        color: AppColors.cardCoverPill.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [leading, const SizedBox(width: 5), Flexible(child: label)],
      ),
    );
  }
}

/// "คู่มือ" or "แผนทริป", behind a badge in the card's accent.
class _TypePill extends StatelessWidget {
  const _TypePill({required this.guide, required this.accent});

  final bool guide;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _CoverPill(
      leading: Container(
        width: 16,
        height: 16,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        child: SvgPicture.asset(
          guide ? 'assets/icons/trip_guide.svg' : 'assets/icons/trip_plan.svg',
          width: 9,
          height: 9,
          colorFilter: ColorFilter.mode(
            // The glyph takes whichever of the two reads on its badge.
            guide ? AppColors.cardPlanAccent : Colors.white,
            BlendMode.srcIn,
          ),
        ),
      ),
      label: Text(
        guide ? 'คู่มือ' : 'แผนทริป',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Avatar and name, on the same pill as the type.
class _CreatorPill extends StatelessWidget {
  const _CreatorPill({required this.creator});

  /// Absent once the owner deletes their account.
  final TripCreator? creator;

  @override
  Widget build(BuildContext context) {
    final avatar = creator?.avatarUrl;

    return _CoverPill(
      leading: Container(
        width: 18,
        height: 18,
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white24,
          shape: BoxShape.circle,
        ),
        child: avatar != null
            ? CoverImage(source: avatar, fit: BoxFit.cover)
            : const Icon(Icons.person, size: 11, color: Colors.white),
      ),
      label: Text(
        creator?.name ?? 'ผู้ใช้ที่ถูกลบ',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The distance chip in the card's accent, then where the trip goes.
class _PlaceLine extends StatelessWidget {
  const _PlaceLine({
    required this.destination,
    required this.accent,
    required this.onAccent,
    this.distanceLabel,
  });

  final String destination;
  final Color accent;
  final Color onAccent;
  final String? distanceLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (distanceLabel case final label?) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: onAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        const Icon(
          Icons.location_on,
          size: 12,
          color: AppColors.cardPlanAccent,
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            destination,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.cardPlanAccent,
              fontSize: 11,
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
          child: Text.rich(
            TextSpan(
              children: [
                for (final (index, fact) in tripFactsParts(trip).indexed) ...[
                  if (index > 0)
                    const TextSpan(
                      text: ' • ',
                      style: TextStyle(color: AppColors.cardPlanAccent),
                    ),
                  TextSpan(text: fact),
                ],
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.cardFacts,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 6),
        ConstrainedBox(
          // Capped so a long duration + budget run can never push the counts
          // off a 320pt phone.
          constraints: const BoxConstraints(maxWidth: 72),
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
        Icon(icon, size: 13, color: AppColors.cardPlanAccent),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.cardFacts,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
