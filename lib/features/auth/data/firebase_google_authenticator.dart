import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/google_authenticator.dart';

/// The real Google path: Google issues an ID token, Firebase turns it into a
/// Firebase user, and *that* user's ID token is what `POST /auth/firebase`
/// wants. The Google token is never sent to our backend.
class FirebaseGoogleAuthenticator implements GoogleAuthenticator {
  FirebaseGoogleAuthenticator({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    String? clientId,
    String? serverClientId,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _clientId = clientId,
        _serverClientId = serverClientId ?? _envServerClientId;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final String? _clientId;
  final String? _serverClientId;

  /// Normally unnecessary: iOS reads its client id from
  /// `GoogleService-Info.plist`, and on Android the google-services Gradle
  /// plugin generates `default_web_client_id` from the `client_type: 3` entry
  /// in `google-services.json`, which the plugin picks up on its own.
  ///
  /// This is the escape hatch for a build without those config files — pass
  /// `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`. Without either, Android
  /// returns an account with no ID token at all.
  static const _envServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  Future<void>? _initialization;

  /// `initialize` is required before any other call and must run exactly once.
  Future<void> _ensureInitialized() {
    return _initialization ??= _googleSignIn.initialize(
      clientId: _clientId,
      serverClientId:
          _serverClientId?.isEmpty ?? true ? null : _serverClientId,
    );
  }

  @override
  Future<String?> signIn() async {
    try {
      await _ensureInitialized();
    } on Object catch (error) {
      throw GoogleSignInUnavailable(
        'เริ่มต้น Google Sign-In ไม่สำเร็จ: $error',
      );
    }

    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (failure) {
      // Backing out of the picker is a cancel, not an error.
      if (failure.code == GoogleSignInExceptionCode.canceled) return null;
      throw GoogleSignInUnavailable(_describe(failure));
    }

    final googleIdToken = account.authentication.idToken;
    if (googleIdToken == null || googleIdToken.isEmpty) {
      throw const GoogleSignInUnavailable(
        'Google ไม่ได้ส่ง ID token กลับมา '
        '(บน Android ต้องตั้ง GOOGLE_SERVER_CLIENT_ID ด้วย)',
      );
    }

    final UserCredential credential;
    try {
      credential = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: googleIdToken),
      );
    } on FirebaseAuthException catch (failure) {
      throw GoogleSignInUnavailable(
        failure.message ?? 'Firebase ปฏิเสธบัญชี Google นี้',
      );
    }

    // This — not the Google token — is what the backend exchanges.
    final firebaseIdToken = await credential.user?.getIdToken();
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      throw const GoogleSignInUnavailable('Firebase ไม่ได้ออก ID token');
    }
    return firebaseIdToken;
  }

  /// Signs out of both, so the next attempt shows the account picker again.
  /// Neither failure should block signing out of the app itself.
  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } on Object {
      // Nothing to forget, or the SDK is not configured. Either is fine here.
    }
    try {
      await _auth.signOut();
    } on Object {
      // Same: the app's own session is already gone by this point.
    }
  }

  static String _describe(GoogleSignInException failure) {
    switch (failure.code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'ตั้งค่า Google Sign-In ในแอปไม่ถูกต้อง '
            '(ตรวจ bundle ID, SHA-1 หรือ client id)';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'ตั้งค่า Firebase ของโปรเจกต์ยังไม่ครบ';
      case GoogleSignInExceptionCode.interrupted:
        return 'การเข้าสู่ระบบถูกขัดจังหวะ กรุณาลองใหม่';
      default:
        return failure.description ?? 'เข้าสู่ระบบด้วย Google ไม่สำเร็จ';
    }
  }
}
