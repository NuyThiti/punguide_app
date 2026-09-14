import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json.dart';

/// Everything `GET /trips` accepts, in one value.
///
/// A named-argument list this long is unreadable at the call site, and the
/// endpoint runs `forbidNonWhitelisted`: a key it does not know is a `400`,
/// not a shrug. Building the query in one place keeps the spelling in one
/// place too.
///
/// Every field is optional and an empty query is the plain feed — every public
/// trip, newest first, unpaginated — exactly what the app asked for before any
/// of this existed.
///
/// Two rules the server applies that are easy to trip over:
///
///  * within a row the values are OR'd, across rows they are AND'd — so
///    `styles: [nature, cafe]` widens and adding `constraints` narrows;
///  * [latitude] and [longitude] only count as a pair. One on its own is
///    ignored, and `distanceKm` then comes back absent on every row.
@immutable
class TripFeedQuery {
  const TripFeedQuery({
    this.destination,
    this.type,
    this.styles = const <TravelStyle>[],
    this.customStyles = const <String>[],
    this.constraints = const <TripConstraint>[],
    this.customConstraints = const <String>[],
    this.adults,
    this.children,
    this.minGuests,
    this.maxGuests,
    this.budgetTiers = const <BudgetTier>[],
    this.budgetMin,
    this.budgetMax,
    this.budgetScope,
    this.dateFrom,
    this.dateTo,
    this.durationDays,
    this.minDurationDays,
    this.maxDurationDays,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.sort,
    this.limit,
    this.offset,
  });

  /// Case-insensitive partial match on the trip's destination text.
  final String? destination;

  /// Plan trips or photo posts. Absent returns both.
  final TripType? type;

  /// Chips that have an enum behind them.
  final List<TravelStyle> styles;

  /// Chips that do not — "อิสลาม", "มังสวิรัติ", anything added through
  /// "+ เพิ่ม". Matched case-insensitively against the free text on a trip's
  /// brief, so product can add a chip without waiting for a backend release.
  final List<String> customStyles;

  final List<TripConstraint> constraints;
  final List<String> customConstraints;

  /// The two halves of the จำนวนคน row. The server adds them up and reads the
  /// total as "planned for at least this many"; sending them beats
  /// [minGuests]/[maxGuests], and `0` + `0` filters nothing.
  final int? adults;
  final int? children;

  final int? minGuests;
  final int? maxGuests;

  /// Brackets from งบเที่ยวของฉัน. Several are OR'd.
  final List<BudgetTier> budgetTiers;

  /// A typed ceiling, in THB, read through [budgetScope]. The server compares
  /// it against the owner's `budgetLimit`, falling back to `totalBudget` —
  /// the same figure the card prints.
  final double? budgetMin;
  final double? budgetMax;
  final FeedBudgetScope? budgetScope;

  /// The Calendar tab. Trips whose dates overlap the window come back — and so
  /// do trips with no dates at all, which can go whenever.
  final DateTime? dateFrom;
  final DateTime? dateTo;

  /// The Flexible tab: an exact length off the stepper.
  final int? durationDays;

  /// Open-ended presets — "1 สัปดาห์" through "1 เดือน".
  final int? minDurationDays;
  final int? maxDurationDays;

  /// Where the traveller is. Only honoured as a pair; [radiusKm] trims the
  /// result to a circle around it.
  final double? latitude;
  final double? longitude;
  final double? radiusKm;

  final FeedSort? sort;

  /// 1–100. Absent returns everything, as the feed always has.
  final int? limit;
  final int? offset;

  /// The query string, with every unanswered row left out entirely.
  ///
  /// Lists are comma-joined — the endpoint takes either that or a repeated
  /// key, and one string per row is easier to read in a log. An empty list is
  /// dropped rather than sent as `?styles=`, which means the same thing.
  Map<String, dynamic> toQuery() => <String, dynamic>{
        'destination': _text(destination),
        'type': type?.wire,
        'styles': _joinWire(styles.map((style) => style.wire)),
        'customStyles': _joinText(customStyles),
        'constraints': _joinWire(constraints.map((rule) => rule.wire)),
        'customConstraints': _joinText(customConstraints),
        'adults': adults,
        'children': children,
        'minGuests': minGuests,
        'maxGuests': maxGuests,
        'budgetTiers': _joinWire(budgetTiers.map((tier) => tier.wire)),
        'budgetMin': budgetMin,
        'budgetMax': budgetMax,
        'budgetScope': budgetScope?.wire,
        'dateFrom': dateFrom == null ? null : Json.formatDate(dateFrom!),
        'dateTo': dateTo == null ? null : Json.formatDate(dateTo!),
        'durationDays': durationDays,
        'minDurationDays': minDurationDays,
        'maxDurationDays': maxDurationDays,
        // Half a fix measures nothing, so neither half goes up alone.
        'lat': hasCoordinates ? latitude : null,
        'lng': hasCoordinates ? longitude : null,
        'radiusKm': hasCoordinates ? radiusKm : null,
        'sort': sort?.wire,
        'limit': limit,
        'offset': offset,
      };

  bool get hasCoordinates => latitude != null && longitude != null;

  TripFeedQuery copyWith({
    FeedSort? sort,
    int? limit,
    int? offset,
  }) =>
      TripFeedQuery(
        destination: destination,
        type: type,
        styles: styles,
        customStyles: customStyles,
        constraints: constraints,
        customConstraints: customConstraints,
        adults: adults,
        children: children,
        minGuests: minGuests,
        maxGuests: maxGuests,
        budgetTiers: budgetTiers,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
        budgetScope: budgetScope,
        dateFrom: dateFrom,
        dateTo: dateTo,
        durationDays: durationDays,
        minDurationDays: minDurationDays,
        maxDurationDays: maxDurationDays,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        sort: sort ?? this.sort,
        limit: limit ?? this.limit,
        offset: offset ?? this.offset,
      );
}

String? _text(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _joinWire(Iterable<String> wires) =>
    wires.isEmpty ? null : wires.join(',');

String? _joinText(List<String> values) {
  final kept = values.map((value) => value.trim()).where((v) => v.isNotEmpty);
  return kept.isEmpty ? null : kept.join(',');
}
