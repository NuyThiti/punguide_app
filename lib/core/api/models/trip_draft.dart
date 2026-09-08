import 'package:flutter/foundation.dart';

import 'destination_place.dart';
import 'enums.dart';
import 'json.dart';

/// The place behind a drafted stop.
///
/// [googlePlaceId] is matched against places we have already cached, so a
/// stop can link to an existing row instead of creating a duplicate.
@immutable
class DraftLocation {
  const DraftLocation({
    required this.name,
    this.latitude,
    this.longitude,
    this.rating,
    this.imageUrl,
    this.googlePlaceId,
  });

  factory DraftLocation.fromJson(Map<String, dynamic> json) => DraftLocation(
        name: Json.requiredString(json, 'name'),
        latitude: Json.number(json, 'lat'),
        longitude: Json.number(json, 'lng'),
        rating: Json.number(json, 'rating'),
        imageUrl: Json.string(json, 'imageUrl'),
        googlePlaceId: Json.string(json, 'googlePlaceId'),
      );

  static DraftLocation? maybeFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    if (json.isEmpty) return null;
    return DraftLocation.fromJson(json);
  }

  final String name;
  final double? latitude;
  final double? longitude;

  /// 0–5, one decimal place.
  final double? rating;
  final String? imageUrl;
  final String? googlePlaceId;

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'name': name,
        'lat': latitude,
        'lng': longitude,
        'rating': rating,
        'imageUrl': imageUrl,
        'googlePlaceId': googlePlaceId,
      });
}

/// A stop in a draft plan.
///
/// This speaks the front end's dialect — `time`, `title`, `cost` — where the
/// itinerary endpoints use `startTime`, `customName`, `costAmount`. That is
/// intentional on the API's side, not an inconsistency to work around.
@immutable
class DraftActivity {
  const DraftActivity({
    required this.title,
    this.id,
    this.time,
    this.endTime,
    this.category,
    this.location,
    this.placeId,
    this.cost,
    this.costCurrency,
    this.notes,
    this.orderIndex,
    this.estimatedDurationMin,
    this.travelTimeFromPrevMin,
    this.travelDistanceFromPrevKm,
    this.travelTypeFromPrev,
    this.travelCustomTypeFromPrev,
    this.travelCostFromPrevAmount,
    this.travelCostFromPrevCurrency,
    this.travelNotesFromPrev,
    this.bookingStatus,
    this.bookingLeadUrl,
    this.isAiSuggested,
    this.travelNote,
    this.icon,
    this.images = const <String>[],
  });

  factory DraftActivity.fromJson(Map<String, dynamic> json) => DraftActivity(
        id: Json.string(json, 'id'),
        time: Json.time(json, 'time'),
        endTime: Json.time(json, 'endTime'),
        title: Json.requiredString(json, 'title'),
        category: ActivityCategory.from(json['category']),
        location: DraftLocation.maybeFromJson(json['location']),
        placeId: Json.string(json, 'placeId'),
        cost: Json.number(json, 'cost'),
        costCurrency: Json.string(json, 'costCurrency'),
        notes: Json.string(json, 'notes'),
        orderIndex: Json.integer(json, 'orderIndex'),
        estimatedDurationMin: Json.integer(json, 'estimatedDurationMin'),
        travelTimeFromPrevMin: Json.integer(json, 'travelTimeFromPrevMin'),
        travelDistanceFromPrevKm:
            Json.number(json, 'travelDistanceFromPrevKm'),
        travelTypeFromPrev: TravelType.from(json['travelTypeFromPrev']),
        travelCustomTypeFromPrev:
            Json.string(json, 'travelCustomTypeFromPrev'),
        travelCostFromPrevAmount:
            Json.number(json, 'travelCostFromPrevAmount'),
        travelCostFromPrevCurrency:
            Json.string(json, 'travelCostFromPrevCurrency'),
        travelNotesFromPrev: Json.string(json, 'travelNotesFromPrev'),
        bookingStatus: BookingStatus.from(json['bookingStatus']),
        bookingLeadUrl: Json.string(json, 'bookingLeadUrl'),
        isAiSuggested:
            json['isAiSuggested'] is bool ? json['isAiSuggested'] as bool : null,
        travelNote: Json.string(json, 'travelNote'),
        icon: Json.string(json, 'icon'),
        images: Json.stringList(json, 'images'),
      );

