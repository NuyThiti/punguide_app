import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pluno_api.dart';

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
