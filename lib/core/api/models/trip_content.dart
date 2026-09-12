import 'json.dart';

/// A story section. Local files and presentation metadata never go on the wire.
class TripContent {
  const TripContent(
      {required this.title,
      required this.content,
      this.imageUrls = const [],
      this.mapId});
  final String title;
  final String content;
  final List<String> imageUrls;
  final String? mapId;

  factory TripContent.fromJson(Map<String, dynamic> json) => TripContent(
        title: Json.requiredString(json, 'title'),
        content: Json.requiredString(json, 'content'),
        imageUrls: Json.stringList(json, 'imageUrls'),
        mapId: Json.string(json, 'mapId'),
      );
  static List<TripContent> listFrom(Object? value) =>
      Json.asMapList(value).map(TripContent.fromJson).toList();
  Map<String, dynamic> toJson() {
    if (title.length > 200 ||
        content.length > 10000 ||
        imageUrls.length > 20 ||
        (mapId != null && mapId!.length > 255)) {
      throw const FormatException('เนื้อหาเกินจำนวนที่กำหนด');
    }
    for (final url in imageUrls) {
      final uri = Uri.tryParse(url);
      if (url.length > 4096 ||
          uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw const FormatException('รูปภาพต้องอัปโหลดให้สำเร็จก่อน');
      }
    }
    return {
      'title': title,
      'content': content,
      'imageUrls': imageUrls,
      if (mapId != null) 'mapId': mapId
    };
  }
}