  /// A client-side id used to match this stop against
  /// `expenses[].linkedActivityId`; the server discards it after saving.
  final String? id;

  /// `HH:mm` or `HH:mm:ss` on the way in; the API answers with `HH:mm`.
  final String? time;
  final String? endTime;
  final String title;

  /// Only used for a stop with no place — a linked stop derives its category
  /// from the place.
  final ActivityCategory? category;
  final DraftLocation? location;

  /// One of our own place ids. Wins over [location] when both are given.
  final String? placeId;

  /// THB for the whole group.
  final double? cost;
  final String? costCurrency;
  final String? notes;
  final int? orderIndex;
  final int? estimatedDurationMin;
  final int? travelTimeFromPrevMin;
  final double? travelDistanceFromPrevKm;
  final TravelType? travelTypeFromPrev;
  final String? travelCustomTypeFromPrev;
  final double? travelCostFromPrevAmount;
  final String? travelCostFromPrevCurrency;
  final String? travelNotesFromPrev;
  final BookingStatus? bookingStatus;
  final String? bookingLeadUrl;

  /// Defaults to false on save-plan (and to true on `POST /days/:id/items`).
  final bool? isAiSuggested;

  /// Accepted, then dropped on save — a prose sentence with nowhere to live.
  /// Send [travelTimeFromPrevMin] and [travelDistanceFromPrevKm] instead and
  /// the API composes the sentence when you read the trip back.
  final String? travelNote;

  /// Accepted, then dropped: presentation only, derived from the category.
  final String? icon;

  /// Accepted, then dropped: photos belong to the place, not the trip.
  final List<String> images;

  DraftActivity copyWith({
    String? title,
    String? time,
    String? endTime,
    ActivityCategory? category,
    DraftLocation? location,
    String? placeId,
    double? cost,
    String? notes,
    int? orderIndex,
    BookingStatus? bookingStatus,
  }) =>
      DraftActivity(
        id: id,
        title: title ?? this.title,
        time: time ?? this.time,
        endTime: endTime ?? this.endTime,
        category: category ?? this.category,
        location: location ?? this.location,
        placeId: placeId ?? this.placeId,
        cost: cost ?? this.cost,
        costCurrency: costCurrency,
        notes: notes ?? this.notes,
        orderIndex: orderIndex ?? this.orderIndex,
        estimatedDurationMin: estimatedDurationMin,
        travelTimeFromPrevMin: travelTimeFromPrevMin,
        travelDistanceFromPrevKm: travelDistanceFromPrevKm,
        travelTypeFromPrev: travelTypeFromPrev,
        travelCustomTypeFromPrev: travelCustomTypeFromPrev,
        travelCostFromPrevAmount: travelCostFromPrevAmount,
        travelCostFromPrevCurrency: travelCostFromPrevCurrency,
        travelNotesFromPrev: travelNotesFromPrev,
        bookingStatus: bookingStatus ?? this.bookingStatus,
        bookingLeadUrl: bookingLeadUrl,
        isAiSuggested: isAiSuggested,
        travelNote: travelNote,
        icon: icon,
        images: images,
      );

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'id': id,
        'time': time,
        'endTime': endTime,
        'title': title,
        'category': category?.wire,
        'location': location?.toJson(),
        'placeId': placeId,
        'cost': cost,
        'costCurrency': costCurrency,
        'notes': notes,
        'orderIndex': orderIndex,
        'estimatedDurationMin': estimatedDurationMin,
        'travelTimeFromPrevMin': travelTimeFromPrevMin,
        'travelDistanceFromPrevKm': travelDistanceFromPrevKm,
        'travelTypeFromPrev': travelTypeFromPrev?.wire,
        'travelCustomTypeFromPrev': travelCustomTypeFromPrev,
        'travelCostFromPrevAmount': travelCostFromPrevAmount,
        'travelCostFromPrevCurrency': travelCostFromPrevCurrency,
        'travelNotesFromPrev': travelNotesFromPrev,
        'bookingStatus': bookingStatus?.wire,
        'bookingLeadUrl': bookingLeadUrl,
        'isAiSuggested': isAiSuggested,
        'travelNote': travelNote,
        'icon': icon,
        'images': images.isEmpty ? null : images,
      });
}

