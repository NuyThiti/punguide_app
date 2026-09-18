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

/// A stop the traveller can file an expense against.
///
/// `TripExpense` has no place column, so the name is all that survives — it
/// becomes the expense's title.
class BudgetPlaceOption {
  const BudgetPlaceOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// What + เพิ่มค่าใช้จ่าย came back with. The sheet files several at once, so
/// the caller gets a list of these.
typedef NewExpense = ({
  String title,
  double amount,
  ExpenseCategory category,
  DateTime? date,
});

/// What ประเภทค่าใช้จ่าย came back with.
typedef ExpenseKind = ({BudgetPlaceOption? place, ExpenseCategory category});

/// One category tile on เลือกหมวดหมู่. The tile labels are also the budget
/// tab's filter labels, so tests need something sharper than the text.
Key expenseCategoryTileKey(ExpenseCategory category) =>
    ValueKey('expense-category-${category.wire}');

/// The + เพิ่มค่าใช้จ่าย that adds a line — it shares its words with both the
/// sheet title and the confirm button.
const addExpenseLineKey = ValueKey('add-expense-line');

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
Future<List<NewExpense>?> showAddExpenseSheet(
  BuildContext context, {
  required List<BudgetDayOption> days,
  required List<BudgetPlaceOption> places,
  required int groupSize,
}) {
  return showModalBottomSheet<List<NewExpense>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (_) => _AddExpenseSheet(
      days: days,
      places: places,
      groupSize: groupSize,
    ),
  );
}

