import 'package:flutter/material.dart';

import '../../../../core/api/pluno_api.dart';
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
    required this.onSave,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.distanceLabelOf,
    this.featuredOf,
  });

  final List<TripListItem> trips;
  final ValueChanged<TripListItem> onOpen;
  final ValueChanged<TripListItem> onSave;
  final EdgeInsetsGeometry padding;

  /// "2.3 Km" for a row, or null to leave the violet chip off. Search has no
  /// origin to measure from, so it passes neither of these.
  final String? Function(TripListItem trip)? distanceLabelOf;

  /// Whether a row wears the Top PunGuide badge.
  final bool Function(TripListItem trip)? featuredOf;

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
            child: PunGuideCard(
              trip: trip,
              distanceLabel: distanceLabelOf?.call(trip),
              featured: featuredOf?.call(trip) ?? false,
              onTap: () => onOpen(trip),
              onSave: () => onSave(trip),
            ),
          ),
      ],
    );
  }
}
