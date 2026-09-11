import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/api/pluno_api.dart';

/// A feed row as the ไปกัน board shows it: the trip, how far its destination
/// sits from where the traveller is, and whether it earned the Top PunGuide
/// badge.
///
/// [distanceKm] is null whenever the distance cannot be worked out — the
/// backend only sends `destinationPlace` once it has resolved coordinates, so
/// a freshly created trip arrives with the free-text destination alone. The
/// card drops the chip in that case rather than showing a made-up number.
@immutable
class NearbyTrip {
  const NearbyTrip({
    required this.trip,
    required this.featured,
    this.distanceKm,
  });

  final TripListItem trip;
  final bool featured;
  final double? distanceKm;

  /// "2.3 Km" — under 10 km reads to one decimal, beyond that the decimal is
  /// noise on a card this small.
  String? get distanceLabel {
    final km = distanceKm;
    if (km == null) return null;
    if (km < 10) return '${km.toStringAsFixed(1)} Km';
    return '${km.round()} Km';
  }
}

/// Where "near me" is measured from.
///
/// The app ships no location plugin, so this is a place the traveller picks
/// rather than a GPS fix; [label] and [address] are what the header prints.
@immutable
class PaigunOrigin {
  const PaigunOrigin({
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final String address;
  final double latitude;
  final double longitude;
}

/// Great-circle distance in kilometres.
double distanceKmBetween(
  double fromLat,
  double fromLng,
  double toLat,
  double toLng,
) {
  const earthRadiusKm = 6371.0;

  final dLat = _radians(toLat - fromLat);
  final dLng = _radians(toLng - fromLng);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_radians(fromLat)) *
          math.cos(_radians(toLat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);

  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _radians(double degrees) => degrees * math.pi / 180;
