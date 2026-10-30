import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
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

/// The photo each stop was given, by activity id: `GET /trips/:id/media`.
///
/// A stop's own uploads land in the trip gallery tagged with
/// `sourceActivityId`, while the stop itself only carries its linked place's
/// photo — so without this a photo the traveller added never shows on the
/// card. The gallery is newest first, so the latest upload wins.
///
/// It reloads whenever the trip does, which is when a stop was just saved.
final stopPhotosProvider =
    FutureProvider.family<Map<String, String>, String>((ref, tripId) async {
  await ref.watch(apiTripProvider(tripId).future);
  final api = await ref.watch(plunoApiProvider.future);
  final gallery = await api.media.gallery(tripId, limit: 200);
  final photos = <String, String>{};
  for (final image in gallery.items) {
    final activityId = image.sourceActivityId;
    if (activityId == null) continue;
    photos.putIfAbsent(activityId, () => image.urls.thumbnail);
  }
  return photos;
});
