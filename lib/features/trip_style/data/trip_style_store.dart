import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/trip_style_preference.dart';

/// Remembers สไตล์เที่ยวของฉัน across restarts.
///
/// Preferences rather than the account, because there is no endpoint for this
/// yet — `PATCH /users/me` takes a name and nothing else. Preferences rather
/// than the keychain, for the same reason the Location Access answer uses
/// them: this is not a secret, and on iOS the keychain outlives the app.
///
/// Null from [read] means the question has never been put. An empty
/// [TripStylePreference] means it was put and waved away with ข้ามไปก่อน —
/// the launch sequence has to tell those apart or it would ask again on every
/// single run.
abstract class TripStyleStore {
  Future<TripStylePreference?> read();

  Future<void> write(TripStylePreference preference);

  /// Forgets the answer, so the page is shown again.
  Future<void> clear();
}

/// The real store, on top of the platform's own preferences.
class PrefsTripStyleStore implements TripStyleStore {
  const PrefsTripStyleStore();

  static const _key = 'pluno.tripStyle';

  @override
  Future<TripStylePreference?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      if (stored == null) return null;

      final json = jsonDecode(stored);
      // Written by some other build, or half written. Asking once more costs
      // the traveller one page; a half-read answer would narrow the board
      // against chips they never chose.
      if (json is! Map<String, dynamic>) return null;
      return TripStylePreference.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint('TripStyleStore.read failed: $error\n$stackTrace');
      return null;
    }
  }

  @override
  Future<void> write(TripStylePreference preference) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(preference.toJson()));
    } catch (error, stackTrace) {
      // The answer still holds for this run; it just will not survive a
      // restart, which costs one more page rather than breaking the flow.
      debugPrint('TripStyleStore.write failed: $error\n$stackTrace');
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (error, stackTrace) {
      debugPrint('TripStyleStore.clear failed: $error\n$stackTrace');
    }
  }
}

/// Forgets everything at exit. For tests, and for a build with no preferences.
class InMemoryTripStyleStore implements TripStyleStore {
  InMemoryTripStyleStore([this._preference]);

  TripStylePreference? _preference;

  @override
  Future<TripStylePreference?> read() async => _preference;

  @override
  Future<void> write(TripStylePreference preference) async =>
      _preference = preference;

  @override
  Future<void> clear() async => _preference = null;
}
