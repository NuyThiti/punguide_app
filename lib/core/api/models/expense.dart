import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json.dart';

/// A standalone cost: fuel, tolls, souvenirs.
///
/// Stop and accommodation costs are not expenses — they have their own
/// columns, and the budget summary folds them in when you read it.
@immutable
class TripExpense {
  const TripExpense({
    required this.id,
    required this.tripId,
    required this.title,
    required this.amount,
    required this.category,
    this.currency,
    this.date,
    this.paidBy,
    this.splitLabel,
    this.updatedAt,
  });

  factory TripExpense.fromJson(Map<String, dynamic> json) => TripExpense(
        id: Json.requiredString(json, 'id'),
        tripId: Json.requiredString(json, 'tripId'),
        title: Json.requiredString(json, 'title'),
        amount: Json.number(json, 'amount') ?? 0,
        currency: Json.string(json, 'currency'),
        category:
            ExpenseCategory.from(json['category']) ?? ExpenseCategory.other,
        date: Json.date(json, 'date'),
        paidBy: Json.string(json, 'paidBy'),
        splitLabel: Json.string(json, 'splitLabel'),
        updatedAt: Json.timestamp(json, 'updatedAt'),
      );

  final String id;
  final String tripId;
  final String title;

  /// Counted as-is in the budget — unlike stop costs, it is not multiplied by
  /// the head count.
  final double amount;
  final String? currency;
  final ExpenseCategory category;
  final DateTime? date;
  final String? paidBy;
  final String? splitLabel;
  final DateTime? updatedAt;
}
