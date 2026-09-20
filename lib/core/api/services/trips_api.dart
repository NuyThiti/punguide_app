import '../../network/api_client.dart';
import '../../network/api_headers.dart';
import '../models/budget.dart';
import '../models/destination_place.dart';
import '../models/enums.dart';
import '../models/json.dart';
import '../models/plan_generation.dart';
import '../models/post_assistant.dart';
import '../models/trip.dart';
import '../models/trip_content.dart';
import '../models/trip_draft.dart';
import '../models/trip_feed_query.dart';

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
    TripType type = TripType.planTrip,
    String? idempotencyKey,
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
    String? budgetCurrency,
    BudgetTier? budgetTier,
    List<String>? customStyles,
    List<String>? customTransport,
    List<String>? customConstraints,
    Patch<String>? linkedTripId,
    String? specialNotes,
    List<TripContentRequest>? contents,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/trips',
      headers: idempotencyKey == null
          ? null
          : PlunoHeaders.idempotent(idempotencyKey),
      body: Json.compact(<String, dynamic>{
        'type': type.wire,
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
        'budgetCurrency': budgetCurrency,
        // The brief merges per key: send a list and it replaces that one, send
        // [] to clear it, leave it out and the server keeps what it has.
        'customStyles': customStyles,
        'customTransport': customTransport,
        'customConstraints': customConstraints,
        // Three states, not two: a uuid links, `Patch.clear()` unlinks, and
        // leaving it out keeps whatever the trip already points at — which is
        // what an autosave that only touched the title must do.
        'linkedTripId': linkedTripId,
        'budgetTier': budgetTier?.wire,
        'specialNotes': specialNotes,
        'contents': TripContentRequest.serializeAll(contents),
      }),
    );
    return ApiTrip.fromJson(Json.asMap(body));
  }

  /// Drafts a post out of photos already uploaded to this trip: a headline,
  /// the sections, and the places the assistant thinks each one is at.
  ///
  /// Writes nothing. The traveller reviews the draft and saves it with
  /// [update], which is the only thing that touches the trip — a draft nobody
  /// keeps must leave nothing behind, and a place the model guessed has to
  /// pass a human first, so every location comes back `suggested`.
  ///
  /// [photos] carry the EXIF the app read: the server cannot, because every
  /// stored variant is stripped of metadata on upload. Their order is the
  /// order of the post, and the answer holds exactly one section per photo in
  /// that same order — a card each, however the model grouped them.
  ///
  /// [locationName] is the one place name the assistant may write into the
  /// captions, and only a place the traveller confirmed themselves may be
  /// passed: coordinates near somewhere are not confirmation. Left out, the
  /// captions describe the place without naming it — the suggestions in
  /// `locationOptions` are unaffected either way.
  ///
  /// [notes] is context, not instruction, and is the only thing that lets the
  /// assistant write "เรา" instead of the first person singular.
  ///
  /// Pass an [idempotencyKey] per attempt: the same key within five minutes
  /// returns the draft it returned the first time, free. "Draft again" needs a
  /// fresh one.
  Future<GeneratedPostDraft> generateContents(
    String tripId, {
    required List<PostAssistantPhoto> photos,
    String? language,
    String? notes,
    String? locationName,
    String? idempotencyKey,
  }) async {
    // The endpoint is billed per photo and caps a call at 20; the app splits
    // nothing itself, so this is a mistake worth catching before the request.
    if (photos.isEmpty || photos.length > 20) {
      throw const FormatException('ร่างโพสต์ได้ครั้งละ 1-20 รูป');
    }
    final ids = photos.map((photo) => photo.mediaId).toList();
    if (ids.toSet().length != ids.length) {
      throw const FormatException('รหัสรูปซ้ำในคำขอเดียวกัน');
    }
    if ((notes?.length ?? 0) > 500) {
      throw const FormatException('บริบทเพิ่มเติมต้องไม่เกิน 500 ตัวอักษร');
    }
    if ((locationName?.length ?? 0) > 200) {
      throw const FormatException('ชื่อสถานที่ต้องไม่เกิน 200 ตัวอักษร');
    }

    final body = await _client.post<Map<String, dynamic>>(
      '/trips/$tripId/contents/generate',
      headers: idempotencyKey == null
          ? null
          : PlunoHeaders.idempotent(idempotencyKey),
      body: Json.compact(<String, dynamic>{
        'photos': photos.map((photo) => photo.toJson()).toList(),
        'language': language,
        'notes': notes,
        'locationName': locationName,
      }),
    );
    return GeneratedPostDraft.fromJson(Json.asMap(body));
  }

  /// The public feed, newest first.
  ///
  /// Every filter lives on [TripFeedQuery]; an empty one is the plain feed —
  /// every public trip, unpaginated — which is what this returned before there
  /// were any filters at all.
  ///
  /// Optional-auth: with a token the rows carry the caller's own `isSaved` and
  /// `isLiked`, without one both are false.
  ///
  /// Two traps worth knowing before adding a parameter here:
  ///
  ///  * the endpoint runs `forbidNonWhitelisted`, so a key it does not
  ///    recognise fails the whole request with a `400` — a typo is loud, but
  ///    it also means nothing may be invented client-side;
  ///  * `distanceKm` comes back on a row only when the query carried both
  ///    coordinates, which [TripFeedQuery] enforces as a pair.
  Future<List<TripListItem>> feed([
    TripFeedQuery query = const TripFeedQuery(),
  ]) async {
    final body = await _client.get<List<dynamic>>(
      '/trips',
      query: query.toQuery(),
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
    TripType? type,
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
    String? budgetCurrency,
    BudgetTier? budgetTier,
    List<String>? customStyles,
    List<String>? customTransport,
    List<String>? customConstraints,
    Patch<String>? linkedTripId,
    String? specialNotes,
    List<TripContentRequest>? contents,
    TripStatus? status,
    TripVisibility? visibility,
  }) async {
    final body = await _client.patch<Map<String, dynamic>>(
      '/trips/$tripId',
      body: Json.compact(<String, dynamic>{
        'type': type?.wire,
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
        'budgetCurrency': budgetCurrency,
        // The brief merges per key: send a list and it replaces that one, send
        // [] to clear it, leave it out and the server keeps what it has.
        'customStyles': customStyles,
        'customTransport': customTransport,
        'customConstraints': customConstraints,
        // Three states, not two: a uuid links, `Patch.clear()` unlinks, and
        // leaving it out keeps whatever the trip already points at — which is
        // what an autosave that only touched the title must do.
        'linkedTripId': linkedTripId,
        'budgetTier': budgetTier?.wire,
        'specialNotes': specialNotes,
        'contents': TripContentRequest.serializeAll(contents),
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
  Future<void> delete(String tripId) => _client.delete<void>('/trips/$tripId');

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
