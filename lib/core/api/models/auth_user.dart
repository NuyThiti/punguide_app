import 'package:flutter/foundation.dart';

import 'json.dart';

/// The signed-in account.
///
/// Unusually for this API, the three optional fields are real `null`s rather
/// than absent keys: a username/password account has no name or email until it
/// signs in with Google.
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    this.name,
    this.email,
    this.avatarUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: Json.requiredString(json, 'id'),
        username: Json.requiredString(json, 'username'),
        name: Json.string(json, 'name'),
        email: Json.string(json, 'email'),
        avatarUrl: Json.string(json, 'avatarUrl'),
      );

  final String id;
  final String username;
  final String? name;
  final String? email;
  final String? avatarUrl;

  /// What to show in the UI: the display name when there is one, else the
  /// username — the same fallback the API applies to `customer.name`.
  String get displayName => name?.isNotEmpty == true ? name! : username;
}

/// The result of `POST /auth/login` and `POST /auth/firebase`.
///
/// The refresh token is deliberately not here — it arrives as an httpOnly
/// cookie on `Path=/auth` and is handled by the client's cookie jar.
@immutable
class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.user,
    this.expiresIn,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        accessToken: Json.requiredString(json, 'accessToken'),
        expiresIn: Json.string(json, 'expiresIn'),
        user: AuthUser.fromJson(Json.asMap(json['user'])),
      );

  final String accessToken;

  /// The access token's lifetime as the server words it, e.g. `15m`.
  final String? expiresIn;
  final AuthUser user;
}
