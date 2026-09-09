import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../home/presentation/providers/home_feed_providers.dart';
import '../../domain/destination_lookup.dart';

/// One row of the destination picker, whichever list it came from.
class DestinationOption {
  const DestinationOption({
    required this.label,
    required this.sublabel,
    required this.value,
    this.placeId,
  });

  /// Built from a type-ahead hit: Google already splits the place from the
  /// region it sits in, and [PlaceSuggestion.description] is the two joined
  /// the way this app writes a destination.
  factory DestinationOption.fromSuggestion(PlaceSuggestion suggestion) {
    return DestinationOption(
      label: suggestion.mainText,
      sublabel: suggestion.secondaryText,
      value: suggestion.description,
      placeId: suggestion.externalRef,
    );
  }

  /// The place itself — "ปูซาน".
  final String label;

  /// Where it sits — "เกาหลีใต้". Empty when the two are the same, as for a
  /// destination recorded as a bare country.
  final String sublabel;

  /// What lands in the Destination field — "ปูซาน, เกาหลีใต้".
  final String value;

  /// Google's `externalRef`, from the type-ahead. Null on a row derived from
  /// the feed or picked out of recents — those are names, not resolved places.
  final String? placeId;

  /// What `POST /trips` wants under `destinationPlace`, or null when there is
  /// no resolved place and the backend has only the free text to go on.
  ///
  /// No lat/lng: the backend resolves those from [placeId] itself.
  ///
  /// Only ever built from a type-ahead hit, where [label] is the place and
  /// [sublabel] the region around it. A trending row carries the country in
  /// [label] instead, but never a [placeId], so it cannot reach here.
  DestinationPlace? get place => placeId == null
      ? null
      : DestinationPlace(
          placeId: placeId,
          name: label,
          country: sublabel.isEmpty ? null : sublabel,
        );
}

final destinationLookupProvider = Provider<DestinationLookup>((ref) {
  return PlacesApiDestinationLookup(() => ref.read(plunoApiProvider.future));
});

/// One autocomplete session, held for as long as the picker is open.
///
/// Auto-disposing is the point: closing the picker ends the session, so the
/// next search is billed as its own instead of extending the last one.
final placesSessionProvider =
    Provider.autoDispose<PlacesSession>((ref) => PlacesSession());

/// What has been typed into the picker.
final destinationQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Long enough to be worth a request. `/places/autocomplete` accepts one
/// character, but a single letter matches most of the planet.
const minDestinationQueryLength = 2;

/// Unlike the trip search — which filters a list already in memory — every
/// keystroke here is a paid request, so they are collapsed.
const _debounce = Duration(milliseconds: 350);

/// Destinations matching [destinationQueryProvider], debounced.
///
/// Rebuilding on the query keeps the previous results visible while the next
/// ones load (Riverpod carries the old value into the new `AsyncLoading`), so
/// the list does not blink empty between keystrokes.
final destinationSuggestionsProvider = AsyncNotifierProvider.autoDispose<
    DestinationSuggestionsNotifier, List<DestinationOption>>(
  DestinationSuggestionsNotifier.new,
);

class DestinationSuggestionsNotifier
    extends AutoDisposeAsyncNotifier<List<DestinationOption>> {
  @override
  Future<List<DestinationOption>> build() async {
    final query = ref.watch(destinationQueryProvider).trim();
    if (query.length < minDestinationQueryLength)
      return const <DestinationOption>[];

    // The next keystroke rebuilds this provider, which disposes the current
    // build — so a run that is already stale never reaches the network.
    var cancelled = false;
    ref.onDispose(() => cancelled = true);
    await Future<void>.delayed(_debounce);
    if (cancelled) return const <DestinationOption>[];

    final suggestions = await ref.read(destinationLookupProvider).search(
          query,
          sessionToken: ref.read(placesSessionProvider).token,
        );
    return suggestions
        .map(DestinationOption.fromSuggestion)
        .toList(growable: false);
  }
}

/// What to offer before anything is typed.
///
/// There is no trending-destinations endpoint, so this is the same trick
/// [topDestinationsProvider] plays: the places people actually planned trips
/// to, most-planned first. That rail collapses to one row per country; here
/// each city keeps its own row, under a country heading — so Japan can appear
/// twice, once for Osaka and once for Tokyo, as the design shows.
final trendingDestinationsProvider = Provider<List<DestinationOption>>((ref) {
  final trips = ref.watch(homeFeedProvider).valueOrNull;
  if (trips == null || trips.isEmpty) return const <DestinationOption>[];

  final groups = <String, ({DestinationOption option, int count})>{};
  for (final trip in trips) {
    final option = _optionFor(trip);
    if (option == null) continue;

    final key = option.value.toLowerCase();
    final seen = groups[key];
    groups[key] = (option: option, count: (seen?.count ?? 0) + 1);
  }

  final ordered = groups.values.toList()
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.option.value.compareTo(b.option.value);
    });

  return List<DestinationOption>.unmodifiable(
    ordered.take(6).map((entry) => entry.option),
  );
});

/// Splits a feed row's destination into the place and the region around it.
///
/// The free text is written "city, country"; the resolved place is trusted for
/// the country when the backend has one. Returns null for a row with no usable
/// destination at all.
DestinationOption? _optionFor(TripListItem trip) {
  final parts = trip.destination
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;

  final city = parts.first;
  final country = parts.length > 1
      ? parts.last
      : (trip.destinationPlace?.country?.trim() ?? '');

  // The country headlines the row and the city sits under it, which is the
  // opposite of a type-ahead hit — there the place you typed has to lead.
  return DestinationOption(
    label: country.isEmpty ? city : country,
    sublabel: country.isEmpty || country == city ? '' : city,
    value: country.isEmpty || country == city ? city : '$city, $country',
  );
}

/// Destinations picked recently, newest first.
///
/// Deliberately not [recentSearchesProvider]: that holds trip queries like
/// "ทะเลใกล้กรุงเทพ", which are not places and would not survive being put
/// back into the Destination field.
///
/// In memory only, for the same reason recent searches are — the app has no
/// key-value store. They survive navigation, not a restart.
final recentDestinationsProvider =
    NotifierProvider<RecentDestinationsNotifier, List<String>>(
  RecentDestinationsNotifier.new,
);

class RecentDestinationsNotifier extends Notifier<List<String>> {
  static const int _limit = 8;

  @override
  List<String> build() => const <String>[];

  void record(String destination) {
    final trimmed = destination.trim();
    if (trimmed.isEmpty) return;

    final folded = trimmed.toLowerCase();
    state = <String>[
      trimmed,
      ...state.where((entry) => entry.toLowerCase() != folded),
    ].take(_limit).toList(growable: false);
  }

  void clear() => state = const <String>[];
}
