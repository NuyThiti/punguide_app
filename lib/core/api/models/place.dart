import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json.dart';

/// A place in our own database. [id] is the `placeId` accepted by
/// `POST /days/:dayId/items` and by the save-plan payload.
@immutable
class Place {
  const Place({
    required this.id,
    required this.name,
    this.address,
    this.category,
    this.latitude,
    this.longitude,
    this.rating,
    this.imageUrl,
  });

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: Json.requiredString(json, 'id'),
        name: Json.requiredString(json, 'name'),
        address: Json.string(json, 'address'),
        category: PlaceCategory.from(json['category']),
        latitude: Json.number(json, 'lat'),
        longitude: Json.number(json, 'lng'),
        rating: Json.number(json, 'rating'),
        imageUrl: Json.string(json, 'imageUrl'),
      );

  static List<Place> listFrom(Object? value) =>
      Json.asMapList(value).map(Place.fromJson).toList(growable: false);

  final String id;
  final String name;
  final String? address;
  final PlaceCategory? category;
  final double? latitude;
  final double? longitude;

  /// Absent unless the server has Google's ratings field enabled.
  final double? rating;

  /// A googleusercontent link with no key in it. These expire — do not cache
  /// them on disk.
  final String? imageUrl;
}

/// One row of the destination type-ahead. Cities, regions and countries only.
@immutable
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.description,
    required this.mainText,
    required this.secondaryText,
    required this.externalRef,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) =>
      PlaceSuggestion(
        description: Json.requiredString(json, 'description'),
        mainText: Json.requiredString(json, 'mainText'),
        secondaryText: Json.requiredString(json, 'secondaryText'),
        externalRef: Json.requiredString(json, 'externalRef'),
      );

  final String description;
  final String mainText;
  final String secondaryText;

  /// A Google place id. Not a `placeId` you can add a stop with — feed it to
  /// `/places/details` to get coordinates.
  final String externalRef;
}

/// The coordinates behind a chosen suggestion.
@immutable
class PlaceLookup {
  const PlaceLookup({
    required this.name,
    required this.externalRef,
    this.address,
    this.latitude,
    this.longitude,
  });

  factory PlaceLookup.fromJson(Map<String, dynamic> json) => PlaceLookup(
        name: Json.requiredString(json, 'name'),
        address: Json.string(json, 'address'),
        latitude: Json.number(json, 'lat'),
        longitude: Json.number(json, 'lng'),
        externalRef: Json.requiredString(json, 'externalRef'),
      );

  final String name;
  final String? address;

  /// Rarely absent — Google occasionally has no coordinates for an id.
  final double? latitude;
  final double? longitude;
  final String externalRef;

  bool get hasCoordinates => latitude != null && longitude != null;
}

/// The three carousels of `/places/suggest/sections`, each filled by its own
/// search so a busy category cannot crowd the others out.
@immutable
class PlaceSuggestionSections {
  const PlaceSuggestionSections({
    required this.attractions,
    required this.restaurants,
    required this.accommodations,
  });

  factory PlaceSuggestionSections.fromJson(Map<String, dynamic> json) =>
      PlaceSuggestionSections(
        attractions: Place.listFrom(json['attractions']),
        restaurants: Place.listFrom(json['restaurants']),
        accommodations: Place.listFrom(json['accommodations']),
      );

  final List<Place> attractions;
  final List<Place> restaurants;
  final List<Place> accommodations;

  List<Place> get all => <Place>[...attractions, ...restaurants, ...accommodations];
}

/// Opening hours. Everything inside can be null.
@immutable
class OpeningHours {
  const OpeningHours({
    this.openNow,
    this.weekdayDescriptions = const <String>[],
    this.nextOpenTime,
    this.nextCloseTime,
  });

  factory OpeningHours.fromJson(Map<String, dynamic> json) => OpeningHours(
        openNow: json['openNow'] is bool ? json['openNow'] as bool : null,
        weekdayDescriptions: Json.stringList(json, 'weekdayDescriptions'),
        nextOpenTime: Json.timestamp(json, 'nextOpenTime'),
        nextCloseTime: Json.timestamp(json, 'nextCloseTime'),
      );

  static OpeningHours? maybeFromJson(Object? value) =>
      value is Map ? OpeningHours.fromJson(Json.asMap(value)) : null;

  /// Cached for 24 hours server-side — treat it as a hint, not live truth.
  final bool? openNow;
  final List<String> weekdayDescriptions;
  final DateTime? nextOpenTime;
  final DateTime? nextCloseTime;
}

/// Accessibility flags. A `null` means "unknown", not "no".
@immutable
class AccessibilityOptions {
  const AccessibilityOptions({
    this.parking,
    this.entrance,
    this.restroom,
    this.seating,
  });