/// A day in a draft plan.
@immutable
class DraftDay {
  const DraftDay({
    required this.activities,
    this.dayNumber,
    this.date,
    this.fatigueLevel,
    this.daySummary,
  });

  factory DraftDay.fromJson(Map<String, dynamic> json) => DraftDay(
        dayNumber: Json.integer(json, 'dayNumber'),
        date: Json.date(json, 'date'),
        fatigueLevel: FatigueLevel.from(json['fatigueLevel']),
        daySummary: Json.string(json, 'daySummary'),
        activities: Json.asMapList(json['activities'])
            .map(DraftActivity.fromJson)
            .toList(growable: false),
      );

  /// Defaults to the last day plus one. Duplicates are rejected with a 400.
  final int? dayNumber;
  final DateTime? date;
  final FatigueLevel? fatigueLevel;
  final String? daySummary;

  /// May be empty, but the key is required.
  final List<DraftActivity> activities;

  DraftDay copyWith({List<DraftActivity>? activities, String? daySummary}) =>
      DraftDay(
        dayNumber: dayNumber,
        date: date,
        fatigueLevel: fatigueLevel,
        daySummary: daySummary ?? this.daySummary,
        activities: activities ?? this.activities,
      );

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'dayNumber': dayNumber,
        'date': date == null ? null : Json.formatDate(date!),
        'fatigueLevel': fatigueLevel?.wire,
        'daySummary': daySummary,
        'activities':
            activities.map((activity) => activity.toJson()).toList(),
      });
}

/// The single accommodation carried by a draft plan.
@immutable
class DraftAccommodation {
  const DraftAccommodation({
    required this.name,
    this.placeId,
    this.imageUrl,
    this.pricePerNight,
    this.currency,
    this.amenities = const <String>[],
    this.checkIn,
    this.checkOut,
    this.description,
  });

  factory DraftAccommodation.fromJson(Map<String, dynamic> json) =>
      DraftAccommodation(
        name: Json.requiredString(json, 'name'),
        placeId: Json.string(json, 'placeId'),
        imageUrl: Json.string(json, 'imageUrl'),
        pricePerNight: Json.number(json, 'pricePerNight'),
        currency: Json.string(json, 'currency'),
        amenities: Json.stringList(json, 'amenities'),
        checkIn: Json.time(json, 'checkIn'),
        checkOut: Json.time(json, 'checkOut'),
        description: Json.string(json, 'description'),
      );

  static DraftAccommodation? maybeFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    if (json.isEmpty) return null;
    return DraftAccommodation.fromJson(json);
  }

  final String name;
  final String? placeId;
  final String? imageUrl;
  final double? pricePerNight;
  final String? currency;

  /// Up to 30 entries, 120 characters each.
  final List<String> amenities;
  final String? checkIn;
  final String? checkOut;
  final String? description;

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'name': name,
        'placeId': placeId,
        'imageUrl': imageUrl,
        'pricePerNight': pricePerNight,
        'currency': currency,
        'amenities': amenities.isEmpty ? null : amenities,
        'checkIn': checkIn,
        'checkOut': checkOut,
        'description': description,
      });
}

/// A standalone expense in a draft plan.
@immutable
class DraftExpense {
  const DraftExpense({
    required this.title,
    required this.amount,
    this.id,
    this.category,
    this.currency,
    this.date,
    this.paidBy,
    this.splitLabel,
    this.linkedActivityId,
  });

  factory DraftExpense.fromJson(Map<String, dynamic> json) => DraftExpense(
        id: Json.string(json, 'id'),
        title: Json.requiredString(json, 'title'),
        amount: Json.number(json, 'amount') ?? 0,
        category: ExpenseCategory.from(json['category']),
        currency: Json.string(json, 'currency'),
        date: Json.date(json, 'date'),
        paidBy: Json.string(json, 'paidBy'),
        splitLabel: Json.string(json, 'splitLabel'),
        linkedActivityId: Json.string(json, 'linkedActivityId'),
      );

