import '../../network/api_client.dart';
import '../../network/uuid_v4.dart';
import '../models/enums.dart';
import '../models/json.dart';
import '../models/place.dart';

/// Place search, suggestions and detail sheets.
///
/// These routes accept anonymous callers, but always let the client attach the
/// token: the 300-per-minute quota is per account when authenticated and
/// shared with every anonymous caller in the world when it is not.
class PlacesApi {
  const PlacesApi(this._client);

  final PlunoApiClient _client;

  /// Destination type-ahead: cities, regions and countries, never points of
  /// interest. One or two characters is enough to call it.
  ///
  /// Reuse one [PlacesSession] across the keystrokes of a single search so
  /// Google bills the session once instead of per keystroke.
  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    String? sessionToken,
  }) async {
    final body = await _client.get<List<dynamic>>(
      '/places/autocomplete',
      query: <String, dynamic>{'q': query, 'sessionToken': sessionToken},
    );
    return Json.asMapList(body)
        .map(PlaceSuggestion.fromJson)
        .toList(growable: false);
  }

  /// Turns a chosen suggestion's `externalRef` into coordinates.
  ///
  /// Pass the same [sessionToken] used while typing to close out the session.
  Future<PlaceLookup> details(
    String externalRef, {
    String? sessionToken,
  }) async {
    final body = await _client.get<Map<String, dynamic>>(
      '/places/details',
      query: <String, dynamic>{
        'externalRef': externalRef,
        'sessionToken': sessionToken,
      },
    );
    return PlaceLookup.fromJson(Json.asMap(body));
  }

  /// Popular places around a point. The ids it returns are usable directly as
  /// `placeId` when adding a stop.
  ///
  /// A province's own coordinates are its centroid, which can sit in the
  /// middle of nowhere — prefer a town, or widen [radiusMeters].
  Future<List<Place>> suggest({
    required double latitude,
    required double longitude,
    int? radiusMeters,
    int? limit,
    List<PlaceCategory>? categories,
  }) async {
    final body = await _client.get<List<dynamic>>(
      '/places/suggest',
      query: <String, dynamic>{
        'lat': latitude,
        'lng': longitude,
        'radius': radiusMeters,
        'limit': limit,
        // Several categories cost one Google call, not one per category.
        'category': categories == null || categories.isEmpty
            ? null
            : categories.map((category) => category.wire).join(','),
      },
    );
    return Place.listFrom(body);
  }

  /// The same idea as [suggest], but as three separately searched carousels,
  /// so a category with many results cannot crowd out the others.
  ///
  /// [limit] counts per section.
  Future<PlaceSuggestionSections> suggestSections({
    required double latitude,
    required double longitude,
    int? radiusMeters,
    int? limit,
  }) async {
    final body = await _client.get<Map<String, dynamic>>(
      '/places/suggest/sections',
      query: <String, dynamic>{
        'lat': latitude,
        'lng': longitude,
        'radius': radiusMeters,
        'limit': limit,
      },
    );
    return PlaceSuggestionSections.fromJson(Json.asMap(body));
  }

  /// Free-text search, as if typing into Maps. Results are cached as our own
  /// places, so their ids can be used to add stops.
  Future<List<Place>> search(String query, {int? limit}) async {
    final body = await _client.get<List<dynamic>>(
      '/places/search',
      query: <String, dynamic>{'q': query, 'limit': limit},
    );
    return Place.listFrom(body);
  }

  /// The full detail sheet for one of our places: hours, contact, photos and
  /// reviews.
  ///
  /// The most expensive call in the API, cached 24 hours server-side. Pass
  /// `reviews: false` when the screen shows none — it drops a pricing tier and
  /// leaves the response shape unchanged.
  Future<PlaceDetails> byId(String placeId, {bool? reviews}) async {
    final body = await _client.get<Map<String, dynamic>>(
      '/places/$placeId',
      query: <String, dynamic>{'reviews': reviews},
    );
    return PlaceDetails.fromJson(Json.asMap(body));
  }
}

/// One destination search, from the first keystroke to the chosen place.
///
/// Google bills autocomplete per session rather than per keystroke, so hold a
/// session while the traveller types and [close] it once they pick something.
///
/// ```dart
/// final session = PlacesSession();
/// // ... on each keystroke:
/// await placesApi.autocomplete(text, sessionToken: session.token);
/// // ... once a suggestion is chosen:
/// final place = await placesApi.details(ref, sessionToken: session.token);
/// session.close();
/// ```
class PlacesSession {
  PlacesSession() : _token = uuidV4();

  String _token;

  String get token => _token;

  /// Ends this session and starts a fresh one for the next search.
  void close() => _token = uuidV4();
}
