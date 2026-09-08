import 'package:flutter/foundation.dart';

import 'destination_place.dart';
import 'enums.dart';
import 'json.dart';
import 'trip_draft.dart';

/// When the trip happens, for the planner.
///
/// Use [PlanDates.fixed] with real dates, or [PlanDates.flexible] with a
/// number of days and an optional month for seasonality.
@immutable
class PlanDates {
  const PlanDates.fixed({
    required DateTime startDate,
    required DateTime endDate,
  })  : mode = DateMode.fixed,
        startDate = startDate,
        endDate = endDate,
        durationDays = null,
        durationNights = null,
        month = null;

  const PlanDates.flexible({
    required int durationDays,
    int? durationNights,
    String? month,
  })  : mode = DateMode.flexible,
        startDate = null,
        endDate = null,
        durationDays = durationDays,
        durationNights = durationNights,
        month = month;

  final DateMode mode;
  final DateTime? startDate;
  final DateTime? endDate;

  /// 1–30.
  final int? durationDays;

  /// 0–29.
  final int? durationNights;

  /// `YYYY-MM`, a hint about the season.
  final String? month;

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'mode': mode.wire,
        'startDate': startDate == null ? null : Json.formatDate(startDate!),
        'endDate': endDate == null ? null : Json.formatDate(endDate!),
        'durationDays': durationDays,
        'durationNights': durationNights,
        'month': month,
      });
}

/// Who is going.
@immutable
class PlanGuests {
  const PlanGuests({
    required this.adults,
    this.children = 0,
    this.infants = 0,
    this.groupType,
  });

  /// 1–50.
  final int adults;

  /// Ages 2–11, up to 50.
  final int children;

  /// Under 2, up to 20.
  final int infants;
  final GroupType? groupType;

  int get headCount => adults + children + infants;

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'groupType': groupType?.wire,
        'adults': adults,
        'children': children,
        'infants': infants,
      });
}

/// The trip block of a plan request. [destination] is the only field the API
/// truly requires anywhere in the request.
@immutable
class PlanTripInput {
  const PlanTripInput({
    required this.destination,
    this.destinationPlace,
    this.dates,
    this.guests,
  });

  final String destination;

  /// When supplied it must carry a place id, a name, and both coordinates.
  final DestinationPlace? destinationPlace;
  final PlanDates? dates;
  final PlanGuests? guests;

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'destination': destination,
        'destinationPlace': destinationPlace?.toJson(),
        'dates': dates?.toJson(),
        'guests': guests?.toJson(),
      });
}

/// A budget preference. [amountPerPersonPerDay] is required — and only
/// meaningful — with [BudgetTier.custom].
@immutable
class PlanBudget {
  const PlanBudget({required this.tier, this.amountPerPersonPerDay});

  final BudgetTier tier;

  /// THB per person per day, excluding accommodation. 0–1,000,000.
  final double? amountPerPersonPerDay;

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'tier': tier.wire,
        'amountPerPersonPerDay': amountPerPersonPerDay,
      });
}

/// Where the traveller is staying, or what they are looking for.
///
/// Fields belonging to the other [status] are ignored rather than rejected.
@immutable
class PlanAccommodation {
  /// A stay that is already booked. Give a [placeId] or a [name]; the place id
  /// wins if both are set.
  const PlanAccommodation.booked({
    this.placeId,
    this.name,
    this.checkIn,
    this.checkOut,
    this.bookingUrl,
    this.attachmentIds = const <String>[],
  })  : status = AccommodationStatus.booked,
        grade = null,
        styles = const <HotelStyle>[],
        customStyles = const <String>[],
        preferredArea = null,
        notes = null;

  /// Nothing booked yet — describe what to look for. Omit a field entirely to
  /// mean "recommend something"; there is no enum value for that.
  const PlanAccommodation.notBooked({
    this.grade,
    this.styles = const <HotelStyle>[],
    this.customStyles = const <String>[],
    this.preferredArea,
    this.notes,
  })  : status = AccommodationStatus.notBooked,
        placeId = null,
        name = null,
        checkIn = null,
        checkOut = null,
        bookingUrl = null,
        attachmentIds = const <String>[];

