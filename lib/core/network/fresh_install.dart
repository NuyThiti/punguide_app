import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_token_store.dart';

/// Signs out whatever the last install left behind.
///
/// On iOS the keychain **outlives the app**: delete PunGuide, install it
/// again, and the old access token is still there — so a traveller who wiped
/// the app comes back signed in, and the launch sequence skips Login. App
/// preferences are wiped with the app, so their absence is what tells the two
/// cases apart.
///
/// Android clears its keystore with the app's data, so this is a no-op there;
/// running it anyway keeps the two platforms on one path.
Future<void> signOutIfFreshInstall({SecretStore? storage}) async {
  const marker = 'pluno.installed';
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(marker) ?? false) return;

    await AuthTokenStore(storage: storage).clear();
    await prefs.setBool(marker, true);
  } catch (error, stackTrace) {
    // Preferences or the keychain being unavailable must not stop the app
    // from starting; the worst case is the old session surviving, which is
    // where this started.
    debugPrint('signOutIfFreshInstall failed: $error\n$stackTrace');
  }
}
