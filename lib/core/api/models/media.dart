import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json.dart';

/// The three renditions of an image, derived from the storage key.
@immutable
class MediaUrls {
  const MediaUrls({required this.large, required this.thumbnail, this.original});

  factory MediaUrls.fromJson(Map<String, dynamic> json) => MediaUrls(
        original: Json.string(json, 'original'),
        large: Json.requiredString(json, 'large'),
        thumbnail: Json.requiredString(json, 'thumbnail'),
      );

  /// Absent on gallery items, which only carry [large] and [thumbnail].
  final String? original;
  final String large;
  final String thumbnail;

  /// The best available full-size URL.
  String get full => original ?? large;
}

/// Where to centre a crop, in 0–1 coordinates.
@immutable
class FocalPoint {
  const FocalPoint({required this.x, required this.y});

  factory FocalPoint.fromJson(Map<String, dynamic> json) => FocalPoint(
        x: Json.number(json, 'x') ?? 0.5,
        y: Json.number(json, 'y') ?? 0.5,
      );

  final double x;
  final double y;

  Map<String, dynamic> toJson() => <String, dynamic>{'x': x, 'y': y};
}

/// A media item as returned by upload, from-place, update, and `coverImage`.
///
/// Note the key is `mediaId`, not `id` — a gallery item uses `id` instead.
@immutable
class Media {
  const Media({
    required this.mediaId,
    required this.urls,
    this.source,
    this.sourcePlaceId,
    this.sourceActivityId,
    this.storageKey,
    this.altText,
    this.caption,
    this.focalPoint,
    this.width,
    this.height,
    this.createdAt,
    this.updatedAt,
  });

  factory Media.fromJson(Map<String, dynamic> json) {
    final dimensions = Json.asMap(json['dimensions']);
    return Media(
      mediaId: Json.requiredString(json, 'mediaId'),
      source: MediaSource.from(json['source']),
      sourcePlaceId: Json.string(json, 'sourcePlaceId'),
      sourceActivityId: Json.string(json, 'sourceActivityId'),
      storageKey: Json.string(json, 'storageKey'),
      urls: MediaUrls.fromJson(Json.asMap(json['urls'])),
      altText: Json.string(json, 'altText'),
      caption: Json.string(json, 'caption'),
      focalPoint: json['focalPoint'] is Map
          ? FocalPoint.fromJson(Json.asMap(json['focalPoint']))
          : null,
      width: Json.integer(dimensions, 'width'),
      height: Json.integer(dimensions, 'height'),
      createdAt: Json.timestamp(json, 'createdAt'),
      updatedAt: Json.timestamp(json, 'updatedAt'),
    );
  }

  static Media? maybeFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    if (json.isEmpty) return null;
    return Media.fromJson(json);
  }

  final String mediaId;
  final MediaSource? source;
  final String? sourcePlaceId;
  final String? sourceActivityId;
  final String? storageKey;
  final MediaUrls urls;
  final String? altText;
  final String? caption;
  final FocalPoint? focalPoint;
  final int? width;
  final int? height;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// One image in a trip's gallery.
///
/// A deliberately different shape from [Media]: keyed by `id`, only two
/// renditions, and no dimensions, attribution, focal point, or storage key.
@immutable
class GalleryImage {
  const GalleryImage({
    required this.id,
    required this.urls,
    required this.isCover,
    this.source,
    this.sourcePlaceId,
    this.sourceActivityId,
    this.dayNumber,
    this.altText,
    this.caption,
    this.sortOrder,
    this.createdAt,
  });

  factory GalleryImage.fromJson(Map<String, dynamic> json) => GalleryImage(
        id: Json.requiredString(json, 'id'),
        source: MediaSource.from(json['source']),
        sourcePlaceId: Json.string(json, 'sourcePlaceId'),
        sourceActivityId: Json.string(json, 'sourceActivityId'),
        dayNumber: Json.integer(json, 'dayNumber'),
        urls: MediaUrls.fromJson(Json.asMap(json['urls'])),
        altText: Json.string(json, 'altText'),
        caption: Json.string(json, 'caption'),
        isCover: Json.boolean(json, 'isCover'),
        sortOrder: Json.integer(json, 'sortOrder'),
        createdAt: Json.timestamp(json, 'createdAt'),
      );

  final String id;
  final MediaSource? source;
  final String? sourcePlaceId;
  final String? sourceActivityId;
  final int? dayNumber;
  final MediaUrls urls;
  final String? altText;
  final String? caption;
  final bool isCover;

  /// Display order for this response only — reordering is not persisted yet.
  final int? sortOrder;
  final DateTime? createdAt;
}

/// One page of a trip's gallery.
@immutable
class MediaGallery {
  const MediaGallery({
    required this.tripId,
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    this.coverMediaId,
  });

  factory MediaGallery.fromJson(Map<String, dynamic> json) => MediaGallery(
        tripId: Json.requiredString(json, 'tripId'),
        coverMediaId: Json.string(json, 'coverMediaId'),
        total: Json.integer(json, 'total') ?? 0,
        page: Json.integer(json, 'page') ?? 1,
        limit: Json.integer(json, 'limit') ?? 24,
        items: Json.asMapList(json['items'])
            .map(GalleryImage.fromJson)
            .toList(growable: false),
      );

  final String tripId;
  final String? coverMediaId;
  final int total;
  final int page;
  final int limit;
  final List<GalleryImage> items;

  bool get hasNextPage => page * limit < total;
}

/// The gallery pointer embedded in a full trip.
@immutable
class MediaSummary {
  const MediaSummary({
    required this.totalImages,
    required this.hasMore,
    required this.galleryEndpoint,
  });

  factory MediaSummary.fromJson(Map<String, dynamic> json) => MediaSummary(
        totalImages: Json.integer(json, 'totalImages') ?? 0,
        hasMore: Json.boolean(json, 'hasMore'),
        galleryEndpoint: Json.requiredString(json, 'galleryEndpoint'),
      );

  final int totalImages;
  final bool hasMore;

  /// Ready to pass straight to the client, e.g. `/trips/<id>/media`.
  final String galleryEndpoint;
}
