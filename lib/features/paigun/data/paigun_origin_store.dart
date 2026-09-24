import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/nearby_trip.dart';

/// Remembers the place the traveller confirmed in the map picker, across
/// restarts.
///
/// The account's own `/users/me/location` is *not* this: that is the device's
/// last fix, it carries no name, and reading it needs a session — sign out, or
/// let a refresh token lapse, and the board would forget where the traveller
/// said they were. A choice they made by hand belongs to the app, so it is
/// kept beside the Location Access answer, in the platform's preferences.
///
/// Same reasoning as [LocationPermissionStore]: preferences, not the keychain.
/// This is not a secret, and on iOS the keychain outlives the app itself.
abstract class PaigunOriginStore {
  /// The last confirmed origin, or null while the traveller has never picked
  /// one — in which case the board falls back to its own default.
  Future<PaigunOrigin?> read();

  Future<void> write(PaigunOrigin origin);

  Future<void> clear();
}

/// The real store, on top of the platform's own preferences.
class PrefsPaigunOriginStore implements PaigunOriginStore {
  const PrefsPaigunOriginStore();

  static const _key = 'pluno.paigunOrigin';

  @override
  Future<PaigunOrigin?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      if (stored == null) return null;

      final json = jsonDecode(stored);
      if (json is! Map) return null;

      final latitude = json['latitude'];
      final longitude = json['longitude'];
      final address = json['address'];
      // Written by some other build, or half written. Falling back to the
      // default costs one more trip to the picker; a half-read origin would
      // measure every distance on the board against nowhere.
      if (latitude is! num || longitude is! num || address is! String) {
        return null;
      }

      return PaigunOrigin(
        label: json['label'] is String ? json['label'] as String : address,
        address: address,
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      );
    } catch (error, stackTrace) {
      // Preferences being unavailable must not stop the board from opening.
      debugPrint('PaigunOriginStore.read failed: $error\n$stackTrace');
      return null;
    }
  }

  @override
  Future<void> write(PaigunOrigin origin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(<String, Object?>{
          'label': origin.label,
          'address': origin.address,
          'latitude': origin.latitude,
          'longitude': origin.longitude,
        }),
      );
    } catch (error, stackTrace) {
      // The origin still holds for this run; it just will not survive a
      // restart, which is the behaviour that was there before this existed.
      debugPrint('PaigunOriginStore.write failed: $error\n$stackTrace');
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (error, stackTrace) {
      debugPrint('PaigunOriginStore.clear failed: $error\n$stackTrace');
    }
  }
}

/// Forgets everything at exit. For tests, and for a build with no preferences.
class InMemoryPaigunOriginStore implements PaigunOriginStore {
  InMemoryPaigunOriginStore([this._origin]);

  PaigunOrigin? _origin;

  @override
  Future<PaigunOrigin?> read() async => _origin;

  @override
  Future<void> write(PaigunOrigin origin) async => _origin = origin;

  @override
  Future<void> clear() async => _origin = null;
}
