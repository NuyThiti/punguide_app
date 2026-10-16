import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/plan_labels.dart';

const _green = Color(0xFF2E6B4C);
const _cream = Color(0xFFF7F1E7);
const _chipBorder = Color(0xFFE6DCC8);

/// One end of the leg, as the route banner names it.
class LegEnd {
  const LegEnd({required this.position, required this.name});

  final int position;
  final String name;
}

/// The chips in the design's order. `other` is the "+ เพิ่มเติม" chip, which
/// carries the traveller's own word in `travelCustomTypeFromPrev`.
const travelTypeChips = <TravelType>[
  TravelType.walk,
  TravelType.bicycle,
  TravelType.tukTuk,
  TravelType.privateTransfer,
  TravelType.rentalCar,
  TravelType.boat,
  TravelType.train,
  TravelType.airplane,
];

/// A chip, for tests: several labels also print on the leg rows behind.
Key travelTypeChipKey(TravelType type) => ValueKey('travel-type-${type.wire}');

/// เพิ่มการเดินทาง — how the traveller gets to [to] from [from].
///
/// A leg has no row of its own: it is stored on the stop it arrives at, in
/// the `travel*FromPrev` columns, so saving is a `PATCH /items/:id` on [to].
/// [emptyLegs] are the other stops on the day whose leg is still blank —
/// what "ใช้กับทุกช่วงที่ว่าง" fills in. Returns true when anything was saved.
Future<bool> showTravelLegSheet(
  BuildContext context, {
  required String tripId,
  required LegEnd from,
  required LegEnd to,
  required Activity arriving,
  List<Activity> emptyLegs = const <Activity>[],
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    builder: (_) => TravelLegSheet(
      tripId: tripId,
      from: from,
      to: to,
      arriving: arriving,
      emptyLegs: emptyLegs,
    ),
  );
  return saved ?? false;
}

class TravelLegSheet extends ConsumerStatefulWidget {
  const TravelLegSheet({
    super.key,
    required this.tripId,
    required this.from,
    required this.to,
    required this.arriving,
    required this.emptyLegs,
  });

  final String tripId;
  final LegEnd from;
  final LegEnd to;
  final Activity arriving;
  final List<Activity> emptyLegs;

  @override
  ConsumerState<TravelLegSheet> createState() => _TravelLegSheetState();
}

enum _Unit { min, hr }

class _TravelLegSheetState extends ConsumerState<TravelLegSheet> {
  final _timeController = TextEditingController();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();
  final _customController = TextEditingController();

  TravelType? _type;
  _Unit _unit = _Unit.min;
  String _currency = 'THB';
  bool _saving = false;

  bool get _isEditing => widget.arriving.travelFromPrevious != null;

  @override
  void initState() {
    super.initState();
    final leg = widget.arriving.travelFromPrevious;
    if (leg != null) {
      _type = leg.type;
      _customController.text = leg.customType ?? '';
      if (leg.customType != null && leg.customType!.isNotEmpty) {
        _type = TravelType.other;
      }
      final minutes = leg.durationMin;
      if (minutes != null && minutes > 0) {
        if (minutes >= 60 && minutes % 60 == 0) {
          _unit = _Unit.hr;
          _timeController.text = '${minutes ~/ 60}';
        } else {
          _timeController.text = '$minutes';
        }
      }
      final cost = leg.costAmount;
      if (cost != null && cost > 0) {
        _costController.text = cost == cost.roundToDouble()
            ? cost.round().toString()
            : cost.toStringAsFixed(2);
      }
      _currency = leg.costCurrency ?? 'THB';
      _notesController.text = leg.notes ?? '';
    }
  }

  @override
  void dispose() {
    _timeController.dispose();
    _costController.dispose();
    _notesController.dispose();
    _customController.dispose();
    super.dispose();
  }

  /// A leg is a way of getting there; without one there is nothing to save.
  bool get _canSave {
    if (_saving || _type == null) return false;
    if (_type == TravelType.other) {
      return _customController.text.trim().isNotEmpty;
    }
    return true;
  }

  int? get _minutes {
    final value = double.tryParse(_timeController.text.trim());
    if (value == null || value <= 0) return null;
    return (_unit == _Unit.hr ? value * 60 : value).round();
  }

  double? get _cost {
    final value =
        double.tryParse(_costController.text.trim().replaceAll(',', ''));
    return value != null && value > 0 ? value : null;
  }

  String? get _notes {
    final text = _notesController.text.trim();
    return text.isEmpty ? null : text;
  }

  String? get _customType {
    if (_type != TravelType.other) return null;
    final text = _customController.text.trim();
    return text.isEmpty ? null : text;
  }

  /// Every field goes up every time: a blank one is a clear, so editing a leg
  /// down to nothing really empties it rather than leaving the old value.
  Future<void> _write(PlunoApi api, String itemId) {
    Patch<T> p<T>(T? value) =>
        value == null ? Patch<T>.clear() : Patch<T>.value(value);
    final cost = _cost;
    return api.itinerary.updateItem(
      itemId,
      travelTypeFromPrev: p(_type),
      travelCustomTypeFromPrev: p(_customType),
      travelTimeFromPrevMin: p(_minutes),
      travelCostFromPrevAmount: p(cost),
      travelCostFromPrevCurrency: p(cost == null ? null : _currency),
      travelNotesFromPrev: p(_notes),
      // The measured route does not depend on how the traveller describes
      // the leg, so there is nothing for the server to recalculate.
      calculateTravelSegments: false,
    );
  }

