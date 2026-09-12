import '../../../../core/api/models/trip_content.dart';
import 'package:flutter/material.dart';

/// Who gets to see a post, as the audience pill offers it.
///
/// The pill shows only the current choice, so the list lives here — the chip
/// and the picker sheet read the same enum and cannot drift apart.
enum PostAudience {
  public('สาธารณะ', Icons.public),
  followers('ผู้ติดตาม', Icons.group_outlined),
  onlyMe('เฉพาะฉัน', Icons.lock_outline);

  const PostAudience(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// A place pinned to one topic, as `/places/search` returned it.
@immutable
class PostPlace {
  const PostPlace(
      {required this.id, required this.name, this.area, this.mapId});

  final String? mapId;

  final String id;
  final String name;

  /// Where it sits — the place's address, when the search carried one.
  final String? area;

  /// One line for the pin row: "Akha Ama Coffee, เชียงใหม่".
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
      other.mapId == mapId;

  @override
  int get hashCode => Object.hash(id, name, area, mapId);
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
class PostTopic {
  const PostTopic({
    required this.title,
    required this.body,
    this.imagePath,
    this.imagePaths = const [],
    this.place,
    this.location,
    this.legacyMapId,
  });

  /// Empty when the writer never added a heading.
  final String title;

  final String body;

  /// A local file path, uploaded before contents are saved.
  final String? imagePath;
  final List<String> imagePaths;
  List<String> get photos => [...imagePaths, if (imagePath != null) imagePath!];

  final PostPlace? place;
  final ContentLocation? location;
  final String? legacyMapId;

  /// An untouched section. The composer always keeps one on screen, and an
  /// empty one is dropped rather than published blank.
  bool get isEmpty =>
      title.trim().isEmpty &&
      body.trim().isEmpty &&
      photos.isEmpty &&
      place == null &&
      location == null &&
      legacyMapId == null;
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
