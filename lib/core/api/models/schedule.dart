import 'package:flutter/foundation.dart';

import 'json.dart';

/// When a trip happens.
///
/// [durationDays] and [durationNights] are derived server-side from the dates
/// whenever both are present, so a client-supplied duration only survives on a
/// trip without fixed dates.
@immutable
class Schedule {
  const Schedule({
    this.startDate,
    this.endDate,
    this.durationDays,
    this.durationNights,
    this.isDateFlexible = false,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
        startDate: Json.date(json, 'startDate'),
        endDate: Json.date(json, 'endDate'),
        durationDays: Json.integer(json, 'durationDays'),
        durationNights: Json.integer(json, 'durationNights'),
        isDateFlexible: Json.boolean(json, 'isDateFlexible'),
      );

  final DateTime? startDate;
  final DateTime? endDate;
  final int? durationDays;
  final int? durationNights;

  /// "Dates not decided yet."
  final bool isDateFlexible;

  bool get hasFixedDates => startDate != null && endDate != null;
}
