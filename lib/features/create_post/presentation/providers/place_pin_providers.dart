import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../domain/models/post_draft.dart';

/// What has been typed into the place-pin picker.
final placePinQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Shorter than a name — "ama" is already a useful search.
const minPlaceQueryLength = 2;

/// Every keystroke here is a paid Places request, so they are collapsed. Same
/// window the destination type-ahead uses.
const _debounce = Duration(milliseconds: 350);

/// Places matching [placePinQueryProvider], debounced.
///
/// `/places/search` rather than `/places/autocomplete`: a post pins a cafe or
/// a viewpoint, and the type-ahead answers with cities only.
final placePinResultsProvider =
    AsyncNotifierProvider.autoDispose<PlacePinResultsNotifier, List<PostPlace>>(
        PlacePinResultsNotifier.new);

class PlacePinResultsNotifier
    extends AutoDisposeAsyncNotifier<List<PostPlace>> {
  @override
  Future<List<PostPlace>> build() async {
    final query = ref.watch(placePinQueryProvider).trim();
    if (query.length < minPlaceQueryLength) return const <PostPlace>[];

    // The next keystroke rebuilds this provider, which disposes the current
    // build — so a run that is already stale never reaches the network.
    var cancelled = false;
    ref.onDispose(() => cancelled = true);
    await Future<void>.delayed(_debounce);
    if (cancelled) return const <PostPlace>[];

    final api = await ref.read(plunoApiProvider.future);
    final places = await api.places.search(query, limit: 20);
    return places.map(_toPostPlace).toList(growable: false);
  }
}

/// Keeps only what the pin row shows. The address is trimmed to the part that
/// reads as a locality — a full Google address is longer than the row.
PostPlace _toPostPlace(Place place) {
  return PostPlace(
    id: place.id,
    mapId: place.mapId,
    name: place.name,
    area: _localityOf(place.address),
  );
}

/// The province-ish tail of an address: the last segment before the country,
/// with any postcode stripped off it. Returns null when nothing is usable.
///
/// Google writes "…, Chiang Mai 50200, Thailand", and the row has space for
/// "เชียงใหม่" — not for the whole line.
String? _localityOf(String? address) {
  final parts = (address ?? '')
      .split(',')
      .map((part) => part.replaceAll(_postcode, '').trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;

  final locality = parts.length > 1 ? parts[parts.length - 2] : parts.first;
  return locality.isEmpty ? null : locality;
}

final _postcode = RegExp(r'\b\d{4,6}\b');
