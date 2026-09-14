import 'package:flutter/foundation.dart';

import '../../../core/api/pluno_api.dart';
import '../../create_trip/domain/plan_labels.dart';
import 'nearby_trip.dart';

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
/// งบ / สไตล์.
///
/// Nothing here filters anything on its own: [toFeedQuery] turns the answers
/// into `GET /trips` parameters and the server decides which rows come back.
/// That is why all four rows now narrow, including จำนวนคน and
/// เงื่อนไข / ข้อจำกัด, which used to be collected and ignored because a feed
/// row carried neither field.
///
/// The wizard stores Thai chip labels rather than wire values, because a chip
/// does not always have an enum behind it — "อิสลาม" and anything added through
/// "+ เพิ่ม" go up as free text instead. [toFeedQuery] is where the two are
/// told apart.
@immutable
class TripFilter {
  const TripFilter({
    this.dateMode = FilterDateMode.calendar,
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

  /// Which half of the Calendar | Flexible toggle was in force. It decides
  /// which of [startDate]/[endDate] and [days] carries the answer — and, on a
  /// filter with no answer at all, which half the wizard opens on.
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

  /// The answers as `GET /trips` parameters.
  ///
  /// [sort] picks the wall — nearest for Near Me, popular for Top PunGuide —
  /// and [origin] rides along whatever the sort is, because `distanceKm` on a
  /// row is what puts the chip on a card and the server only measures when it
  /// is given both coordinates.
  ///
  /// Two answers do not map one-to-one, and this is where that is decided:
  ///
  ///  * a **calendar range** is a window the traveller is free in, not a trip
  ///    length, so it goes up as `dateFrom`/`dateTo` plus a `maxDurationDays`
  ///    ceiling — "what fits in these days". The **flexible** tab is the
  ///    opposite: the stepper is an exact length, so it goes up as
  ///    `durationDays`;
  ///  * a **typed budget** overrides the bracket rather than narrowing it
  ///    further, the way ระบุเอง does in the create wizard, so the tier is left
  ///    off when there is a figure.
  TripFeedQuery toFeedQuery({
    required FeedSort sort,
    PaigunOrigin? origin,
    int? limit,
  }) {
    final styleEnums = <TravelStyle>[];
    final freeStyles = <String>[];
    for (final label in styles) {
      final style = styleByLabel[label];
      if (style == null) {
        freeStyles.add(label);
      } else {
        styleEnums.add(style);
      }
    }

    final constraintEnums = <TripConstraint>[];
    final freeConstraints = <String>[];
    for (final label in constraints) {
      final rule = constraintByLabel[label];
      if (rule == null) {
        freeConstraints.add(label);
      } else {
        constraintEnums.add(rule);
      }
    }

    final amount = (budgetAmount ?? 0) > 0 ? budgetAmount : null;
    final calendar = dateMode == FilterDateMode.calendar;
    final span = lengthInDays;

    return TripFeedQuery(
      styles: styleEnums,
      customStyles: freeStyles,
      constraints: constraintEnums,
      customConstraints: freeConstraints,
      // Sending zeroes would read as "at least nobody", so an untouched row
      // sends nothing at all.
      adults: hasPeople ? adults : null,
      children: hasPeople ? children : null,
      budgetTiers: amount == null && budgetTier != null
          ? <BudgetTier>[budgetTier!]
          : const <BudgetTier>[],
      budgetMax: amount,
      budgetScope: amount == null
          ? null
          : budgetScope == BudgetScope.everyone
              ? FeedBudgetScope.total
              : FeedBudgetScope.perPerson,
      dateFrom: calendar ? startDate : null,
      // A half-drawn range is a single day, which is what the wizard shows.
      dateTo: calendar ? (endDate ?? startDate) : null,
      durationDays: calendar ? null : days,
      maxDurationDays: calendar ? span : null,
      latitude: origin?.latitude,
      longitude: origin?.longitude,
      sort: sort,
      limit: limit,
    );
  }
}
