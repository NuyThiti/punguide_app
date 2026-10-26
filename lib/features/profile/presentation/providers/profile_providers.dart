import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../../shared/models/feed_rows.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../my_trips/presentation/providers/my_trips_providers.dart';

/// The five icons under the profile hero (Figma 1539-8068).
///
/// Tabs 1–4 are the traveller's own shelf filtered by what a row *is*; the
/// fifth is the album grid, which is a different view rather than a filter.
enum ProfileTab { all, content, plans, clips, albums }

final profileTabProvider =
    StateProvider.autoDispose<ProfileTab>((ref) => ProfileTab.all);

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

/// The rows the tab in force shows, or null when that tab is not a wall of
/// trips — [ProfileTab.albums] draws its own grid instead.
///
/// **Clips are judged by their cover, not their type.** The server still
/// sends a Puntok as `type: "content"` with a video cover (see
/// `shared/models/feed_rows.dart`), so filtering `type == puntok` alone would
/// leave the Puntok tab empty and spill every clip into the posts tab. Both
/// tabs therefore go through `isClip`, which tests the type *and* the cover —
/// and keeps working unchanged once the server starts sending the real type.
final profileTabRowsProvider =
    Provider.autoDispose<AsyncValue<List<TripListItem>>?>((ref) {
  final mine = ref.watch(myTripsProvider);

  return switch (ref.watch(profileTabProvider)) {
    // Everything the traveller owns. Albums are a view, not a kind, so
    // nothing is held back here.
    ProfileTab.all => mine,
    ProfileTab.content => mine.whenData(
        (trips) => List<TripListItem>.unmodifiable(
          trips.where((trip) => trip.type == TripType.content && !trip.isClip),
        ),
      ),
    ProfileTab.plans => mine.whenData(
        (trips) => List<TripListItem>.unmodifiable(
          trips.where((trip) => trip.type == TripType.planTrip),
        ),
      ),
    ProfileTab.clips => mine.whenData(onlyClips),
    ProfileTab.albums => null,
  };
});

/// How many albums one page of อัลบั้มของฉัน asks for. The endpoint caps
/// `limit` at 100 and 400s above it.
const albumsPageSize = 20;

/// The kinds of trip that are albums: photo posts and Puntok clips. Plans are
/// not albums — they live on the posts tab.
const albumTypes = <TripType>[TripType.content, TripType.puntok];

/// อัลบั้มของฉัน (Personal), from `GET /trips/mine?type=content,puntok`.
///
/// Paged rather than read whole: the shelf grows without bound, so the grid
/// asks for [albumsPageSize] at a time and walks forward on [loadMore].
final myAlbumsProvider =
    AsyncNotifierProvider<MyAlbumsNotifier, List<TripListItem>>(
  MyAlbumsNotifier.new,
);

class MyAlbumsNotifier extends AsyncNotifier<List<TripListItem>> {
  /// True once a page came back shorter than asked for — the documented way
  /// this endpoint says "that was the last one", since it sends no total.
  bool _exhausted = false;
  bool get hasMore => !_exhausted;

  @override
  Future<List<TripListItem>> build() async {
    _exhausted = false;
    // 401 for an anonymous caller, so an empty shelf rather than an error —
    // and a re-read the moment the session changes.
    if (ref.watch(authSessionProvider) == null) {
      _exhausted = true;
      return const <TripListItem>[];
    }

    final api = await ref.watch(plunoApiProvider.future);
    final page = await api.trips.mine(
      types: albumTypes,
      limit: albumsPageSize,
      offset: 0,
    );
    _exhausted = page.length < albumsPageSize;
    return page;
  }

  /// Appends the next page. Does nothing while one is already in flight or
  /// the shelf is spent, so a scroll that fires twice cannot double-read.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || _exhausted || state.isLoading) return;

    state = AsyncLoading<List<TripListItem>>()
        .copyWithPrevious(AsyncData<List<TripListItem>>(current));
    state = await AsyncValue.guard(() async {
      final api = await ref.read(plunoApiProvider.future);
      final page = await api.trips.mine(
        types: albumTypes,
        limit: albumsPageSize,
        offset: current.length,
      );
      _exhausted = page.length < albumsPageSize;
      // The window can shift when a trip is created mid-walk, so drop any id
      // already held rather than printing it twice.
      final seen = {for (final trip in current) trip.id};
      return <TripListItem>[
        ...current,
        ...page.where((trip) => !seen.contains(trip.id)),
      ];
    });
  }

  /// Pull-to-refresh starts the walk again from zero rather than patching a
  /// window that may have moved underneath it.
  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      _exhausted = false;
      if (ref.read(authSessionProvider) == null) {
        _exhausted = true;
        return const <TripListItem>[];
      }
      final api = await ref.read(plunoApiProvider.future);
      final page = await api.trips.mine(
        types: albumTypes,
        limit: albumsPageSize,
        offset: 0,
      );
      _exhausted = page.length < albumsPageSize;
      return page;
    });
  }
}
