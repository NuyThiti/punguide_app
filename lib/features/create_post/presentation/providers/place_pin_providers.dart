import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../location_access/presentation/providers/location_providers.dart';
import '../../../paigun/domain/nearby_trip.dart';
import '../../../paigun/presentation/providers/paigun_providers.dart';
import '../../domain/models/post_draft.dart';

/// What has been typed into the place-pin picker.
final placePinQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Shorter than a name — "ama" is already a useful search.
const minPlaceQueryLength = 2;

/// Every keystroke here is a paid Places request, so they are collapsed. Same
/// window the destination type-ahead uses.
const _debounce = Duration(milliseconds: 350);

/// How wide "nearby" reaches before the list would stop being walkable.
const _nearbyRadiusMeters = 3000;

/// Where distances are measured from: the device's own fix when there is one,
/// otherwise the point the traveller set for ไปกัน — the app's single notion of
/// "where I am", shared so the two boards cannot disagree.
final placePinOriginProvider = Provider<({double lat, double lng})?>((ref) {
  final fix = ref.watch(locationFixProvider);
  if (fix != null) return (lat: fix.latitude, lng: fix.longitude);

  // Never asked means nothing has been chosen, not even by hand, so the picker
  // offers to turn location on instead of measuring from a default.
  if (ref.watch(locationPermissionProvider) == null) return null;

  final origin = ref.watch(paigunOriginProvider);
  return (lat: origin.latitude, lng: origin.longitude);
});

/// True once the device itself can say where the traveller is standing, which
/// is the only case where "Use Current location" means anything.
final hasDeviceFixProvider =
    Provider<bool>((ref) => ref.watch(locationFixProvider) != null);

/// Places matching [placePinQueryProvider], debounced.
///
/// `/places/search` rather than `/places/autocomplete`: a post pins a cafe or
/// a viewpoint, and the type-ahead answers with cities only.
final placePinResultsProvider =
    AsyncNotifierProvider.autoDispose<PlacePinResultsNotifier, List<PostPlace>>(
        PlacePinResultsNotifier.new);

class PlacePinResultsNotifier
    extends AutoDisposeAsyncNotifier<List<PostPlace>> {
  @override
  Future<List<PostPlace>> build() async {
    final query = ref.watch(placePinQueryProvider).trim();
    if (query.length < minPlaceQueryLength) return const <PostPlace>[];

    // The next keystroke rebuilds this provider, which disposes the current
    // build — so a run that is already stale never reaches the network.
    var cancelled = false;
    ref.onDispose(() => cancelled = true);
    await Future<void>.delayed(_debounce);
    if (cancelled) return const <PostPlace>[];

    final origin = ref.read(placePinOriginProvider);
    final api = await ref.read(plunoApiProvider.future);
    final places = await api.places.search(query, limit: 20);
    return places
        .map((place) => _toPostPlace(place, origin))
        .toList(growable: false);
  }
}

/// What to show before anything is typed: the places around the traveller,
/// nearest first, from `/places/suggest`.
///
/// Empty when there is no origin at all — the picker then offers to turn
/// location on rather than guessing a point.
final nearbyPlacePinsProvider =
    AsyncNotifierProvider.autoDispose<NearbyPlacePinsNotifier, List<PostPlace>>(
        NearbyPlacePinsNotifier.new);

class NearbyPlacePinsNotifier
    extends AutoDisposeAsyncNotifier<List<PostPlace>> {
  @override
  Future<List<PostPlace>> build() async {
    final origin = ref.watch(placePinOriginProvider);
    if (origin == null) return const <PostPlace>[];

    final api = await ref.read(plunoApiProvider.future);
    final places = await api.places.suggest(
      latitude: origin.lat,
      longitude: origin.lng,
      radiusMeters: _nearbyRadiusMeters,
      limit: 20,
    );

    final pins = places
        .map((place) => _toPostPlace(place, origin))
        .toList(growable: false);
    // The endpoint orders by its own popularity score; the design lists them
    // by how far they are, and a row without coordinates has no distance to
    // sort on, so those keep their place at the end.
    return pins.toList()
      ..sort((a, b) => (a.distanceKm ?? double.infinity)
          .compareTo(b.distanceKm ?? double.infinity));
  }
}

/// Keeps what the picker rows show. [origin] measures the distance; without
/// one the row prints its address alone rather than a made-up "0 m.".
PostPlace _toPostPlace(Place place, ({double lat, double lng})? origin) {
  final latitude = place.latitude;
  final longitude = place.longitude;
  final measurable = origin != null && latitude != null && longitude != null;

  return PostPlace(
    id: place.id,
    mapId: place.mapId,
    name: place.name,
    area: _localityOf(place.address),
    address: place.address?.trim().isEmpty ?? true ? null : place.address,
    latitude: latitude,
    longitude: longitude,
    distanceKm: measurable
        ? distanceKmBetween(origin.lat, origin.lng, latitude, longitude)
        : null,
  );
}

/// The province-ish tail of an address: the last segment before the country,
/// with any postcode stripped off it. Returns null when nothing is usable.
///
/// Google writes "…, Chiang Mai 50200, Thailand", and the row has space for
/// "เชียงใหม่" — not for the whole line.
String? _localityOf(String? address) {
  final parts = (address ?? '')
      .split(',')
      .map((part) => part.replaceAll(_postcode, '').trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;

  final locality = parts.length > 1 ? parts[parts.length - 2] : parts.first;
  return locality.isEmpty ? null : locality;
}

final _postcode = RegExp(r'\b\d{4,6}\b');
