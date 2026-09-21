import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Prints one line per API call while developing.
///
/// Debug builds only — it is never added in release, so nothing here can leak
/// into a shipped app. What it deliberately never prints:
///
///  * the `Authorization` header, or any header at all;
///  * the body of an auth route, which carries passwords and refresh tokens.
class ApiLogInterceptor extends Interceptor {
  const ApiLogInterceptor();

  static const _startedAt = '_loggedAt';

  /// How much of a body to print. Responses get more room than requests
  /// because a feed page is the thing you actually want to read.
  static const _requestLimit = 1000;
  static const _responseLimit = 2000;

  /// `debugPrint` drops output when a single line is very long, so bodies go
  /// out in pieces.
  static const _chunk = 800;

  /// Routes whose request body must never reach the console.
  static bool _isSecret(String path) =>
      path.startsWith('/auth') || path.contains('password');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAt] = DateTime.now();
    debugPrint('→ ${options.method} ${_path(options)}');
    _printBody(_requestBody(options));
    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    debugPrint('← ${response.statusCode} ${response.requestOptions.method} '
        '${_path(response.requestOptions)}  ${_took(response.requestOptions)}'
        '${_size(response)}');
    _printBody(_responseBody(response));
    handler.next(response);
  }

  @override
  void onError(DioException failure, ErrorInterceptorHandler handler) {
    final options = failure.requestOptions;
    final status = failure.response?.statusCode;
    debugPrint('✗ ${status ?? failure.type.name} ${options.method} '
        '${_path(options)}  ${_took(options)}');
    debugPrint('  ${_message(failure)}');
    final body =
        failure.response == null ? null : _responseBody(failure.response!);
    _printBody(body);
    handler.next(failure);
  }

  /// Long bodies in pieces, indented so they read as part of the call above.
  static void _printBody(String? body) {
    if (body == null) return;
    for (var i = 0; i < body.length; i += _chunk) {
      final end = i + _chunk < body.length ? i + _chunk : body.length;
      debugPrint('  ${body.substring(i, end)}');
    }
  }

  static String _path(RequestOptions options) {
    final query = options.uri.query;
    return query.isEmpty ? options.path : '${options.path}?$query';
  }

  static String _took(RequestOptions options) {
    final started = options.extra[_startedAt];
    if (started is! DateTime) return '';
    return '${DateTime.now().difference(started).inMilliseconds} ms';
  }

  static String _size(Response<dynamic> response) {
    final length = response.headers.value(Headers.contentLengthHeader);
    final bytes = int.tryParse(length ?? '');
    if (bytes == null) return '';
    return bytes < 1024
        ? '  $bytes B'
        : '  ${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  /// The request body for writes. Reads have none, and auth routes are
  /// withheld entirely — they carry passwords and refresh tokens.
  static String? _requestBody(RequestOptions options) {
    if (options.method == 'GET' || options.data == null) return null;
    if (_isSecret(options.path)) return '<redacted>';
    if (options.data is FormData) return '<form-data>';
    return _encode(options.data, _requestLimit);
  }

  /// What came back. Auth routes are withheld for the same reason: their
  /// response is where the tokens actually live.
  static String? _responseBody(Response<dynamic> response) {
    final data = response.data;
    if (data == null) return null;
    if (_isSecret(response.requestOptions.path)) return '<redacted>';
    if (data is ResponseBody) return '<stream>';
    return _encode(data, _responseLimit);
  }

  static String _encode(Object? data, int limit) {
    String text;
    try {
      text = jsonEncode(data);
    } catch (_) {
      text = data.toString();
    }
    return text.length <= limit
        ? text
        : '${text.substring(0, limit)}… (${text.length} chars total)';
  }

  static String _message(DioException failure) {
    final data = failure.response?.data;
    if (data is Map && data['message'] != null) return '${data['message']}';
    if (data is String && data.isNotEmpty) {
      return data.length <= 200 ? data : '${data.substring(0, 200)}…';
    }
    return failure.message ?? failure.type.name;
  }
}
