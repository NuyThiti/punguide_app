/// Whether this build can show a Google map.
///
/// The Maps SDKs read their key from native config — `MAPS_API_KEY` in
/// `ios/Flutter/Secrets.xcconfig` and in `android/local.properties`, both
/// gitignored — but Dart cannot see either, and building a `GoogleMap` on iOS
/// without `GMSServices.provideAPIKey` throws. So the same key is passed at
/// build time purely as a flag:
///
/// `flutter run --dart-define=MAPS_API_KEY=…`
///
/// Without it the map falls back to a placeholder instead of crashing.
class MapsConfig {
  const MapsConfig._();

  static const _key = String.fromEnvironment('MAPS_API_KEY');

  static bool get isConfigured => _key.trim().isNotEmpty;
}
