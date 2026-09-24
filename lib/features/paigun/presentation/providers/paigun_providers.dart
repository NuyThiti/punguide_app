import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/paigun_origin_store.dart';
import '../../domain/nearby_trip.dart';
import '../../domain/trip_filter.dart';

/// The three chips across the top of the ไปกัน board.
enum PaigunFilter { all, nearMe, topPunGuide }

extension PaigunFilterLabel on PaigunFilter {
  String get label => switch (this) {
        PaigunFilter.all => 'ทั้งหมด',
        PaigunFilter.nearMe => 'Near Me',
        PaigunFilter.topPunGuide => 'Top PunGuide',
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

/// What the ตัวกรอง wizard last applied to the board.
///
/// Empty until the traveller finishes the wizard, and it outlives the wizard's
/// own route so reopening it shows the answers already in force. Kept in
/// memory only — a filter is a mood, not a setting.
final tripFilterProvider = StateProvider<TripFilter>((ref) => TripFilter.none);

/// One wall of the board, straight from `GET /trips`.
///
/// Keyed by sort because the two walls are two different questions — "what is
/// near me" and "what is popular" — and the server answers each in one
/// request. Nothing is filtered or re-sorted here: the query carries the
/// wizard's answers, so what comes back is already the answer.
///
/// Re-reads whenever the session changes, the way Home's feed does: `isSaved`
/// and `isLiked` are per-viewer and come back false for an anonymous caller.
final paigunFeedProvider =
    FutureProvider.family<List<TripListItem>, FeedSort>((ref, sort) async {
  ref.watch(authSessionProvider);
  final filter = ref.watch(tripFilterProvider);
  final origin = ref.watch(paigunOriginProvider);

  final api = await ref.watch(plunoApiProvider.future);
  return api.trips.feed(filter.toFeedQuery(sort: sort, origin: origin));
});

/// A wall as the cards need it: distance from the server, the badge, and
/// whatever the traveller has bookmarked since the rows were fetched.
final paigunWallProvider =
    Provider.family<AsyncValue<List<NearbyTrip>>, FeedSort>((ref, sort) {
  final saved = ref.watch(paigunSavedProvider);

  // The badge ranks the wall it is on, not what the filter let through: a trip
  // does not stop being a Top PunGuide because someone asked for beaches.
  return ref
      .watch(paigunFeedProvider(sort))
      .whenData((trips) => decorateTrips(trips, saved: saved));
});

/// Nearest first, as the server ordered them. Rows whose destination has no
/// coordinates come back last rather than first — unknown is not "here".
final nearMeTripsProvider = Provider<AsyncValue<List<NearbyTrip>>>(
  (ref) => ref.watch(paigunWallProvider(FeedSort.nearest)),
);

/// Most liked, then most remixed.
final topPunGuideTripsProvider = Provider<AsyncValue<List<NearbyTrip>>>(
  (ref) => ref.watch(paigunWallProvider(FeedSort.popular)),
);

/// Re-reads both walls — pull to refresh, and the retry on a failed one.
///
/// Waits for them so the spinner lasts as long as the request does. A wall
/// that fails is not rethrown here: it renders its own error state, and
/// letting it escape would only crash the refresh gesture.
Future<void> refreshPaigunFeed(WidgetRef ref) async {
  ref.invalidate(paigunFeedProvider);

  await Future.wait(<Future<void>>[
    for (final sort in <FeedSort>[FeedSort.nearest, FeedSort.popular])
      ref
          .read(paigunFeedProvider(sort).future)
          .then<void>((_) {}, onError: (_, __) {}),
  ]);
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
