import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The three operations [AuthTokenStore] needs from a keystore.
///
/// An interface rather than a direct dependency so the store can be tested,
/// and so a platform without a keychain can fall back to memory.
abstract class SecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// The real thing: the platform keychain / keystore.
class SecureSecretStore implements SecretStore {
  const SecureSecretStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// A store that forgets everything at exit. Used by tests, and as a fallback.
class InMemorySecretStore implements SecretStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// Holds the access token for the app's lifetime and across restarts.
///
/// The refresh token is never seen here: the API returns it as an httpOnly
/// cookie scoped to `Path=/auth`, so the cookie jar owns it instead.
class AuthTokenStore {
  AuthTokenStore({SecretStore? storage})
      : _storage = storage ?? const SecureSecretStore();

  static const _tokenKey = 'pluno.accessToken';
  static const _expiryKey = 'pluno.accessTokenExpiresAt';

  /// Refresh this early rather than waiting for a 401 — the optional-auth
  /// routes answer 200 as an anonymous caller when the token has expired, so a
  /// 401 never arrives to trigger the retry.
  static const refreshLeeway = Duration(minutes: 2);

  final SecretStore _storage;

  String? _accessToken;
  DateTime? _expiresAt;
  bool _loaded = false;

  String? get accessToken => _accessToken;

  DateTime? get expiresAt => _expiresAt;

  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  /// True once the token is inside [refreshLeeway] of expiry, and for a token
  /// whose expiry we never learned (treated as stale so it gets refreshed).
  bool get needsRefresh {
    if (!hasToken) return false;
    final expiry = _expiresAt;
    if (expiry == null) return true;
    return DateTime.now().isAfter(expiry.subtract(refreshLeeway));
  }

  /// Reads the persisted token once per launch; later calls are a no-op.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      _accessToken = await _storage.read(_tokenKey);
      final rawExpiry = await _storage.read(_expiryKey);
      _expiresAt = rawExpiry == null ? null : DateTime.tryParse(rawExpiry);
    } catch (error, stackTrace) {
      // A locked keychain must not stop the app from starting; the user just
      // lands on the sign-in screen.
      debugPrint('AuthTokenStore.load failed: $error\n$stackTrace');
      _accessToken = null;
      _expiresAt = null;
    }
  }

  /// Stores a freshly issued token. [expiresIn] is the API's own string
  /// (`15m`, `900s`, `1h`) — see [parseExpiresIn].
  Future<void> save({required String accessToken, String? expiresIn}) async {
    final lifetime = parseExpiresIn(expiresIn);
    _accessToken = accessToken;
    _expiresAt = lifetime == null ? null : DateTime.now().add(lifetime);
    _loaded = true;
    try {
      await _storage.write(_tokenKey, accessToken);
      final expiry = _expiresAt;
      if (expiry == null) {
        await _storage.delete(_expiryKey);
      } else {
        await _storage.write(_expiryKey, expiry.toIso8601String());
      }
    } catch (error, stackTrace) {
      // Keep the in-memory token: this session still works, it just will not
      // survive a restart.
      debugPrint('AuthTokenStore.save failed: $error\n$stackTrace');
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _expiresAt = null;
    _loaded = true;
    try {
      await _storage.delete(_tokenKey);
      await _storage.delete(_expiryKey);
    } catch (error, stackTrace) {
      debugPrint('AuthTokenStore.clear failed: $error\n$stackTrace');
    }
  }

  /// `15m` -> 15 minutes. Accepts `s`/`m`/`h`/`d` suffixes and bare seconds,
  /// and returns `null` for anything it cannot read.
  static Duration? parseExpiresIn(String? expiresIn) {
    final raw = expiresIn?.trim().toLowerCase() ?? '';
    if (raw.isEmpty) return null;
    final match = RegExp(r'^(\d+)\s*([smhd])?$').firstMatch(raw);
    if (match == null) return null;
    final amount = int.tryParse(match.group(1)!);
    if (amount == null) return null;
    switch (match.group(2)) {
      case 'm':
        return Duration(minutes: amount);
      case 'h':
        return Duration(hours: amount);
      case 'd':
        return Duration(days: amount);
      case 's':
      case null:
      default:
        return Duration(seconds: amount);
    }
  }
}
