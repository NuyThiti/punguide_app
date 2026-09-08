import '../../network/api_client.dart';
import '../models/accommodation.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/json.dart';

/// Accommodations and standalone expenses.
///
/// Neither has a list endpoint: read them back from `TripsApi.budget`, where
/// they appear as items with `source == accommodation` / `expense`.
class BudgetApi {
  const BudgetApi(this._client);

  final PlunoApiClient _client;

  /// Adds a place to stay. Costs `pricePerNight × durationNights` in the
  /// budget summary.
  Future<TripAccommodation> addAccommodation(
    String tripId, {
    required String name,
    String? placeId,
    String? imageUrl,
    double? pricePerNight,
    String? currency,
    List<String>? amenities,
    String? checkIn,
    String? checkOut,
    String? description,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/trips/$tripId/accommodations',
      body: _accommodationBody(
        name: name,
        placeId: placeId,
        imageUrl: imageUrl,
        pricePerNight: pricePerNight,
        currency: currency,
        amenities: amenities,
        checkIn: checkIn,
        checkOut: checkOut,
        description: description,
      ),
    );
    return TripAccommodation.fromJson(Json.asMap(body));
  }

  Future<TripAccommodation> updateAccommodation(
    String accommodationId, {
    String? name,
    String? placeId,
    String? imageUrl,
    double? pricePerNight,
    String? currency,
    List<String>? amenities,
    String? checkIn,
    String? checkOut,
    String? description,
  }) async {
    final body = await _client.patch<Map<String, dynamic>>(
      '/accommodations/$accommodationId',
      body: _accommodationBody(
        name: name,
        placeId: placeId,
        imageUrl: imageUrl,
        pricePerNight: pricePerNight,
        currency: currency,
        amenities: amenities,
        checkIn: checkIn,
        checkOut: checkOut,
        description: description,
      ),
    );
    return TripAccommodation.fromJson(Json.asMap(body));
  }

  Future<void> deleteAccommodation(String accommodationId) =>
      _client.delete<void>('/accommodations/$accommodationId');

  /// Adds a cost that stands on its own — fuel, tolls, souvenirs.
  ///
  /// Stop and accommodation costs already have columns; duplicating them here
  /// would double-count them in the budget.
  Future<TripExpense> addExpense(
    String tripId, {
    required String title,
    required double amount,
    ExpenseCategory? category,
    String? currency,
    DateTime? date,
    String? paidBy,
    String? splitLabel,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/trips/$tripId/expenses',
      body: Json.compact(<String, dynamic>{
        'title': title,
        'amount': amount,
        'category': category?.wire,
        'currency': currency,
        'date': date == null ? null : Json.formatDate(date),
        'paidBy': paidBy,
        'splitLabel': splitLabel,
      }),
    );
    return TripExpense.fromJson(Json.asMap(body));
  }

  Future<TripExpense> updateExpense(
    String expenseId, {
    String? title,
    double? amount,
    ExpenseCategory? category,
    String? currency,
    DateTime? date,
    String? paidBy,
    String? splitLabel,
  }) async {
    final body = await _client.patch<Map<String, dynamic>>(
      '/expenses/$expenseId',
      body: Json.compact(<String, dynamic>{
        'title': title,
        'amount': amount,
        'category': category?.wire,
        'currency': currency,
        'date': date == null ? null : Json.formatDate(date),
        'paidBy': paidBy,
        'splitLabel': splitLabel,
      }),
    );
    return TripExpense.fromJson(Json.asMap(body));
  }

  Future<void> deleteExpense(String expenseId) =>
      _client.delete<void>('/expenses/$expenseId');

  static Map<String, dynamic> _accommodationBody({
    String? name,
    String? placeId,
    String? imageUrl,
    double? pricePerNight,
    String? currency,
    List<String>? amenities,
    String? checkIn,
    String? checkOut,
    String? description,
  }) =>
      Json.compact(<String, dynamic>{
        'name': name,
        'placeId': placeId,
        'imageUrl': imageUrl,
        'pricePerNight': pricePerNight,
        'currency': currency,
        'amenities': amenities,
        'checkIn': checkIn,
        'checkOut': checkOut,
        'description': description,
      });
}