  final String? id;
  final String title;
  final double amount;
  final ExpenseCategory? category;
  final String? currency;
  final DateTime? date;
  final String? paidBy;
  final String? splitLabel;

  /// A row carrying this is **dropped** on save: it duplicates a stop's cost,
  /// which already has a column. Keep only expenses that stand alone.
  final String? linkedActivityId;

  bool get willBeDropped => linkedActivityId != null;

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'id': id,
        'title': title,
        'amount': amount,
        'category': category?.wire,
        'currency': currency,
        'date': date == null ? null : Json.formatDate(date!),
        'paidBy': paidBy,
        'splitLabel': splitLabel,
        'linkedActivityId': linkedActivityId,
      });
}

/// A whole plan, ready to save with `POST /trips/create`.
///
/// `POST /trips/plan/generate` returns one of these under `draft`, unsaved —
/// edit it, then post it back. It is also the shape to build by hand for a
/// manually planned trip.
///
/// When [planMode] is [PlanMode.ai] the API additionally requires
/// [numPeople], [budgetTier], [styles] (which may be empty), [intensity] and
/// a non-empty [transport]; see [missingAiFields].
@immutable
class TripDraft {
  const TripDraft({
    required this.title,
    required this.destination,
    required this.days,
    this.planMode,
    this.status,
    this.startDate,
    this.endDate,
    this.isDateFlexible,
    this.durationDays,
    this.durationNights,
    this.numPeople,
    this.budgetTier,
    this.budgetLimit,
    this.styles,
    this.intensity,
    this.transport,
    this.customStyles = const <String>[],
    this.customTransport = const <String>[],
    this.constraints = const <TripConstraint>[],
    this.customConstraints = const <String>[],
    this.groupType,
    this.specialNotes,
    this.coverImageUrl,
    this.destinationPlace,
    this.accommodation,
    this.expenses = const <DraftExpense>[],
  });

  factory TripDraft.fromJson(Map<String, dynamic> json) => TripDraft(
        title: Json.requiredString(json, 'title'),
        destination: Json.requiredString(json, 'destination'),
        planMode: PlanMode.from(json['planMode']),
        status: TripStatus.from(json['status']),
        startDate: Json.date(json, 'startDate'),
        endDate: Json.date(json, 'endDate'),
        isDateFlexible: json['isDateFlexible'] is bool
            ? json['isDateFlexible'] as bool
            : null,
        durationDays: Json.integer(json, 'durationDays'),
        durationNights: Json.integer(json, 'durationNights'),
        numPeople: Json.integer(json, 'numPeople'),
        budgetTier: BudgetTier.from(json['budgetTier']),
        budgetLimit: Json.number(json, 'budgetLimit') ??
            Json.number(json, 'budgetGoal'),
        styles: json.containsKey('styles')
            ? parseEnumList(json['styles'], TravelStyle.from)
            : null,
        intensity: TripIntensity.from(json['intensity']),
        transport: json.containsKey('transport')
            ? parseEnumList(json['transport'], TransportMode.from)
            : null,
        customStyles: Json.stringList(json, 'customStyles'),
        customTransport: Json.stringList(json, 'customTransport'),
        constraints: parseEnumList(json['constraints'], TripConstraint.from),
        customConstraints: Json.stringList(json, 'customConstraints'),
        groupType: GroupType.from(json['groupType']),
        specialNotes: Json.string(json, 'specialNotes'),
        coverImageUrl: Json.string(json, 'coverImageUrl'),
        destinationPlace:
            DestinationPlace.maybeFromJson(json['destinationPlace']),
        days: Json.asMapList(json['days'])
            .map(DraftDay.fromJson)
            .toList(growable: false),
        accommodation:
            DraftAccommodation.maybeFromJson(json['accommodation']),
        expenses: Json.asMapList(json['expenses'])
            .map(DraftExpense.fromJson)
            .toList(growable: false),
      );

