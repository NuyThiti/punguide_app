import '../../network/api_client.dart';
import '../../network/api_headers.dart';
import '../models/activity.dart';
import '../models/day.dart';
import '../models/enums.dart';
import '../models/json.dart';
import '../models/travel_segment.dart';

/// Days, stops, and the legs between them.
///
/// Every call here requires ownership of the trip; someone else's trip answers
/// 404 rather than 403.
///
/// These DTOs treat an explicit null as "clear this field" and an omitted key
/// as "leave it alone" — express the difference with [Patch].
class ItineraryApi {
  const ItineraryApi(this._client);

  final PlunoApiClient _client;

  /// Appends a day. [dayNumber] defaults to the last day plus one, and a
  /// duplicate is a 409.
  Future<ItineraryDay> addDay(
    String tripId, {
    int? dayNumber,
    DateTime? date,
    FatigueLevel? fatigueLevel,
    String? daySummary,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/trips/$tripId/days',
      body: Json.compact(<String, dynamic>{
        'dayNumber': dayNumber,
        'date': date == null ? null : Json.formatDate(date),
        'fatigueLevel': fatigueLevel?.wire,
        'daySummary': daySummary,
      }),
    );
    return ItineraryDay.fromJson(Json.asMap(body));
  }

  /// One day, with its stops and calculated legs.
  Future<ItineraryDay> day(String dayId) async {
    final body = await _client.get<Map<String, dynamic>>('/days/$dayId');
    return ItineraryDay.fromJson(Json.asMap(body));
  }

  /// Edits a day. Pass `Patch.clear()` to blank a field out.
  ///
  /// There is no `dayNumber` here on purpose: the pair (trip, day number) is
  /// unique, so renumbering a day means rebuilding the itinerary.
  Future<ItineraryDay> updateDay(
    String dayId, {
    Patch<DateTime>? date,
    Patch<FatigueLevel>? fatigueLevel,
    Patch<String>? daySummary,
  }) async {
    final body = await _client.patch<Map<String, dynamic>>(
      '/days/$dayId',
      body: Json.compact(<String, dynamic>{
        'date': _patchDate(date),
        'fatigueLevel': _patchEnum(fatigueLevel),
        'daySummary': daySummary,
      }),
    );
    return ItineraryDay.fromJson(Json.asMap(body));
  }

  /// Deletes a day and every stop in it.
  Future<void> deleteDay(String dayId) => _client.delete<void>('/days/$dayId');

  /// Adds a stop and calculates the leg from the previous one.
  ///
  /// Give a [placeId] or a [customName] — a stop with neither is a 400.
  /// Set [calculateTravelSegments] to false while the traveller is still
  /// rearranging, then call [retryTravelSegments] once at the end.
  Future<CreatedItineraryItem> addItem(
    String dayId, {
    String? placeId,
    String? customName,
    int? orderIndex,
    String? startTime,
    String? endTime,
    int? estimatedDurationMin,
    int? travelTimeFromPrevMin,
    double? travelDistanceFromPrevKm,
    TravelType? travelTypeFromPrev,
    String? travelCustomTypeFromPrev,
    double? travelCostFromPrevAmount,
    String? travelCostFromPrevCurrency,
    String? travelNotesFromPrev,
    ActivityCategory? category,
    double? costAmount,
    String? costCurrency,
    BookingStatus? bookingStatus,
    String? bookingLeadUrl,
    bool? isAiSuggested,
    String? notes,
    String? paidBy,
    String? splitLabel,
    bool calculateTravelSegments = true,
    String? idempotencyKey,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/days/$dayId/items',
      body: Json.compact(<String, dynamic>{
        'placeId': placeId,
        'customName': customName,
        'orderIndex': orderIndex,
        'startTime': startTime,
        'endTime': endTime,
        'estimatedDurationMin': estimatedDurationMin,
        'travelTimeFromPrevMin': travelTimeFromPrevMin,
        'travelDistanceFromPrevKm': travelDistanceFromPrevKm,
        'travelTypeFromPrev': travelTypeFromPrev?.wire,
        'travelCustomTypeFromPrev': travelCustomTypeFromPrev,
        'travelCostFromPrevAmount': travelCostFromPrevAmount,
        'travelCostFromPrevCurrency': travelCostFromPrevCurrency,
        'travelNotesFromPrev': travelNotesFromPrev,
        'category': category?.wire,
        'costAmount': costAmount,
        'costCurrency': costCurrency,
        'bookingStatus': bookingStatus?.wire,
        'bookingLeadUrl': bookingLeadUrl,
        'isAiSuggested': isAiSuggested,
        'notes': notes,
        'paidBy': paidBy,
        'splitLabel': splitLabel,
      }),
      headers: _writeHeaders(
        calculateTravelSegments: calculateTravelSegments,
        idempotencyKey: idempotencyKey,
      ),
    );
    return CreatedItineraryItem.fromJson(Json.asMap(body));
  }

