import 'json.dart';
import 'media.dart';

enum ContentLocationStatus { none, suggested, confirmed }

class ContentLocation {
  const ContentLocation(
      {required this.status,
      this.name,
      this.placeId,
      this.latitude,
      this.longitude});
  final ContentLocationStatus status;
  final String? name, placeId;
  final double? latitude, longitude;
  factory ContentLocation.fromJson(Map<String, dynamic> json) {
    final status = ContentLocationStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ContentLocationStatus.none);
    if (status == ContentLocationStatus.none)
      return const ContentLocation(status: ContentLocationStatus.none);
    return ContentLocation(
        status: status,
        name: Json.string(json, 'name'),
        placeId: Json.string(json, 'placeId'),
        latitude: Json.number(json, 'latitude'),
        longitude: Json.number(json, 'longitude'));
  }
  Map<String, dynamic> toJson() {
    if (status == ContentLocationStatus.none) return {'status': 'none'};
    _coordinates(latitude, longitude);
    if ((name?.length ?? 0) > 200 ||
        (placeId?.length ?? 0) > 255 ||
        ((name?.trim().isEmpty ?? true) &&
            (placeId?.trim().isEmpty ?? true) &&
            latitude == null))
      throw const FormatException('กรุณาระบุชื่อสถานที่หรือพิกัดที่ถูกต้อง');
    return {
      'status': status.name,
      if (name != null) 'name': name,
      if (placeId != null) 'placeId': placeId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude
    };
  }
}

void _coordinates(double? latitude, double? longitude) {
  if ((latitude == null) != (longitude == null) ||
      (latitude != null &&
          (!latitude.isFinite ||
              latitude.abs() > 90 ||
              !longitude!.isFinite ||
              longitude.abs() > 180)))
    throw const FormatException('พิกัดต้องครบคู่และอยู่ในช่วงที่กำหนด');
}

class PhotoMetadata {
  const PhotoMetadata(
      {required this.mediaId, this.takenAt, this.latitude, this.longitude});
  final String mediaId;
  final String? takenAt;
  final double? latitude, longitude;
  factory PhotoMetadata.fromJson(Map<String, dynamic> json) => PhotoMetadata(
      mediaId: Json.requiredString(json, 'mediaId'),
      takenAt: Json.string(json, 'takenAt'),
      latitude: Json.number(json, 'latitude'),
      longitude: Json.number(json, 'longitude'));
  Map<String, dynamic> toJson() {
    _coordinates(latitude, longitude);
    if (takenAt != null &&
        (DateTime.tryParse(takenAt!) == null ||
            !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(takenAt!)))
      throw const FormatException('เวลาถ่ายต้องมี timezone');
    return {
      'mediaId': mediaId,
      if (takenAt != null) 'takenAt': takenAt,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude
    };
  }
}

class ContentImage {
  const ContentImage(
      {required this.mediaId, this.urls, this.unavailable = false});
  final String mediaId;
  final MediaUrls? urls;
  final bool unavailable;
  factory ContentImage.fromJson(Map<String, dynamic> json) => ContentImage(
      mediaId: Json.requiredString(json, 'mediaId'),
      unavailable: json['unavailable'] == true,
      urls: json['urls'] is Map
          ? MediaUrls.fromJson(Json.asMap(json['urls']))
          : null);
}

