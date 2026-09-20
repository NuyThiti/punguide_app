import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json.dart';

/// One calculated leg between two consecutive stops.
///
/// A day with `n` stops has `n - 1` segments, and a day with one or none has an
/// empty list rather than a missing key.
///
/// Match a segment to the gap between two cards by [fromPlaceId]/[toPlaceId],
/// never by index: a failed or missing segment does not shift the others.
@immutable
class TravelSegment {
  const TravelSegment({
    required this.id,
    required this.dayId,
    required this.fromPlaceId,
    required this.toPlaceId,
    required this.order,
    required this.travelMode,
    required this.routeStatus,
    this.durationSeconds,
    this.durationMinutes,
    this.distanceMeters,
    this.distanceKilometers,
    this.calculatedAt,
  });

  factory TravelSegment.fromJson(Map<String, dynamic> json) => TravelSegment(
        id: Json.requiredString(json, 'id'),
        dayId: Json.requiredString(json, 'dayId'),
        fromPlaceId: Json.requiredString(json, 'fromPlaceId'),
        toPlaceId: Json.requiredString(json, 'toPlaceId'),
        order: Json.integer(json, 'order') ?? 0,
        travelMode: TravelMode.from(json['travelMode']) ?? TravelMode.drive,
        routeStatus:
            RouteStatus.from(json['routeStatus']) ?? RouteStatus.failed,
        durationSeconds: Json.integer(json, 'durationSeconds'),
        durationMinutes: Json.integer(json, 'durationMinutes'),
        distanceMeters: Json.integer(json, 'distanceMeters'),
        distanceKilometers: Json.number(json, 'distanceKilometers'),
        calculatedAt: Json.timestamp(json, 'calculatedAt'),
      );

  static List<TravelSegment> listFrom(Object? value) =>
      Json.asMapList(value).map(TravelSegment.fromJson).toList(growable: false);

  static TravelSegment? maybeFromJson(Object? value) =>
      value is Map ? TravelSegment.fromJson(Json.asMap(value)) : null;

  final String id;
  final String dayId;

  /// The **itinerary item** id of the origin stop — not a `places.id`, and not
  /// a Google place id, despite the name.
  final String fromPlaceId;

  /// The itinerary item id of the destination stop.
  final String toPlaceId;

  /// The leg between stops `n` and `n + 1` has `order == n`.
  final int order;
  final TravelMode travelMode;
  final RouteStatus routeStatus;

  /// All four measures are null together when [routeStatus] is
  /// [RouteStatus.failed] — the provider was down, or a stop has no coordinates.
  final int? durationSeconds;
  final int? durationMinutes;
  final int? distanceMeters;
  final double? distanceKilometers;
  final DateTime? calculatedAt;

  bool get isCalculated => routeStatus == RouteStatus.calculated;

  /// Retryable via `POST /trips/:tripId/travel-segments/retry`.
  bool get hasFailed => routeStatus == RouteStatus.failed;
}

/// The result of `POST /routes/calculate`.
@immutable
class RouteCalculation {
  const RouteCalculation({
    required this.travelMode,
    this.durationSeconds,
    this.durationMinutes,
    this.distanceMeters,
    this.distanceKilometers,
    this.calculatedAt,
  });

  factory RouteCalculation.fromJson(Map<String, dynamic> json) =>
      RouteCalculation(
        travelMode: TravelMode.from(json['travelMode']) ?? TravelMode.drive,
        durationSeconds: Json.integer(json, 'durationSeconds'),
        durationMinutes: Json.integer(json, 'durationMinutes'),
        distanceMeters: Json.integer(json, 'distanceMeters'),
        distanceKilometers: Json.number(json, 'distanceKilometers'),
        calculatedAt: Json.timestamp(json, 'calculatedAt'),
      );

  final TravelMode travelMode;
  final int? durationSeconds;
  final int? durationMinutes;
  final int? distanceMeters;
  final double? distanceKilometers;

  /// On a cache hit this is when the route was *first* calculated, so it also
  /// tells you how stale the traffic estimate is.
  final DateTime? calculatedAt;
}

/// One end of a route calculation.
@immutable
class RouteWaypoint {
  const RouteWaypoint({
    required this.latitude,
    required this.longitude,
    this.placeId,
  });

  final double latitude;
  final double longitude;

  /// Accepted but unused for routing — coordinates always win, so that the
  /// cache key and the calculated route cannot disagree.
  final String? placeId;

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'lat': latitude,
        'lng': longitude,
        'placeId': placeId,
      });
}
