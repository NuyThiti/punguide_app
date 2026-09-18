import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/extensions/currency_extensions.dart';
import '../../domain/plan_labels.dart';
import '../providers/edit_plan_providers.dart';
import 'budget_sheets.dart';

const _planGreen = Color(0xFF1F5B44);
const _panel = Color(0xFFF7F6F1);

/// The สรุปงบ tab: what the trip has cost, against what was set aside for it,
/// split by category and then day by day.
///
/// Everything here is read from `GET /trips/:id/budget` — the totals, the
/// category shares and every line — so nothing on screen is computed twice.
class PlanBudgetTab extends ConsumerStatefulWidget {
  const PlanBudgetTab({
    super.key,
    required this.tripId,
    required this.groupSize,
    required this.days,
    required this.onShare,
    required this.onEditBudget,
    required this.onAddExpense,
  });

  final String tripId;

  /// How many people share the trip, for the per-person figures. One when the
  /// trip never recorded a party size.
  final int groupSize;

  /// The plan's days, so an expense can be filed under one and a day with no
  /// spend still shows its own card.
  final List<BudgetDayOption> days;

  final VoidCallback onShare;

  /// Opens the cap editor; the sheet itself lives in the screen because it
  /// writes to the trip.
  final VoidCallback onEditBudget;

  final VoidCallback onAddExpense;

  @override
  ConsumerState<PlanBudgetTab> createState() => _PlanBudgetTabState();
}

class _PlanBudgetTabState extends ConsumerState<PlanBudgetTab> {
  /// The design leads with the per-head figure; the whole-trip total is the
  /// same data seen the other way, so the pill switches between them.
  bool _perPerson = true;

  /// Which day is open. The first one starts open, as the design shows.
  int? _openDay = 1;

  /// Null means ทุกหมวด.
  ExpenseCategory? _filter;

  int get _heads => widget.groupSize < 1 ? 1 : widget.groupSize;

  double _share(double amount) => _perPerson ? amount / _heads : amount;

  @override
  Widget build(BuildContext context) {
    final budget = ref.watch(planBudgetProvider(widget.tripId));

    return budget.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _BudgetNote(
        text: 'อ่านสรุปงบไม่สำเร็จ',
        onRetry: () => ref.invalidate(planBudgetProvider(widget.tripId)),
      ),
      data: _content,
    );
  }

  Widget _content(BudgetSummary summary) {
    final spent = _share(summary.totalBudget);
    final limit =
        summary.budgetLimit == null ? null : _share(summary.budgetLimit!);
    final unit = _perPerson ? '/ ต่อคน' : '/ ทั้งทริป';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeadingRow(
          perPerson: _perPerson,
          onTogglePerPerson: () => setState(() => _perPerson = !_perPerson),
          onShare: widget.onShare,
          onEditBudget: widget.onEditBudget,
          onAddExpense: widget.onAddExpense,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _TotalCard(
                      label: 'รวมงบที่ใช้ไป $unit',
                      amount: spent,
                      filled: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TotalCard(
                      label: 'งบที่ตั้งเอาไว้ $unit',
                      amount: limit,
                      filled: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _RemainingCard(spent: spent, limit: limit),
              const SizedBox(height: 10),
              _CategoryBreakdown(
                summary: summary,
                unit: unit,
                share: _share,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final day in _days(summary)) ...[
          _DayBudgetCard(
            day: day,
            total: _share(day.amount),
            open: _openDay == day.number,
            filter: _filter,
            items: _itemsOf(summary, day.number),
            share: _share,
            onToggle: () => setState(
                () => _openDay = _openDay == day.number ? null : day.number),
            onFilter: (category) => setState(() => _filter = category),
          ),
          const SizedBox(height: 10),
        ],
        // Lines the server could not put on a day — accommodation has no date,
        // and neither does an expense entered without one.
        if (_itemsOf(summary, null).isNotEmpty)
          _DayBudgetCard(
            day: null,
            total: _share(_itemsOf(summary, null)
                .fold<double>(0, (sum, item) => sum + item.amount)),
            open: _openDay == 0,
            filter: _filter,
            items: _itemsOf(summary, null),
            share: _share,
            onToggle: () => setState(() => _openDay = _openDay == 0 ? null : 0),
            onFilter: (category) => setState(() => _filter = category),
          ),
      ],
    );
  }

  /// Every day of the plan, in order — a day nobody has spent on yet still
  /// gets its own card, showing ฿0, because the design lists the whole trip.
  List<_DayRow> _days(BudgetSummary summary) {
    final spendByDay = <int, double>{
      for (final total in summary.byDay) total.dayNumber: total.amount,
    };
    final numbers = <int>{
      for (final day in widget.days) day.number,
      ...spendByDay.keys,
    }.toList()
      ..sort();
    final labels = <int, String>{
      for (final day in widget.days) day.number: day.menuLabel,
    };

    return [
      for (final number in numbers)
        _DayRow(
          number: number,
          label: labels[number] ?? 'วันที่ $number',
          amount: spendByDay[number] ?? 0,
        ),
    ];
  }

  List<BudgetItem> _itemsOf(BudgetSummary summary, int? dayNumber) =>
      summary.items
          .where((item) => item.dayNumber == dayNumber)
          .toList(growable: false);
}

