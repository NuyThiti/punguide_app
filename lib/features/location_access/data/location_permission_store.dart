import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/location_service.dart';

/// Remembers how the traveller answered the Location Access page, across
/// restarts.
///
/// Deliberately not the keychain `SecretStore` the access token uses: this is
/// not a secret, and on iOS the keychain **survives the app being deleted**, so
/// a reinstall would never ask again. App preferences go with the app's data,
/// which is the behaviour wanted here — clear the storage and the page comes
/// back.
abstract class LocationPermissionStore {
  /// The stored answer, or null when nobody has been asked yet.
  Future<LocationPermissionStatus?> read();

  Future<void> write(LocationPermissionStatus status);

  /// Forgets the answer, so the page is shown again.
  Future<void> clear();
}

/// The real store, on top of the platform's own preferences.
class PrefsLocationPermissionStore implements LocationPermissionStore {
  const PrefsLocationPermissionStore();

  static const _key = 'pluno.locationPermission';

  @override
  Future<LocationPermissionStatus?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      if (stored == null) return null;
      // An unreadable value means some other build wrote it. Treating it as
      // unanswered is the safe way round: the cost is one extra ask, not a
      // board the traveller can never reach.
      for (final status in LocationPermissionStatus.values) {
        if (status.name == stored) return status;
      }
      return null;
    } catch (error, stackTrace) {
      // Preferences being unavailable must not stop the app from starting.
      debugPrint('LocationPermissionStore.read failed: $error\n$stackTrace');
      return null;
    }
  }

  @override
  Future<void> write(LocationPermissionStatus status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, status.name);
    } catch (error, stackTrace) {
      // The answer still holds for this run; it just will not survive a
      // restart, which costs one more ask rather than breaking the flow.
      debugPrint('LocationPermissionStore.write failed: $error\n$stackTrace');
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (error, stackTrace) {
      debugPrint('LocationPermissionStore.clear failed: $error\n$stackTrace');
    }
  }
}

/// Forgets everything at exit. For tests, and for a build with no preferences.
class InMemoryLocationPermissionStore implements LocationPermissionStore {
  InMemoryLocationPermissionStore([this._status]);

  LocationPermissionStatus? _status;

  @override
  Future<LocationPermissionStatus?> read() async => _status;

  @override
  Future<void> write(LocationPermissionStatus status) async => _status = status;

  @override
  Future<void> clear() async => _status = null;
}