/// Response only. Display resolved images in server order, never gallery order.
class TripContent {
  const TripContent(
      {this.title = '',
      required this.content,
      this.mediaIds,
      this.images = const [],
      this.imageUrls = const [],
      this.mapId,
      this.location,
      this.photoMetadata = const []});
  final String title, content;
  final List<String>? mediaIds;
  final List<ContentImage> images;
  final List<String> imageUrls;
  final String? mapId;
  final ContentLocation? location;
  final List<PhotoMetadata> photoMetadata;
  factory TripContent.fromJson(Map<String, dynamic> json) => TripContent(
      title: Json.string(json, 'title') ?? '',
      content: Json.string(json, 'content') ?? '',
      mediaIds:
          json['mediaIds'] is List ? Json.stringList(json, 'mediaIds') : null,
      images:
          Json.asMapList(json['images']).map(ContentImage.fromJson).toList(),
      imageUrls: Json.stringList(json, 'imageUrls'),
      mapId: Json.string(json, 'mapId'),
      location: json['location'] is Map
          ? ContentLocation.fromJson(Json.asMap(json['location']))
          : null,
      photoMetadata: Json.asMapList(json['photoMetadata'])
          .map(PhotoMetadata.fromJson)
          .toList());
  static List<TripContent> listFrom(Object? value) =>
      Json.asMapList(value).map(TripContent.fromJson).toList();
  TripContentRequest toRequest() => TripContentRequest(
      title: title,
      content: content,
      mediaIds: mediaIds,
      imageUrls: mediaIds == null ? imageUrls : const [],
      mapId: location == null ? mapId : null,
      location: location,
      photoMetadata: photoMetadata);
  Map<String, dynamic> toJson() => toRequest().toJson();
}

/// Explicit allowlist for requests; never serializes response images/local state.
class TripContentRequest {
  const TripContentRequest(
      {this.title = '',
      required this.content,
      this.mediaIds,
      this.imageUrls = const [],
      this.mapId,
      this.location,
      this.photoMetadata = const []});
  final String title, content;
  final List<String>? mediaIds;
  final List<String> imageUrls;
  final String? mapId;
  final ContentLocation? location;
  final List<PhotoMetadata> photoMetadata;
  Map<String, dynamic> toJson() {
    final ids = mediaIds ?? const <String>[];
    if (title.length > 200 ||
        content.length > 10000 ||
        ids.length > 20 ||
        imageUrls.length > 20 ||
        (mapId?.length ?? 0) > 255 ||
        photoMetadata.length > 20)
      throw const FormatException('เนื้อหาเกินจำนวนที่กำหนด');
    if (ids.toSet().length != ids.length ||
        ids.any((id) => !RegExp(
                r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(id)))
      throw const FormatException('รหัสรูปต้องเป็น UUID และไม่ซ้ำภายในส่วน');
    if ((mediaIds != null && imageUrls.isNotEmpty) ||
        (mapId != null && location != null))
      throw const FormatException(
          'ห้ามผสมข้อมูลรูปหรือสถานที่แบบเดิมและแบบใหม่');
    if (photoMetadata.map((p) => p.mediaId).toSet().length !=
            photoMetadata.length ||
        photoMetadata.any((p) => !ids.contains(p.mediaId)))
      throw const FormatException('metadata ต้องอ้างรูปในส่วนเดียวกัน');
    for (final url in imageUrls) {
      final uri = Uri.tryParse(url);
      if (url.length > 4096 ||
          uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty)
        throw const FormatException('รูปภาพต้องอัปโหลดให้สำเร็จก่อน');
    }
    return {
      if (title.isNotEmpty) 'title': title,
      'content': content,
      if (mediaIds != null) 'mediaIds': mediaIds,
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      if (mapId != null) 'mapId': mapId,
      if (location != null) 'location': location!.toJson(),
      if (photoMetadata.isNotEmpty)
        'photoMetadata': photoMetadata.map((p) => p.toJson()).toList()
    };
  }

  static List<Map<String, dynamic>>? serializeAll(
      List<TripContentRequest>? contents) {
    if (contents == null) return null;
    if (contents.length > 100 ||
        contents.fold<int>(
                0, (n, s) => n + (s.mediaIds?.length ?? s.imageUrls.length)) >
            200)
      throw const FormatException('รองรับสูงสุด 100 ส่วนและ 200 รูปต่อโพสต์');
    return contents.map((s) => s.toJson()).toList();
  }
}
