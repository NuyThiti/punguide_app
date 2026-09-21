import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../home/presentation/providers/home_feed_providers.dart';

/// How a result list is ordered. [relevance] is only meaningful while there is
/// a query — with an empty one the corpus keeps its feed order.
enum SearchSort { relevance, popular, remixed, cheapest }

extension SearchSortLabel on SearchSort {
  String get label => switch (this) {
        SearchSort.relevance => 'แนะนำ',
        SearchSort.popular => 'ยอดนิยม',
        SearchSort.remixed => 'รีมิกซ์มาก',
        SearchSort.cheapest => 'งบน้อยสุด',
      };
}

final searchSortProvider =
    StateProvider<SearchSort>((ref) => SearchSort.relevance);

/// Recent queries, newest first.
///
/// In memory only: the app has no key-value store, and Isar here holds trips
/// rather than preferences. They survive navigation, not a restart.
final recentSearchesProvider =
    NotifierProvider<RecentSearchesNotifier, List<String>>(
  RecentSearchesNotifier.new,
);

class RecentSearchesNotifier extends Notifier<List<String>> {
  static const int _limit = 8;

  @override
  List<String> build() => const <String>[];

  void record(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final folded = trimmed.toLowerCase();
    state = <String>[
      trimmed,
      ...state.where((entry) => entry.toLowerCase() != folded),
    ].take(_limit).toList(growable: false);
  }

  void remove(String query) {
    state = state.where((entry) => entry != query).toList(growable: false);
  }

  void clear() => state = const <String>[];
}

/// Trips matching [rawQuery], ordered by [searchSortProvider].
///
/// The corpus is the public feed the home screen already holds: `GET /trips`
/// returns everything public and is not paginated, and its `destination`
/// filter matches the destination alone. Filtering the cached list instead
/// searches titles, tags and creators too, and does it on every keystroke
/// without a request — so there is nothing to debounce.
///
/// Keyed by the query and auto-disposing, so the entry a keystroke creates
/// goes away with the next one rather than piling up a cache of prefixes.
final searchResultsProvider = Provider.autoDispose
    .family<AsyncValue<List<TripListItem>>, String>((ref, rawQuery) {
  final query = rawQuery.trim();
  final sort = ref.watch(searchSortProvider);

  return ref.watch(homeFeedProvider).whenData((trips) {
    final matches = query.isEmpty
        ? List<TripListItem>.of(trips)
        : trips.where((trip) => _score(trip, query.toLowerCase()) > 0).toList();

    switch (sort) {
      case SearchSort.relevance:
        if (query.isNotEmpty) {
          final folded = query.toLowerCase();
          matches.sort((a, b) {
            final byScore = _score(b, folded).compareTo(_score(a, folded));
            return byScore != 0 ? byScore : b.likeCount.compareTo(a.likeCount);
          });
        }
      case SearchSort.popular:
        matches.sort((a, b) => b.likeCount.compareTo(a.likeCount));
      case SearchSort.remixed:
        matches.sort((a, b) => b.remixCount.compareTo(a.remixCount));
      case SearchSort.cheapest:
        // A trip with no costed plan totals 0, which is "unknown" rather than
        // free — those sink to the bottom instead of leading the list.
        matches.sort((a, b) => _budgetRank(a).compareTo(_budgetRank(b)));
    }

    return List<TripListItem>.unmodifiable(matches);
  });
});

/// Trips to show before anything is typed: the most-liked handful of the feed.
final trendingTripsProvider = Provider<List<TripListItem>>((ref) {
  final trips = ref.watch(homeFeedProvider).valueOrNull;
  if (trips == null) return const <TripListItem>[];

  final ordered = List<TripListItem>.of(trips)
    ..sort((a, b) => b.likeCount.compareTo(a.likeCount));
  return List<TripListItem>.unmodifiable(ordered.take(6));
});

double _budgetRank(TripListItem trip) =>
    trip.totalBudget > 0 ? trip.totalBudget : double.infinity;

/// Higher is a better match. Zero means the row is filtered out.
///
/// A title hit outranks a destination hit, and a prefix outranks a hit buried
/// mid-word, so typing "เชียง" leads with trips named for it.
int _score(TripListItem trip, String folded) {
  var score = 0;

  score += _fieldScore(trip.title, folded) * 4;
  score += _fieldScore(trip.destination, folded) * 3;
  score += _fieldScore(trip.destinationPlace?.name, folded) * 3;
  score += _fieldScore(trip.destinationPlace?.country, folded) * 2;
  score += _fieldScore(trip.creator?.name, folded) * 2;
  for (final tag in trip.tags) {
    score += _fieldScore(tag, folded);
  }

  return score;
}

int _fieldScore(String? value, String folded) {
  if (value == null || value.isEmpty) return 0;
  final haystack = value.toLowerCase();
  if (haystack.startsWith(folded)) return 3;
  return haystack.contains(folded) ? 1 : 0;
}
