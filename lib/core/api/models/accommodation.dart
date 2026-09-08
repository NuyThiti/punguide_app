import 'package:flutter/foundation.dart';

import 'activity.dart';
import 'json.dart';

/// A place to stay, attached to a trip.
///
/// There is no list endpoint: read accommodations from the budget summary,
/// where they appear as items with `source == accommodation`.
@immutable
class TripAccommodation {
  const TripAccommodation({
    required this.id,
    required this.tripId,
    required this.name,
    this.imageUrl,
    this.pricePerNight,
    this.currency,
    this.amenities = const <String>[],
    this.checkIn,
    this.checkOut,
    this.description,
    this.location,
    this.updatedAt,
  });

  factory TripAccommodation.fromJson(Map<String, dynamic> json) =>
      TripAccommodation(
        id: Json.requiredString(json, 'id'),
        tripId: Json.requiredString(json, 'tripId'),
        name: Json.requiredString(json, 'name'),
        imageUrl: Json.string(json, 'imageUrl'),
        pricePerNight: Json.number(json, 'pricePerNight'),
        currency: Json.string(json, 'currency'),
        amenities: Json.stringList(json, 'amenities'),
        checkIn: Json.time(json, 'checkIn'),
        checkOut: Json.time(json, 'checkOut'),
        description: Json.string(json, 'description'),
        location: ActivityLocation.maybeFromJson(json['location']),
        updatedAt: Json.timestamp(json, 'updatedAt'),
      );

  final String id;
  final String tripId;
  final String name;
  final String? imageUrl;
  final double? pricePerNight;
  final String? currency;
  final List<String> amenities;

  /// `HH:mm`.
  final String? checkIn;
  final String? checkOut;
  final String? description;

  /// Present only when this accommodation is linked to a real place.
  final ActivityLocation? location;
  final DateTime? updatedAt;
}
