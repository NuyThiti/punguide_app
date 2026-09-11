import 'package:flutter/material.dart';

import '../../../home/presentation/widgets/pun_guide_card.dart';
import '../../domain/nearby_trip.dart';

export '../../../home/presentation/widgets/pun_guide_card.dart'
    show compactCount;

/// The ไปกัน board's card.
///
/// The board and Home draw the same card (Figma 1834-5085); this only unpacks
/// a [NearbyTrip] into the pieces [PunGuideCard] renders.
class PaigunCard extends StatelessWidget {
  const PaigunCard({
    super.key,
    required this.row,
    required this.onTap,
    required this.onSave,
  });

  final NearbyTrip row;
  final VoidCallback onTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return PunGuideCard(
      trip: row.trip,
      distanceLabel: row.distanceLabel,
      featured: row.featured,
      onTap: onTap,
      onSave: onSave,
    );
  }
}
