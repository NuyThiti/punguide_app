import 'package:flutter/foundation.dart';

import 'activity.dart';
import 'enums.dart';
import 'json.dart';
import 'media.dart';
import 'schedule.dart';

/// A share link, from the owner's side.
@immutable
class TripShare {
  const TripShare({
    required this.id,
    required this.shareUrl,
    required this.shareToken,
    required this.accessLevel,
    required this.isActive,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  factory TripShare.fromJson(Map<String, dynamic> json) => TripShare(
        id: Json.requiredString(json, 'id'),
        shareUrl: Json.requiredString(json, 'shareUrl'),
        shareToken: Json.requiredString(json, 'shareToken'),
        accessLevel:
            ShareAccessLevel.from(json['accessLevel']) ?? ShareAccessLevel.view,
        isActive: Json.boolean(json, 'isActive'),
        expiresAt: Json.timestamp(json, 'expiresAt'),
        createdAt: Json.timestamp(json, 'createdAt'),
        updatedAt: Json.timestamp(json, 'updatedAt'),
      );

  /// The share row's id, not the trip's.
  final String id;

  /// Hand this to the user verbatim. Do not rebuild it from [shareToken] —
  /// the base URL is server configuration.
  final String shareUrl;

  /// Treat as a credential: whoever holds it can read the trip.
  final String shareToken;
  final ShareAccessLevel accessLevel;
  final bool isActive;

  /// Absent means the link never expires, which is the default.
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// A stop as a share-link visitor sees it: no ids, no money, no notes.
@immutable
class SharedActivity {
  const SharedActivity({
    required this.order,
    required this.title,
    required this.category,
    this.time,
    this.place,
    this.travelNote,
    this.travelFromPrevious,
  });

  factory SharedActivity.fromJson(Map<String, dynamic> json) => SharedActivity(
        order: Json.integer(json, 'order') ?? 0,
        time: Json.time(json, 'time'),
        title: Json.requiredString(json, 'title'),
        category:
            ActivityCategory.from(json['category']) ?? ActivityCategory.other,
        place: ActivityLocation.maybeFromJson(json['place']),
        travelNote: Json.string(json, 'travelNote'),
        travelFromPrevious:
            TravelFromPrevious.maybeFromJson(json['travelFromPrevious']),
      );

  /// Identity within the day — the public view has no stop ids.
  final int order;
  final String? time;
  final String title;
  final ActivityCategory category;
  final ActivityLocation? place;
  final String? travelNote;
  final TravelFromPrevious? travelFromPrevious;
}

/// A day in the public view, identified by its number rather than an id.
@immutable
class SharedDay {
  const SharedDay({
    required this.dayNumber,
    required this.activities,
    this.date,
  });

  factory SharedDay.fromJson(Map<String, dynamic> json) => SharedDay(
        dayNumber: Json.integer(json, 'dayNumber') ?? 0,
        date: Json.date(json, 'date'),
        activities: Json.asMapList(json['activities'])
            .map(SharedActivity.fromJson)
            .toList(growable: false),
      );

  final int dayNumber;
  final DateTime? date;
  final List<SharedActivity> activities;
}

/// The trip owner, reduced to what a public page may show.
@immutable
class SharedTripOwner {
  const SharedTripOwner({this.name, this.avatarUrl});

  factory SharedTripOwner.fromJson(Map<String, dynamic> json) =>
      SharedTripOwner(
        name: Json.string(json, 'name'),
        avatarUrl: Json.string(json, 'avatarUrl'),
      );

  /// The whole object is absent when there is neither a name nor an avatar.
  static SharedTripOwner? maybeFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    if (json.isEmpty) return null;
    return SharedTripOwner.fromJson(json);
  }

  final String? name;
  final String? avatarUrl;
}

/// A trip read through a share token, with no authentication.
///
/// A deliberately narrow allow-list, not a [ApiTrip]: no ids of any kind, no
/// money, no bookings, no private notes, no accommodation or expenses.
@immutable
class PublicSharedTrip {
  const PublicSharedTrip({
    required this.title,
    required this.destination,
    required this.schedule,
    required this.tags,
    required this.days,
    required this.likeCount,
    required this.remixCount,
    this.owner,
    this.coverImage,
    this.updatedAt,
  });

  factory PublicSharedTrip.fromJson(Map<String, dynamic> json) =>
      PublicSharedTrip(
        title: Json.requiredString(json, 'title'),
        destination: Json.requiredString(json, 'destination'),
        schedule: Schedule.fromJson(Json.asMap(json['schedule'])),
        tags: Json.stringList(json, 'tags'),
        owner: SharedTripOwner.maybeFromJson(json['owner']),
        coverImage: json['coverImage'] is Map
            ? MediaUrls.fromJson(Json.asMap(json['coverImage']))
            : null,
        days: Json.asMapList(json['days'])
            .map(SharedDay.fromJson)
            .toList(growable: false),
        likeCount: Json.integer(json, 'likeCount') ?? 0,
        remixCount: Json.integer(json, 'remixCount') ?? 0,
        updatedAt: Json.timestamp(json, 'updatedAt'),
      );

  final String title;
  final String destination;
  final Schedule schedule;

  /// Styles and custom styles only — pace, transport and constraints stay private.
  final List<String> tags;
  final SharedTripOwner? owner;

  /// Carries an `altText` alongside the renditions in the raw payload.
  final MediaUrls? coverImage;
  final List<SharedDay> days;
  final int likeCount;
  final int remixCount;
  final DateTime? updatedAt;
}
