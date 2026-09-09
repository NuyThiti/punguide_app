import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';

/// The trip the plan editor works on, straight off `GET /trips/:id`.
///
/// The local [Trip] model the detail screen uses drops the schedule, the
/// brief, the budget tier and the itinerary, all of which this page renders —
/// so the editor reads the API trip rather than the cached flattening.
final editPlanProvider =
    FutureProvider.family<ApiTrip, String>((ref, tripId) async {
  final api = await ref.watch(plunoApiProvider.future);
  return api.trips.byId(tripId);
});

/// Where the traveller is staying.
///
/// There is no accommodations endpoint — they come back inside the budget
/// summary as items whose source is `accommodation`.
final planAccommodationsProvider =
    FutureProvider.family<List<BudgetItem>, String>((ref, tripId) async {
  final api = await ref.watch(plunoApiProvider.future);
  final summary = await api.trips.budget(tripId);
  return summary.items
      .where((item) => item.source == BudgetItemSource.accommodation)
      .toList(growable: false);
});
