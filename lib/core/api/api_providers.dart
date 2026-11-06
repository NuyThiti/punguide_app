import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pluno_api.dart';

final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// The app's single API client.
///
/// Async because it restores the stored access token and opens the cookie jar
/// that carries the refresh token.
final plunoApiProvider = FutureProvider<PlunoApi>((ref) async {
  final api = await PlunoApi.create();
  ref.onDispose(api.close);
  return api;
});

/// The signed-in user according to the server, or `null` when the restored
/// token is gone or rejected.
///
/// Useful at startup to decide between the sign-in screen and the app.
final currentUserProvider = FutureProvider<AuthUser?>((ref) async {
  final api = await ref.watch(plunoApiProvider.future);
  if (!api.hasSession) return null;
  try {
    return await api.auth.me();
  } on ApiException catch (failure) {
    // An expired session is an answer, not an error. Anything else — no
    // network, a 5xx — should surface so the UI can offer a retry.
    if (failure.isUnauthorized) return null;
    rethrow;
  }
});

/// The live phone/website/hours for one of our places — `GET /places/:id`,
/// fetched automatically wherever a place is shown so the reader/writer sees
/// them the moment Google actually has them, no tap required.
///
/// Neither reviews nor photos: every screen that uses this already has its
/// own photos and nowhere to put a review list, so both are left off to stay
/// a tier cheaper.
///
/// [placeId] is one of ours (a UUID) or Google's own id (`ChIJ…`): a post's
/// pin often carries the latter, since the place was never saved to our
/// table, and `GET /places/google/:externalRef` reads the same sheet for it.
/// Null for anything else, or when the lookup fails — a caller with nothing to
/// add just renders as it was.
final placeDetailsProvider = FutureProvider.autoDispose
    .family<PlaceDetails?, String>((ref, placeId) async {
  final ours = _uuid.hasMatch(placeId);
  if (!ours && !_googlePlaceId.hasMatch(placeId)) return null;
  try {
    final api = await ref.watch(plunoApiProvider.future);
    return ours
        ? await api.places.byId(placeId, reviews: false, photos: false)
        : await api.places.byGoogleId(placeId, reviews: false, photos: false);
  } catch (_) {
    return null;
  }
});

/// Google place ids are long, URL-safe tokens — `ChIJ0QDC8BOZ4jARY7WqIrAOkck`.
/// Anything with spaces or punctuation (a hand-typed name, coordinates) is
/// not one, and never reaches the network.
final _googlePlaceId = RegExp(r'^[A-Za-z0-9_-]{16,}$');
