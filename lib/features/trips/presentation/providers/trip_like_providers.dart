import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Hearts the traveller has flipped this session, by trip id — the one copy
/// every screen reads through.
///
/// The twin of the bookmark ledger, and for the same reason: a trip can sit in
/// Home, both ไปกัน walls, search and its own page at once, each its own
/// request, so a tap kept inside any one list would go stale in the others.
/// Rows read `ledger[id] ?? row.isLiked`. Only server-accepted flips stay
/// here, so an entry is never older than the row it overrides.
final tripLikedProvider =
    NotifierProvider<TripLikedNotifier, Map<String, bool>>(
  TripLikedNotifier.new,
);

class TripLikedNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    // `isLiked` is per viewer: another account's taps must not carry over.
    // Keyed on the account rather than the session, which a token refresh
    // replaces without anyone signing out.
    ref.watch(authSessionProvider.select((session) => session?.userId));
    return const <String, bool>{};
  }

  /// Flips the heart before the request so the tap feels instant, and puts it
  /// back if the server refuses. `POST`/`DELETE /trips/:id/like` are both
  /// idempotent, so a double tap cannot leave the server out of step.
  ///
  /// Throws [ApiException] so the caller can tell "sign in first" (401) from a
  /// genuine failure.
  Future<void> toggle(String tripId, {required bool wasLiked}) async {
    final previous = state;
    state = <String, bool>{...previous, tripId: !wasLiked};

    try {
      final api = await ref.read(plunoApiProvider.future);
      if (wasLiked) {
        await api.trips.unlike(tripId);
      } else {
        await api.trips.like(tripId);
      }
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  /// Notes a heart another screen has already written to the server — the clip
  /// viewer keeps its own copy of a post and flips it there.
  void record(String tripId, {required bool liked}) {
    state = <String, bool>{...state, tripId: liked};
  }
}

/// The heart as it stands now for [trip] — the ledger if the traveller has
/// touched it, otherwise what the row came back with.
bool likedNow(Map<String, bool> ledger, TripListItem trip) =>
    ledger[trip.id] ?? trip.isLiked;
