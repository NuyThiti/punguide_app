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
String tripFactsLine(TripListItem trip) => tripFactsParts(trip).join(' • ');

/// The same facts unjoined, for a card that paints its own separator.
List<String> tripFactsParts(TripListItem trip) {
  if (trip.type == TripType.content) {
    return trip.placeCount > 0
        ? <String>['${trip.placeCount} สถานที่']
        : const <String>[];
  }

  final days = trip.schedule.durationDays;
  return <String>[
    if (days != null) tripDurationLabel(days),
    // A costed plan prints its price; one that adds up to nothing is free,
    // not unpriced — the design spells that out rather than leaving a gap.
    if (trip.totalBudget > 0)
      '${trip.totalBudget.asSpacedBaht} /คน'
    else
      'ฟรี / คน',
  ];
}

/// "ครึ่งวัน" for a same-day trip, "N วัน" for anything longer.
String tripDurationLabel(int days) => days <= 0 ? 'ครึ่งวัน' : '$days วัน';
