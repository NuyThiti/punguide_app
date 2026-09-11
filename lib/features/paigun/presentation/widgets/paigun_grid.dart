import 'package:flutter/material.dart';

import '../../domain/nearby_trip.dart';
import 'paigun_card.dart';

/// The two-column wall of [PaigunCard]s under each section heading.
///
/// Two columns of naturally sized cards rather than a fixed-extent grid, for
/// the same reason the Home wall is: a card is as tall as its own title and
/// meta, so nothing is padded out with dead space and nothing overflows.
class PaigunGrid extends StatelessWidget {
  const PaigunGrid({
    super.key,
    required this.rows,
    required this.onOpen,
    required this.onSave,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<NearbyTrip> rows;
  final ValueChanged<NearbyTrip> onOpen;
  final ValueChanged<NearbyTrip> onSave;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final left = <NearbyTrip>[];
    final right = <NearbyTrip>[];
    for (var i = 0; i < rows.length; i++) {
      (i.isEven ? left : right).add(rows[i]);
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

  Widget _column(List<NearbyTrip> column) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in column)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: PaigunCard(
              row: row,
              onTap: () => onOpen(row),
              onSave: () => onSave(row),
            ),
          ),
      ],
    );
  }
}
