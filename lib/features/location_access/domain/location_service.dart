import 'package:flutter/foundation.dart';

/// What the OS answered when the app asked for the traveller's position.
enum LocationPermissionStatus {
  /// The traveller allowed it — once, or while using the app.
  granted,

  /// The traveller tapped "Don't Allow".
  denied,

  /// The flow cannot run at all on this build.
  unavailable,
}

/// A position read from the device.
@immutable
class LocationFix {
  const LocationFix({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// Asks the OS for the traveller's position.
///
/// This is a seam, exactly like [GoogleAuthenticator]: the app ships no
/// location plugin — `geolocator` and the `NSLocationWhenInUseUsageDescription`
/// entries that go with it are not in the project — so nothing here can reach
/// CoreLocation yet. Add the plugin, implement this, and override
/// [locationServiceProvider]; no screen has to change.
///
/// The Location Access page is built so that a device which cannot answer is
/// not a dead end: whatever comes back, the traveller lands on the map picker
/// and sets the origin by hand.
abstract class LocationService {
  /// Runs the OS permission dialog — the one the design shows over the sheet.
  Future<LocationPermissionStatus> requestPermission();

  /// The current position, or null when it is not available (no permission,
  /// no plugin, or no fix yet).
  Future<LocationFix?> currentFix();
}

/// The implementation the app ships with today: it reports that the flow
/// cannot run, which sends the traveller to the map picker to choose a place
/// themselves rather than failing in a way that looks like a bug.
class UnsupportedLocationService implements LocationService {
  const UnsupportedLocationService();

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      LocationPermissionStatus.unavailable;

  @override
  Future<LocationFix?> currentFix() async => null;
}
