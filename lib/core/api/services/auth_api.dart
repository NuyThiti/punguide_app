import '../../network/api_client.dart';
import '../models/auth_user.dart';
import '../models/json.dart';
import '../models/user_location.dart';
import 'upload_form.dart';

/// Sign-up, sign-in, and the session probe.
///
/// The client owns token storage and refreshing; this service only performs
/// the calls and hands the token over after a successful exchange.
class AuthApi {
  const AuthApi(this._client);

  final PlunoApiClient _client;

  /// Creates an account. Returns the new user but **no token** — follow with
  /// [login].
  ///
  /// [username] is 3–30 characters of letters, digits, `.` or `_`.
  /// [password] is 8–72 characters (bcrypt truncates past 72 bytes).
  /// Throws with `isConflict` when the username is taken.
  Future<AuthUser> register({
    required String username,
    required String password,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/auth/register',
      body: <String, dynamic>{'username': username, 'password': password},
    );
    return AuthUser.fromJson(Json.asMap(body));
  }

  /// Signs in with a username and password. Rate limited to 5 per minute.
  ///
  /// On success the access token is persisted and the refresh cookie is in the
  /// jar, so every later call is authenticated automatically.
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/auth/login',
      body: <String, dynamic>{'username': username, 'password': password},
    );
    return _adopt(AuthResult.fromJson(Json.asMap(body)));
  }

  /// Signs in with a Firebase ID token — the Google path. Creates the account
  /// on first use, taking name, email and avatar from the Google profile.
  ///
  /// The Firebase token goes in the `Authorization` header, not the body, and
  /// replaces our own token for this one call.
  Future<AuthResult> loginWithFirebase(String firebaseIdToken) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/auth/firebase',
      headers: <String, String>{
        'Authorization': 'Bearer $firebaseIdToken',
      },
    );
    return _adopt(AuthResult.fromJson(Json.asMap(body)));
  }

  /// The signed-in user. Use it at startup to check a restored session.
  Future<AuthUser> me() async {
    final body = await _client.get<Map<String, dynamic>>('/auth/me');
    return AuthUser.fromJson(Json.asMap(body));
  }

  /// Clears the refresh cookie server-side, then drops everything locally.
  ///
  /// Refresh tokens are stateless, so a copy taken beforehand cannot be
  /// revoked — this ends the session on this device.
  Future<void> logout() async {
    try {
      await _client.post<dynamic>('/auth/logout');
    } finally {
      await _client.clearSession();
    }
  }

  Future<AuthResult> _adopt(AuthResult result) async {
    await _client.tokenStore.save(
      accessToken: result.accessToken,
      expiresIn: result.expiresIn,
    );
    return result;
  }
}

/// The profile mutations, plus the account's copy of where the traveller is.
/// Username and email are deliberately immutable.
class UsersApi {
  const UsersApi(this._client);

  final PlunoApiClient _client;

  /// Sets the display name. Required, non-empty, up to 255 characters.
  Future<AuthUser> updateName(String name) async {
    final body = await _client.patch<Map<String, dynamic>>(
      '/users/me',
      body: <String, dynamic>{'name': name},
    );
    return AuthUser.fromJson(Json.asMap(body));
  }

  /// Uploads a profile picture, up to 5 MB.
  Future<AuthUser> uploadAvatar({
    String? filePath,
    List<int>? bytes,
    String? filename,
  }) async {
    final form = await buildUploadForm(
      filePath: filePath,
      bytes: bytes,
      filename: filename,
    );
    final body = await _client.upload<Map<String, dynamic>>(
      '/users/me/avatar',
      form: form,
    );
    return AuthUser.fromJson(Json.asMap(body));
  }

  /// Where the traveller was last seen, or null when nothing is stored.
  ///
  /// Never a 404: "has not given permission yet" is an ordinary answer, so the
  /// endpoint returns 200 with `{"location": null}`.
  Future<UserLocation?> location() async {
    final body = await _client.get<Map<String, dynamic>>('/users/me/location');
    return UserLocation.fromEnvelope(body);
  }

  /// Saves the position, replacing whatever was there.
  ///
  /// 400 when the coordinates are out of range, or when `capturedAt` is more
  /// than five minutes ahead of the server or more than a day behind it — so
  /// never hand this a cached reading without checking its age first.
  Future<UserLocation?> saveLocation(UserLocation location) async {
    final body = await _client.put<Map<String, dynamic>>(
      '/users/me/location',
      body: location.toJson(),
    );
    return UserLocation.fromEnvelope(body);
  }

  /// Erases the stored position. Idempotent — a 204 either way, so there is no
  /// need to find out whether anything was there.
  Future<void> deleteLocation() => _client.delete<void>('/users/me/location');
}
