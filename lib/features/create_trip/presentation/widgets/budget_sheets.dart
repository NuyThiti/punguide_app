import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/extensions/currency_extensions.dart';
import '../../domain/plan_labels.dart';

const _planGreen = Color(0xFF1F5B44);

/// One day a new expense can be filed under.
class BudgetDayOption {
  const BudgetDayOption({
    required this.number,
    required this.label,
    this.date,
  });

  final int number;

  /// "Sat, 20 Aug", or empty on a trip whose dates are still open.
  final String label;

  /// Null on a day the trip has no date for — the expense then goes up
  /// without one, and the server files it under ไม่ระบุวัน.
  final DateTime? date;

  String get menuLabel => label.isEmpty ? 'วันที่ $number' : label;
}

/// What แก้ไขงบ came back with.
typedef BudgetLimitResult = ({double? limit});

/// What + เพิ่มค่าใช้จ่าย came back with.
typedef NewExpense = ({
  String title,
  double amount,
  ExpenseCategory category,
  DateTime? date,
});

/// แก้ไขงบ — the trip's own cap, which is what the progress bar measures
/// against. Returns null when the traveller backed out; a result carrying a
/// null [BudgetLimitResult.limit] means they cleared the cap on purpose.
Future<BudgetLimitResult?> showBudgetLimitSheet(
  BuildContext context, {
  required double? current,
  required int groupSize,
}) {
  return showModalBottomSheet<BudgetLimitResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BudgetLimitSheet(current: current, groupSize: groupSize),
  );
}

/// เพิ่มค่าใช้จ่าย — a cost that stands on its own. Stop and accommodation
/// costs are not entered here: they have their own columns, and adding them
/// again would double-count them.
Future<NewExpense?> showAddExpenseSheet(
  BuildContext context, {
  required List<BudgetDayOption> days,
}) {
  return showModalBottomSheet<NewExpense>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (_) => _AddExpenseSheet(days: days),
  );
}

class _BudgetLimitSheet extends StatefulWidget {
  const _BudgetLimitSheet({required this.current, required this.groupSize});

  final double? current;
  final int groupSize;

  @override
  State<_BudgetLimitSheet> createState() => _BudgetLimitSheetState();
}

class _BudgetLimitSheetState extends State<_BudgetLimitSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current == null ? '' : _plain(widget.current!),
  );

  int get _heads => widget.groupSize < 1 ? 1 : widget.groupSize;

  static String _plain(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';

  double? get _typed {
    final parsed = double.tryParse(_controller.text.trim().replaceAll(',', ''));
    return parsed != null && parsed > 0 ? parsed : null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perHead = _typed;

    return _SheetShell(
      title: 'แก้ไขงบ',
      children: [
        const _FieldLabel('งบทั้งทริป (บาท)'),
        _FieldBox(
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'เช่น 20000',
              prefixText: '฿ ',
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          perHead == null
              ? 'เว้นว่างไว้ = ยังไม่ตั้งงบ'
              : 'ตกคนละประมาณ ${(perHead / _heads).asBaht} ($_heads คน)',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
      action: 'บันทึกงบ',
      // Clearing the cap is a real choice, so an empty field saves too.
      onAction: () => Navigator.of(context).pop((limit: _typed)),
      canAct: true,
    );
  }
}

class _AddExpenseSheet extends StatefulWidget {
  const _AddExpenseSheet({required this.days});

  final List<BudgetDayOption> days;

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  ExpenseCategory _category = ExpenseCategory.other;
  int? _dayNumber;

  @override
  void initState() {
    super.initState();
    _dayNumber = widget.days.isEmpty ? null : widget.days.first.number;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double? get _amount {
    final parsed =
        double.tryParse(_amountController.text.trim().replaceAll(',', ''));
    return parsed != null && parsed > 0 ? parsed : null;
  }

  /// A line needs both a name and a number; everything else has a default.
  bool get _canAdd =>
      _titleController.text.trim().isNotEmpty && _amount != null;

  BudgetDayOption? get _day {
    for (final day in widget.days) {
      if (day.number == _dayNumber) return day;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'เพิ่มค่าใช้จ่าย',
      children: [
        const _FieldLabel('รายการ'),
        _FieldBox(
          child: TextField(
            controller: _titleController,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'เช่น ค่าน้ำมันขาไป',
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _FieldLabel('จำนวนเงิน'),
                  _FieldBox(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '0',
                        prefixText: '฿ ',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _FieldLabel('วัน'),
                  _FieldBox(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _dayNumber,
                        isExpanded: true,
                        isDense: true,
                        icon: const Icon(Icons.keyboard_arrow_down,
                            size: 20, color: AppColors.muted),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('ไม่ระบุวัน'),
                          ),
                          for (final day in widget.days)
                            DropdownMenuItem<int?>(
                              value: day.number,
                              child: Text(day.menuLabel),
                            ),
                        ],
                        selectedItemBuilder: (_) => [
                          const Text('ไม่ระบุวัน',
                              overflow: TextOverflow.ellipsis),
                          for (final day in widget.days)
                            Text(day.menuLabel,
                                overflow: TextOverflow.ellipsis),
                        ],
                        onChanged: (value) =>
                            setState(() => _dayNumber = value),
                        style: const TextStyle(
                          color: AppColors.foreground,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _FieldLabel('หมวด'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in ExpenseCategory.values)
              _CategoryChip(
                category: category,
                selected: category == _category,
                onTap: () => setState(() => _category = category),
              ),
          ],
        ),
      ],
      action: 'เพิ่มค่าใช้จ่าย',
      canAct: _canAdd,
      onAction: () => Navigator.of(context).pop((
        title: _titleController.text.trim(),
        amount: _amount!,
        category: _category,
        date: _day?.date,
      )),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ExpenseCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = expenseCategoryColor(category);

    return Material(
      color: selected ? colour.withValues(alpha: 0.12) : Colors.white,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? colour : AppColors.chipBorder,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(expenseCategoryIcon(category), size: 15, color: colour),
              const SizedBox(width: 6),
              Text(
                expenseCategoryLabel(category),
                style: TextStyle(
                  color: selected ? colour : AppColors.foreground,
                  fontSize: 12,
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

/// The chrome both sheets share: rounded top, title with a close button, a
/// scrolling body and one pinned action.
class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.title,
    required this.children,
    required this.action,
    required this.onAction,
    required this.canAct,
  });

  final String title;
  final List<Widget> children;
  final String action;
  final VoidCallback onAction;
  final bool canAct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Keep the pinned action above the keyboard, which both sheets raise.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1EFEC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 19, color: Color(0xFF6C6862)),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: SizedBox(
                height: 50,
                width: double.infinity,
                child: FilledButton(
                  onPressed: canAct ? onAction : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _planGreen,
                    disabledBackgroundColor: const Color(0xFFDCD8D2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  child: Text(
                    action,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: child,
    );
  }
}
