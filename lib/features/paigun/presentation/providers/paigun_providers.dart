import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/paigun_origin_store.dart';
import '../../domain/nearby_trip.dart';
import '../../domain/trip_filter.dart';

/// The chips across the top of the ไปกัน board (Figma 2480-67909).
///
/// Three of them narrow by what a trip *is* and the fourth re-orders, which is
/// why they are one row rather than two controls: whichever is in force, the
/// board below is a single wall.
enum PaigunFilter {
  all,
  guide,
  plan,
  topPunGuide;

  String get label => switch (this) {
        PaigunFilter.all => 'ทั้งหมด',
        PaigunFilter.guide => 'คู่มือ',
        PaigunFilter.plan => 'แผนทริป',
        PaigunFilter.topPunGuide => 'Top PunGuide',
      };

  /// What the chip asks `GET /trips` for.
  ///
  /// Only Top PunGuide changes the ordering; the rest stay nearest-first,
  /// because the whole board is "what is around me" and a type chip answers a
  /// different question from a sort.
  FeedSort get sort =>
      this == PaigunFilter.topPunGuide ? FeedSort.popular : FeedSort.nearest;

  /// Null on the chips that do not care what a trip is.
  TripType? get type => switch (this) {
        PaigunFilter.guide => TripType.content,
        PaigunFilter.plan => TripType.planTrip,
        _ => null,
      };
}

final paigunFilterProvider =
    StateProvider<PaigunFilter>((ref) => PaigunFilter.all);

/// Where the board measures distances from.
///
/// The map picker writes this when the traveller confirms a place, and it goes
/// up as `lat`/`lng` on every feed request, whichever wall is asking: the
/// server only returns `distanceKm` when it is given both, and that number is
/// what puts the chip on a card.
///
/// Starts from whatever was confirmed last time — `main` seeds
/// [storedPaigunOriginProvider] from the store before the app builds — and
/// falls back to the district the design is drawn on only when nobody has
/// ever picked anything.
final paigunOriginProvider = StateProvider<PaigunOrigin>(
  (ref) => ref.watch(storedPaigunOriginProvider) ?? defaultPaigunOrigin,
);

/// What the board measures from before the traveller has said anything.
const defaultPaigunOrigin = PaigunOrigin(
  label: 'ตำแหน่งของฉัน',
  address: 'เขตพระนคร, กรุงเทพ 10200',
  latitude: 13.7563,
  longitude: 100.4930,
);

/// Where a confirmed origin is kept between runs.
final paigunOriginStoreProvider = Provider<PaigunOriginStore>(
  (ref) => const PrefsPaigunOriginStore(),
);

/// The remembered origin as it stood when the app started, which `main`
/// overrides once it has read storage. Null means nobody has ever confirmed
/// one.
///
/// Read once at startup rather than awaited on demand, for the same reason
/// the stored permission is: the board asks for its origin while it builds,
/// and waiting on the disk would stall the first request behind it.
final storedPaigunOriginProvider = Provider<PaigunOrigin?>((ref) => null);

/// What was typed into the header's search field and submitted.
///
/// Goes up as `q`, which the endpoint matches across everything a trip shows
/// as words — title, destination, description, creator, and the sections or
/// stops inside it — so it narrows the wall in place rather than taking the
/// traveller to another screen.
final paigunQueryProvider = StateProvider<String>((ref) => '');

/// What the ตัวกรอง wizard last applied to the board.
///
/// Empty until the traveller finishes the wizard, and it outlives the wizard's
/// own route so reopening it shows the answers already in force. Kept in
/// memory only — a filter is a mood, not a setting.
final tripFilterProvider = StateProvider<TripFilter>((ref) => TripFilter.none);

/// The board's wall, straight from `GET /trips`.
///
/// One request, not two: the chips are a single row over a single wall, so
/// whichever is in force decides both the ordering and what type of trip the
/// server is asked for. Nothing is filtered or re-sorted here — the query
/// carries the wizard's answers and the search box, so what comes back is
/// already the answer.
///
/// Re-reads whenever the session changes, the way Home's feed does: `isSaved`
/// and `isLiked` are per-viewer and come back false for an anonymous caller.
final paigunFeedProvider =
    FutureProvider.family<List<TripListItem>, PaigunFilter>((ref, chip) async {
  ref.watch(authSessionProvider);
  final filter = ref.watch(tripFilterProvider);
  final origin = ref.watch(paigunOriginProvider);
  final query = ref.watch(paigunQueryProvider);

  final api = await ref.watch(plunoApiProvider.future);
  return api.trips.feed(
    filter.toFeedQuery(
      sort: chip.sort,
      type: chip.type,
      query: query,
      origin: origin,
    ),
  );
});

/// The wall as the cards need it: distance from the server, the badge, and
/// whatever the traveller has bookmarked since the rows were fetched.
final paigunWallProvider =
    Provider.family<AsyncValue<List<NearbyTrip>>, PaigunFilter>((ref, chip) {
  final saved = ref.watch(paigunSavedProvider);

  // The badge ranks the wall it is on, not what the filter let through: a trip
  // does not stop being a Top PunGuide because someone asked for beaches.
  return ref
      .watch(paigunFeedProvider(chip))
      .whenData((trips) => decorateTrips(trips, saved: saved));
});

/// What the board is showing right now — the chip in force, already decorated.
final paigunTripsProvider = Provider<AsyncValue<List<NearbyTrip>>>(
  (ref) => ref.watch(paigunWallProvider(ref.watch(paigunFilterProvider))),
);

/// Re-reads the wall — pull to refresh, and the retry on a failed one.
///
/// Invalidates every chip rather than only the one on screen: they are four
/// answers to the same feed, and leaving the other three cached would show a
/// stale wall the moment a chip is tapped.
///
/// Waits for the chip in force so the spinner lasts as long as its request
/// does. A failure is not rethrown: the wall renders its own error state, and
/// letting it escape would only crash the refresh gesture.
Future<void> refreshPaigunFeed(WidgetRef ref) async {
  final chip = ref.read(paigunFilterProvider);
  ref.invalidate(paigunFeedProvider);

  await ref
      .read(paigunFeedProvider(chip).future)
      .then<void>((_) {}, onError: (_, __) {});
}

/// Bookmarks the traveller has flipped on this board, by trip id.
///
/// A trip can sit in both walls at once, and each wall is its own request, so
/// the bookmark cannot live in either list — it would go stale in the other
/// one the moment it was tapped. This is the one copy both walls read through.
final paigunSavedProvider =
    NotifierProvider<PaigunSavedNotifier, Map<String, bool>>(
  PaigunSavedNotifier.new,
);

class PaigunSavedNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => const <String, bool>{};

  /// Flips the bookmark before the request so the tap feels instant, and puts
  /// it back if the server refuses.
  ///
  /// Throws [ApiException] so the caller can tell "sign in first" (401) from a
  /// genuine failure.
  Future<void> toggle(String tripId, {required bool wasSaved}) async {
    final previous = state;
    state = <String, bool>{...previous, tripId: !wasSaved};

    try {
      final api = await ref.read(plunoApiProvider.future);
      if (wasSaved) {
        await api.trips.unsave(tripId);
      } else {
        await api.trips.save(tripId);
      }
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}
