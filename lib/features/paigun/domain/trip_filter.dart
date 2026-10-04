import 'package:flutter/foundation.dart';

import '../../../core/api/pluno_api.dart';
import '../../create_trip/domain/plan_labels.dart';
import 'nearby_trip.dart';

/// What the ตัวกรอง sheet hands back — the answers to วันที่เดินทาง /
/// จำนวนผู้ร่วมทริป / งบประมาณต่อคน / รัศมี / สไตล์การเที่ยว.
///
/// Nothing here filters anything on its own: [toFeedQuery] turns the answers
/// into `GET /trips` parameters and the server decides which rows come back.
///
/// The sheet stores Thai chip labels rather than wire values, because a chip
/// does not always have an enum behind it — anything added through "+ เพิ่ม"
/// goes up as free text instead. [toFeedQuery] is where the two are told
/// apart.
@immutable
class TripFilter {
  const TripFilter({
    this.startDate,
    this.endDate,
    this.adults = 0,
    this.children = 0,
    this.budgetPerPerson,
    this.radiusKm,
    this.styles = const <String>[],
  });

  /// Nothing answered — every row survives, and the board looks as it did
  /// before the sheet was ever opened.
  static const none = TripFilter();

  /// The ceiling the budget slider can be dragged to. Sitting on it means "any
  /// budget" rather than "ten thousand exactly", which is what the design's
  /// "฿10,000+" says.
  static const double budgetCeiling = 10000;

  /// วันที่เดินทาง. [endDate] is null while only a start has been picked,
  /// which reads as a single day.
  final DateTime? startDate;
  final DateTime? endDate;

  final int adults;
  final int children;

  /// What the slider was left at, in THB per traveller. Null — or sitting on
  /// [budgetCeiling] — is no ceiling at all.
  final double? budgetPerPerson;

  /// รัศมีสถานที่ห่างจากฉัน, in kilometres. Null is ไม่จำกัด.
  final double? radiusKm;

  /// Thai chip labels, as [styleByLabel] keys them.
  final List<String> styles;

  /// How many days the window spans, counting both endpoints — Sep 28–30 is
  /// three — and one for a window with only a start.
  int? get lengthInDays {
    final start = startDate;
    if (start == null) return null;
    final end = endDate;
    if (end == null) return 1;
    return end.difference(start).inDays + 1;
  }

  bool get hasDates => startDate != null;
  bool get hasPeople => adults > 0 || children > 0;

  /// A slider left on the ceiling is not a budget answer — it is the absence
  /// of one.
  bool get hasBudget {
    final amount = budgetPerPerson;
    return amount != null && amount > 0 && amount < budgetCeiling;
  }

  bool get hasRadius => (radiusKm ?? 0) > 0;
  bool get hasStyles => styles.isNotEmpty;

  bool get isEmpty =>
      !hasDates && !hasPeople && !hasBudget && !hasRadius && !hasStyles;

  /// How many of the sheet's questions were answered — the number on the
  /// board's ตัวกรอง button.
  int get answeredCount =>
      (hasDates ? 1 : 0) +
      (hasPeople ? 1 : 0) +
      (hasBudget ? 1 : 0) +
      (hasRadius ? 1 : 0) +
      (hasStyles ? 1 : 0);

  TripFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? adults,
    int? children,
    double? budgetPerPerson,
    double? radiusKm,
    List<String>? styles,
    bool clearDates = false,
    bool clearRadius = false,
  }) =>
      TripFilter(
        startDate: clearDates ? null : startDate ?? this.startDate,
        endDate: clearDates ? null : endDate ?? this.endDate,
        adults: adults ?? this.adults,
        children: children ?? this.children,
        budgetPerPerson: budgetPerPerson ?? this.budgetPerPerson,
        radiusKm: clearRadius ? null : radiusKm ?? this.radiusKm,
        styles: styles ?? this.styles,
      );

  /// The answers as `GET /trips` parameters.
  ///
  /// [sort] picks the ordering and [origin] rides along whatever it is,
  /// because `distanceKm` on a row is what puts the chip on a card and the
  /// server only measures when it is given both coordinates.
  ///
  /// Two answers do not map one-to-one, and this is where that is decided:
  ///
  ///  * a **date window** is when the traveller is free, not a trip length, so
  ///    it goes up as `dateFrom`/`dateTo` plus a `maxDurationDays` ceiling —
  ///    "what fits in these days";
  ///  * the **budget slider** is per traveller, so it goes up as typed with
  ///    `budgetScope=per_person` and the server divides the trip's own budget
  ///    by the trip's own head count. Never pre-multiply it here.
  ///
  /// [type] and [query] are the board's own controls — the chip row and the
  /// search box — rather than the sheet's, and ride along here because one
  /// request carries the lot. The search goes up as `q`, which reads every
  /// word a trip shows, not as `destination`, which only reads where it goes:
  /// someone typing "คาเฟ่" means the cafés in it, not a place called that.
  TripFeedQuery toFeedQuery({
    required FeedSort sort,
    TripType? type,
    String? query,
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

    return TripFeedQuery(
      // The chip row and the search box, which belong to the board rather than
      // to the sheet — they narrow the same request all the same.
      type: type,
      q: query,
      styles: styleEnums,
      customStyles: freeStyles,
      // Sending zeroes would read as "at least nobody", so an untouched row
      // sends nothing at all.
      adults: hasPeople ? adults : null,
      children: hasPeople ? children : null,
      budgetMax: hasBudget ? budgetPerPerson : null,
      budgetScope: hasBudget ? FeedBudgetScope.perPerson : null,
      dateFrom: startDate,
      // A window with only a start is the single day the sheet shows.
      dateTo: endDate ?? startDate,
      maxDurationDays: lengthInDays,
      latitude: origin?.latitude,
      longitude: origin?.longitude,
      radiusKm: hasRadius ? radiusKm : null,
      sort: sort,
      limit: limit,
    );
  }
}