/// One day's line in the tab: its number, how the plan labels it, and what
/// the trip spent on it.
@immutable
class _DayRow {
  const _DayRow({
    required this.number,
    required this.label,
    required this.amount,
  });

  final int number;
  final String label;
  final double amount;
}

/// "สรุปงบ", the per-person pill, and the three actions.
class _HeadingRow extends StatelessWidget {
  const _HeadingRow({
    required this.perPerson,
    required this.onTogglePerPerson,
    required this.onShare,
    required this.onEditBudget,
    required this.onAddExpense,
  });

  final bool perPerson;
  final VoidCallback onTogglePerPerson;
  final VoidCallback onShare;
  final VoidCallback onEditBudget;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'สรุปงบ',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 10),
            // The design puts the unit in a pill beside the heading; it is the
            // switch, because both figures come from the same numbers. It
            // yields rather than overflow the heading on a narrow phone.
            Flexible(
              child: Material(
                color: AppColors.screen,
                borderRadius: BorderRadius.circular(99),
                child: InkWell(
                  onTap: onTogglePerPerson,
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(
                      perPerson ? 'ค่าใช้จ่ายต่อคน' : 'ค่าใช้จ่ายทั้งทริป',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Three actions do not fit a phone beside the heading, so they wrap
        // onto their own line rather than shrinking into unreadable chips.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _BudgetAction(
              label: 'แชร์',
              icon: Icons.ios_share,
              onTap: onShare,
            ),
            _BudgetAction(
              label: 'แก้ไขงบ',
              icon: Icons.edit_outlined,
              background: AppColors.brandOrange,
              foreground: Colors.white,
              onTap: onEditBudget,
            ),
            _BudgetAction(
              label: 'เพิ่มค่าใช้จ่าย',
              icon: Icons.add,
              background: _planGreen,
              foreground: Colors.white,
              onTap: onAddExpense,
            ),
          ],
        ),
      ],
    );
  }
}

class _BudgetAction extends StatelessWidget {
  const _BudgetAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.background,
    this.foreground,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final outlined = background == null;

