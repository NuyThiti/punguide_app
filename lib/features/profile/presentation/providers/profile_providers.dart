import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../../shared/models/feed_rows.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../my_trips/presentation/providers/my_trips_providers.dart';
import '../../../paigun/presentation/providers/paigun_providers.dart';

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
    // So the same trip's bookmark goes hollow on Home and its own page too.
    ref.read(paigunSavedProvider.notifier).record(tripId, saved: false);
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

/// The kinds of trip that are albums: photo posts and plan trips.
///
/// Puntok is deliberately absent — a clip is not a page of pictures. Asking
/// the server to leave it out is not enough on its own, though: it still
/// answers a clip as `type: "content"` with a video cover, so the rows come
/// back through `withoutClips` as well. See `shared/models/feed_rows.dart`.
const albumTypes = <TripType>[TripType.content, TripType.planTrip];

/// อัลบั้มของฉัน (Personal), from `GET /trips/mine?type=content,plan_trip`.
///
/// **Read whole, not paged** (2026-11-13). `limit` on this endpoint does not
/// count trips: it counts the rows a trip joins to, so one plan with two
/// dozen stops swallows the whole window and the shelf comes back holding a
/// single album. Measured against the live server with 21 trips:
///
/// ```text
/// type=content,plan_trip                 -> 21
/// type=content,plan_trip&limit=20&offset=0 ->  1
/// type=plan_trip&limit=20&offset=0        ->  1   (there are 11)
/// type=content&limit=20&offset=0          -> 10   (there are 10)
/// ```
///
/// `offset` is unusable for the same reason, so there is nothing to page
/// with. Every other `/trips/mine` read in the app sends neither and is
/// unaffected. Bring the window back — and `loadMore` with it — once the
/// server counts trips; see `docs/backend-gaps.md`.
final myAlbumsProvider =
    AsyncNotifierProvider<MyAlbumsNotifier, List<TripListItem>>(
  MyAlbumsNotifier.new,
);

class MyAlbumsNotifier extends AsyncNotifier<List<TripListItem>> {
  @override
  Future<List<TripListItem>> build() async {
    // 401 for an anonymous caller, so an empty shelf rather than an error —
    // and a re-read the moment the session changes.
    if (ref.watch(authSessionProvider) == null) {
      return const <TripListItem>[];
    }
    final api = await ref.watch(plunoApiProvider.future);
    return _read(api);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      if (ref.read(authSessionProvider) == null) {
        return const <TripListItem>[];
      }
      final api = await ref.read(plunoApiProvider.future);
      return _read(api);
    });
  }

  /// Asked for by type, then stripped of the clips the server sends back as
  /// `content` anyway.
  Future<List<TripListItem>> _read(PlunoApi api) async =>
      withoutClips(await api.trips.mine(types: albumTypes));
}

/// How many pictures one page of an album asks for. The gallery is the only
/// paginated list in the API and answers with `page` / `limit` / `total`.
const albumGalleryPageSize = 30;

/// Every picture filed under one trip, from `GET /trips/:id/media`.
///
/// **Not `trip.contents`.** Those are only the pictures embedded in a post's
/// sections: media uploaded to the trip but attached to no section never
/// appears there, and a plan trip keeps its pictures against its stops rather
/// than in sections at all. `mediaSummary` on the trip says so outright — it
/// carries `totalImages`, a `hasMore`, and the `galleryEndpoint` this reads.
final albumGalleryProvider = AsyncNotifierProvider.autoDispose
    .family<AlbumGalleryNotifier, List<GalleryImage>, String>(
  AlbumGalleryNotifier.new,
);

class AlbumGalleryNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<GalleryImage>, String> {
  int _page = 0;
  bool _exhausted = false;
  int _total = 0;

  bool get hasMore => !_exhausted;

  /// How many pictures the trip holds in all — the server's own count, which
  /// is what the header should print rather than how many are loaded so far.
  int get total => _total;

  @override
  Future<List<GalleryImage>> build(String tripId) async {
    _page = 0;
    _exhausted = false;
    _total = 0;
    final api = await ref.watch(plunoApiProvider.future);
    return _append(api, const <GalleryImage>[]);
  }

  /// Appends the next page; a no-op while one is in flight or the gallery is
  /// spent, so a tap that fires twice cannot double-read.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || _exhausted || state.isLoading) return;

    state = AsyncLoading<List<GalleryImage>>()
        .copyWithPrevious(AsyncData<List<GalleryImage>>(current));
    state = await AsyncValue.guard(() async {
      final api = await ref.read(plunoApiProvider.future);
      return _append(api, current);
    });
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      _page = 0;
      _exhausted = false;
      final api = await ref.read(plunoApiProvider.future);
      return _append(api, const <GalleryImage>[]);
    });
  }

  /// Reads the page after the last one held and adds what is new.
  ///
  /// Paging is by page number here, not offset, and the server reports
  /// `total`, so the end is `hasNextPage` rather than a short page.
  Future<List<GalleryImage>> _append(
    PlunoApi api,
    List<GalleryImage> current,
  ) async {
    final gallery = await api.media.gallery(
      arg,
      page: _page + 1,
      limit: albumGalleryPageSize,
    );
    _page = gallery.page;
    _total = gallery.total;
    _exhausted = !gallery.hasNextPage;

    // An upload mid-walk shifts the window, so never print one twice.
    final seen = {for (final image in current) image.id};
    return <GalleryImage>[
      ...current,
      ...gallery.items.where((image) => !seen.contains(image.id)),
    ];
  }
}
