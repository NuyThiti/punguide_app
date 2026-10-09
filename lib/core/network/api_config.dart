import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Where the Pluno API lives, and the knobs the client needs at startup.
///
/// Release builds talk to production, debug and profile builds to the local
/// dev server. Override either at build time:
/// `flutter run --dart-define=PLUNO_API_BASE_URL=https://api.pluno.co`
@immutable
class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 30),
    this.locale = 'th',
    this.currency = 'THB',
  });

  /// Reads `PLUNO_API_BASE_URL`, falling back to [productionBaseUrl] in
  /// release builds and the local dev server otherwise.
  factory ApiConfig.fromEnvironment() =>
      ApiConfig(baseUrl: _resolveBaseUrl(_envBaseUrl));

  static const _envBaseUrl =
      String.fromEnvironment('PLUNO_API_BASE_URL', defaultValue: '');

  static const productionBaseUrl =
      'https://travel-planner-api-git-909858882015.asia-northeast3.run.app';
  // TEMP (demo): debug points at production. Revert to
  // 'http://localhost:4002' after the demo — do not commit.
  static const _devBaseUrl = productionBaseUrl;

  /// No global prefix — paths start at `/trips`, `/places`, `/auth`.
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  /// Sent as the default `locale` on plan generation.
  final String locale;

  /// ISO 4217. The API treats every unlabelled amount as THB.
  final String currency;

  /// `localhost` means the developer's Mac, which an Android emulator cannot
  /// reach — it needs `10.0.2.2` for the same machine. iOS simulators share
  /// the host network, so they are left alone.
  static String _resolveBaseUrl(String configured) {
    final fallback = kReleaseMode ? productionBaseUrl : _devBaseUrl;
    final raw = configured.trim().isEmpty ? fallback : configured.trim();
    final url = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    if (kIsWeb) return url;
    final isAndroid = !kIsWeb && Platform.isAndroid;
    if (!isAndroid) return url;
    return url
        .replaceFirst('//localhost', '//10.0.2.2')
        .replaceFirst('//127.0.0.1', '//10.0.2.2');
  }
}