  final AccommodationStatus status;

  /// One of our own place ids.
  final String? placeId;
  final String? name;

  /// Overrides a flexible `dates.mode`.
  final DateTime? checkIn;
  final DateTime? checkOut;

  /// Accepted but not yet used by the planner.
  final String? bookingUrl;

  /// Accepted but not yet used by the planner.
  final List<String> attachmentIds;
  final HotelGrade? grade;
  final List<HotelStyle> styles;
  final List<String> customStyles;
  final String? preferredArea;
  final String? notes;

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'status': status.wire,
        'placeId': placeId,
        'name': name,
        'checkIn': checkIn == null ? null : Json.formatDate(checkIn!),
        'checkOut': checkOut == null ? null : Json.formatDate(checkOut!),
        'bookingUrl': bookingUrl,
        'attachmentIds': attachmentIds.isEmpty ? null : attachmentIds,
        'grade': grade?.wire,
        'styles': wireList(styles),
        'customStyles': customStyles.isEmpty ? null : customStyles,
        'preferredArea': preferredArea,
        'notes': notes,
      });
}

/// Everything the traveller told us about how they want to travel. The whole
/// block is optional, so a "skip for now" button needs no placeholder values.
@immutable
class PlanPreferences {
  const PlanPreferences({
    this.styles = const <TravelStyle>[],
    this.customStyles = const <String>[],
    this.intensity,
    this.transport = const <TransportMode>[],
    this.customTransport = const <String>[],
    this.budget,
    this.accommodation,
    this.constraints = const <TripConstraint>[],
    this.customConstraints = const <String>[],
  });

  final List<TravelStyle> styles;
  final List<String> customStyles;
  final TripIntensity? intensity;
  final List<TransportMode> transport;
  final List<String> customTransport;
  final PlanBudget? budget;
  final PlanAccommodation? accommodation;

  /// Up to 6. These override [intensity] where they disagree.
  final List<TripConstraint> constraints;
  final List<String> customConstraints;

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'styles': wireList(styles),
        'customStyles': customStyles.isEmpty ? null : customStyles,
        'intensity': intensity?.wire,
        'transport': wireList(transport),
        'customTransport': customTransport.isEmpty ? null : customTransport,
        'budget': budget?.toJson(),
        'accommodation': accommodation?.toJson(),
        'constraints': wireList(constraints),
        'customConstraints':
            customConstraints.isEmpty ? null : customConstraints,
      });
}

/// A request to `POST /trips/plan/generate`.
@immutable
class PlanGenerationRequest {
  const PlanGenerationRequest({
    required this.trip,
    this.preferences,
    this.selectedPlaceIds = const <String>[],
    this.locale,
    this.currency,
  });

  final PlanTripInput trip;
  final PlanPreferences? preferences;

  /// Up to 40 of our own place ids, from `/places/suggest` or
  /// `/places/suggest/sections`. An unknown id is a 400. Every one is placed
  /// in the plan; any that will not fit the pace come back as a
  /// `missing_picked_place` warning.
  final List<String> selectedPlaceIds;

  /// `th` or `en`.
  final String? locale;
  final String? currency;

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'trip': trip.toJson(),
        'preferences': preferences?.toJson(),
        'selectedPlaceIds':
            selectedPlaceIds.isEmpty ? null : selectedPlaceIds,
        'locale': locale,
        'currency': currency,
      });
}

/// A stop-count range for a day.
@immutable
class ItemsPerDay {
  const ItemsPerDay({required this.min, required this.max});

  factory ItemsPerDay.fromJson(Map<String, dynamic> json) => ItemsPerDay(
        min: Json.integer(json, 'min') ?? 0,
        max: Json.integer(json, 'max') ?? 0,
      );

  final int min;
  final int max;
}

/// What the planner decided after filling in the gaps in a request.
@immutable
class ResolvedBrief {
  const ResolvedBrief({
    required this.durationDays,
    required this.numPeople,
    required this.defaultsApplied,
    required this.warnings,
    this.itemsPerDay,
    this.budgetPerPersonPerDayCap,
    this.budgetCapTotal,
  });

