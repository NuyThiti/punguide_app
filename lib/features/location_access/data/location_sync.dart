import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/models/place.dart';
import '../../../core/api/pluno_api.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../paigun/domain/nearby_trip.dart' show distanceKmBetween;
import '../domain/location_service.dart';
import '../domain/picked_location.dart';

/// Keeps the account's copy of where the traveller is in step with the
/// device, through `/users/me/location`.
///
/// The account stores one *place* — a row in `places`, not raw coordinates —
/// and overwrites it, never a trail. So a device reading has to be turned into
/// the nearest place first ([_nearestPlace]), which costs a `/places/suggest`
/// call: one more reason not to send often. What it buys is a position on a
/// run where the device never produces one: the app can measure distances
/// without waking the GPS on every screen.
class LocationSync {
  LocationSync(this._ref);

  final Ref _ref;

  /// A reading older than this is not where the traveller *is*. The API no
  /// longer checks age — a place does not expire — but
  /// `getLastKnownPosition()` can hand back a days-old fix, and filing that
  /// over a fresher row would move them backwards.
  static const maxAge = Duration(hours: 23);

  /// How far out the nearest place is looked for, widened once: a quiet
  /// street can come back empty at close range while the district around it
  /// still has something on the map.
  static const searchRadiiMeters = <int>[300, 2000];

  /// Below this the traveller has not really gone anywhere, and the account
  /// would learn nothing from the write.
  static const minMoveKm = 1.0;

  /// What was last sent up, so an unmoved traveller costs no requests. In
  /// memory only: a fresh run should send once, which is exactly what the
  /// contract asks for on app open.
  LocationFixPoint? _lastPushed;

  /// Mirrors [fix] onto the account, unless there is no point.
  ///
  /// Returns true when something was actually written. Never throws: a failed
  /// sync is a stale row on the server, not a broken screen.
  Future<bool> push(LocationFix fix) async {
    // Every one of these routes is behind the auth guard. A signed-out
    // traveller still gets the map and the distances, just no stored copy.
    if (!_ref.read(isSignedInProvider)) return false;
    if (!_isSendable(fix.capturedAt)) return false;
    if (!_hasMovedEnough(fix)) return false;

    try {
      final api = await _ref.read(plunoApiProvider.future);
      final place = await _nearestPlace(api, fix.latitude, fix.longitude);
      if (place == null) return false;
      await api.users.saveLocation(place.id);
      _lastPushed = LocationFixPoint(
        latitude: fix.latitude,
        longitude: fix.longitude,
      );
      return true;
    } on ApiException catch (failure) {
      debugPrint('location push failed: ${failure.statusCode} $failure');
      return false;
    }
  }

  /// Mirrors a place the traveller pinned by hand onto the account.
  ///
  /// Unlike [push], the move threshold does not apply — confirming a spot two
  /// streets away is a deliberate act, and ignoring it would look broken.
  ///
  /// [placeId] is the row the traveller picked from search, sent as it is. A
  /// pin dropped on the map has none, so it goes up as the nearest place
  /// instead — the API stores places, not points.
  Future<bool> pushChosen({
    String? placeId,
    required double latitude,
    required double longitude,
  }) async {
    if (!_ref.read(isSignedInProvider)) return false;

    try {
      final api = await _ref.read(plunoApiProvider.future);
      final id =
          placeId ?? (await _nearestPlace(api, latitude, longitude))?.id;
      if (id == null) return false;
      await api.users.saveLocation(id);
      // Counts as the last thing sent, so the next device reading has to have
      // moved a kilometre from *here* to be worth a write.
      _lastPushed = LocationFixPoint(
        latitude: latitude,
        longitude: longitude,
      );
      return true;
    } on ApiException catch (failure) {
      debugPrint('chosen location push failed: ${failure.statusCode} $failure');
      return false;
    }
  }

  /// The position the account already holds, or null when it holds none.
  Future<UserLocation?> pull() async {
    if (!_ref.read(isSignedInProvider)) return null;
    try {
      return await (await _ref.read(plunoApiProvider.future)).users.location();
    } on ApiException catch (failure) {
      debugPrint('location pull failed: ${failure.statusCode} $failure');
      return null;
    }
  }

  /// Erases the stored position, for a traveller who has taken the permission
  /// back. Withdrawing it is a request for the data to be gone, not for one
  /// response to stop mentioning it.
  Future<void> forget() async {
    _lastPushed = null;
    if (!_ref.read(isSignedInProvider)) return;
    try {
      await (await _ref.read(plunoApiProvider.future)).users.deleteLocation();
    } on ApiException catch (failure) {
      debugPrint('location delete failed: ${failure.statusCode} $failure');
    }
  }

  /// A reading recent enough to stand for where the traveller is. A missing
  /// timestamp is taken as fresh.
  bool _isSendable(DateTime? capturedAt) {
    if (capturedAt == null) return true;
    return DateTime.now().difference(capturedAt) <= maxAge;
  }

  /// The closest place `/places/suggest` knows around the point — "near me,
  /// take the first", but by distance rather than the popularity order the
  /// route answers in, since a landmark two streets away says less about
  /// where someone stands than the shop across the road.
  ///
  /// Only places with coordinates count: the account's row is read back as a
  /// point to measure from, and one without any is no location at all.
  Future<Place?> _nearestPlace(
    PlunoApi api,
    double latitude,
    double longitude,
  ) async {
    for (final radius in searchRadiiMeters) {
      final places = await api.places.suggest(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radius,
        limit: 10,
      );
      final located = places
          .where((place) => place.latitude != null && place.longitude != null)
          .toList();
      if (located.isEmpty) continue;
      double away(Place place) => distanceKmBetween(
            latitude,
            longitude,
            place.latitude!,
            place.longitude!,
          );
      located.sort((a, b) => away(a).compareTo(away(b)));
      return located.first;
    }
    return null;
  }

  bool _hasMovedEnough(LocationFix fix) {
    final last = _lastPushed;
    if (last == null) return true;
    return distanceKmBetween(
          last.latitude,
          last.longitude,
          fix.latitude,
          fix.longitude,
        ) >=
        minMoveKm;
  }
}

final locationSyncProvider = Provider<LocationSync>(LocationSync.new);
