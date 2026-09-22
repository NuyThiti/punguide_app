import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// The chips across the top of ทริปฉัน.
///
/// `GET /trips/mine` takes no parameters — it is the whole shelf in one call —
/// so unlike the ไปกัน board these sort in memory rather than as a request.
enum MyTripsFilter { all, plans, posts }

extension MyTripsFilterLabel on MyTripsFilter {
  String get label => switch (this) {
        MyTripsFilter.all => 'ทั้งหมด',
        MyTripsFilter.plans => 'แผนเที่ยว',
        MyTripsFilter.posts => 'โพสต์',
      };

  bool accepts(TripListItem trip) => switch (this) {
        MyTripsFilter.all => true,
        MyTripsFilter.plans => trip.type == TripType.planTrip,
        MyTripsFilter.posts => trip.type == TripType.content,
      };
}

final myTripsFilterProvider =
    StateProvider<MyTripsFilter>((ref) => MyTripsFilter.all);

/// Every trip the signed-in traveller owns, drafts and private ones included.
///
/// This is the one list in the app that is *not* the feed: the feed only ever
/// shows what is public, so a plan the traveller has not published can be
/// reached from nowhere else.
final myTripsProvider =
    AsyncNotifierProvider<MyTripsNotifier, List<TripListItem>>(
  MyTripsNotifier.new,
);

class MyTripsNotifier extends AsyncNotifier<List<TripListItem>> {
  @override
  Future<List<TripListItem>> build() async {
    // An empty shelf, not an error, while nobody is signed in — the endpoint
    // is 401 for an anonymous caller and the screen says so itself. Watching
    // the session re-reads the shelf the moment they sign in, and empties it
    // again on sign-out so the next account never sees the last one's trips.
    if (ref.watch(authSessionProvider) == null) {
      return const <TripListItem>[];
    }

    final api = await ref.watch(plunoApiProvider.future);
    return api.trips.mine();
  }

  /// Pull to refresh, and the retry on a failed read.
  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      if (ref.read(authSessionProvider) == null) {
        return const <TripListItem>[];
      }
      final api = await ref.read(plunoApiProvider.future);
      return api.trips.mine();
    });
  }

  /// Deletes the trip and everything filed under it — days, stops, media,
  /// expenses. The row leaves the list before the request so it closes up
  /// under the finger, and comes back if the server refuses.
  ///
  /// The per-trip caches behind the detail page are deliberately left alone:
  /// invalidating them here fetches a trip that no longer exists, and the only
  /// way back to that page — this list — no longer holds the row.
  ///
  /// Throws [ApiException] so the screen can tell "sign in again" from a
  /// genuine failure.
  Future<void> delete(String tripId) async {
    final previous = state.valueOrNull;
    if (previous != null) {
      state = AsyncData<List<TripListItem>>(
        List<TripListItem>.unmodifiable(
          previous.where((trip) => trip.id != tripId),
        ),
      );
    }

    try {
      final api = await ref.read(plunoApiProvider.future);
      await api.trips.delete(tripId);
    } catch (_) {
      if (previous != null) state = AsyncData<List<TripListItem>>(previous);
      rethrow;
    }
  }
}

/// The rows the chip in force lets through, in the order the server sent them.
final visibleMyTripsProvider = Provider<AsyncValue<List<TripListItem>>>((ref) {
  final filter = ref.watch(myTripsFilterProvider);
  return ref.watch(myTripsProvider).whenData(
        (trips) =>
            List<TripListItem>.unmodifiable(trips.where(filter.accepts)),
      );
});