  factory ResolvedBrief.fromJson(Map<String, dynamic> json) => ResolvedBrief(
        durationDays: Json.integer(json, 'durationDays') ?? 0,
        numPeople: Json.integer(json, 'numPeople') ?? 1,
        itemsPerDay: json['itemsPerDay'] is Map
            ? ItemsPerDay.fromJson(Json.asMap(json['itemsPerDay']))
            : null,
        budgetPerPersonPerDayCap:
            Json.number(json, 'budgetPerPersonPerDayCap'),
        budgetCapTotal: Json.number(json, 'budgetCapTotal'),
        defaultsApplied: Json.stringList(json, 'defaultsApplied'),
        warnings: Json.stringList(json, 'warnings'),
      );

  final int durationDays;
  final int numPeople;
  final ItemsPerDay? itemsPerDay;
  final double? budgetPerPersonPerDayCap;
  final double? budgetCapTotal;

  /// Fields the traveller left blank that the server filled in — worth telling
  /// them about.
  final List<String> defaultsApplied;

  /// Values the traveller did give that a stricter rule overrode.
  final List<String> warnings;

  bool get hasNotices => defaultsApplied.isNotEmpty || warnings.isNotEmpty;
}

/// One thing the planner could not satisfy.
@immutable
class PlanViolation {
  const PlanViolation({
    required this.severity,
    required this.code,
    required this.message,
    this.dayNumber,
    this.itemIndex,
  });

  factory PlanViolation.fromJson(Map<String, dynamic> json) => PlanViolation(
        severity: ViolationSeverity.from(json['severity']) ??
            ViolationSeverity.warning,
        code: Json.requiredString(json, 'code'),
        message: Json.requiredString(json, 'message'),
        dayNumber: Json.integer(json, 'dayNumber'),
        itemIndex: Json.integer(json, 'itemIndex'),
      );

  final ViolationSeverity severity;

  /// A stable machine code, e.g. `missing_picked_place`.
  final String code;
  final String message;
  final int? dayNumber;
  final int? itemIndex;

  bool get isError => severity == ViolationSeverity.error;
}

/// How the generation itself went.
@immutable
class GenerationReport {
  const GenerationReport({
    required this.attempts,
    required this.resolvedWithoutErrors,
    required this.modelWarnings,
    required this.violations,
  });

  factory GenerationReport.fromJson(Map<String, dynamic> json) =>
      GenerationReport(
        attempts: Json.integer(json, 'attempts') ?? 1,
        resolvedWithoutErrors:
            Json.boolean(json, 'resolvedWithoutErrors', fallback: true),
        modelWarnings: Json.stringList(json, 'modelWarnings'),
        violations: Json.asMapList(json['violations'])
            .map(PlanViolation.fromJson)
            .toList(growable: false),
      );

  final int attempts;

  /// False means the repair loop gave up with errors outstanding. The plan is
  /// still usable, but the traveller should see [violations].
  final bool resolvedWithoutErrors;
  final List<String> modelWarnings;
  final List<PlanViolation> violations;

  List<PlanViolation> get errors =>
      violations.where((violation) => violation.isError).toList(growable: false);
}

/// The result of `POST /trips/plan/generate`.
///
/// Nothing has been saved: if the traveller closes the app here, no trip is
/// left behind. Post [draft] to `POST /trips/create` to keep it.
@immutable
class PlanGenerationResult {
  const PlanGenerationResult({
    required this.draft,
    required this.resolvedBrief,
    required this.generation,
  });

  factory PlanGenerationResult.fromJson(Map<String, dynamic> json) =>
      PlanGenerationResult(
        draft: TripDraft.fromJson(Json.asMap(json['draft'])),
        resolvedBrief:
            ResolvedBrief.fromJson(Json.asMap(json['resolvedBrief'])),
        generation:
            GenerationReport.fromJson(Json.asMap(json['generation'])),
      );

  final TripDraft draft;
  final ResolvedBrief resolvedBrief;
  final GenerationReport generation;
}