  Future<void> _save({required bool toAllEmpty}) async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final api = await ref.read(plunoApiProvider.future);
      await _write(api, widget.arriving.id);
      if (toAllEmpty) {
        for (final stop in widget.emptyLegs) {
          if (stop.id == widget.arriving.id) continue;
          await _write(api, stop.id);
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (failure) {
      _fail(failure.isUnauthorized
          ? 'เข้าสู่ระบบก่อนบันทึกการเดินทาง'
          : 'บันทึกไม่สำเร็จ: ${failure.message}');
    } catch (error) {
      _fail('บันทึกไม่สำเร็จ: $error');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final others =
        widget.emptyLegs.where((s) => s.id != widget.arriving.id).length;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RouteBanner(from: widget.from, to: widget.to),
                    const SizedBox(height: 18),
                    _typeChips(),
                    if (_type == TravelType.other) ...[
                      const SizedBox(height: 10),
                      _box(
                        child: TextField(
                          controller: _customController,
                          autofocus: _customController.text.isEmpty,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'เช่น สองแถว, มอเตอร์ไซค์รับจ้าง',
                          ),
                          style: _fieldStyle,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    // Two-up as in the design; a phone still fits the pair.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _timeField()),
                        const SizedBox(width: 12),
                        Expanded(child: _costField()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _Label('โน้ต (ไม่บังคับ)'),
                    _box(
                      child: TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'โน้ต (ไม่บังคับ)',
                        ),
                        style: _fieldStyle,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _BudgetNote(),
                  ],
                ),
              ),
            ),
            _bottomBar(others),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isEditing ? 'แก้ไขการเดินทาง' : 'เพิ่มการเดินทาง',
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Tooltip(
                message: 'ปิด',
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1EFEC),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 19, color: Color(0xFF6C6862)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.line),
        ],
      ),
    );
  }

  Widget _typeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: [
        for (final type in travelTypeChips)
          _TypeChip(
            key: travelTypeChipKey(type),
            label: travelTypeLabels[type]!,
            selected: _type == type,
            onTap: () => setState(
              () => _type = _type == type ? null : type,
            ),
          ),
        _TypeChip(
          key: travelTypeChipKey(TravelType.other),
          label: 'เพิ่มเติม',
          icon: Icons.add,
          accent: true,
          selected: _type == TravelType.other,
          onTap: () => setState(() =>
              _type = _type == TravelType.other ? null : TravelType.other),
        ),
      ],
    );
  }

  Widget _timeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('ใช้เวลา (ประเมินคร่าวๆได้)'),
        _box(
          padding: const EdgeInsets.only(left: 12, right: 6),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 18, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _timeController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '0',
                  ),
                  style: _fieldStyle,
                ),
              ),
              _UnitPicker<_Unit>(
                value: _unit,
                items: const {_Unit.min: 'Min', _Unit.hr: 'Hr'},
                onChanged: (value) => setState(() => _unit = value),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _costField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('ค่าเดินทาง / ค่าน้ำมัน'),
        _box(
          padding: const EdgeInsets.only(left: 14, right: 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _costController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '0',
                  ),
                  style: _fieldStyle,
                ),
              ),
              _UnitPicker<String>(
                value: _currency,
                items: const {
                  'THB': 'THB',
                  'USD': 'USD',
                  'LAK': 'LAK',
                  'VND': 'VND',
                },
                onChanged: (value) => setState(() => _currency = value),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bottomBar(int others) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              // Only worth offering when there is another blank leg to fill.
              onPressed:
                  _canSave && others > 0 ? () => _save(toAllEmpty: true) : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: AppColors.foreground,
                side: const BorderSide(color: _chipBorder, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                others > 0
                    ? 'ใช้กับทุกช่วงที่ว่าง ($others)'
                    : 'ใช้กับทุกช่วงที่ว่าง',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _canSave ? () => _save(toAllEmpty: false) : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: _green,
                disabledBackgroundColor: const Color(0xFFE4E1DC),
                disabledForegroundColor: const Color(0xFF9E9A94),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'บันทึก',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static const _fieldStyle =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

  Widget _box({required Widget child, EdgeInsets? padding}) {
    return Container(
      height: 48,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _chipBorder),
      ),
      child: child,
    );
  }
}

/// "1 จาก สนามบินหลวงพระบาง → 2 Manda de Laos".
class _RouteBanner extends StatelessWidget {
  const _RouteBanner({required this.from, required this.to});

  final LegEnd from;
  final LegEnd to;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(12),
      ),
      // Wraps rather than truncating: both names matter, and long ones are
      // common.
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          _Badge(from.position),
          Text('จาก ${from.name}', style: _bannerStyle),
          const Icon(Icons.arrow_forward,
              size: 16, color: AppColors.foreground),
          _Badge(to.position),
          Text(to.name, style: _bannerStyle),
        ],
      ),
    );
  }

  static const _bannerStyle = TextStyle(
    color: AppColors.foreground,
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.accent = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// The "+ เพิ่มเติม" chip is orange even when not picked.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final orange = AppColors.brandOrange;
    final Color fg = selected
        ? (accent ? orange : _green)
        : (accent ? orange : AppColors.foreground);
    final Color border = selected
        ? (accent ? orange : _green)
        : (accent ? orange.withValues(alpha: 0.6) : _chipBorder);
    final Color bg = selected
        ? (accent
            ? orange.withValues(alpha: 0.10)
            : _green.withValues(alpha: 0.08))
        : Colors.white;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: border, width: selected ? 1.5 : 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 14,
                fontWeight:
                    selected || accent ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitPicker<T> extends StatelessWidget {
  const _UnitPicker({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 8, right: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4F0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _chipBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final entry in items.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (picked) {
            if (picked != null) onChanged(picked);
          },
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BudgetNote extends StatelessWidget {
  const _BudgetNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2EC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 16, color: _green),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'ค่าเดินทางจะแสดงที่หน้า สรุปงบ หมวด "ค่าเดินทาง"',
              style: TextStyle(
                color: _green,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
