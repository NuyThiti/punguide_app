import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/destination.dart';

/// The public trip feed behind "Top PunGuide", plus the save toggle.
///
/// `GET /trips` is optional-auth: `isSaved` and `isLiked` come back false for
/// an anonymous caller, so the feed is re-read whenever the session changes.
final homeFeedProvider =
    AsyncNotifierProvider<HomeFeedNotifier, List<TripListItem>>(
  HomeFeedNotifier.new,
);

class HomeFeedNotifier extends AsyncNotifier<List<TripListItem>> {
  @override
  Future<List<TripListItem>> build() async {
    // Signing in or out changes the per-viewer flags on every row.
    ref.watch(authSessionProvider);
    final api = await ref.watch(plunoApiProvider.future);
    return api.trips.feed();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<TripListItem>>();
    state = await AsyncValue.guard(() async {
      final api = await ref.read(plunoApiProvider.future);
      return api.trips.feed();
    });
  }

  /// Bookmarks or un-bookmarks one trip, flipping the row before the request
  /// so the tap feels instant, and putting it back if the server refuses.
  ///
  /// Throws [ApiException] so the caller can tell "sign in first" (401) from a
  /// genuine failure.
  Future<void> toggleSaved(String tripId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final index = current.indexWhere((trip) => trip.id == tripId);
    if (index < 0) return;

    final wasSaved = current[index].isSaved;
    state = AsyncData<List<TripListItem>>(
      List<TripListItem>.of(current)..[index] = current[index].withSaved(!wasSaved),
    );

    try {
      final api = await ref.read(plunoApiProvider.future);
      if (wasSaved) {
        await api.trips.unsave(tripId);
      } else {
        await api.trips.save(tripId);
      }
    } catch (_) {
      state = AsyncData<List<TripListItem>>(current);
      rethrow;
    }
  }
}

/// "Top Destination" derived from the feed — the API has no destinations
/// endpoint, so the rail is the places people actually planned trips to,
/// most-planned first.
final topDestinationsProvider = Provider<List<Destination>>((ref) {
  final trips = ref.watch(homeFeedProvider).valueOrNull;
  if (trips == null || trips.isEmpty) return const <Destination>[];

  final groups = <String, _DestinationGroup>{};
  for (final trip in trips) {
    final label = _labelFor(trip);
    if (label.isEmpty) continue;
    final group = groups.putIfAbsent(
      label.toLowerCase(),
      () => _DestinationGroup(label),
    );
    group.count++;
    group.coverImage ??= trip.coverImage?.urls.large;
  }

  final ordered = groups.values.toList()
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.label.compareTo(b.label);
    });

  return ordered
      .take(8)
      .map((g) => Destination(
            id: g.label.toLowerCase(),
            name: g.label,
            coverImage: g.coverImage,
          ))
      .toList(growable: false);
});

/// Prefer the country the backend resolved; otherwise the tail of the free
/// text destination, which is written "city, country".
String _labelFor(TripListItem trip) {
  final country = trip.destinationPlace?.country?.trim();
  if (country != null && country.isNotEmpty) return country;

  final parts = trip.destination
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  return parts.isEmpty ? trip.destination.trim() : parts.last;
}

class _DestinationGroup {
  _DestinationGroup(this.label);

  final String label;
  int count = 0;
  String? coverImage;
}
