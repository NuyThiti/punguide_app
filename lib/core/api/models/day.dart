import 'package:flutter/foundation.dart';

import 'activity.dart';
import 'json.dart';
import 'travel_segment.dart';

/// One day of an itinerary.
@immutable
class ItineraryDay {
  const ItineraryDay({
    required this.id,
    required this.dayNumber,
    required this.activities,
    required this.travelSegments,
    this.date,
  });

  factory ItineraryDay.fromJson(Map<String, dynamic> json) => ItineraryDay(
        id: Json.requiredString(json, 'id'),
        dayNumber: Json.integer(json, 'dayNumber') ?? 0,
        // The API sends an empty string, not null, for an undated day.
        date: Json.date(json, 'date'),
        activities: Activity.listFrom(json['activities']),
        travelSegments: TravelSegment.listFrom(json['travelSegments']),
      );

  static List<ItineraryDay> listFrom(Object? value) =>
      Json.asMapList(value).map(ItineraryDay.fromJson).toList(growable: false);

  final String id;
  final int dayNumber;

  /// Null on a trip without fixed dates.
  final DateTime? date;
  final List<Activity> activities;

  /// One fewer than [activities]; empty for a day with a single stop.
  final List<TravelSegment> travelSegments;

  /// The leg arriving at [activity], or null when it is the day's first stop
  /// or its route has not been calculated.
  ///
  /// Looked up by stop id rather than by position, because a missing segment
  /// must not shift the rest.
  TravelSegment? segmentInto(Activity activity) {
    for (final segment in travelSegments) {
      if (segment.toPlaceId == activity.id) return segment;
    }
    return null;
  }
}
