import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'api_config.dart';
import 'api_exception.dart';
import 'auth_token_store.dart';

/// The single HTTP entry point for the Pluno API.
///
/// It owns three things the rest of the app should not have to think about:
///
///  * the cookie jar that carries the httpOnly `refresh_token` (the API never
///    puts it in a response body, so a jar is mandatory, not an optimisation);
///  * the access token, attached as `Authorization: Bearer` to *every* request
///    — including the optional-auth ones, where an anonymous call would share
///    one global rate-limit bucket with the whole world;
///  * refreshing that token before it expires, and once reactively on a 401,
///    with concurrent callers folded into a single refresh.
class PlunoApiClient {
  PlunoApiClient({
    required ApiConfig config,
    required AuthTokenStore tokenStore,
    CookieJar? cookieJar,
    Dio? dio,
    Dio? refreshDio,
  })  : config = config,
        _tokenStore = tokenStore,
        _cookieJar = cookieJar ?? CookieJar(),
        _dio = dio ?? Dio(),
        _refreshDio = refreshDio ?? Dio() {
    _configure(_dio);
    _configure(_refreshDio);
    if (!kIsWeb) {
      final manager = CookieManager(_cookieJar);
      _dio.interceptors.add(manager);
      // The refresh call is the one request that *needs* the cookie, so the
      // bare client that performs it shares the same jar.
      _refreshDio.interceptors.add(manager);
    }
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  /// Builds a client whose cookie jar survives app restarts, so a returning
  /// user is refreshed back into their session instead of signed out.
  static Future<PlunoApiClient> create({
    ApiConfig? config,
    AuthTokenStore? tokenStore,
  }) async {
    final resolvedConfig = config ?? ApiConfig.fromEnvironment();
    final store = tokenStore ?? AuthTokenStore();
    await store.load();
    return PlunoApiClient(
      config: resolvedConfig,
      tokenStore: store,
      cookieJar: await _createCookieJar(),
    );
  }

  final ApiConfig config;
  final AuthTokenStore _tokenStore;
  final CookieJar _cookieJar;
  final Dio _dio;
  final Dio _refreshDio;

  Future<bool>? _refreshInFlight;
  final _sessionExpired = StreamController<void>.broadcast();

  AuthTokenStore get tokenStore => _tokenStore;

  /// Fires when the refresh cookie is gone or rejected — the user has to sign
  /// in again. Listen once, near the auth controller.
  Stream<void> get onSessionExpired => _sessionExpired.stream;

  /// Paths that must never carry a stale token or trigger a refresh, because
  /// they are how a token is obtained in the first place.
  static const _authExemptPaths = <String>{
    '/auth/login',
    '/auth/register',
    '/auth/refresh',
    '/auth/logout',
    '/auth/firebase',
  };

  void _configure(Dio dio) {
    dio.options
      ..baseUrl = config.baseUrl
      ..connectTimeout = config.connectTimeout
      ..receiveTimeout = config.receiveTimeout
      ..sendTimeout = config.receiveTimeout
      ..contentType = Headers.jsonContentType
      ..responseType = ResponseType.json
      // 4xx/5xx are handled by [ApiException], not by throwing raw Dio errors
      // from every call site, so let them through as responses first.
      ..validateStatus = (status) => status != null && status < 400;
    if (kIsWeb) {
      // Browsers own the cookie jar; they only send it when asked to.
      dio.options.extra['withCredentials'] = true;
    }
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isAuthExempt(options.path)) {
      handler.next(options);
      return;
    }
    await _tokenStore.load();
    if (_tokenStore.needsRefresh) {
      // Proactive: the optional-auth routes silently downgrade an expired
      // token to "anonymous" instead of answering 401, so waiting for a 401
      // would mean quietly losing isSaved/isLiked and the per-account quota.
      await _refresh();
    }
    final token = _tokenStore.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException failure,
    ErrorInterceptorHandler handler,
  ) async {
    final options = failure.requestOptions;
    final isRetryable = failure.response?.statusCode == 401 &&
        !_isAuthExempt(options.path) &&
        options.extra[_retriedFlag] != true;
    if (!isRetryable) {
      handler.next(failure);
      return;
    }
    final refreshed = await _refresh();
    if (!refreshed) {
      handler.next(failure);
      return;
    }
    try {
      final retried = await _dio.fetch<dynamic>(
        options..extra[_retriedFlag] = true,
      );
      handler.resolve(retried);
    } on DioException catch (retryFailure) {
      handler.next(retryFailure);
    }
  }

