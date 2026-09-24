import 'package:flutter/material.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/trip_facts.dart';
import '../../../../shared/widgets/cover_image.dart';

/// One row of ทริปฉัน: cover, title, where it goes, and how it stands.
///
/// A wide row rather than the feed's two-per-row card on purpose — the owner
/// is scanning their own shelf for one trip, not browsing, and the two things
/// the feed card cannot show are exactly what they need: whether a trip is
/// still a draft, and a way into it.
class MyTripCard extends StatelessWidget {
  const MyTripCard({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final TripListItem trip;
  final VoidCallback onTap;

  /// Null on a post: the editor behind it is the plan editor, and a post has
  /// no plan to edit.
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  static const double coverSize = 92;

  @override
  Widget build(BuildContext context) {
    final cover = trip.coverImage?.urls.thumbnail;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: coverSize,
                    height: coverSize,
                    child: cover == null
                        ? const _MissingCover()
                        : CoverImage(source: cover, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _Details(trip: trip)),
                _TripMenu(onEdit: onEdit, onDelete: onDelete),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.trip});

  final TripListItem trip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 2),
        Text(
          trip.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 15,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.location_on, size: 12, color: AppColors.muted),
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
        const SizedBox(height: 8),
        Row(
          children: [
            _StatusChip(status: trip.status, type: trip.type),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tripFactsLine(trip),
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
    );
  }
}

/// Where the trip stands — the one thing a feed card never shows, because the
/// feed only carries trips that are already out in the world.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.type});

  final TripStatus status;
  final TripType type;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = _style;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  (String, Color, Color) get _style {
    // A post is never "3 วัน" or "ยืนยันแล้ว" — the states below are a plan's
    // life, so a post just says what it is.
    if (type == TripType.content) {
      return ('โพสต์', AppColors.postPurpleWell, AppColors.postPurple);
    }

    return switch (status) {
      TripStatus.draft => ('แบบร่าง', AppColors.postDraftBg, AppColors.muted),
      TripStatus.shared => (
          'แชร์แล้ว',
          AppColors.postPurpleWell,
          AppColors.postPurple,
        ),
      TripStatus.confirmed => (
          'ยืนยันแล้ว',
          AppColors.filterSelected,
          AppColors.filterSelectedText,
        ),
      TripStatus.completed => (
          'เที่ยวจบแล้ว',
          AppColors.handleChip,
          AppColors.primary,
        ),
    };
  }
}

class _TripMenu extends StatelessWidget {
  const _TripMenu({required this.onEdit, required this.onDelete});

  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<VoidCallback>(
      onSelected: (action) => action(),
      tooltip: 'ตัวเลือก',
      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.navIconMuted),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      itemBuilder: (context) => <PopupMenuEntry<VoidCallback>>[
        if (onEdit case final edit?)
          PopupMenuItem<VoidCallback>(
            value: edit,
            child: const _MenuRow(icon: Icons.edit_outlined, label: 'แก้ไข'),
          ),
        PopupMenuItem<VoidCallback>(
          value: onDelete,
          child: const _MenuRow(
            icon: Icons.delete_outline,
            label: 'ลบทริป',
            tint: AppColors.brandOrangeDeep,
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.tint});

  final IconData icon;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: tint ?? AppColors.navIconIdle),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: tint ?? AppColors.foreground,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MissingCover extends StatelessWidget {
  const _MissingCover();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFEDEAE6),
      child: Center(
        child: Icon(Icons.photo_outlined, color: Color(0xFFB4ADA6), size: 24),
      ),
    );
  }
}
