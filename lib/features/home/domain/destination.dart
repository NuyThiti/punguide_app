import 'package:flutter/foundation.dart';

@immutable
class Destination {
  const Destination({
    required this.id,
    required this.name,
    this.coverImage,
  });

  final String id;
  final String name;

  /// Null when no trip to this place has a cover yet.
  final String? coverImage;
}