  static const _retriedFlag = 'pluno.retriedAfterRefresh';

  bool _isAuthExempt(String path) {
    final normalised = path.startsWith(config.baseUrl)
        ? path.substring(config.baseUrl.length)
        : path;
    return _authExemptPaths.contains(normalised.split('?').first);
  }

  /// Exchanges the refresh cookie for a new access token. Concurrent callers
  /// share one in-flight request rather than each spending the cookie.
  Future<bool> _refresh() {
    return _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _performRefresh() async {
    try {
      // No body: the server reads the `refresh_token` cookie the jar attaches.
      final response = await _refreshDio.post<dynamic>('/auth/refresh');
      final body = response.data;
      final token = body is Map ? body['accessToken'] : null;
      if (token is! String || token.isEmpty) {
        await _abandonSession();
        return false;
      }
      final expiresIn = body is Map && body['expiresIn'] is String
          ? body['expiresIn'] as String
          : null;
      await _tokenStore.save(accessToken: token, expiresIn: expiresIn);
      return true;
    } on DioException catch (failure) {
      final status = failure.response?.statusCode;
      if (status == 401 || status == 403) {
        // The cookie is gone, revoked, or expired: this session is over.
        await _abandonSession();
        return false;
      }
      // A timeout or a 5xx says nothing about the session — keep the token we
      // have and let the original request fail so the caller can retry.
      return false;
    }
  }

  Future<void> _abandonSession() async {
    await _tokenStore.clear();
    if (!_sessionExpired.isClosed) _sessionExpired.add(null);
  }

  /// Drops the access token and the refresh cookie. Call after `/auth/logout`.
  Future<void> clearSession() async {
    await _tokenStore.clear();
    try {
      await _cookieJar.deleteAll();
    } catch (error, stackTrace) {
      debugPrint('PlunoApiClient.clearSession failed: $error\n$stackTrace');
    }
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) =>
      _send<T>('GET', path, query: query, headers: headers);

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) =>
      _send<T>('POST', path, body: body, query: query, headers: headers);

  Future<T> patch<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _send<T>('PATCH', path, body: body, headers: headers);

  Future<T> put<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _send<T>('PUT', path, body: body, headers: headers);

  /// 204-returning deletes come back as `null`; use `delete<void>`.
  Future<T?> delete<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _sendNullable<T>('DELETE', path, body: body, headers: headers);

  /// Multipart upload — used by avatar and trip media.
  Future<T> upload<T>(
    String path, {
    required FormData form,
    Map<String, String>? headers,
  }) =>
      _send<T>('POST', path, body: form, headers: headers);

  Future<T> _send<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final result = await _sendNullable<T>(
      method,
      path,
      body: body,
      query: query,
      headers: headers,
    );
    if (result == null) {
      throw ApiException(
        statusCode: null,
        messages: const ['เซิร์ฟเวอร์ตอบกลับว่าง'],
        method: method,
        path: path,
      );
    }
    return result;
  }

  Future<T?> _sendNullable<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: _pruneQuery(query),
        options: Options(method: method, headers: headers),
      );
      final data = response.data;
      if (data == null || (data is String && data.isEmpty)) return null;
      return data as T;
    } on DioException catch (failure) {
      throw ApiException.fromDio(failure);
    }
  }

  /// Drops null values so an unset filter does not become `?destination=null`.
  static Map<String, dynamic>? _pruneQuery(Map<String, dynamic>? query) {
    if (query == null) return null;
    final pruned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value != null) pruned[key] = value;
    });
    return pruned.isEmpty ? null : pruned;
  }

  Future<void> close() async {
    await _sessionExpired.close();
    _dio.close(force: true);
    _refreshDio.close(force: true);
  }

  static Future<CookieJar> _createCookieJar() async {
    if (kIsWeb) return CookieJar();
    try {
      final directory = await getApplicationSupportDirectory();
      return PersistCookieJar(
        storage: FileStorage('${directory.path}/pluno_cookies'),
      );
    } catch (error, stackTrace) {
      // Without a writable directory the session simply ends at app exit.
      debugPrint('Falling back to an in-memory cookie jar: '
          '$error\n$stackTrace');
      return CookieJar();
    }
  }
}
