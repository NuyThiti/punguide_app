import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// A failed API call, already unpacked from Nest's error envelope.
///
/// `message` on the wire is a `String` for business errors and a `List<String>`
/// when validation rejects a payload; both land in [messages] here so callers
/// never have to type-test it.
@immutable
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.messages,
    this.error,
    this.method,
    this.path,
  });

  /// Builds an [ApiException] from a Dio failure, whatever its cause.
  factory ApiException.fromDio(DioException failure) {
    final response = failure.response;
    final requestOptions = failure.requestOptions;
    final method = requestOptions.method;
    final path = requestOptions.path;

    if (response == null) {
      return ApiException(
        statusCode: null,
        messages: [_transportMessage(failure)],
        method: method,
        path: path,
      );
    }

    final body = response.data;
    final map = body is Map ? body : const <String, dynamic>{};
    final rawMessage = map['message'];
    final messages = rawMessage is List
        ? rawMessage.map((entry) => '$entry').toList()
        : rawMessage is String && rawMessage.isNotEmpty
            ? <String>[rawMessage]
            : <String>[_statusMessage(response.statusCode)];

    return ApiException(
      statusCode: response.statusCode,
      messages: messages,
      error: map['error'] is String ? map['error'] as String : null,
      method: method,
      path: path,
    );
  }

  /// `null` when the request never reached the server (timeout, no network).
  final int? statusCode;

  /// Always at least one entry, ready to show to the user.
  final List<String> messages;

  /// Nest's short reason phrase, e.g. `Bad Request`.
  final String? error;
  final String? method;
  final String? path;

  /// The whole reason, newline-joined — validation failures list several.
  String get message => messages.join('\n');

  bool get isNetworkFailure => statusCode == null;

  /// The token is missing, malformed, or expired.
  bool get isUnauthorized => statusCode == 401;

  /// Remixing someone else's private trip — the only 403 in the API.
  bool get isForbidden => statusCode == 403;

  /// Not found, or found but owned by somebody else: the API answers 404 to
  /// both on purpose, so this never proves the resource is gone.
  bool get isNotFound => statusCode == 404;

  /// Username taken, duplicate `dayNumber`, or an email colliding.
  bool get isConflict => statusCode == 409;

  bool get isRateLimited => statusCode == 429;

  /// Validation rejected the payload, including an unknown field —
  /// `forbidNonWhitelisted` is on, so echoing a response back is a 400.
  bool get isValidationError => statusCode == 400;

  /// Google Places / Routes is down or refused the key.
  bool get isUpstreamFailure => statusCode == 502;

  /// A server-side env key is unset (Firebase, OpenAI, Google, ...).
  bool get isNotConfigured => statusCode == 503;

  @override
  String toString() =>
      'ApiException(${statusCode ?? 'no response'} $method $path): $message';

  static String _transportMessage(DioException failure) {
    switch (failure.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return 'เชื่อมต่อเซิร์ฟเวอร์ไม่ทัน กรุณาลองอีกครั้ง';
      case DioExceptionType.cancel:
        return 'คำขอถูกยกเลิก';
      case DioExceptionType.connectionError:
        return 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ตรวจสอบอินเทอร์เน็ตของคุณ';
      case DioExceptionType.badCertificate:
        return 'ใบรับรองของเซิร์ฟเวอร์ไม่ถูกต้อง';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return failure.message ?? 'เกิดข้อผิดพลาดที่ไม่รู้จัก';
    }
  }

  static String _statusMessage(int? statusCode) {
    switch (statusCode) {
      case 401:
        return 'กรุณาเข้าสู่ระบบอีกครั้ง';
      case 404:
        return 'ไม่พบข้อมูลที่ต้องการ';
      case 429:
        return 'เรียกใช้บ่อยเกินไป กรุณารอสักครู่';
      case 502:
        return 'บริการภายนอกขัดข้อง กรุณาลองอีกครั้ง';
      case 503:
        return 'บริการนี้ยังไม่พร้อมใช้งาน';
      default:
        return 'คำขอไม่สำเร็จ (${statusCode ?? '-'})';
    }
  }
}