    return Material(
      color: background ?? AppColors.screen,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: outlined ? Border.all(color: AppColors.line) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: foreground ?? AppColors.foreground),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: foreground ?? AppColors.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the two headline figures. A trip with no cap shows a dash rather
/// than a zero — never setting a budget is not the same as setting none.
class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.amount,
    required this.filled,
  });

  final String label;
  final double? amount;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: filled ? _planGreen : AppColors.screen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: filled ? Colors.white70 : AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount == null ? '—' : amount!.asBaht,
            style: TextStyle(
              color: filled ? Colors.white : AppColors.foreground,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// How much of the cap is left, and the bar under it.
class _RemainingCard extends StatelessWidget {
  const _RemainingCard({required this.spent, required this.limit});

  final double spent;
  final double? limit;

  @override
  Widget build(BuildContext context) {
    final cap = limit;
    final remaining = cap == null ? 0.0 : cap - spent;
    final ratio =
        cap == null || cap <= 0 ? null : (spent / cap).clamp(0.0, 1.0);
    final over = cap != null && remaining < 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            cap == null
                ? 'ยังไม่ได้ตั้งงบไว้'
                : over
                    ? 'เกินงบ ${(-remaining).asBaht}'
                    : 'เหลือ ${remaining.asBaht} จะเท่างบ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: over ? const Color(0xFFE4574C) : AppColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio ?? 0,
              minHeight: 8,
              backgroundColor: AppColors.line,
              valueColor: AlwaysStoppedAnimation<Color>(
                over ? const Color(0xFFE4574C) : const Color(0xFF5FBE9B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "สัดส่วนค่าใช้จ่าย": one bar split by category, then the legend.
class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.summary,
    required this.unit,
    required this.share,
  });

  final BudgetSummary summary;
  final String unit;
  final double Function(double) share;

  @override
  Widget build(BuildContext context) {
    final totals = summary.byCategory
        .where((total) => total.amount > 0)
        .toList(growable: false);
    final items = totals.fold<int>(0, (sum, total) => sum + total.itemCount);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'สัดส่วนค่าใช้จ่าย $unit',
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$items รายการ',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (totals.isEmpty)
            const Text(
              'ยังไม่มีค่าใช้จ่ายในแผนนี้',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            )
          else ...[
            Row(
              children: [
                for (final total in totals) ...[
                  Expanded(
                    // The flex is the share itself, so the bar reads as the
                    // split without any width being measured.
                    flex: (total.amount * 100).round().clamp(1, 1 << 30),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: expenseCategoryColor(total.category),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  if (total != totals.last) const SizedBox(width: 4),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                for (final total in totals)
                  _LegendEntry(
                    category: total.category,
                    amount: share(total.amount),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.category, required this.amount});

  final ExpenseCategory category;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: expenseCategoryColor(category),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              expenseCategoryLabel(category),
              style: TextStyle(
                color: expenseCategoryColor(category),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          amount.asBaht,
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// One day's total, and its lines once opened.
class _DayBudgetCard extends StatelessWidget {
  const _DayBudgetCard({
    required this.day,
    required this.total,
    required this.open,
    required this.filter,
    required this.items,
    required this.share,
    required this.onToggle,
    required this.onFilter,
  });

  /// Null on the card that collects lines with no day of their own.
  final _DayRow? day;

  final double total;
  final bool open;
  final ExpenseCategory? filter;
  final List<BudgetItem> items;
  final double Function(double) share;
  final VoidCallback onToggle;
  final ValueChanged<ExpenseCategory?> onFilter;

  @override
  Widget build(BuildContext context) {
    final shown = filter == null
        ? items
        : items.where((item) => item.category == filter).toList();

    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      day == null ? 'ไม่ระบุวัน' : day!.label,
                      style: const TextStyle(
                        color: AppColors.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    total.asBaht,
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.screen,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      open
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              decoration: BoxDecoration(
                color: AppColors.screen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'รายการค่าใช้จ่าย',
                          style: TextStyle(
                            color: AppColors.foreground,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _CategoryFilter(
                        items: items,
                        selected: filter,
                        onSelect: onFilter,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (shown.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'ยังไม่มีรายการในหมวดนี้',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    )
                  else
                    for (final item in shown) ...[
                      _ExpenseRow(item: item, amount: share(item.amount)),
                      if (item != shown.last)
                        const Divider(height: 1, color: AppColors.line),
                    ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "ทุกหมวด", or one category of the day's lines.
class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final List<BudgetItem> items;
  final ExpenseCategory? selected;
  final ValueChanged<ExpenseCategory?> onSelect;

  @override
  Widget build(BuildContext context) {
    final present = <ExpenseCategory>{for (final item in items) item.category};

    return PopupMenuButton<ExpenseCategory?>(
      tooltip: 'กรองตามหมวด',
      onSelected: onSelect,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        const PopupMenuItem<ExpenseCategory?>(
          value: null,
          child: Text('ทุกหมวด'),
        ),
        for (final category in present)
          PopupMenuItem<ExpenseCategory?>(
            value: category,
            child: Text(expenseCategoryLabel(category)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list, size: 15, color: AppColors.muted),
            const SizedBox(width: 6),
            Text(
              selected == null ? 'ทุกหมวด' : expenseCategoryLabel(selected!),
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line: its category tile, what it was, and what it cost.
class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.item, required this.amount});

  final BudgetItem item;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final colour = expenseCategoryColor(item.category);
    final note = item.splitLabel ?? item.paidBy;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(expenseCategoryIcon(item.category),
                size: 17, color: colour),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                // One line, two colours: a long category label and a split
                // note together are wider than a phone row, so they share an
                // ellipsis rather than overflowing the card.
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: expenseCategoryLabel(item.category),
                        style: TextStyle(
                          color: colour,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (note != null && note.isNotEmpty)
                        TextSpan(text: ' · $note'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount.asBaht,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetNote extends StatelessWidget {
  const _BudgetNote({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            text,
            style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: const Text('ลองอีกครั้ง')),
        ],
      ),
    );
  }
}
