import 'package:flutter/foundation.dart';

import 'json.dart';

/// The traveller's last known position as the account holds it.
///
/// One fix, overwritten on every save — deliberately not a trail. See
/// `PUT /users/me/location`, which is readable only by its owner.
@immutable
class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.capturedAt,
  });

  /// Null for `{"location": null}`, which is what a 200 says when nothing has
  /// been stored yet — and also for a row carrying only one coordinate. The
  /// two are only ever written together, so one alone is a response to
  /// distrust rather than a position to use.
  static UserLocation? maybeFrom(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    final latitude = Json.number(json, 'lat');
    final longitude = Json.number(json, 'lng');
    if (latitude == null || longitude == null) return null;

    return UserLocation(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: Json.integer(json, 'accuracyM'),
      capturedAt: Json.timestamp(json, 'capturedAt'),
    );
  }

  /// Unwraps the `location` key that both the GET and the PUT answer with.
  static UserLocation? fromEnvelope(Object? body) =>
      maybeFrom(Json.asMap(body)['location']);

  final double latitude;
  final double longitude;

  /// The radius CoreLocation / FusedLocation reported, in metres.
  final int? accuracyMeters;

  /// When the **device** took the reading, not when the server filed it.
  final DateTime? capturedAt;

  /// The `PUT /users/me/location` body.
  ///
  /// The timestamp goes up in UTC on purpose. The API insists on an offset,
  /// and `toIso8601String` writes one only for a UTC value — a local
  /// `DateTime` serialises as `2026-09-21T14:43:00.000`, with no zone at all,
  /// which comes back 400.
  ///
  /// A PUT replaces the whole row, so leaving `accuracyM` out clears it. That
  /// is the intended behaviour: the old radius described a different point.
  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'lat': latitude,
        'lng': longitude,
        'accuracyM': accuracyMeters,
        'capturedAt': capturedAt?.toUtc().toIso8601String(),
      });
}
