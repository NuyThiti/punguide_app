import 'package:flutter/foundation.dart';

import 'json.dart';
import 'trip_content.dart';

/// One photo as the assistant takes it: the id it was uploaded under, plus the
/// EXIF the app read off the original.
///
/// The server cannot read that itself — every stored variant is stripped of
/// metadata on upload — so a photo with no EXIF simply carries less, and
/// nothing here is ever guessed.
@immutable
class PostAssistantPhoto {
  const PostAssistantPhoto({
    required this.mediaId,
    this.takenAt,
    this.latitude,
    this.longitude,
  });

  final String mediaId;

  /// ISO 8601 with a timezone. Without one the field is left out rather than
  /// assumed — the same rule `photoMetadata` follows.
  final String? takenAt;

  final double? latitude, longitude;

  Map<String, dynamic> toJson() {
    if (!_uuid.hasMatch(mediaId)) {
      throw const FormatException('รหัสรูปต้องเป็น UUID');
    }
    if ((latitude == null) != (longitude == null) ||
        (latitude != null &&
            (!latitude!.isFinite ||
                latitude!.abs() > 90 ||
                !longitude!.isFinite ||
                longitude!.abs() > 180))) {
      throw const FormatException('พิกัดต้องครบคู่และอยู่ในช่วงที่กำหนด');
    }
    if (takenAt != null &&
        (DateTime.tryParse(takenAt!) == null ||
            !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(takenAt!))) {
      throw const FormatException('เวลาถ่ายต้องมี timezone');
    }
    return <String, dynamic>{
      'mediaId': mediaId,
      if (takenAt != null) 'takenAt': takenAt,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }
}

/// How sure the assistant is about the *place* of a section — never about the
/// words. `low` is a nudge to look harder, or means nothing was suggested.
enum PlaceConfidence {
  high('high'),
  medium('medium'),
  low('low');

  const PlaceConfidence(this.wire);

  final String wire;

  static PlaceConfidence from(Object? value) => values.firstWhere(
        (confidence) => confidence.wire == value,
        orElse: () => PlaceConfidence.low,
      );
}

/// One real place near a section's photos, offered for the traveller to pick.
@immutable
class SuggestedPlace {
  const SuggestedPlace({
    required this.name,
    this.placeId,
    this.category,
    this.latitude,
    this.longitude,
    this.rating,
  });

  factory SuggestedPlace.fromJson(Map<String, dynamic> json) => SuggestedPlace(
        name: Json.requiredString(json, 'name'),
        placeId: Json.string(json, 'placeId'),
        category: Json.string(json, 'category'),
        latitude: Json.number(json, 'latitude'),
        longitude: Json.number(json, 'longitude'),
        rating: Json.number(json, 'rating'),
      );

  final String name;
  final String? placeId, category;
  final double? latitude, longitude;
  final double? rating;
}

/// The candidates for one section, in the order the assistant ranked them.
///
/// Review-screen data only: [sectionIndex] points into the draft's `contents`,
/// and none of this may be sent back — `PATCH /trips/:id` rejects fields it
/// does not know.
@immutable
class SectionPlaceOptions {
  const SectionPlaceOptions({
    required this.sectionIndex,
    required this.confidence,
    required this.options,
  });

  factory SectionPlaceOptions.fromJson(Map<String, dynamic> json) =>
      SectionPlaceOptions(
        sectionIndex: Json.number(json, 'sectionIndex')?.toInt() ?? 0,
        confidence: PlaceConfidence.from(json['confidence']),
        options: (json['options'] is List
                ? Json.asMapList(json['options'])
                : const <Map<String, dynamic>>[])
            .map(SuggestedPlace.fromJson)
            .toList(growable: false),
      );

  final int sectionIndex;
  final PlaceConfidence confidence;

  /// Empty when the section's photos carry no coordinates — the picker then
  /// offers its own search instead.
  final List<SuggestedPlace> options;
}

/// A post the assistant drafted from photos. Nothing here is saved: the
/// traveller reads it, edits it, and only then does `PATCH /trips/:id` run.
@immutable
class GeneratedPostDraft {
  const GeneratedPostDraft({
    this.title = '',
    this.contents = const [],
    this.locationOptions = const [],
    this.warnings = const [],
  });

  factory GeneratedPostDraft.fromJson(Map<String, dynamic> json) =>
      GeneratedPostDraft(
        title: Json.string(json, 'title') ?? '',
        contents: (json['contents'] is List
                ? Json.asMapList(json['contents'])
                : const <Map<String, dynamic>>[])
            .map(TripContent.fromJson)
            .toList(growable: false),
        locationOptions: (json['locationOptions'] is List
                ? Json.asMapList(json['locationOptions'])
                : const <Map<String, dynamic>>[])
            .map(SectionPlaceOptions.fromJson)
            .toList(growable: false),
        warnings: Json.stringList(json, 'warnings'),
      );

  /// The headline it suggests. Empty when it had nothing to go on.
  final String title;

  /// Sections in the shape `PATCH /trips/:id` accepts, so a reviewed draft
  /// goes back untouched.
  final List<TripContent> contents;

  final List<SectionPlaceOptions> locationOptions;

  /// Why the draft may not match what the traveller expected. Every one of
  /// these has to reach the screen.
  final List<String> warnings;

  /// The candidates for [index], or null when that section has none.
  SectionPlaceOptions? optionsFor(int index) {
    for (final entry in locationOptions) {
      if (entry.sectionIndex == index) return entry;
    }
    return null;
  }
}

final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