  final String title;
  final String destination;

  /// Omitted means manual.
  final PlanMode? planMode;
  final TripStatus? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? isDateFlexible;
  final int? durationDays;
  final int? durationNights;
  final int? numPeople;
  final BudgetTier? budgetTier;

  /// THB for the whole trip — not per person per day.
  final double? budgetLimit;

  /// May be an empty list: the traveller can skip the styles step.
  final List<TravelStyle>? styles;
  final TripIntensity? intensity;
  final List<TransportMode>? transport;
  final List<String> customStyles;
  final List<String> customTransport;
  final List<TripConstraint> constraints;
  final List<String> customConstraints;
  final GroupType? groupType;
  final String? specialNotes;
  final String? coverImageUrl;
  final DestinationPlace? destinationPlace;

  /// At least one day is required.
  final List<DraftDay> days;
  final DraftAccommodation? accommodation;

  /// Up to 200 entries. Rows with a `linkedActivityId` are dropped on save.
  final List<DraftExpense> expenses;

  /// The AI-mode requirements this draft does not yet meet, by field name.
  /// Empty for a manual plan, which requires none of them.
  List<String> get missingAiFields {
    if (planMode != PlanMode.ai) return const <String>[];
    return <String>[
      if (numPeople == null) 'numPeople',
      if (budgetTier == null) 'budgetTier',
      if (styles == null) 'styles',
      if (intensity == null) 'intensity',
      if (transport == null || transport!.isEmpty) 'transport',
    ];
  }

  TripDraft copyWith({
    String? title,
    String? destination,
    TripStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    double? budgetLimit,
    String? specialNotes,
    String? coverImageUrl,
    List<DraftDay>? days,
    DraftAccommodation? accommodation,
    List<DraftExpense>? expenses,
  }) =>
      TripDraft(
        title: title ?? this.title,
        destination: destination ?? this.destination,
        planMode: planMode,
        status: status ?? this.status,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        isDateFlexible: isDateFlexible,
        durationDays: durationDays,
        durationNights: durationNights,
        numPeople: numPeople,
        budgetTier: budgetTier,
        budgetLimit: budgetLimit ?? this.budgetLimit,
        styles: styles,
        intensity: intensity,
        transport: transport,
        customStyles: customStyles,
        customTransport: customTransport,
        constraints: constraints,
        customConstraints: customConstraints,
        groupType: groupType,
        specialNotes: specialNotes ?? this.specialNotes,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        destinationPlace: destinationPlace,
        days: days ?? this.days,
        accommodation: accommodation ?? this.accommodation,
        expenses: expenses ?? this.expenses,
      );

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'title': title,
        'destination': destination,
        'planMode': planMode?.wire,
        'status': status?.wire,
        'startDate': startDate == null ? null : Json.formatDate(startDate!),
        'endDate': endDate == null ? null : Json.formatDate(endDate!),
        'isDateFlexible': isDateFlexible,
        'durationDays': durationDays,
        'durationNights': durationNights,
        'numPeople': numPeople,
        'budgetTier': budgetTier?.wire,
        'budgetLimit': budgetLimit,
        // An empty list is meaningful here ("styles skipped"), so it is sent
        // rather than pruned.
        'styles': styles?.map((style) => style.wire).toList(),
        'intensity': intensity?.wire,
        'transport': transport?.map((mode) => mode.wire).toList(),
        'customStyles': customStyles.isEmpty ? null : customStyles,
        'customTransport': customTransport.isEmpty ? null : customTransport,
        'constraints': wireList(constraints),
        'customConstraints':
            customConstraints.isEmpty ? null : customConstraints,
        'groupType': groupType?.wire,
        'specialNotes': specialNotes,
        'coverImageUrl': coverImageUrl,
        'destinationPlace': destinationPlace?.toJson(),
        'days': days.map((day) => day.toJson()).toList(),
        'accommodation': accommodation?.toJson(),
        'expenses': expenses.isEmpty
            ? null
            : expenses.map((expense) => expense.toJson()).toList(),
      });
}
