import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';

/// What the แนะนำสถานที่ sheet is asking for.
///
/// Typing wins over the chips: free text goes to `/places/search`, which is a
/// worldwide lookup and takes no category, so a chip cannot narrow it.
@immutable
class SuggestQuery {
  const SuggestQuery({
    required this.latitude,
    required this.longitude,
    this.category,
    this.search = '',
  });

  final double latitude;
  final double longitude;
  final PlaceCategory? category;
  final String search;

  bool get isSearching => search.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is SuggestQuery &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.category == category &&
      other.search == search;

  @override
  int get hashCode => Object.hash(latitude, longitude, category, search);
}

/// Places to offer for a day, either around the trip or matching a search.
/// The server rejects anything above this outright, on both endpoints.
const _maxResults = 20;

final suggestedPlacesProvider =
    FutureProvider.family<List<Place>, SuggestQuery>((ref, query) async {
  final api = await ref.watch(plunoApiProvider.future);
  if (query.isSearching) {
    return api.places.search(query.search.trim(), limit: _maxResults);
  }
  return api.places.suggest(
    latitude: query.latitude,
    longitude: query.longitude,
    limit: _maxResults,
    categories: query.category == null ? null : [query.category!],
  );
});
