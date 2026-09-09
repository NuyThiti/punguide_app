import '../../../core/api/pluno_api.dart';

/// Destination type-ahead, behind an interface so a test can answer without a
/// server — the same seam [GoogleAuthenticator] uses for sign-in.
abstract class DestinationLookup {
  /// Cities, regions and countries matching [query] — never points of
  /// interest.
  ///
  /// [sessionToken] must be the same across the keystrokes of one search:
  /// Google bills autocomplete per session, not per request.
  Future<List<PlaceSuggestion>> search(
    String query, {
    required String sessionToken,
  });
}

/// The real path: `GET /places/autocomplete`.
class PlacesApiDestinationLookup implements DestinationLookup {
  const PlacesApiDestinationLookup(this._api);

  /// The client is opened asynchronously, so it is resolved per call rather
  /// than held — by the time anyone types, the future is already complete.
  final Future<PlunoApi> Function() _api;

  @override
  Future<List<PlaceSuggestion>> search(
    String query, {
    required String sessionToken,
  }) async {
    final api = await _api();
    return api.places.autocomplete(query, sessionToken: sessionToken);
  }
}
