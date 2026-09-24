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

  /// The same point under a name found for it later.
  ///
  /// The coordinates and any distance already measured stay as they are — only
  /// the label changes, because the point itself never moved. The address line
  /// is dropped: what replaces it is the area, which is the address.
  PickedLocation named(String name) => PickedLocation(
        name: name,
        latitude: latitude,
        longitude: longitude,
        distanceKm: distanceKm,
      );

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
  ///
  /// The board's header prints the label as a caption over the address in
  /// bold, so a place with both gives "Wat Pho" over "Bangkok 10200". A point
  /// named by its area alone has nothing to caption it with — repeating the
  /// same line twice would look like a bug — so it falls back to the header's
  /// own wording.
  PaigunOrigin toOrigin() => PaigunOrigin(
        label: address == null ? 'ตำแหน่งของฉัน' : name,
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
