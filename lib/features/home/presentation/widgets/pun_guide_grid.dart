import 'package:flutter/material.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../shared/models/feed_rows.dart';
import '../../../../shared/widgets/moderation_notice.dart';
import '../../../puntok/presentation/widgets/puntok_card.dart';
import 'pun_guide_card.dart';

/// The two-column wall of [PunGuideCard]s shared by Home and Search.
///
/// Two columns of naturally sized cards rather than a fixed-extent grid: a
/// card is as tall as its own title and meta, so nothing is padded out with
/// dead space and nothing can overflow a budgeted tile.
class PunGuideGrid extends StatelessWidget {
  const PunGuideGrid({
    super.key,
    required this.trips,
    required this.onOpen,
    this.onSave,
    this.onLike,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.distanceLabelOf,
    this.featuredOf,
    this.savedOf,
    this.likedOf,
    this.overlayOf,
    this.onDelete,
    this.moreOf,
    this.isMine = false,
  });

  final List<TripListItem> trips;
  final ValueChanged<TripListItem> onOpen;

  /// Null leaves the bookmark off every card — see [PunGuideCard.onSave].
  final ValueChanged<TripListItem>? onSave;

  /// Null leaves the heart a readout on every card — see [PunGuideCard.onLike].
  final ValueChanged<TripListItem>? onLike;
  final EdgeInsetsGeometry padding;

  /// "2.3 Km" for a row, or null to leave the violet chip off. Search has no
  /// origin to measure from, so it passes neither of these.
  final String? Function(TripListItem trip)? distanceLabelOf;

  /// Whether a row wears the Top PunGuide badge.
  final bool Function(TripListItem trip)? featuredOf;

  /// Resolves the bookmark when something outside the row tracks it.
  final bool Function(TripListItem trip)? savedOf;

  /// Resolves the heart when something outside the row tracks it — the
  /// app-wide like ledger, which every wall reads through.
  final bool Function(TripListItem trip)? likedOf;

  /// Something to lay over a card's top-left corner — Save Draft's "Editing"
  /// tag. Null for rows that carry none. Stacked at the wall rather than
  /// threaded through both card types, so one hook covers both.
  final Widget? Function(TripListItem trip)? overlayOf;

  /// Turns every card's corner button into a delete. Passed only by walls of
  /// the traveller's own trips — the album grid is a different widget and
  /// never gets one.
  final ValueChanged<TripListItem>? onDelete;

  /// The ⋯ (report / block) for a row, or null to leave it off — null for
  /// the viewer's own rows, which is why it is asked per row rather than
  /// settled for the wall. See `tripMoreOf` in the safety feature.
  final VoidCallback? Function(TripListItem trip)? moreOf;

  /// Whether this whole wall is the traveller's own trips — see
  /// [PunGuideCard.isMine]. A wall is one person's or it is not, so this is
  /// settled once here rather than asked per row.
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final left = <TripListItem>[];
    final right = <TripListItem>[];
    for (var i = 0; i < trips.length; i++) {
      (i.isEven ? left : right).add(trips[i]);
    }

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _column(left)),
          const SizedBox(width: 12),
          Expanded(child: _column(right)),
        ],
      ),
    );
  }

  Widget _column(List<TripListItem> column) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final trip in column)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _withOverlay(
              trip,
              // A clip has no itinerary to print, so it gets the plainer
              // card. Where the tap goes is still the caller's business.
              trip.isClip
                  ? PuntokCard(
                      trip: trip,
                      onTap: () => onOpen(trip),
                      onDelete: _deleteFor(trip),
                      onMore: moreOf?.call(trip),
                    )
                  : PunGuideCard(
                      trip: trip,
                      distanceLabel: distanceLabelOf?.call(trip),
                      featured: featuredOf?.call(trip) ?? false,
                      saved: savedOf?.call(trip),
                      liked: likedOf?.call(trip),
                      isMine: isMine,
                      onTap: () => onOpen(trip),
                      onSave: _saveFor(trip),
                      onLike: _likeFor(trip),
                      onDelete: _deleteFor(trip),
                      onMore: moreOf?.call(trip),
                    ),
            ),
          ),
      ],
    );
  }

  VoidCallback? _saveFor(TripListItem trip) {
    final onSave = this.onSave;
    return onSave == null ? null : () => onSave(trip);
  }

  VoidCallback? _likeFor(TripListItem trip) {
    final onLike = this.onLike;
    return onLike == null ? null : () => onLike(trip);
  }

  VoidCallback? _deleteFor(TripListItem trip) {
    final onDelete = this.onDelete;
    return onDelete == null ? null : () => onDelete(trip);
  }

  /// Stacks the card's top-left corner: the content-check badge first, then
  /// whatever the caller lays on top of it.
  ///
  /// The badge needs no parameter and no caller change — only
  /// `GET /trips/mine` sends `moderation`, and only to the owner, so a wall
  /// built from any other list has nothing to draw and draws nothing.
  Widget _withOverlay(TripListItem trip, Widget card) {
    final overlay = overlayOf?.call(trip);
    final moderation = trip.moderation;
    final badge = isModerationWorthShowing(moderation)
        ? ModerationBadge(status: moderation!.status)
        : null;
    if (overlay == null && badge == null) return card;

    return Stack(
      children: [
        card,
        Positioned(
          top: 10,
          left: 10,
          // Leaves room for the corner button on the right, so a long badge
          // ellipsises rather than running under it.
          right: 46,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge != null) badge,
              if (badge != null && overlay != null) const SizedBox(height: 6),
              if (overlay != null) overlay,
            ],
          ),
        ),
      ],
    );
  }
}
