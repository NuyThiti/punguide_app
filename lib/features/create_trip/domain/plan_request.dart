import '../../../core/api/pluno_api.dart';
import 'plan_labels.dart';

/// Turns what the two-step wizard collected into the body of
/// `POST /trips/plan/generate`.
///
/// Kept apart from the screen so the mapping can be read — and tested —
/// without a widget tree. Every field the traveller skipped is left out
/// rather than sent empty: the endpoint rejects unknown keys and treats an
/// absent field as "choose for me", which is exactly what ข้ามไปก่อน means.
PlanGenerationRequest buildPlanRequest({
  required String destination,
  DestinationPlace? destinationPlace,
  DateTime? startDate,
  DateTime? endDate,
  int nights = 0,
  int adults = 1,
  int children = 0,
  List<String> styleLabels = const <String>[],
  String paceTier = '',
  String transportLabel = '',
  BudgetTier? budgetTier,
  double perPersonPerDay = 0,
  String lodging = '',
  List<String> constraintLabels = const <String>[],
}) {
  return PlanGenerationRequest(
    trip: PlanTripInput(
      destination: destination.trim(),
      destinationPlace: destinationPlace,
      dates: _dates(startDate, endDate, nights),
      guests: PlanGuests(
        adults: adults.clamp(1, 50),
        children: children,
      ),
    ),
    preferences: PlanPreferences(
      styles: styleLabels
          .map((label) => styleByLabel[label])
          .whereType<TravelStyle>()
          .toList(growable: false),
      intensity: TripIntensity.from(paceTier),
      // The planner insists on at least one when planMode is ai, and
      // "recommend" is the enum's own way of saying nothing was chosen.
      transport: <TransportMode>[
        wizardTransportByLabel[transportLabel] ?? TransportMode.recommend,
      ],
      budget: _budget(budgetTier, perPersonPerDay),
      accommodation: _accommodation(lodging),
      constraints: constraintLabels
          .map((label) => constraintByLabel[label])
          .whereType<TripConstraint>()
          .toList(growable: false),
      // The chips with no enum behind them — dietary rather than
      // accessibility — are a hint for the model instead of a hard rule.
      customConstraints: constraintLabels
          .where((label) => !constraintByLabel.containsKey(label))
          .toList(growable: false),
    ),
  );
}

/// Real days when both were picked, otherwise the night count on its own.
/// Neither means flexible, which the endpoint defaults to three days.
PlanDates? _dates(DateTime? start, DateTime? end, int nights) {
  if (start != null && end != null) {
    return PlanDates.fixed(startDate: start, endDate: end);
  }
  if (nights > 0) {
    return PlanDates.flexible(
      durationDays: (nights + 1).clamp(1, 30),
      durationNights: nights,
    );
  }
  return null;
}

/// A figure typed under ระบุเอง makes the tier custom, which is the one tier
/// that has to carry an amount with it.
PlanBudget? _budget(BudgetTier? tier, double perPersonPerDay) {
  if (perPersonPerDay > 0 && tier == BudgetTier.custom) {
    return PlanBudget(
      tier: BudgetTier.custom,
      amountPerPersonPerDay: perPersonPerDay,
    );
  }
  if (tier == null || tier == BudgetTier.custom) return null;
  return PlanBudget(tier: tier);
}

/// Nothing chosen means no preference, which is a field left out entirely.
PlanAccommodation? _accommodation(String lodging) => switch (lodging) {
      'booked' => const PlanAccommodation.booked(),
      'searching' => const PlanAccommodation.notBooked(),
      _ => null,
    };
