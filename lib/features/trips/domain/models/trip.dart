import 'package:flutter/foundation.dart';

@immutable
class Trip {
  const Trip({
    required this.id,
    required this.title,
    required this.destination,
    required this.coverImage,
    required this.budget,
    required this.duration,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.isSaved = false,
  });

  final String id;
  final String title;
  final String destination;
  final String coverImage;
  final double budget;
  final int duration;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSaved;

  Trip copyWith({
    String? id,
    String? title,
    String? destination,
    String? coverImage,
    double? budget,
    int? duration,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSaved,
  }) {
    return Trip(
      id: id ?? this.id,
      title: title ?? this.title,
      destination: destination ?? this.destination,
      coverImage: coverImage ?? this.coverImage,
      budget: budget ?? this.budget,
      duration: duration ?? this.duration,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  @override
  String toString() {
    return 'Trip('
        'id: $id, '
        'title: $title, '
        'destination: $destination, '
        'coverImage: $coverImage, '
        'budget: $budget, '
        'duration: $duration, '
        'description: $description, '
        'createdAt: $createdAt, '
        'updatedAt: $updatedAt, '
        'isSaved: $isSaved'
        ')';
  }
}
