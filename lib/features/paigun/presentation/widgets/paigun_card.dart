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
    required this.liked,
    required this.onLike,
  });

  final NearbyTrip row;
  final VoidCallback onTap;
  final VoidCallback onSave;

  /// The heart as the app-wide like ledger has it. [NearbyTrip] does not carry
  /// it the way it carries the bookmark, so it is resolved by the wall and
  /// handed down.
  final bool liked;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return PunGuideCard(
      trip: row.trip,
      distanceLabel: row.distanceLabel,
      featured: row.featured,
      saved: row.isSaved,
      liked: liked,
      onTap: onTap,
      onSave: onSave,
      onLike: onLike,
    );
  }
}
