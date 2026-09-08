import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json.dart';

/// One category's share of the plan. Sorted by amount, largest first.
@immutable
class BudgetCategoryTotal {
  const BudgetCategoryTotal({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.itemCount,
  });

  factory BudgetCategoryTotal.fromJson(Map<String, dynamic> json) =>
      BudgetCategoryTotal(
        category:
            ExpenseCategory.from(json['category']) ?? ExpenseCategory.other,
        amount: Json.number(json, 'amount') ?? 0,
        percentage: Json.integer(json, 'percentage') ?? 0,
        itemCount: Json.integer(json, 'itemCount') ?? 0,
      );

  final ExpenseCategory category;
  final double amount;

  /// A whole number 0–100, and 0 when the trip totals nothing.
  final int percentage;
  final int itemCount;
}

/// One day's spend.
@immutable
class BudgetDayTotal {
  const BudgetDayTotal({
    required this.dayId,
    required this.dayNumber,
    required this.amount,
    this.date,
  });

  factory BudgetDayTotal.fromJson(Map<String, dynamic> json) => BudgetDayTotal(
        dayId: Json.requiredString(json, 'dayId'),
        dayNumber: Json.integer(json, 'dayNumber') ?? 0,
        date: Json.date(json, 'date'),
        amount: Json.number(json, 'amount') ?? 0,
      );

  final String dayId;
  final int dayNumber;
  final DateTime? date;
  final double amount;
}

/// A single line in the budget breakdown, wherever it came from.
@immutable
class BudgetItem {
  const BudgetItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.source,
    this.date,
    this.dayNumber,
    this.paidBy,
    this.splitLabel,
  });

  factory BudgetItem.fromJson(Map<String, dynamic> json) => BudgetItem(
        id: Json.requiredString(json, 'id'),
        title: Json.requiredString(json, 'title'),
        category:
            ExpenseCategory.from(json['category']) ?? ExpenseCategory.other,
        amount: Json.number(json, 'amount') ?? 0,
        date: Json.date(json, 'date'),
        dayNumber: Json.integer(json, 'dayNumber'),
        paidBy: Json.string(json, 'paidBy'),
        splitLabel: Json.string(json, 'splitLabel'),
        source: BudgetItemSource.from(json['source']) ??
            BudgetItemSource.expense,
      );

  /// **Not unique on its own**: a stop's own cost and the leg leading to it
  /// share one id. Use [key] when building widget keys.
  final String id;
  final String title;
  final ExpenseCategory category;
  final double amount;

  /// Absent on accommodation, and on expenses that were not tied to a date.
  final DateTime? date;
  final int? dayNumber;
  final String? paidBy;
  final String? splitLabel;
  final BudgetItemSource source;

  /// A stable, unique identity for lists.
  String get key => '$id-${source.wire}';
}

/// The money view of a trip: `GET /trips/:id/budget`.
///
/// Only THB is counted — a line in another currency is skipped entirely, so
/// [totalBudget] can be lower than the visible items suggest.
@immutable
class BudgetSummary {
  const BudgetSummary({
    required this.totalBudget,
    required this.byCategory,
    required this.byDay,
    required this.items,
    this.budgetLimit,
  });

  factory BudgetSummary.fromJson(Map<String, dynamic> json) => BudgetSummary(
        budgetLimit: Json.number(json, 'budgetLimit'),
        totalBudget: Json.number(json, 'totalBudget') ?? 0,
        byCategory: Json.asMapList(json['byCategory'])
            .map(BudgetCategoryTotal.fromJson)
            .toList(growable: false),
        byDay: Json.asMapList(json['byDay'])
            .map(BudgetDayTotal.fromJson)
            .toList(growable: false),
        items: Json.asMapList(json['items'])
            .map(BudgetItem.fromJson)
            .toList(growable: false),
      );

  /// Absent means no budget was set, which is not the same as zero.
  final double? budgetLimit;

  /// The same number as `totalBudget` on the trip itself.
  final double totalBudget;
  final List<BudgetCategoryTotal> byCategory;
  final List<BudgetDayTotal> byDay;

  /// Ordered by date; undated lines come first.
  final List<BudgetItem> items;

  bool get hasLimit => budgetLimit != null;

  /// How much of the cap is spent, or null when there is no cap.
  double? get limitUsedRatio {
    final limit = budgetLimit;
    if (limit == null || limit <= 0) return null;
    return totalBudget / limit;
  }

  bool get isOverBudget {
    final limit = budgetLimit;
    return limit != null && totalBudget > limit;
  }

  /// Only the lines from one origin, e.g. every accommodation row.
  List<BudgetItem> itemsFrom(BudgetItemSource source) =>
      items.where((item) => item.source == source).toList(growable: false);
}
