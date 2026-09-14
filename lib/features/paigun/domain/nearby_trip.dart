import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/api/pluno_api.dart';

/// A feed row as the ไปกัน board shows it: the trip, how far its destination
/// sits from where the traveller is, and whether it earned the Top PunGuide
/// badge.
///
/// [distanceKm] is measured by the server, from the `lat`/`lng` the feed was
/// asked for. It is null whenever the distance cannot be worked out — the
/// backend only measures against a destination it has resolved to real
/// coordinates, so a freshly created trip arrives without one. The card drops
/// the chip in that case rather than showing a made-up number.
@immutable
class NearbyTrip {
  const NearbyTrip({
    required this.trip,
    required this.featured,
    required this.isSaved,
    this.distanceKm,
  });

  final TripListItem trip;
  final bool featured;

  /// The bookmark as it stands *now* — `trip.isSaved` as the row was fetched,
  /// unless the traveller has tapped it since. Read this, never `trip`: the
  /// same trip can sit in both walls, and only one of them would be patched.
  final bool isSaved;
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

/// Wraps feed rows for the card: server distance, the Top PunGuide badge, and
/// whatever the traveller has bookmarked since the rows were fetched.
///
/// The badge marks the [featuredCount] most liked-and-remixed rows of the list
/// it is given, so a wall badges its own rows rather than inheriting a ranking
/// from somewhere else.
List<NearbyTrip> decorateTrips(
  List<TripListItem> trips, {
  required Map<String, bool> saved,
  int featuredCount = 6,
}) {
  final ranked = List<TripListItem>.of(trips)
    ..sort((a, b) => _popularity(b).compareTo(_popularity(a)));
  final featured = ranked
      .take(featuredCount)
      .where((trip) => _popularity(trip) > 0)
      .map((trip) => trip.id)
      .toSet();

  return List<NearbyTrip>.unmodifiable(
    trips.map(
      (trip) => NearbyTrip(
        trip: trip,
        featured: featured.contains(trip.id),
        distanceKm: trip.distanceKm,
        isSaved: saved[trip.id] ?? trip.isSaved,
      ),
    ),
  );
}

int _popularity(TripListItem trip) => trip.remixCount + trip.likeCount;

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
