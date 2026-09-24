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

/// The province an address ends in — "เชียงใหม่", "กรุงเทพมหานคร" — or null
/// when nothing in it is usable.
///
/// This now fills the post's `destination`, so it has to be a name a reader
/// recognises. Two shapes have to survive it, and Google answers with both:
///
///  * comma-separated, as it writes English — "…, Phra Nakhon, Bangkok 10200,
///    Thailand" — where the last segment is the country and the one before it
///    the city;
///  * one unbroken run of words, as it writes Thai, with no commas at all —
///    "ถนน ราชดำเนินกลาง แขวงพระบรมมหาราชวัง เขตพระนคร กรุงเทพมหานคร 10200".
///    There the postcode is the anchor and the word in front of it is the
///    province; with no postcode, the last word is.
///
/// A place with no street number of its own is led by a Plus Code, which is a
/// coordinate in disguise and must never be what a post says it was about.
String? _localityOf(String? address) {
  final text = _withoutPlusCode((address ?? '').trim()).trim();
  if (text.isEmpty) return null;

  final parts = text
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;
  if (parts.length > 1) {
    final city = parts[parts.length - 2].replaceAll(_postcode, '').trim();
    return city.isEmpty ? null : city;
  }
  return _provinceInRun(parts.first);
}

/// The province inside one unbroken run of words. See [_localityOf].
String? _provinceInRun(String run) {
  // The last match, not the first: a house number can be five digits too, and
  // the postcode is always near the end.
  final postcodes = _postcode.allMatches(run);
  final head = postcodes.isEmpty ? run : run.substring(0, postcodes.last.start);
  final words = head.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return words.isEmpty ? null : words.last;
}

/// Drops a leading Plus Code, keeping whatever the segment says after it.
String _withoutPlusCode(String part) => part.replaceFirst(_plusCode, '');

final _postcode = RegExp(r'\b\d{4,6}\b');

/// Open Location Code: four to eight characters of its own alphabet, a plus,
/// then two or three more — "QF4V+88R", "7P88+5C".
final _plusCode = RegExp(
    r'^\s*[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,3}\b',
    caseSensitive: false);


