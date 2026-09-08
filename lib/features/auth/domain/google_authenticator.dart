/// Obtains a **Firebase ID token** for the Google sign-in flow.
///
/// The app deliberately does not depend on the Firebase SDKs yet: no iOS or
/// Android app is registered in the `punguide-65ad8` project, so there is no
/// `GoogleService-Info.plist` / `google-services.json` to initialise them
/// with. This is the seam they will plug into — implement it with
/// `firebase_auth` + `google_sign_in` and override
/// `googleAuthenticatorProvider`; nothing else has to change.
///
/// The token this returns is spent once, on `POST /auth/firebase`, in exchange
/// for the backend's own access token. It must never be sent anywhere else.
abstract class GoogleAuthenticator {
  /// Runs the Google account picker and returns a fresh Firebase ID token.
  ///
  /// Returns `null` when the traveller backs out of the picker — a cancel is
  /// not a failure and should leave the screen exactly as it was.
  ///
  /// Throws [GoogleSignInUnavailable] when the flow cannot run at all.
  Future<String?> signIn();

  /// Forgets the Google account so the next sign-in shows the picker again.
  /// Safe to call when nobody is signed in.
  Future<void> signOut();
}

/// Google sign-in cannot run on this build — the SDKs are absent, or the
/// Firebase project is not configured for this platform.
class GoogleSignInUnavailable implements Exception {
  const GoogleSignInUnavailable(this.message);

  /// Shown to the traveller as-is, so keep it plain.
  final String message;

  @override
  String toString() => 'GoogleSignInUnavailable: $message';
}

/// The implementation the app ships with today: it always reports that the
/// flow is unavailable, so the button explains itself instead of failing in a
/// way that looks like a bug.
class UnconfiguredGoogleAuthenticator implements GoogleAuthenticator {
  const UnconfiguredGoogleAuthenticator();

  @override
  Future<String?> signIn() async {
    throw const GoogleSignInUnavailable(
      'ยังเชื่อมต่อ Google ไม่ได้ รอตั้งค่า Firebase ให้เสร็จก่อน',
    );
  }

  @override
  Future<void> signOut() async {}
}
