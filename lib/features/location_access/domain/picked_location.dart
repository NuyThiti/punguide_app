import 'package:flutter/foundation.dart';

import '../../paigun/domain/nearby_trip.dart';

/// A place the traveller has settled on in the map picker.
///
/// [distanceKm] is how far it sits from where they are standing, and is null
/// whenever that is unknown — the device gave no fix — so the row prints the
/// address alone instead of a made-up "0.0km".
@immutable
class PickedLocation {
  const PickedLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.distanceKm,
  });

  /// What the sheet headlines — "เขตพระนคร".
  final String name;

  /// The line under it — "Bangkok 10200". Null for a place the search
  /// returned without one.
  final String? address;

  final double latitude;
  final double longitude;
  final double? distanceKm;

  /// "0.1km" — always one decimal under 10 km, whole kilometres beyond that,
  /// which is the design's own precision.
  String? get distanceLabel {
    final km = distanceKm;
    if (km == null) return null;
    return km < 10 ? '${km.toStringAsFixed(1)}km' : '${km.round()}km';
  }

  /// "0.1km • Bangkok 10200", dropping whichever half is missing.
  String get subtitle =>
      [distanceLabel, address].whereType<String>().join(' • ');

  /// The same place measured from somewhere else. Used when a fix arrives
  /// after the picker has already drawn a pin.
  PickedLocation measuredFrom(LocationFixPoint? origin) {
    if (origin == null) return this;
    return PickedLocation(
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      distanceKm: distanceKmBetween(
        origin.latitude,
        origin.longitude,
        latitude,
        longitude,
      ),
    );
  }

  /// What the ไปกัน board measures "near me" from once this is confirmed.
  PaigunOrigin toOrigin() => PaigunOrigin(
        label: name,
        address: address ?? name,
        latitude: latitude,
        longitude: longitude,
      );
}

/// A bare point to measure from — the device's fix, or the origin the board
/// already held.
@immutable
class LocationFixPoint {
  const LocationFixPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}