  factory AccessibilityOptions.fromJson(Map<String, dynamic> json) =>
      AccessibilityOptions(
        parking: _flag(json['wheelchairAccessibleParking']),
        entrance: _flag(json['wheelchairAccessibleEntrance']),
        restroom: _flag(json['wheelchairAccessibleRestroom']),
        seating: _flag(json['wheelchairAccessibleSeating']),
      );

  static AccessibilityOptions? maybeFromJson(Object? value) =>
      value is Map ? AccessibilityOptions.fromJson(Json.asMap(value)) : null;

  static bool? _flag(Object? value) => value is bool ? value : null;

  final bool? parking;
  final bool? entrance;
  final bool? restroom;
  final bool? seating;
}

@immutable
class PlaceReview {
  const PlaceReview({
    this.authorName,
    this.authorUri,
    this.authorPhotoUri,
    this.rating,
    this.text,
    this.relativePublishTime,
    this.publishTime,
  });

  factory PlaceReview.fromJson(Map<String, dynamic> json) => PlaceReview(
        authorName: Json.string(json, 'authorName'),
        authorUri: Json.string(json, 'authorUri'),
        authorPhotoUri: Json.string(json, 'authorPhotoUri'),
        rating: Json.number(json, 'rating'),
        text: Json.string(json, 'text'),
        relativePublishTime:
            Json.string(json, 'relativePublishTimeDescription'),
        publishTime: Json.timestamp(json, 'publishTime'),
      );

  final String? authorName;
  final String? authorUri;
  final String? authorPhotoUri;
  final double? rating;
  final String? text;

  /// Already localised by Google, e.g. "2 เดือนที่แล้ว".
  final String? relativePublishTime;
  final DateTime? publishTime;
}

/// The full detail sheet for a place: hours, contact, reviews, photos.
///
/// This is the most expensive call in the API. It is cached for 24 hours
/// server-side, and `reviews=false` drops it a pricing tier.
@immutable
class PlaceDetails {
  const PlaceDetails({
    required this.externalRef,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.primaryType,
    this.primaryTypeDisplayName,
    this.rating,
    this.userRatingCount,
    this.priceLevel,
    this.nationalPhoneNumber,
    this.internationalPhoneNumber,
    this.websiteUri,
    this.googleMapsUri,
    this.businessStatus,
    this.editorialSummary,
    this.regularOpeningHours,
    this.currentOpeningHours,
    this.accessibilityOptions,
    this.photos = const <String>[],
    this.reviews = const <PlaceReview>[],
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) => PlaceDetails(
        externalRef: Json.requiredString(json, 'externalRef'),
        name: Json.requiredString(json, 'name'),
        address: Json.string(json, 'address'),
        latitude: Json.number(json, 'lat'),
        longitude: Json.number(json, 'lng'),
        primaryType: Json.string(json, 'primaryType'),
        primaryTypeDisplayName: Json.string(json, 'primaryTypeDisplayName'),
        rating: Json.number(json, 'rating'),
        userRatingCount: Json.integer(json, 'userRatingCount'),
        priceLevel: Json.string(json, 'priceLevel'),
        nationalPhoneNumber: Json.string(json, 'nationalPhoneNumber'),
        internationalPhoneNumber:
            Json.string(json, 'internationalPhoneNumber'),
        websiteUri: Json.string(json, 'websiteUri'),
        googleMapsUri: Json.string(json, 'googleMapsUri'),
        businessStatus: Json.string(json, 'businessStatus'),
        editorialSummary: Json.string(json, 'editorialSummary'),
        regularOpeningHours:
            OpeningHours.maybeFromJson(json['regularOpeningHours']),
        currentOpeningHours:
            OpeningHours.maybeFromJson(json['currentOpeningHours']),
        accessibilityOptions:
            AccessibilityOptions.maybeFromJson(json['accessibilityOptions']),
        photos: Json.stringList(json, 'photos'),
        reviews: Json.asMapList(json['reviews'])
            .map(PlaceReview.fromJson)
            .toList(growable: false),
      );

  final String externalRef;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? primaryType;
  final String? primaryTypeDisplayName;
  final double? rating;
  final int? userRatingCount;

  /// Google's own enum string, e.g. `PRICE_LEVEL_FREE`.
  final String? priceLevel;
  final String? nationalPhoneNumber;
  final String? internationalPhoneNumber;
  final String? websiteUri;
  final String? googleMapsUri;
  final String? businessStatus;

  /// Empty when the caller asked for `reviews=false`.
  final String? editorialSummary;
  final OpeningHours? regularOpeningHours;
  final OpeningHours? currentOpeningHours;
  final AccessibilityOptions? accessibilityOptions;
  final List<String> photos;
  final List<PlaceReview> reviews;
}
