import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';

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
