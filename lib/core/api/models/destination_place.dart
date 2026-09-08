import 'package:flutter/foundation.dart';

import 'json.dart';

/// The resolved destination of a trip.
///
/// The whole object is absent from a response unless both coordinates are
/// known, so [latitude] and [longitude] are non-null on anything decoded from
/// the API — they are nullable only because a request may omit them.
@immutable
class DestinationPlace {
  const DestinationPlace({
    required this.name,
    this.placeId,
    this.country,
    this.countryCode,
    this.latitude,
    this.longitude,
  });

  factory DestinationPlace.fromJson(Map<String, dynamic> json) =>
      DestinationPlace(
        name: Json.requiredString(json, 'name'),
        placeId: Json.string(json, 'placeId'),
        country: Json.string(json, 'country'),
        countryCode: Json.string(json, 'countryCode'),
        latitude: Json.number(json, 'latitude'),
        longitude: Json.number(json, 'longitude'),
      );

  /// Null when the key is missing entirely.
  static DestinationPlace? maybeFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    if (json.isEmpty) return null;
    return DestinationPlace.fromJson(json);
  }

  /// A Google place id — the `externalRef` from `/places/autocomplete`.
  final String? placeId;
  final String name;
  final String? country;

  /// ISO 3166-1 alpha-2.
  final String? countryCode;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'placeId': placeId,
        'name': name,
        'country': country,
        'countryCode': countryCode,
        'latitude': latitude,
        'longitude': longitude,
      });
}
