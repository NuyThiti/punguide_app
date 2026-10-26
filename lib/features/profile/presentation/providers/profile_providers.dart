import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../../shared/models/feed_rows.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../my_trips/presentation/providers/my_trips_providers.dart';

/// The four icons under the profile hero (Figma 1539-8068).
enum ProfileTab { posts, albums, saved, remixes, clips }

final profileTabProvider =
    StateProvider.autoDispose<ProfileTab>((ref) => ProfileTab.posts);

/// Trips the traveller has bookmarked.
///
/// `GET /trips/saved` is its own endpoint rather than a filter over the feed,
/// which matters: a bookmark outlives the slice of the feed Home happens to
/// be holding, so filtering the cached feed would quietly lose the rest.
final savedFeedProvider =
    AsyncNotifierProvider<SavedFeedNotifier, List<TripListItem>>(
  SavedFeedNotifier.new,
);

class SavedFeedNotifier extends AsyncNotifier<List<TripListItem>> {
  @override
  Future<List<TripListItem>> build() async {
    // 401 for an anonymous caller, so an empty shelf rather than an error —
    // and a re-read the moment the session changes, exactly like ทริปฉัน.
    if (ref.watch(authSessionProvider) == null) {
      return const <TripListItem>[];
    }
    final api = await ref.watch(plunoApiProvider.future);
    return api.trips.saved();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      if (ref.read(authSessionProvider) == null) {
        return const <TripListItem>[];
      }
      final api = await ref.read(plunoApiProvider.future);
      return api.trips.saved();
    });
  }

  /// Un-bookmarking from this wall takes the row out of it — the wall *is*
  /// the bookmarks, so a row that stays would be lying until the next read.
  Future<void> unsave(String tripId) async {
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
      await api.trips.unsave(tripId);
    } catch (_) {
      if (previous != null) state = AsyncData<List<TripListItem>>(previous);
      rethrow;
    }
  }
}

/// The rows the tab in force shows.
///
/// Null means "this tab is not a wall of trips": [ProfileTab.albums] draws
/// its own grid, and [ProfileTab.remixes] has no endpoint at all —
/// `POST /trips/:id/remix` makes one but nothing lists them back, so the
/// screen says so rather than showing an empty wall that reads as "you have
/// none".
final profileTabRowsProvider =
    Provider.autoDispose<AsyncValue<List<TripListItem>>?>((ref) {
  switch (ref.watch(profileTabProvider)) {
    case ProfileTab.posts:
      return ref.watch(myTripsProvider).whenData(withoutClips);
    case ProfileTab.saved:
      return ref.watch(savedFeedProvider);
    case ProfileTab.albums:
    case ProfileTab.remixes:
      return null;
    case ProfileTab.clips:
      return ref.watch(myTripsProvider).whenData(onlyClips);
  }
});
