import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../data/location_permission_store.dart';
import '../../data/location_sync.dart';
import '../../domain/location_service.dart';
import '../../domain/picked_location.dart';

/// The seam the OS permission dialog plugs into. Overridden in tests, and by
/// whichever build finally ships a location plugin.
final locationServiceProvider =
    Provider<LocationService>((ref) => const UnsupportedLocationService());

/// Where the answer is kept between runs.
final locationPermissionStoreProvider = Provider<LocationPermissionStore>(
  (ref) => const PrefsLocationPermissionStore(),
);

/// The answer as it stood when the app started, which `main` overrides once it
/// has read storage. Null means nobody has ever been asked.
///
/// Loaded once at startup rather than awaited on demand because the route gate
/// that consumes it has to answer synchronously — see `_locationGate`. Waiting
/// on the disk would stall every navigation to the board.
final storedLocationPermissionProvider =
    Provider<LocationPermissionStatus?>((ref) => null);

/// What the traveller last answered on the Location Access page, or null while
/// they have never been asked.
///
/// Deliberately not auto-disposing: the whole point is that the app stops
/// asking once there is an answer.
final locationPermissionProvider =
    NotifierProvider<LocationPermissionController, LocationPermissionStatus?>(
  LocationPermissionController.new,
);

class LocationPermissionController extends Notifier<LocationPermissionStatus?> {
  @override
  LocationPermissionStatus? build() =>
      ref.watch(storedLocationPermissionProvider);

  /// Takes the answer and writes it through, so the page does not come back on
  /// the next launch. Only clearing the app's storage undoes this.
  ///
  /// A refusal also erases the copy the account holds. Note that
  /// [LocationPermissionStatus.unavailable] deliberately does not: it means
  /// the question could not be put — location services switched off, or no
  /// plugin — and throwing away a good stored position over a momentary
  /// "could not ask" would lose data the traveller never asked to lose.
  Future<void> record(LocationPermissionStatus status) async {
    state = status;
    await ref.read(locationPermissionStoreProvider).write(status);

    if (status == LocationPermissionStatus.denied) {
      ref.read(locationFixProvider.notifier).forget();
      await ref.read(locationSyncProvider).forget();
    }
  }
}

/// Where the traveller is, as far as this run of the app knows.
///
/// Every reading goes through [LocationFixController.capture], which is the
/// one place that mirrors it onto the account — so a new call site cannot
/// quietly forget to sync.
final locationFixProvider =
    NotifierProvider<LocationFixController, LocationFixPoint?>(
  LocationFixController.new,
);

class LocationFixController extends Notifier<LocationFixPoint?> {
  @override
  LocationFixPoint? build() => null;

  /// Takes a fresh reading from the device and sends it up.
  Future<void> capture(LocationFix fix) async {
    state = LocationFixPoint(
      latitude: fix.latitude,
      longitude: fix.longitude,
    );
    await ref.read(locationSyncProvider).push(fix);
  }

  /// Makes sure there is *some* position to measure from, without insisting on
  /// the GPS.
  ///
  /// The account's stored fix lands first: it costs one request, no hardware
  /// and no wait, which is the whole reason it is kept. The device is then
  /// asked for a fresher one, which replaces it and syncs back up if the
  /// traveller has moved — the "update on app open" half of the contract.
  Future<void> ensureFix() async {
    if (state == null) {
      final stored = await ref.read(locationSyncProvider).pull();
      if (stored != null) {
        state = LocationFixPoint(
          latitude: stored.latitude,
          longitude: stored.longitude,
        );
      }
    }

    if (ref.read(locationPermissionProvider) !=
        LocationPermissionStatus.granted) {
      return;
    }
    final fix = await ref.read(locationServiceProvider).currentFix();
    if (fix != null) await capture(fix);
  }

  /// Drops the position this run was holding. Does not touch the account —
  /// [LocationPermissionController.record] owns that call.
  void forget() => state = null;
}

/// What has been typed into the picker's search field.
final locationQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Two characters is enough for a district — "บาง" already narrows Bangkok.
const minLocationQueryLength = 2;

/// Every keystroke here is a paid Places request, so they are collapsed. Same
/// window the destination type-ahead and the post pin picker use.
const _debounce = Duration(milliseconds: 350);

/// Places matching [locationQueryProvider], debounced.
///
/// `/places/search` rather than `/places/autocomplete`: the picker has to drop
/// a pin the moment a row is tapped, and search answers with coordinates and
/// an address already attached. Autocomplete would cost a second `/details`
/// round trip before the map could move.
final locationResultsProvider = AsyncNotifierProvider.autoDispose<
    LocationResultsNotifier, List<PickedLocation>>(LocationResultsNotifier.new);

class LocationResultsNotifier
    extends AutoDisposeAsyncNotifier<List<PickedLocation>> {
  @override
  Future<List<PickedLocation>> build() async {
    final query = ref.watch(locationQueryProvider).trim();
    if (query.length < minLocationQueryLength) return const <PickedLocation>[];

    // The next keystroke rebuilds this provider, which disposes the current
    // build — so a run that is already stale never reaches the network.
    var cancelled = false;
    ref.onDispose(() => cancelled = true);
    await Future<void>.delayed(_debounce);
    if (cancelled) return const <PickedLocation>[];

    final origin = ref.read(locationFixProvider);
    final api = await ref.read(plunoApiProvider.future);
    final places = await api.places.search(query, limit: 12);

    return places
        .where((place) => place.latitude != null && place.longitude != null)
        .map((place) => _toPicked(place).measuredFrom(origin))
        .toList(growable: false);
  }
}

PickedLocation _toPicked(Place place) => PickedLocation(
      name: place.name,
      address: _shortAddress(place.address),
      latitude: place.latitude!,
      longitude: place.longitude!,
    );

/// The tail of a Google address, as the design prints it: "Bangkok 10200".
///
/// Google writes an English address "…, Phra Nakhon, Bangkok 10200, Thailand"
/// but a Thai one with no commas at all — "เขตพระนคร กรุงเทพมหานคร 10200".
/// Splitting on commas therefore trims the first and leaves the second whole,
/// so the postcode leads instead: the word in front of it is the city, in
/// either language.
///
/// Some places come back with no postcode at all — the API answers "Chiang
/// Mai" as "เทศบาลนครเชียงใหม่ อำเภอเมืองเชียงใหม่ เชียงใหม่" — and there the
/// last word is the province, which is the part worth keeping. Returns null
/// when there is nothing usable.
String? _shortAddress(String? address) {
  final text = (address ?? '').trim();
  if (text.isEmpty) return null;

  // The last match, not the first: a house number can be five digits too, and
  // the postcode is always near the end.
  final postcodes = _postcode.allMatches(text);
  if (postcodes.isNotEmpty) {
    final postcode = postcodes.last;
    final words = text
        .substring(0, postcode.start)
        .split(RegExp(r'[,\s]+'))
        .where((word) => word.isNotEmpty)
        .toList();
    return words.isEmpty
        ? postcode.group(0)
        : '${words.last} ${postcode.group(0)}';
  }

  final parts = text
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;

  // Comma-separated: the last segment is the country, the one before it the
  // city. Written as one run of words instead: the last of them is the
  // province, everything ahead of it being street and district.
  if (parts.length >= 2) return parts[parts.length - 2];

  final words = parts.first.split(RegExp(r'\s+'))
    ..removeWhere((word) => word.isEmpty);
  return words.isEmpty ? null : words.last;
}

/// Thai postcodes are five digits, and so are Google's for most of the world.
final _postcode = RegExp(r'\b\d{5}\b');
