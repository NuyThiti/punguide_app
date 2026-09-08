import 'uuid_v4.dart';

/// The two custom headers the API reads, plus builders for them.
class PlunoHeaders {
  const PlunoHeaders._();

  /// Replay protection on `POST /trips/create`, `/remix`, `/days/:id/items`
  /// and `/trips/plan/generate`. Mint one key per user gesture and reuse it
  /// across retries; max 255 characters.
  static const idempotencyKey = 'Idempotency-Key';

  /// `false` skips route calculation, so dragging stops around stays cheap.
  static const calculateTravelSegments = 'X-Calculate-Travel-Segments';

  /// A header map carrying [key], or a fresh v4 UUID when it is omitted.
  static Map<String, String> idempotent([String? key]) =>
      {idempotencyKey: key ?? uuidV4()};

  /// Suppresses travel-segment calculation on itinerary writes. Follow a burst
  /// of these with one `POST /trips/:tripId/travel-segments/retry`.
  static Map<String, String> skipTravelSegments({bool skip = true}) =>
      {calculateTravelSegments: skip ? 'false' : 'true'};
}