  /// Edits a stop. Every field is optional; `Patch.clear()` blanks one out.
  ///
  /// Clearing [placeId] unlinks the place and leaves [customName] as the name,
  /// and vice versa — clearing both at once is a 400, since the stop would
  /// have no name at all.
  Future<Activity> updateItem(
    String itemId, {
    Patch<String>? placeId,
    Patch<String>? customName,
    int? orderIndex,
    Patch<String>? startTime,
    Patch<String>? endTime,
    Patch<int>? estimatedDurationMin,
    Patch<int>? travelTimeFromPrevMin,
    Patch<double>? travelDistanceFromPrevKm,
    Patch<TravelType>? travelTypeFromPrev,
    Patch<String>? travelCustomTypeFromPrev,
    Patch<double>? travelCostFromPrevAmount,
    Patch<String>? travelCostFromPrevCurrency,
    Patch<String>? travelNotesFromPrev,
    Patch<ActivityCategory>? category,
    double? costAmount,
    String? costCurrency,
    BookingStatus? bookingStatus,
    Patch<String>? bookingLeadUrl,
    bool? isAiSuggested,
    Patch<String>? notes,
    Patch<String>? paidBy,
    Patch<String>? splitLabel,
    bool calculateTravelSegments = true,
  }) async {
    final body = await _client.patch<Map<String, dynamic>>(
      '/items/$itemId',
      body: Json.compact(<String, dynamic>{
        'placeId': placeId,
        'customName': customName,
        'orderIndex': orderIndex,
        'startTime': startTime,
        'endTime': endTime,
        'estimatedDurationMin': estimatedDurationMin,
        'travelTimeFromPrevMin': travelTimeFromPrevMin,
        'travelDistanceFromPrevKm': travelDistanceFromPrevKm,
        'travelTypeFromPrev': _patchEnum(travelTypeFromPrev),
        'travelCustomTypeFromPrev': travelCustomTypeFromPrev,
        'travelCostFromPrevAmount': travelCostFromPrevAmount,
        'travelCostFromPrevCurrency': travelCostFromPrevCurrency,
        'travelNotesFromPrev': travelNotesFromPrev,
        'category': _patchEnum(category),
        'costAmount': costAmount,
        'costCurrency': costCurrency,
        'bookingStatus': bookingStatus?.wire,
        'bookingLeadUrl': bookingLeadUrl,
        'isAiSuggested': isAiSuggested,
        'notes': notes,
        'paidBy': paidBy,
        'splitLabel': splitLabel,
      }),
      headers: _writeHeaders(
        calculateTravelSegments: calculateTravelSegments,
      ),
    );
    return Activity.fromJson(Json.asMap(body));
  }

  Future<void> deleteItem(
    String itemId, {
    bool calculateTravelSegments = true,
  }) =>
      _client.delete<void>(
        '/items/$itemId',
        headers: _writeHeaders(
          calculateTravelSegments: calculateTravelSegments,
        ),
      );

  /// Reorders a day's stops.
  ///
  /// [itemIds] must be exactly the day's stops — one missing, one extra, or
  /// one that belongs elsewhere is a 400.
  Future<ItineraryDay> reorderItems(
    String dayId,
    List<String> itemIds, {
    bool calculateTravelSegments = true,
  }) async {
    final body = await _client.patch<Map<String, dynamic>>(
      '/days/$dayId/items/order',
      body: <String, dynamic>{'itemIds': itemIds},
      headers: _writeHeaders(
        calculateTravelSegments: calculateTravelSegments,
      ),
    );
    return ItineraryDay.fromJson(Json.asMap(body));
  }

  /// The legs of one day — the cheap way to refresh after an edit, instead of
  /// re-reading the whole trip.
  Future<List<TravelSegment>> travelSegments(String dayId) async {
    final body =
        await _client.get<List<dynamic>>('/days/$dayId/travel-segments');
    return TravelSegment.listFrom(body);
  }

  /// Recalculates one leg with a different mode, leaving its neighbours alone.
  ///
  /// Only [TravelMode.drive] works today; the rest return a 400.
  Future<TravelSegment> setTravelMode(
    String segmentId,
    TravelMode travelMode,
  ) async {
    final body = await _client.patch<Map<String, dynamic>>(
      '/travel-segments/$segmentId/travel-mode',
      body: <String, dynamic>{'travelMode': travelMode.wire},
    );
    return TravelSegment.fromJson(Json.asMap(body));
  }

  /// Recalculates only the failed legs of a trip and returns *all* of them.
  ///
  /// Safe to call every time a trip is opened: a healthy trip costs one query
  /// and no provider calls. It is a POST because it can spend money and write.
  Future<List<TravelSegment>> retryTravelSegments(String tripId) async {
    final body = await _client.post<List<dynamic>>(
      '/trips/$tripId/travel-segments/retry',
    );
    return TravelSegment.listFrom(body);
  }

  static Map<String, String>? _writeHeaders({
    required bool calculateTravelSegments,
    String? idempotencyKey,
  }) {
    final headers = <String, String>{
      if (!calculateTravelSegments) ...PlunoHeaders.skipTravelSegments(),
      if (idempotencyKey != null)
        ...PlunoHeaders.idempotent(idempotencyKey),
    };
    return headers.isEmpty ? null : headers;
  }

  /// A date patch, formatted or explicitly cleared.
  static Patch<String>? _patchDate(Patch<DateTime>? patch) {
    if (patch == null) return null;
    if (patch.isClear) return const Patch<String>.clear();
    return Patch<String>.value(Json.formatDate(patch.value!));
  }

  /// An enum patch, reduced to its wire value or explicitly cleared.
  static Patch<String>? _patchEnum<T>(Patch<T>? patch) {
    if (patch == null) return null;
    if (patch.isClear) return const Patch<String>.clear();
    return Patch<String>.value((patch.value as dynamic).wire as String);
  }
}
