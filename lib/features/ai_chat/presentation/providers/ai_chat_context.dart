import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../../shared/formatting/thai_address.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Where the assistant believes the traveller is, before they have typed
/// anything.
///
/// Read from `GET /users/me/location`, which since 2026-10-04 answers with a
/// *named place* rather than a bare point — so the page can say "เชียงใหม่"
/// without reverse-geocoding anything itself.
@immutable
class AiChatContext {
  const AiChatContext({
    required this.latitude,
    required this.longitude,
    required this.placeName,
    this.area,
  });

  static AiChatContext? from(UserLocation? stored) {
    if (stored == null) return null;
    return AiChatContext(
      latitude: stored.latitude,
      longitude: stored.longitude,
      placeName: stored.name,
      area: localityOf(stored.address),
    );
  }

  final double latitude;
  final double longitude;

  /// The stored place's own name — a landmark, often too specific to greet
  /// with ("ร้านกาแฟริมคลอง").
  final String placeName;

  /// The province around it, which is what a greeting should use. Null when
  /// the address did not carry one.
  final String? area;

  /// What to call this on screen. Falls back to the place when the address
  /// yielded no province, because a specific name beats no name at all.
  String get label => area ?? placeName;

  /// Sent as `origin.label`. The server uses it verbatim and never
  /// reverse-geocodes, so this must be a name the traveller would recognise
  /// as their own — which is exactly what the account stored.
  ChatOrigin toOrigin() =>
      ChatOrigin(latitude: latitude, longitude: longitude, label: label);
}

/// The account's stored place, or null when there is none — or when nobody is
/// signed in, since the route is behind the auth guard.
///
/// Never throws: a context the page could not load is a page without an
/// opening suggestion, not a broken one.
final aiChatContextProvider = FutureProvider.autoDispose<AiChatContext?>(
  (ref) async {
    if (!ref.watch(isSignedInProvider)) return null;
    try {
      final api = await ref.watch(plunoApiProvider.future);
      return AiChatContext.from(await api.users.location());
    } on Object {
      return null;
    }
  },
);

/// The openers the page offers.
///
/// With a known area they name it, so one tap asks a question the assistant
/// can answer in full — which is the whole point of knowing where the
/// traveller is before they type. Without one, the design's single generic
/// chip stands, and tapping it earns a question back rather than a guess.
List<String> chatOpeners(AiChatContext? context) {
  if (context == null) return const <String>['สถานที่ใกล้ฉัน'];
  return <String>[
    'ร้านอาหารใกล้ฉัน',
    'ที่เที่ยวใน${context.label}',
    'คาเฟ่ใกล้ฉัน',
  ];
}
