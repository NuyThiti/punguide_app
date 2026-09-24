import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/pluno_api.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../paigun/domain/nearby_trip.dart' show distanceKmBetween;
import '../domain/location_service.dart';
import '../domain/picked_location.dart';

/// Keeps the account's copy of the traveller's position in step with the
/// device, through `/users/me/location`.
///
/// The account stores one fix and overwrites it — never a trail — so there is
/// nothing to be gained by sending often. What it buys is a position on a run
/// where the device never produces one: the app can measure distances without
/// waking the GPS on every screen.
class LocationSync {
  LocationSync(this._ref);

  final Ref _ref;

  /// The API refuses a reading older than 24 hours. Kept a clear hour short of
  /// that so a request in flight cannot age past the limit in transit.
  static const maxAge = Duration(hours: 23);

  /// And one more than five minutes ahead of the server, which is its
  /// allowance for a device clock running fast. Half of that is plenty.
  static const maxSkew = Duration(minutes: 2);

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
      await (await _ref.read(plunoApiProvider.future)).users.saveLocation(
            UserLocation(
              latitude: fix.latitude,
              longitude: fix.longitude,
              accuracyMeters: fix.accuracyMeters,
              capturedAt: fix.capturedAt,
            ),
          );
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
  /// Three things separate this from [push], all of them following from the
  /// fact that a person chose this point rather than a sensor reporting it:
  ///
  /// * the move threshold does not apply — confirming a spot two streets away
  ///   is a deliberate act, and ignoring it would look broken;
  /// * no `accuracyM` goes up, because a pinned point has no error radius, and
  ///   leaving the field out clears whatever the last reading left behind —
  ///   that radius described a different point;
  /// * no `capturedAt` either: nothing captured this, so the server stamps its
  ///   own arrival time rather than the app inventing one.
  Future<bool> pushChosen({
    required double latitude,
    required double longitude,
  }) async {
    if (!_ref.read(isSignedInProvider)) return false;

    try {
      await (await _ref.read(plunoApiProvider.future)).users.saveLocation(
            UserLocation(latitude: latitude, longitude: longitude),
          );
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

  /// A reading the API will accept. A missing timestamp is fine — the server
  /// then stamps it on arrival.
  bool _isSendable(DateTime? capturedAt) {
    if (capturedAt == null) return true;
    final now = DateTime.now();
    // A cached fix can be days old, and a device clock can run fast; either
    // way the API answers 400, so neither is worth the request.
    if (now.difference(capturedAt) > maxAge) return false;
    return capturedAt.difference(now) <= maxSkew;
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