/// ประเภทค่าใช้จ่าย — the second step, opened from a line's type row: an
/// optional stop to file the cost against, then the category itself.
Future<ExpenseKind?> showExpenseCategorySheet(
  BuildContext context, {
  required List<BudgetPlaceOption> places,
  BudgetPlaceOption? place,
  ExpenseCategory? category,
}) {
  return showModalBottomSheet<ExpenseKind>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (_) => _ExpenseCategorySheet(
      places: places,
      place: place,
      category: category,
    ),
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

/// One line of the sheet. Each keeps its own controller, so removing a line
/// disposes exactly its own text and nobody else's.
class _ExpenseLine {
  _ExpenseLine({required this.dayNumber})
      : amountController = TextEditingController();

  final TextEditingController amountController;
  BudgetPlaceOption? place;
  ExpenseCategory? category;
  int? dayNumber;

  /// What the traveller typed, per head.
  double? get perPerson {
    final parsed =
        double.tryParse(amountController.text.trim().replaceAll(',', ''));
    return parsed != null && parsed > 0 ? parsed : null;
  }

  /// A line counts once it has both a number and a category.
  bool get isComplete => perPerson != null && category != null;

  bool get isBlank => perPerson == null && category == null && place == null;

  void dispose() => amountController.dispose();
}

class _AddExpenseSheet extends StatefulWidget {
  const _AddExpenseSheet({
    required this.days,
    required this.places,
    required this.groupSize,
  });

  final List<BudgetDayOption> days;
  final List<BudgetPlaceOption> places;
  final int groupSize;

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  late final List<_ExpenseLine> _lines;

  @override
  void initState() {
    super.initState();
    _lines = [_ExpenseLine(dayNumber: _defaultDay)];
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  int? get _defaultDay => widget.days.isEmpty ? null : widget.days.first.number;

  /// Every filled-in line has to be complete; blank ones are simply ignored,
  /// so a stray "+ เพิ่มค่าใช้จ่าย" tap does not block the sheet.
  bool get _canAdd =>
      _lines.any((line) => line.isComplete) &&
      _lines.every((line) => line.isComplete || line.isBlank);

  DateTime? _dateOf(int? number) {
    for (final day in widget.days) {
      if (day.number == number) return day.date;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'เพิ่มค่าใช้จ่าย',
      cancel: 'ยกเลิก',
      action: 'เพิ่มค่าใช้จ่าย',
      canAct: _canAdd,
      onAction: _submit,
      children: [
        for (var i = 0; i < _lines.length; i++) ...[
          _ExpenseLineCard(
            line: _lines[i],
            index: i + 1,
            days: widget.days,
            canRemove: _lines.length > 1,
            onRemove: () => setState(() => _lines.removeAt(i).dispose()),
            onPickKind: () => _pickKind(_lines[i]),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            key: addExpenseLineKey,
            onTap: () => setState(
              () => _lines.add(_ExpenseLine(dayNumber: _defaultDay)),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: AppColors.brandOrange),
                  SizedBox(width: 6),
                  Text(
                    'เพิ่มค่าใช้จ่าย',
                    style: TextStyle(
                      color: AppColors.brandOrange,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickKind(_ExpenseLine line) async {
    final picked = await showExpenseCategorySheet(
      context,
      places: widget.places,
      place: line.place,
      category: line.category,
    );
    if (picked == null) return;
    setState(() {
      line.place = picked.place;
      line.category = picked.category;
    });
  }

  void _submit() {
    // The field is labelled ต่อคน, but TripExpense.amount is counted as-is —
    // so the head count is applied here rather than left to the server.
    final heads = widget.groupSize < 1 ? 1 : widget.groupSize;
    final expenses = <NewExpense>[
      for (final line in _lines)
        if (line.isComplete)
          (
            title:
                line.place?.name ?? expenseCategoryShortLabel(line.category!),
            amount: line.perPerson! * heads,
            category: line.category!,
            date: _dateOf(line.dayNumber),
          ),
    ];
    Navigator.of(context).pop(expenses);
  }
}

class _ExpenseLineCard extends StatelessWidget {
  const _ExpenseLineCard({
    required this.line,
    required this.index,
    required this.days,
    required this.canRemove,
    required this.onRemove,
    required this.onPickKind,
    required this.onChanged,
  });

  final _ExpenseLine line;
  final int index;
  final List<BudgetDayOption> days;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onPickKind;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'รายการที่ $index',
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Tooltip(
                message:
                    canRemove ? 'ลบรายการนี้' : 'ต้องมีอย่างน้อยหนึ่งรายการ',
                child: GestureDetector(
                  onTap: canRemove ? onRemove : null,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1EE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 17,
                      color: canRemove
                          ? const Color(0xFFE4574C)
                          : const Color(0xFFE4574C).withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _FieldLabel('จำนวนเงิน'),
          _FieldBox(
            child: Row(
              children: [
                // A leading widget, not prefixText: Flutter hides a prefix
                // while the field is empty and unfocused, and the mock shows
                // the ฿ on an untouched 0.00.
                const Text(
                  '฿',
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: line.amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: '0.00',
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Text(
                  'ต่อคน',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _FieldLabel('ประเภทค่าใช้จ่าย'),
          GestureDetector(
            onTap: onPickKind,
            child: _FieldBox(
              child: Row(
                children: [
                  Expanded(child: _kindSummary()),
                  const Icon(Icons.chevron_right,
                      size: 20, color: AppColors.muted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _FieldLabel('วันที่จ่าย'),
          _FieldBox(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: line.dayNumber,
                isExpanded: true,
                isDense: true,
                icon: const Icon(Icons.keyboard_arrow_down,
                    size: 20, color: AppColors.muted),
                hint: const Text(
                  'วันที่จ่าย',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('ไม่ระบุวัน'),
                  ),
                  for (final day in days)
                    DropdownMenuItem<int?>(
                      value: day.number,
                      child: Text(day.menuLabel),
                    ),
                ],
                selectedItemBuilder: (_) => [
                  const Text('ไม่ระบุวัน', overflow: TextOverflow.ellipsis),
                  for (final day in days)
                    Text(day.menuLabel, overflow: TextOverflow.ellipsis),
                ],
                onChanged: (value) {
                  line.dayNumber = value;
                  onChanged();
                },
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
    );
  }

  /// "ตลาดเช้า • [icon] ช้อปปิ้ง", or the placeholder until one is picked.
  Widget _kindSummary() {
    final category = line.category;
    if (category == null) {
      return const Text(
        'ประเภทค่าใช้จ่าย',
        style: TextStyle(color: AppColors.muted, fontSize: 14),
      );
    }
    final colour = expenseCategoryColor(category);
    return Row(
      children: [
        if (line.place != null) ...[
          Flexible(
            child: Text(
              line.place!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 7),
            child: Text('•', style: TextStyle(color: AppColors.muted)),
          ),
        ],
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: colour.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(expenseCategoryIcon(category), size: 13, color: colour),
        ),
        const SizedBox(width: 7),
        Text(
          expenseCategoryShortLabel(category),
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// ประเภทค่าใช้จ่าย — an optional stop, then one of six categories.
class _ExpenseCategorySheet extends StatefulWidget {
  const _ExpenseCategorySheet({
    required this.places,
    required this.place,
    required this.category,
  });

  final List<BudgetPlaceOption> places;
  final BudgetPlaceOption? place;
  final ExpenseCategory? category;

  @override
  State<_ExpenseCategorySheet> createState() => _ExpenseCategorySheetState();
}

class _ExpenseCategorySheetState extends State<_ExpenseCategorySheet> {
  String? _placeId;
  ExpenseCategory? _category;

  @override
  void initState() {
    super.initState();
    _placeId = widget.place?.id;
    _category = widget.category;
  }

  BudgetPlaceOption? get _place {
    for (final place in widget.places) {
      if (place.id == _placeId) return place;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'ประเภทค่าใช้จ่าย',
      cancel: 'ยกเลิก',
      action: 'ยืนยัน',
      canAct: _category != null,
      onAction: () =>
          Navigator.of(context).pop((place: _place, category: _category!)),
      children: [
        if (widget.places.isNotEmpty) ...[
          _PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The mock sets these side by side at desktop width; on a
                // phone the hint drops to its own line rather than overflowing.
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'จากสถานที่ในแผน',
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '(ไม่บังคับ)',
                      style: TextStyle(
                        color: AppColors.muted.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _FieldBox(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _placeId,
                      isExpanded: true,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down,
                          size: 20, color: AppColors.muted),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('ไม่ระบุสถานที่'),
                        ),
                        for (final place in widget.places)
                          DropdownMenuItem<String?>(
                            value: place.id,
                            child: Text(place.name),
                          ),
                      ],
                      selectedItemBuilder: (_) => [
                        const Text('ไม่ระบุสถานที่',
                            overflow: TextOverflow.ellipsis),
                        for (final place in widget.places)
                          Text(place.name, overflow: TextOverflow.ellipsis),
                      ],
                      onChanged: (value) => setState(() => _placeId = value),
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
          const SizedBox(height: 14),
        ],
        _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'เลือกหมวดหมู่',
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              // Six across fits the mock's desktop width; on a phone they wrap
              // to three.
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 10.0;
                  final columns = constraints.maxWidth >= 520 ? 6 : 3;
                  final width =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final category in expenseCategoryTiles)
                        SizedBox(
                          width: width,
                          child: _CategoryTile(
                            key: expenseCategoryTileKey(category),
                            category: category,
                            selected: category == _category,
                            onTap: () => setState(() => _category = category),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? colour.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colour : AppColors.chipBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              expenseCategoryIcon(category),
              size: 20,
              color: selected ? colour : AppColors.muted,
            ),
            const SizedBox(height: 7),
            FittedBox(
              child: Text(
                expenseCategoryShortLabel(category),
                style: TextStyle(
                  color: selected ? colour : AppColors.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
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
    this.cancel,
  });

  final String title;
  final List<Widget> children;
  final String action;
  final VoidCallback onAction;
  final bool canAct;

  /// When set, the action sits beside a cancel of equal width, which is what
  /// the expense sheets do.
  final String? cancel;

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
              child: Row(
                children: [
                  if (cancel != null) ...[
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.foreground,
                            side: const BorderSide(color: AppColors.chipBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          child: Text(
                            cancel!,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: canAct ? onAction : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _planGreen,
                          disabledBackgroundColor: const Color(0xFFDCD8D2),
                          disabledForegroundColor: const Color(0xFF8C8880),
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
