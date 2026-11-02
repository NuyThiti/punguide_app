import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../create_post/presentation/widgets/trip_link_picker.dart';
import '../../../my_trips/presentation/providers/my_trips_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../trips/presentation/providers/trip_providers.dart';

/// The money view of a plan: `GET /trips/:id/budget`.
///
/// One request serves both the lodging panel and the สรุปงบ tab — they used to
/// ask separately for the same summary.
final planBudgetProvider =
    FutureProvider.family<BudgetSummary, String>((ref, tripId) async {
  final api = await ref.watch(plunoApiProvider.future);
  return api.trips.budget(tripId);
});

/// Where the traveller is staying.
///
/// There is no accommodations endpoint — they come back inside the budget
/// summary as items whose source is `accommodation`.
final planAccommodationsProvider =
    FutureProvider.family<List<BudgetItem>, String>((ref, tripId) async {
  final summary = await ref.watch(planBudgetProvider(tripId).future);
  return summary.items
      .where((item) => item.source == BudgetItemSource.accommodation)
      .toList(growable: false);
});

/// The photos each stop was given, by activity id, newest first:
/// `GET /trips/:id/media`.
///
/// A stop's own uploads land in the trip gallery tagged with
/// `sourceActivityId`, while the stop itself only carries its linked place's
/// photo — so without this a photo the traveller added never shows on the
/// card. The gallery is newest first, and so is each list.
///
/// It reloads whenever the trip does, which is when a stop was just saved.
final stopMediaProvider =
    FutureProvider.family<Map<String, List<GalleryImage>>, String>(
        (ref, tripId) async {
  await ref.watch(apiTripProvider(tripId).future);
  final api = await ref.watch(plunoApiProvider.future);
  final gallery = await api.media.gallery(tripId, limit: 200);
  final media = <String, List<GalleryImage>>{};
  for (final image in gallery.items) {
    final activityId = image.sourceActivityId;
    if (activityId == null) continue;
    (media[activityId] ??= <GalleryImage>[]).add(image);
  }
  return media;
});

/// The thumbnail each stop card shows: its newest photo in [stopMediaProvider].
final stopPhotosProvider =
    FutureProvider.family<Map<String, String>, String>((ref, tripId) async {
  final media = await ref.watch(stopMediaProvider(tripId).future);
  return {
    for (final entry in media.entries)
      entry.key: entry.value.first.urls.thumbnail,
  };
});

/// Re-reads every list of the traveller's own trips, so a change made in the
/// editor — a new cover — reaches their cards, not just the page it was made on.
void refreshOwnTripLists(WidgetRef ref) => ref
  ..invalidate(myTripsProvider)
  ..invalidate(myAlbumsProvider)
  ..invalidate(myPlansProvider);
