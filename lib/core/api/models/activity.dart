import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json.dart';
import 'travel_segment.dart';

/// The place a stop points at, flattened into the itinerary response.
/// Absent when the stop was typed by hand instead of linked to a place.
@immutable
class ActivityLocation {
  const ActivityLocation({
    required this.name,
    this.latitude,
    this.longitude,
    this.rating,
    this.imageUrl,
  });

  factory ActivityLocation.fromJson(Map<String, dynamic> json) =>
      ActivityLocation(
        name: Json.requiredString(json, 'name'),
        latitude: Json.number(json, 'lat'),
        longitude: Json.number(json, 'lng'),
        rating: Json.number(json, 'rating'),
        imageUrl: Json.string(json, 'imageUrl'),
      );

  static ActivityLocation? maybeFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    if (json.isEmpty) return null;
    return ActivityLocation.fromJson(json);
  }

  final String name;
  final double? latitude;
  final double? longitude;
  final double? rating;
  final String? imageUrl;

  bool get hasCoordinates => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'name': name,
        'lat': latitude,
        'lng': longitude,
        'rating': rating,
        'imageUrl': imageUrl,
      });
}

/// How the traveller got here from the previous stop, as recorded on the stop.
///
/// This is the user's own plan for the leg. The measured route lives in
/// [TravelSegment], which the server calculates.
@immutable
class TravelFromPrevious {
  const TravelFromPrevious({
    this.type,
    this.customType,
    this.durationMin,
    this.distanceKm,
    this.costAmount,
    this.costCurrency,
    this.notes,
  });

  factory TravelFromPrevious.fromJson(Map<String, dynamic> json) =>
      TravelFromPrevious(
        type: TravelType.from(json['type']),
        customType: Json.string(json, 'customType'),
        durationMin: Json.integer(json, 'durationMin'),
        distanceKm: Json.number(json, 'distanceKm'),
        costAmount: Json.number(json, 'costAmount'),
        costCurrency: Json.string(json, 'costCurrency'),
        notes: Json.string(json, 'notes'),
      );

  static TravelFromPrevious? maybeFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    if (json.isEmpty) return null;
    return TravelFromPrevious.fromJson(json);
  }

  final TravelType? type;
  final String? customType;
  final int? durationMin;
  final double? distanceKm;
  final double? costAmount;
  final String? costCurrency;
  final String? notes;
}

/// One stop in a day.
@immutable
class Activity {
  const Activity({
    required this.id,
    required this.title,
    required this.category,
    required this.order,
    required this.cost,
    this.time,
    this.location,
    this.notes,
    this.travelNote,
    this.travelFromPrevious,
    this.paidBy,
    this.splitLabel,
  });

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: Json.requiredString(json, 'id'),
        // Empty string means "no time set"; [Json.time] normalises it to null.
        time: Json.time(json, 'time'),
        title: Json.requiredString(json, 'title'),
        category: ActivityCategory.from(json['category']) ??
            ActivityCategory.other,
        order: Json.integer(json, 'order') ?? 0,
        location: ActivityLocation.maybeFromJson(json['location']),
        notes: Json.string(json, 'notes'),
        cost: Json.number(json, 'cost') ?? 0,
        travelNote: Json.string(json, 'travelNote'),
        travelFromPrevious:
            TravelFromPrevious.maybeFromJson(json['travelFromPrevious']),
        paidBy: Json.string(json, 'paidBy'),
        splitLabel: Json.string(json, 'splitLabel'),
      );

  static List<Activity> listFrom(Object? value) =>
      Json.asMapList(value).map(Activity.fromJson).toList(growable: false);

  final String id;

  /// `HH:mm`, or null when the stop has no time.
  final String? time;
  final String title;
  final ActivityCategory category;

  /// Position within the day, from 0.
  final int order;
  final ActivityLocation? location;
  final String? notes;

  /// THB for the whole group.
  final double cost;

  /// A pre-composed display string like `~8 นาที · 1.2 กม.`. Legacy —
  /// prefer [travelFromPrevious] and localise it yourself.
  final String? travelNote;
  final TravelFromPrevious? travelFromPrevious;
  final String? paidBy;
  final String? splitLabel;
}

/// The response to `POST /days/:dayId/items`: the new stop, plus the leg
/// leading to it.
@immutable
class CreatedItineraryItem {
  const CreatedItineraryItem({required this.activity, this.travelSegment});

  factory CreatedItineraryItem.fromJson(Map<String, dynamic> json) =>
      CreatedItineraryItem(
        activity: Activity.fromJson(Json.asMap(json['place'])),
        travelSegment: TravelSegment.maybeFromJson(json['travelSegment']),
      );

  final Activity activity;

  /// Null for the first stop of a day — there is nowhere to travel from.
  /// Present with [RouteStatus.failed] when the stop saved but routing did not.
  final TravelSegment? travelSegment;
}
