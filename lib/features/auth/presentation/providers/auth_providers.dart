import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../domain/auth_session.dart';
import '../../domain/google_authenticator.dart';

/// The current session, or `null` when nobody is signed in.
///
/// Backed by the API: at startup it asks `/auth/me` with whatever access token
/// survived the last run, and it drops the session when the client reports the
/// refresh cookie is gone.
final authSessionProvider =
    StateNotifierProvider<AuthController, AuthSession?>((ref) {
  final controller = AuthController(
    null,
    ref.watch(plunoApiProvider.future),
    ref.watch(googleAuthenticatorProvider),
  );
  // Fire and forget: the UI shows the signed-out state until this lands.
  controller.restoreSession();
  return controller;
});

/// Convenience read for widgets that only care whether a session exists.
final isSignedInProvider =
    Provider<bool>((ref) => ref.watch(authSessionProvider) != null);

/// How the app obtains a Firebase ID token for `POST /auth/firebase`.
///
/// Ships unconfigured. Override this one provider with a `firebase_auth`
/// implementation once the platform apps exist in `punguide-65ad8` — the login
/// screen needs no change.
final googleAuthenticatorProvider = Provider<GoogleAuthenticator>(
  (ref) => const UnconfiguredGoogleAuthenticator(),
);

/// Owns the session for the whole app.
///
/// Constructed without an [api] — as tests and previews do — it falls back to
/// a local stand-in that fabricates a session from the username it is given,
/// so
/// screens can be exercised with no server running.
class AuthController extends StateNotifier<AuthSession?> {
  AuthController([
    AuthSession? initial,
    Future<PlunoApi>? api,
    GoogleAuthenticator? google,
  ])  : _api = api,
        _google = google,
        super(initial);

  final Future<PlunoApi>? _api;

  /// Only used to forget the Google account on sign-out; the sign-in flow is
  /// driven from the screen so it can tell a cancel from a failure.
  final GoogleAuthenticator? _google;
  StreamSubscription<void>? _expirySubscription;

  /// Whether this controller talks to the server or to the local stand-in.
  bool get isBackedByApi => _api != null;

  /// Restores the session left over from the last run.
  ///
  /// Silent on failure: a traveller who has never signed in, and one whose
  /// refresh cookie has lapsed, both just start signed out.
  Future<void> restoreSession() async {
    final api = await _resolveApi();
    if (api == null) return;
    _listenForExpiry(api);
    if (!api.hasSession) return;
    try {
      final user = await api.auth.me();
      if (!mounted) return;
      state = AuthSession.fromUser(user);
    } on ApiException catch (failure) {
      if (failure.isUnauthorized) return;
      debugPrint('Session restore failed: $failure');
    }
  }

  /// Creates an account, then signs into it — registering does not issue a
  /// token of its own.
  ///
  /// Throws [ApiException] with `isConflict` when the username is taken.
  Future<void> register({
    required String username,
    required String password,
  }) async {
    final api = await _resolveApi();
    if (api == null) {
      await signIn(username: username, password: password);
      return;
    }
    await api.auth.register(username: username, password: password);
    await signIn(username: username, password: password);
  }

  /// Signs in with a username and password.
  ///
  /// Note the API identifies accounts by **username**, not email: 3–30
  /// characters of letters, digits, `.` or `_`.
  ///
  /// Throws [ApiException] — `isUnauthorized` for wrong credentials,
  /// `isRateLimited` past five attempts a minute.
  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    final api = await _resolveApi();
    if (api == null) {
      await _signInLocally(username);
      return;
    }
    final result = await api.auth.login(username: username, password: password);
    if (!mounted) return;
    state = AuthSession.fromUser(result.user);
  }

  /// Signs in with a Firebase ID token — the Google path. The account is
  /// created on first use from the Google profile.
  Future<void> signInWithFirebase(String firebaseIdToken) async {
    final api = await _resolveApi();
    if (api == null) {
      await _signInLocally('google.user');
      return;
    }
    final result = await api.auth.loginWithFirebase(firebaseIdToken);
    if (!mounted) return;
    state = AuthSession.fromUser(result.user);
  }

  void signInAsDemo() => state = AuthSession.demo;

  /// Clears the session here and the refresh cookie on the server.
  ///
  /// The local state is dropped first, so signing out cannot be blocked by a
  /// failing network call.
  Future<void> signOut() async {
    state = null;
    try {
      await _google?.signOut();
    } on Object catch (error) {
      debugPrint('Google sign-out failed, continuing: $error');
    }
    final api = await _resolveApi();
    if (api == null) return;
    try {
      await api.auth.logout();
    } on ApiException catch (failure) {
      debugPrint('Sign-out call failed, session cleared locally: $failure');
    }
  }

  /// Updates the display name on the server and in the session.
  Future<void> updateDisplayName(String name) async {
    final api = await _resolveApi();
    if (api == null) return;
    final user = await api.users.updateName(name);
    if (!mounted) return;
    state = AuthSession.fromUser(user);
  }

  /// Uploads a new profile picture, up to 5 MB (JPEG or PNG).
  ///
  /// The returned `avatarUrl` is the same string as before — the file is
  /// overwritten at a fixed key — so the session takes a cache-busted copy.
  /// Widgets backed by their own disk cache still need clearing separately.
  Future<void> updateAvatar({
    String? filePath,
    List<int>? bytes,
    String? filename,
  }) async {
    final api = await _resolveApi();
    if (api == null) return;
    final user = await api.users.uploadAvatar(
      filePath: filePath,
      bytes: bytes,
      filename: filename,
    );
    if (!mounted) return;
    state = AuthSession.fromUser(user).withFreshAvatar();
  }

  /// Drops the session as soon as the client finds the refresh cookie gone,
  /// instead of leaving a signed-in shell that 401s on every call.
  void _listenForExpiry(PlunoApi api) {
    _expirySubscription ??= api.client.onSessionExpired.listen((_) {
      if (mounted) state = null;
    });
  }

  Future<PlunoApi?> _resolveApi() async {
    final api = _api;
    if (api == null) return null;
    try {
      return await api;
    } catch (error, stackTrace) {
      // The client could not be built at all — no keychain, no storage. The
      // app stays usable, signed out.
      debugPrint('API client unavailable: $error\n$stackTrace');
      return null;
    }
  }

  /// The offline stand-in. Keeps the pending state honest, and shapes the
  /// session exactly as [AuthSession.fromUser] would — a username/password
  /// account has no email until it signs in with Google.
  Future<void> _signInLocally(String username) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    state = AuthSession(
      displayName: _displayNameFrom(username),
      handle: '@$username',
      email: '',
      avatarImage: AuthSession.demo.avatarImage,
    );
  }

  @override
  void dispose() {
    _expirySubscription?.cancel();
    super.dispose();
  }

  /// `somchai.jai` -> `Somchai Jai`.
  static String _displayNameFrom(String username) {
    final words = username
        .split(RegExp(r'[._]'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .toList();
    return words.isEmpty ? 'PunGuide Traveler' : words.join(' ');
  }
}
