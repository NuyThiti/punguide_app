import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/auth/data/firebase_google_authenticator.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/location_access/data/geolocator_location_service.dart';
import 'features/location_access/data/location_permission_store.dart';
import 'features/location_access/presentation/providers/location_providers.dart';

export 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await _initialiseFirebase();
  // Read before the first frame so the route gate — which has to answer
  // synchronously — already knows whether the traveller has been asked.
  final locationPermission = await const PrefsLocationPermissionStore().read();
  runApp(
    ProviderScope(
      overrides: [
        storedLocationPermissionProvider.overrideWithValue(locationPermission),
        // The real CoreLocation / FusedLocationProvider flow. Tests and the
        // default keep the unconfigured stub.
        locationServiceProvider
            .overrideWithValue(const GeolocatorLocationService()),
        // Without Firebase the provider keeps its unconfigured default, which
        // tells the traveller Google sign-in is unavailable instead of
        // throwing at them.
        if (firebaseReady)
          googleAuthenticatorProvider
              .overrideWithValue(FirebaseGoogleAuthenticator()),
      ],
      child: const PlunoApp(),
    ),
  );
}

/// Starts Firebase from the platform config files — `GoogleService-Info.plist`
/// on iOS, `google-services.json` on Android. No generated `firebase_options`
/// needed.
///
/// A failure here is not fatal: everything except Google sign-in works without
/// Firebase, so the app launches either way.
Future<bool> _initialiseFirebase() async {
  try {
    await Firebase.initializeApp();
    return true;
  } catch (error, stackTrace) {
    debugPrint('Firebase unavailable, Google sign-in disabled: $error');
    debugPrintStack(stackTrace: stackTrace);
    return false;
  }
}
