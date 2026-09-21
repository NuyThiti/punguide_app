import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/location_service.dart';

/// [LocationService] on top of the `geolocator` plugin — the implementation
/// that actually raises the OS dialog the design draws over the sheet.
///
/// Only "while using the app" is asked for. The design's copy talks about
/// "Always", but nothing here needs a position with the app closed: the board
/// is sorted the moment it is opened. Asking for Always costs a second, harder
/// prompt and a longer App Store review for nothing.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  /// A fix can take several seconds outdoors and never arrive indoors, so the
  /// wait is capped — the picker opens either way, and the traveller can
  /// choose a place by hand.
  static const _fixTimeout = Duration(seconds: 8);

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    try {
      // Location turned off for the whole device: the dialog would never
      // appear, so this is "unavailable" rather than a refusal by the
      // traveller — they never got the chance to refuse.
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationPermissionStatus.unavailable;
      }

      var permission = await Geolocator.checkPermission();
      // `denied` is also the state before anyone has ever been asked, which is
      // exactly when the dialog should come up.
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return _statusOf(permission);
    } catch (error, stackTrace) {
      // A platform that cannot answer must not take the flow down with it —
      // the traveller lands on the picker and sets a place by hand.
      debugPrint('requestPermission failed: $error\n$stackTrace');
      return LocationPermissionStatus.unavailable;
    }
  }

  @override
  Future<LocationFix?> currentFix() async {
    try {
      if (!await _isAllowed()) return null;

      // The cached position first: it is instant, and a board sorted by a
      // position from a minute ago is far better than one that waits.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return _fixOf(last);

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          // The board works in kilometres; metre-level accuracy would only
          // cost battery.
          accuracy: LocationAccuracy.medium,
          timeLimit: _fixTimeout,
        ),
      );
      return _fixOf(position);
    } catch (error, stackTrace) {
      // Timeouts land here too, which is the common case indoors.
      debugPrint('currentFix failed: $error\n$stackTrace');
      return null;
    }
  }

  Future<bool> _isAllowed() async {
    final permission = await Geolocator.checkPermission();
    return _statusOf(permission) == LocationPermissionStatus.granted;
  }

  static LocationFix _fixOf(Position position) => LocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        // The platforms report a radius in metres as a double; the API takes
        // a whole number, and sub-metre precision on an accuracy estimate is
        // noise anyway.
        accuracyMeters:
            position.accuracy.isFinite ? position.accuracy.round() : null,
        capturedAt: position.timestamp,
      );

  /// `deniedForever` is a refusal like any other as far as this app is
  /// concerned — it just cannot be undone from inside the dialog. The page
  /// records it and stops asking, which is what it would do anyway.
  static LocationPermissionStatus _statusOf(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.whileInUse ||
        LocationPermission.always =>
          LocationPermissionStatus.granted,
        LocationPermission.denied ||
        LocationPermission.deniedForever =>
          LocationPermissionStatus.denied,
        LocationPermission.unableToDetermine =>
          LocationPermissionStatus.unavailable,
      };
}
