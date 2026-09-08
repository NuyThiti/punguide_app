import 'package:flutter/foundation.dart';

@immutable
class Destination {
  const Destination({
    required this.id,
    required this.name,
    required this.coverImage,
  });

  final String id;
  final String name;
  final String coverImage;
}
