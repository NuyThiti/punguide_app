import '../../network/api_client.dart';
import '../../network/api_headers.dart';
import '../models/budget.dart';
import '../models/destination_place.dart';
import '../models/enums.dart';
import '../models/json.dart';
import '../models/plan_generation.dart';
import '../models/trip.dart';
import '../models/trip_draft.dart';

/// Trips: the feed, the traveller's own trips, saving a plan, remixing,
/// bookmarks and likes.
class TripsApi {
  const TripsApi(this._client);

  final PlunoApiClient _client;

  /// Creates an empty draft, for when the traveller opens the editor. The id
  /// it returns is the one every itinerary, media and autosave call needs.
  ///
  /// A trip always starts as a draft — `status` cannot be set here.
  Future<ApiTrip> createDraft({
    required String title,
    required String destination,
    DestinationPlace? destinationPlace,
    DateTime? startDate,
    DateTime? endDate,
    int? guestCount,
    int? durationDays,
    int? durationNights,
    PlanMode? planMode,
    List<TravelStyle>? travelStyles,
    TripIntensity? pace,
    List<TripConstraint>? constraints,
    double? budgetLimit,
    BudgetTier? budgetTier,
    String? specialNotes,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/trips',
      body: Json.compact(<String, dynamic>{
        'title': title,
        'destination': destination,
        'destinationPlace': destinationPlace?.toJson(),
        'startDate': startDate == null ? null : Json.formatDate(startDate),
        'endDate': endDate == null ? null : Json.formatDate(endDate),
        'guestCount': guestCount,
        // Only trusted while the trip has no real dates; with dates, the
        // server derives the duration itself.
        'durationDays': durationDays,
        'durationNights': durationNights,
        'planMode': planMode?.wire,
        'travelStyles': wireList(travelStyles),
        'pace': pace?.wire,
        'constraints': wireList(constraints),
        'budgetLimit': budgetLimit,
        'budgetTier': budgetTier?.wire,
        'specialNotes': specialNotes,
      }),
    );
    return ApiTrip.fromJson(Json.asMap(body));
  }

  /// The public feed. Not paginated yet — it returns everything public.
  ///
  /// [destination] is a case-insensitive partial match.
  Future<List<TripListItem>> feed({String? destination}) async {
    final body = await _client.get<List<dynamic>>(
      '/trips',
      query: <String, dynamic>{'destination': destination},
    );
    return TripListItem.listFrom(body);
  }

  /// Every trip the signed-in traveller owns, at any visibility.
  Future<List<TripListItem>> mine() async {
    final body = await _client.get<List<dynamic>>('/trips/mine');
    return TripListItem.listFrom(body);
  }

  /// Bookmarked trips, most recently saved first. Trips whose owner deleted
  /// them simply disappear from the list.
  Future<List<TripListItem>> saved() async {
    final body = await _client.get<List<dynamic>>('/trips/saved');
    return TripListItem.listFrom(body);
  }

  /// A full trip with its itinerary.
  ///
  /// Accommodations and expenses are not included — call [budget] for those.
  Future<ApiTrip> byId(String tripId) async {
    final body = await _client.get<Map<String, dynamic>>('/trips/$tripId');
    return ApiTrip.fromJson(Json.asMap(body));
  }

  /// The money view: totals by category and by day, plus every line item.
  Future<BudgetSummary> budget(String tripId) async {
    final body =
        await _client.get<Map<String, dynamic>>('/trips/$tripId/budget');
    return BudgetSummary.fromJson(Json.asMap(body));
  }

