import 'package:flutter/foundation.dart';

import '../../../core/api/pluno_api.dart';
import '../../create_trip/domain/plan_labels.dart';

/// How the traveller said *when* they are going: exact days off a calendar, or
/// just a length with no dates attached.
enum FilterDateMode { calendar, flexible }

/// Whether the figure typed under ตั้งงบเอง is one traveller's share or the
/// whole group's bill.
enum BudgetScope {
  perPerson('ต่อคน'),
  everyone('รวมทุกคน');

  const BudgetScope(this.label);

  final String label;
}

/// What the ไปกัน filter wizard hands back — the answers to วันที่ / จำนวนคน /
/// งบ / สไตล์, and the rule for deciding whether a feed row survives them.
///
/// The board has no filtering endpoint (see `paigunTripsProvider`), so this
/// runs over the cached feed in memory, and it can only ask about the fields a
/// list row actually carries. Two of the four answers have no column to match
/// against yet:
///
/// - **จำนวนคน** — head count lives on the full trip (`TripCustomer.groupSize`),
///   never on a list row. It is collected, shown in the summary, and used to
///   scale a per-person budget, but it narrows nothing on its own.
/// - **เงื่อนไข / ข้อจำกัด** — `TripPlanBrief.constraints` is likewise absent
///   from a list row.
///
/// Both are kept rather than dropped: the moment `GET /trips` grows the fields,
/// [matches] is the only place that has to change.
@immutable
class TripFilter {
  const TripFilter({
    this.dateMode = FilterDateMode.flexible,
    this.startDate,
    this.endDate,
    this.days,
    this.adults = 0,
    this.children = 0,
    this.budgetTier,
    this.budgetAmount,
    this.budgetScope = BudgetScope.perPerson,
    this.styles = const <String>[],
    this.constraints = const <String>[],
  });

  /// Nothing answered — every row survives, and the board looks as it did
  /// before the wizard was ever opened.
  static const none = TripFilter();

  final FilterDateMode dateMode;

  /// Set only in [FilterDateMode.calendar]. [endDate] is null while a range is
  /// half-drawn, which reads as a single day.
  final DateTime? startDate;
  final DateTime? endDate;

  /// The ตัวเลือกยืดหยุ่น length, in days. Null means the wheel was never
  /// touched.
  final int? days;

  final int adults;
  final int children;

  /// The bracket tapped on งบเที่ยวของฉัน. [BudgetTier.custom] is never stored
  /// here — a typed figure goes in [budgetAmount] instead.
  final BudgetTier? budgetTier;

  /// What was typed under ตั้งงบเอง, in THB, read through [budgetScope]. It
  /// overrides the bracket, the same way the create wizard's ระบุเอง does.
  final double? budgetAmount;
  final BudgetScope budgetScope;

  /// Thai chip labels, as [styleByLabel] and [constraintByLabel] key them.
  final List<String> styles;
  final List<String> constraints;

  /// How long the trip is meant to be, however the traveller said it.
  ///
  /// A calendar range counts both endpoints — Sep 28–30 is three days — and a
  /// half-drawn range is one.
  int? get lengthInDays {
    if (dateMode == FilterDateMode.flexible) return days;
    final start = startDate;
    if (start == null) return null;
    final end = endDate;
    if (end == null) return 1;
    return end.difference(start).inDays + 1;
  }

  /// Heads to divide a per-person budget by. Never zero: a filter with no head
  /// count still has to price one traveller.
  int get heads {
    final total = adults + children;
    return total > 0 ? total : 1;
  }

  bool get hasDates => lengthInDays != null;
  bool get hasPeople => adults > 0 || children > 0;
  bool get hasBudget => budgetTier != null || (budgetAmount ?? 0) > 0;
  bool get hasStyles => styles.isNotEmpty || constraints.isNotEmpty;

  bool get isEmpty => !hasDates && !hasPeople && !hasBudget && !hasStyles;

  /// How many of the wizard's four questions were answered — the number on the
  /// ไปกัน header's filter button.
  int get answeredCount =>
      (hasDates ? 1 : 0) +
      (hasPeople ? 1 : 0) +
      (hasBudget ? 1 : 0) +
      (hasStyles ? 1 : 0);

  /// Does this feed row survive the filter?
  ///
  /// An **absent** value is unknown, not a mismatch, so it is kept — the same
  /// call `nearMeTripsProvider` makes about a trip with no coordinates. An
  /// **empty tag list**, on the other hand, is an answer: a trip that declares
  /// no style cannot claim to be a beach trip.
  bool matches(TripListItem trip) =>
      _matchesLength(trip) && _matchesBudget(trip) && _matchesStyles(trip);

  bool _matchesLength(TripListItem trip) {
    final want = lengthInDays;
    if (want == null) return true;
    final got = tripLengthInDays(trip);
    if (got == null) return true;
    // Fits in the time available — a two-day trip is still an answer to "I
    // have three days", where a five-day one is not.
    return got <= want;
  }

  bool _matchesBudget(TripListItem trip) {
    final spend =
        trip.budgetLimit ?? (trip.totalBudget > 0 ? trip.totalBudget : null);

    final cap = wholeTripCap;
    if (cap != null) {
      if (spend == null) return true;
      return spend <= cap;
    }

    final tier = budgetTier;
    if (tier == null) return true;
    // A row the backend never tiered is unknown, not a mismatch.
    if (trip.budgetTier == null) return true;
    return trip.budgetTier == tier;
  }

  /// The typed figure as a whole-trip total, which is the shape a trip's own
  /// budget is stored in. Null when nothing was typed.
  double? get wholeTripCap {
    final amount = budgetAmount;
    if (amount == null || amount <= 0) return null;
    return budgetScope == BudgetScope.everyone ? amount : amount * heads;
  }

  bool _matchesStyles(TripListItem trip) {
    if (styles.isEmpty) return true;
    final wanted = <String>{
      for (final label in styles) ...[
        label.toLowerCase(),
        if (styleByLabel[label] != null) styleByLabel[label]!.wire,
      ],
    };
    return trip.tags.any((tag) => wanted.contains(tag.toLowerCase()));
  }
}

/// How long a feed row runs, in days.
///
/// `durationDays` is derived server-side whenever a trip has both dates, so it
/// is the first thing to trust; the other two shapes are what is left on a trip
/// that was planned by length alone. Null means the row never said.
int? tripLengthInDays(TripListItem trip) {
  final schedule = trip.schedule;
  final days = schedule.durationDays;
  if (days != null && days > 0) return days;

  final start = schedule.startDate;
  final end = schedule.endDate;
  if (start != null && end != null) return end.difference(start).inDays + 1;

  final nights = schedule.durationNights;
  if (nights != null && nights > 0) return nights + 1;
  return null;
}
