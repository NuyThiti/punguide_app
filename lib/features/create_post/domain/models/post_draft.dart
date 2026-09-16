import '../../../../core/api/models/trip_content.dart';
import 'package:flutter/material.dart';

/// Who gets to see a post, as the audience pill offers it.
///
/// The pill shows only the current choice, so the list lives here — the chip
/// and the picker sheet read the same enum and cannot drift apart.
enum PostAudience {
  public('Public', Icons.public),
  followers('Followers', Icons.group_outlined),
  onlyMe('Only me', Icons.lock_outline);

  const PostAudience(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// A place pinned to one topic, as `/places/search` returned it.
@immutable
class PostPlace {
  const PostPlace({
    required this.id,
    required this.name,
    this.area,
    this.mapId,
    this.address,
    this.distanceKm,
    this.latitude,
    this.longitude,
    this.placeId,
  });

  final String? mapId;

  final String id;
  final String name;

  /// The locality alone — "เชียงใหม่". This is what a post falls back to for
  /// the trip's `destination`, so it stays short on purpose.
  final String? area;

  /// The whole street line, for the second row of the picker and of the spot's
  /// location row: "ถนนพระสุเมรุ แขวงบวรนิเวศ เขตพระนคร กรุงเทพมหานคร".
  final String? address;

  /// How far it sits from where the traveller is, when that is known.
  final double? distanceKm;

  final double? latitude, longitude;

  /// Google's own id, set only when the assistant suggested this place — it is
  /// what `ContentLocation.placeId` takes. A row from `/places/search` carries
  /// our [id] instead, which is a different namespace and is not sent.
  final String? placeId;

  /// "240 m." under a kilometre, then "1.2 km", then whole kilometres — the
  /// precision the design prints.
  String? get distanceLabel {
    final km = distanceKm;
    if (km == null) return null;
    if (km < 1) return '${(km * 1000).round()} m.';
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  /// "240 m. • ถนนพระสุเมรุ …", dropping whichever half is missing.
  String get subtitle =>
      [distanceLabel, address].whereType<String>().join(' • ');

  /// One line, for anywhere with room for only one: "Akha Ama Coffee, เชียงใหม่".
  String get label {
    final where = area?.trim() ?? '';
    return where.isEmpty ? name : '$name, $where';
  }

  @override
  bool operator ==(Object other) =>
      other is PostPlace &&
      other.id == id &&
      other.name == name &&
      other.area == area &&
      other.mapId == mapId &&
      other.address == address &&
      other.distanceKm == distanceKm &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.placeId == placeId;

  @override
  int get hashCode => Object.hash(id, name, area, mapId, address, distanceKm,
      latitude, longitude, placeId);
}

/// The trip a post hangs off, kept as its own type so the composer does not
/// have to hold a whole [Trip] just to draw one row.
@immutable
class PostTripLink {
  const PostTripLink({required this.id, required this.title});

  final String id;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is PostTripLink && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);
}

/// One section of a post: the story itself, plus whatever the writer chose to
/// hang off it — a heading, a photo, a pinned place.
///
/// The body leads. A heading is optional, which is why the composer offers it
/// as a chip rather than a labelled field.
@immutable
class PostTopicItem {
  const PostTopicItem({
    required this.body,
    this.imagePath,
    this.imagePaths = const [],
    this.place,
    this.location,
    this.legacyMapId,
  });

  final String body;

  /// A local file path, uploaded before contents are saved.
  final String? imagePath;
  final List<String> imagePaths;
  List<String> get photos => [...imagePaths, if (imagePath != null) imagePath!];

  final PostPlace? place;
  final ContentLocation? location;
  final String? legacyMapId;

  bool get isEmpty =>
      body.trim().isEmpty &&
      photos.isEmpty &&
      place == null &&
      location == null &&
      legacyMapId == null;
}

/// One section of a post: the story itself, plus whatever the writer chose to
/// hang off it — a heading, photos, a pinned place.
///
/// When a heading is present, the composer may hold several [items]. That maps
/// to the reference layout: one heading with multiple photo-and-description
/// rows underneath it. Without a heading, the first item is the same single
/// body/photo group the composer has always shown.
@immutable
class PostTopic {
  const PostTopic({
    required this.title,
    required this.body,
    this.imagePath,
    this.imagePaths = const [],
    this.items = const [],
    this.place,
    this.location,
    this.legacyMapId,
  });

  /// Empty when the writer never added a heading.
  final String title;

  final String body;

  /// Compatibility for the older single body/photo group.
  final String? imagePath;
  final List<String> imagePaths;

  final List<PostTopicItem> items;
  List<PostTopicItem> get contentItems => items.isEmpty
      ? [
          PostTopicItem(
              body: body,
              imagePath: imagePath,
              imagePaths: imagePaths,
              place: place,
              location: location,
              legacyMapId: legacyMapId)
        ]
      : items;

  List<String> get photos =>
      contentItems.expand((item) => item.photos).toList(growable: false);

  final PostPlace? place;
  final ContentLocation? location;
  final String? legacyMapId;

  /// An untouched section. The composer always keeps one on screen, and an
  /// empty one is dropped rather than published blank.
  bool get isEmpty =>
      title.trim().isEmpty && contentItems.every((item) => item.isEmpty);
}

/// Local composer state converted into trip contents at publish time.
@immutable
class PostDraft {
  const PostDraft({
    required this.audience,
    required this.topics,
    this.trip,
  });

  final PostAudience audience;

  /// Empty sections already removed, in the order they were written.
  final List<PostTopic> topics;

  final PostTripLink? trip;

  /// A post needs something to say: words, a heading, or a picture. A pinned
  /// place on its own is a location, not a post — and the trip is labelled
  /// ไม่บังคับ on the page itself.
  bool get isPublishable => topics.any(
        (topic) =>
            topic.body.trim().isNotEmpty ||
            topic.title.trim().isNotEmpty ||
            topic.photos.isNotEmpty,
      );
}
