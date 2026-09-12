import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../home/presentation/providers/home_feed_providers.dart';
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
/// A fixed place, not a GPS fix: the app has no location plugin, and the
/// header in the design shows a district and postcode rather than a live
/// position. Kept behind a provider so a real fix — or a place the traveller
/// picks — can replace it without touching the cards.
final paigunOriginProvider = StateProvider<PaigunOrigin>(
  (ref) => const PaigunOrigin(
    label: 'ตำแหน่งของฉัน',
    address: 'เขตพระนคร, กรุงเทพ 10200',
    latitude: 13.7563,
    longitude: 100.4930,
  ),
);

/// What the ตัวกรอง wizard last applied to the board.
///
/// Empty until the traveller finishes the wizard, and it outlives the wizard's
/// own route so reopening it shows the answers already in force. Kept in
/// memory only — a filter is a mood, not a setting.
final tripFilterProvider = StateProvider<TripFilter>((ref) => TripFilter.none);

/// How many rows of the feed wear the Top PunGuide badge.
const _featuredCount = 6;

/// The public feed decorated with distance and the Top PunGuide badge.
///
/// The corpus is the same `GET /trips` list Home already holds — there is no
/// nearby endpoint, and the feed is not paginated — so switching chips and
/// re-sorting costs no request.
final paigunTripsProvider = Provider<AsyncValue<List<NearbyTrip>>>((ref) {
  final origin = ref.watch(paigunOriginProvider);
  final filter = ref.watch(tripFilterProvider);

  return ref.watch(homeFeedProvider).whenData((trips) {
    // The badge ranks the whole feed, not what survives the filter: a trip
    // does not stop being a Top PunGuide because someone asked for beaches.
    final featured = _featuredIds(trips);

    return List<NearbyTrip>.unmodifiable(
      trips.where(filter.matches).map(
            (trip) => NearbyTrip(
              trip: trip,
              featured: featured.contains(trip.id),
              distanceKm: _distanceTo(trip, origin),
            ),
          ),
    );
  });
});

/// Nearest first. Rows whose destination has no coordinates keep their feed
/// order at the end — unknown is not "far away", so they must not be dropped.
final nearMeTripsProvider = Provider<AsyncValue<List<NearbyTrip>>>((ref) {
  return ref.watch(paigunTripsProvider).whenData((trips) {
    final located = trips.where((row) => row.distanceKm != null).toList()
      ..sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));

    return List<NearbyTrip>.unmodifiable(<NearbyTrip>[
      ...located,
      ...trips.where((row) => row.distanceKm == null),
    ]);
  });
});

/// Most remixed and liked first — the same ranking that hands out the badge.
final topPunGuideTripsProvider = Provider<AsyncValue<List<NearbyTrip>>>((ref) {
  return ref.watch(paigunTripsProvider).whenData((trips) {
    final ordered = List<NearbyTrip>.of(trips)
      ..sort((a, b) => _popularity(b.trip).compareTo(_popularity(a.trip)));
    return List<NearbyTrip>.unmodifiable(ordered);
  });
});

Set<String> _featuredIds(List<TripListItem> trips) {
  final ordered = List<TripListItem>.of(trips)
    ..sort((a, b) => _popularity(b).compareTo(_popularity(a)));
  return ordered
      .take(_featuredCount)
      .where((trip) => _popularity(trip) > 0)
      .map((trip) => trip.id)
      .toSet();
}

int _popularity(TripListItem trip) => trip.remixCount + trip.likeCount;

double? _distanceTo(TripListItem trip, PaigunOrigin origin) {
  final place = trip.destinationPlace;
  if (place == null || !place.hasCoordinates) return null;

  return distanceKmBetween(
    origin.latitude,
    origin.longitude,
    place.latitude!,
    place.longitude!,
  );
}