  /// Autosave. Every field is optional and only what you pass is touched.
  ///
  /// Two traps this signature cannot hide:
  ///
  ///  * the plan brief is rewritten *as a whole* if any of [travelStyles],
  ///    [pace] or [constraints] is present, so send all three or none;
  ///  * unknown fields are rejected outright, so never feed a response object
  ///    back in — pass named arguments.
  Future<ApiTrip> update(
    String tripId, {
    String? title,
    String? destination,
    DestinationPlace? destinationPlace,
    DateTime? startDate,
    DateTime? endDate,
    int? guestCount,
    int? durationDays,
    int? durationNights,
    PlanMode? planMode,
    List<TravelStyle>? travelStyles,
    TripIntensity? pace,
    List<TripConstraint>? constraints,
    double? budgetLimit,
    BudgetTier? budgetTier,
    String? specialNotes,
    TripStatus? status,
    TripVisibility? visibility,
  }) async {
    final body = await _client.patch<Map<String, dynamic>>(
      '/trips/$tripId',
      body: Json.compact(<String, dynamic>{
        'title': title,
        'destination': destination,
        'destinationPlace': destinationPlace?.toJson(),
        'startDate': startDate == null ? null : Json.formatDate(startDate),
        'endDate': endDate == null ? null : Json.formatDate(endDate),
        'guestCount': guestCount,
        'durationDays': durationDays,
        'durationNights': durationNights,
        'planMode': planMode?.wire,
        'travelStyles': wireList(travelStyles),
        'pace': pace?.wire,
        'constraints': wireList(constraints),
        'budgetLimit': budgetLimit,
        'budgetTier': budgetTier?.wire,
        'specialNotes': specialNotes,
        'status': status?.wire,
        // The first switch to public stamps publishedAt; going private again
        // does not clear it.
        'visibility': visibility?.wire,
      }),
    );
    return ApiTrip.fromJson(Json.asMap(body));
  }

  /// Deletes the trip and everything attached to it: days, stops, segments,
  /// media, expenses, accommodations.
  Future<void> delete(String tripId) =>
      _client.delete<void>('/trips/$tripId');

  /// Saves a whole plan in one call — the only way to persist a generated
  /// draft, and equally the way to save a hand-built one.
  ///
  /// Pass an [idempotencyKey] minted per tap: replaying it returns the trip
  /// created the first time instead of a duplicate.
  Future<ApiTrip> createFromDraft(
    TripDraft draft, {
    String? idempotencyKey,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/trips/create',
      body: draft.toJson(),
      headers: idempotencyKey == null
          ? null
          : PlunoHeaders.idempotent(idempotencyKey),
    );
    return ApiTrip.fromJson(Json.asMap(body));
  }

  /// Asks the planner for an itinerary. **Nothing is saved** — pass
  /// `result.draft` to [createFromDraft] if the traveller keeps it.
  ///
  /// Rate limited to 30 an hour. Replaying an [idempotencyKey] within five
  /// minutes returns the same plan without paying for the model again.
  Future<PlanGenerationResult> generatePlan(
    PlanGenerationRequest request, {
    String? idempotencyKey,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/trips/plan/generate',
      body: request.toJson(),
      headers: idempotencyKey == null
          ? null
          : PlunoHeaders.idempotent(idempotencyKey),
    );
    return PlanGenerationResult.fromJson(Json.asMap(body));
  }

  /// Copies someone's trip into a private draft of your own.
  ///
  /// [startDate] and [endDate] go together, and the span has to match the
  /// source trip's length exactly. The destination cannot be changed.
  /// Remixing a stranger's private trip is the API's only 403.
  Future<RemixedTrip> remix(
    String sourceTripId, {
    required String title,
    DateTime? startDate,
    DateTime? endDate,
    int? travelerCount,
    bool? copyNotes,
    bool? copyBudget,
    String? idempotencyKey,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/trips/$sourceTripId/remix',
      body: Json.compact(<String, dynamic>{
        'title': title,
        'startDate': startDate == null ? null : Json.formatDate(startDate),
        'endDate': endDate == null ? null : Json.formatDate(endDate),
        'travelerCount': travelerCount,
        'copyNotes': copyNotes,
        'copyBudget': copyBudget,
      }),
      headers: idempotencyKey == null
          ? null
          : PlunoHeaders.idempotent(idempotencyKey),
    );
    return RemixedTrip.fromJson(Json.asMap(body));
  }

  /// Bookmarks a trip. Idempotent, and works on other people's trips.
  /// The new count is not returned — re-read the trip for `isSaved`.
  Future<void> save(String tripId) =>
      _client.post<dynamic>('/trips/$tripId/save');

  Future<void> unsave(String tripId) =>
      _client.delete<void>('/trips/$tripId/save');

  /// Likes a trip. Idempotent; read `likeCount` back from the trip.
  Future<void> like(String tripId) =>
      _client.post<dynamic>('/trips/$tripId/like');

  Future<void> unlike(String tripId) =>
      _client.delete<void>('/trips/$tripId/like');
}
