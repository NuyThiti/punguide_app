import 'dart:math';

/// Random v4 UUIDs, for the two places the API asks for one from the client:
/// `Idempotency-Key` headers and Places `sessionToken` query params.
String uuidV4([Random? random]) {
  final rng = random ?? _secureRandom;
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

final Random _secureRandom = _tryCreateSecureRandom();

Random _tryCreateSecureRandom() {
  try {
    return Random.secure();
  } on UnsupportedError {
    // No CSPRNG on this platform. These ids only need to be unique, not
    // unguessable, so a seeded generator is an acceptable fallback.
    return Random(DateTime.now().microsecondsSinceEpoch);
  }
}
