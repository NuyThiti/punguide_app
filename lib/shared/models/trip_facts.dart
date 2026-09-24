import '../../core/api/pluno_api.dart';
import '../extensions/currency_extensions.dart';

/// The one line of facts a trip card prints beside its counts.
///
/// A plan is measured in days and money. A post has neither — what it has is
/// the places it stops at, which is what `placeCount` is on a feed row for.
/// Reading `schedule` or `totalBudget` on a post would print the trip it
/// describes, not the post, so those are asked for only on a plan.
///
/// Anything the row did not come back with is left out rather than shown as
/// zero: a feed row can arrive with no schedule, a plan nobody costed totals
/// 0, and a post with nothing located answers 0 places.
String tripFactsLine(TripListItem trip) {
  if (trip.type == TripType.content) {
    return trip.placeCount > 0 ? '${trip.placeCount} สถานที่' : '';
  }

  final days = trip.schedule.durationDays;
  return <String>[
    if (days != null && days > 0) '$days วัน',
    if (trip.totalBudget > 0) '${trip.totalBudget.asApproxBaht} /คน',
  ].join(' • ');
}
