import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';

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
