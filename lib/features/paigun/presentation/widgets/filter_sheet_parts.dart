import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../create_trip/domain/plan_labels.dart';
import '../../domain/trip_filter.dart';
import '../providers/paigun_providers.dart';

/// The pill at the top of the sheet that says it can be dragged.
class FilterGrabber extends StatelessWidget {
  const FilterGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 5,
      decoration: BoxDecoration(
        color: AppColors.filterGrabber,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

/// One question: its heading, its answers, and the rule under it.
class FilterSection extends StatelessWidget {
  const FilterSection({
    super.key,
    required this.title,
    required this.child,
    this.showDivider = true,
  });

  final String title;
  final Widget child;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        child,
        if (showDivider) ...[
          const SizedBox(height: 18),
          const Divider(height: 1, thickness: 1, color: AppColors.line),
        ],
      ],
    );
  }
}

/// รูปแบบโพสที่จะเห็น — the board's own chip row, asked here as a question.
class FilterTypeChips extends StatelessWidget {
  const FilterTypeChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final PaigunFilter selected;
  final ValueChanged<PaigunFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final filter in PaigunFilter.values)
          FilterPillChip(
            label: filter.label,
            selected: filter == selected,
            onTap: () => onSelected(filter),
          ),
      ],
    );
  }
}

/// The rounded chip every answer on this sheet is made of: outlined while
/// untouched, peach once chosen.
class FilterPillChip extends StatelessWidget {
  const FilterPillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// A style chip's glyph. Recoloured to match the chip's state, so one asset
  /// serves both.
  final Widget Function(Color color)? icon;

  /// "+ เพิ่ม", which is an action rather than an answer: coral outline and
  /// coral text, never filled.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final foreground = outlined
        ? AppColors.filterAction
        : selected
            ? AppColors.filterAction
            : AppColors.foreground;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected && !outlined ? AppColors.filterChipOn : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected || outlined
                ? AppColors.filterAction.withValues(alpha: outlined ? 1 : 0)
                : AppColors.chipBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon!(foreground),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// วันที่เดินทาง — two wells that open one range picker between them.
class FilterDateRow extends StatelessWidget {
  const FilterDateRow({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onPick,
  });

  final DateTime? startDate;
  final DateTime? endDate;

  /// A null start clears the answer.
  final void Function(DateTime? start, DateTime? end) onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DateWell(
            hint: 'วันที่เริ่ม',
            value: startDate,
            onTap: () => _pick(context),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '—',
            style: TextStyle(color: AppColors.muted, fontSize: 15),
          ),
        ),
        Expanded(
          child: _DateWell(
            hint: 'วันที่สิ้นสุด',
            value: endDate,
            onTap: () => _pick(context),
          ),
        ),
      ],
    );
  }

  /// One picker for both wells: the answer is a window, and picking its ends
  /// separately lets a traveller leave it half-drawn or inside out.
  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, now.month, now.day),
      initialDateRange: startDate == null
          ? null
          : DateTimeRange(start: startDate!, end: endDate ?? startDate!),
      helpText: 'วันที่เดินทาง',
    );
    if (picked != null) onPick(picked.start, picked.end);
  }
}

class _DateWell extends StatelessWidget {
  const _DateWell({required this.hint, required this.value, required this.onTap});

  final String hint;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = value != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.chipBorder),
        ),
        child: Text(
          filled ? _thaiDate(value!) : hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: filled ? AppColors.foreground : AppColors.postFieldHint,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// "28 ก.ย. 69" — short enough for a well half the sheet wide.
String _thaiDate(DateTime date) {
  const months = <String>[
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];
  // Buddhist era, two digits, as every other date on the app reads.
  final year = (date.year + 543) % 100;
  return '${date.day} ${months[date.month - 1]} '
      '${year.toString().padLeft(2, '0')}';
}

/// ผู้ใหญ่ / เด็ก — a label, what it means, and the two buttons that change it.
class FilterCounterRow extends StatelessWidget {
  const FilterCounterRow({
    super.key,
    required this.label,
    required this.caption,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String caption;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        _StepperButton(
          icon: Icons.remove,
          // Nobody is the floor, and the control says so rather than letting a
          // dead tap look broken.
          enabled: value > 0,
          filled: false,
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: value > 0 ? AppColors.foreground : AppColors.muted,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add,
          enabled: true,
          filled: true,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: filled ? AppColors.paigunControl : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: filled ? AppColors.paigunControl : AppColors.chipBorder,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: filled
              ? Colors.white
              : enabled
                  ? AppColors.foreground
                  : AppColors.postFieldHint,
        ),
      ),
    );
  }
}

/// งบประมาณต่อคน — ฿0 to ฿10,000+, where both ends mean "do not narrow by
/// budget".
class FilterBudgetSlider extends StatelessWidget {
  const FilterBudgetSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double? value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final amount = (value ?? 0).clamp(0, TripFilter.budgetCeiling).toDouble();
    final atCeiling = amount >= TripFilter.budgetCeiling;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '฿${_grouped(amount)}',
              style: TextStyle(
                color: amount > 0 ? AppColors.filterAction : AppColors.muted,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '฿${_grouped(TripFilter.budgetCeiling)}+',
              style: TextStyle(
                color: atCeiling ? AppColors.filterAction : AppColors.muted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: AppColors.filterAction,
            inactiveTrackColor: AppColors.line,
            thumbColor: Colors.white,
            overlayColor: AppColors.filterAction.withValues(alpha: 0.12),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 11,
              elevation: 2,
            ),
          ),
          child: Slider(
            value: amount,
            max: TripFilter.budgetCeiling,
            // ฿500 steps: the figure is a ceiling to browse by, not a price.
            divisions: 20,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

String _grouped(double value) {
  final whole = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    buffer.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

/// รัศมีสถานที่ห่างจากฉัน — type a figure, or take one of the presets.
class FilterRadiusPicker extends StatelessWidget {
  const FilterRadiusPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double? value;

  /// Null is ไม่จำกัด.
  final ValueChanged<double?> onChanged;

  static const _presets = <double>[5, 10, 25, 50, 100];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RadiusField(value: value, onChanged: onChanged),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final preset in _presets)
              FilterPillChip(
                label: '${preset.round()} Km.',
                selected: value == preset,
                onTap: () => onChanged(value == preset ? null : preset),
              ),
            FilterPillChip(
              label: 'ไม่จำกัด',
              selected: value == null,
              onTap: () => onChanged(null),
            ),
          ],
        ),
      ],
    );
  }
}

class _RadiusField extends StatefulWidget {
  const _RadiusField({required this.value, required this.onChanged});

  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  State<_RadiusField> createState() => _RadiusFieldState();
}

class _RadiusFieldState extends State<_RadiusField> {
  late final TextEditingController _controller =
      TextEditingController(text: _textOf(widget.value));

  @override
  void didUpdateWidget(_RadiusField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A preset chip writes through to the field; typing must not be fought.
    final text = _textOf(widget.value);
    if (widget.value != oldWidget.value && text != _controller.text) {
      _controller.text = text;
    }
  }

  static String _textOf(double? value) =>
      value == null ? '' : value.round().toString();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (text) {
          final parsed = double.tryParse(text.trim());
          widget.onChanged(parsed != null && parsed > 0 ? parsed : null);
        },
        style: const TextStyle(
          color: AppColors.foreground,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: 'รัศมีสถานที่ห่าง',
          hintStyle: TextStyle(
            color: AppColors.postFieldHint,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// สไตล์การเที่ยว — the same labels the create wizard collects a brief with,
/// asked here as a filter.
class FilterStyleChips extends StatelessWidget {
  const FilterStyleChips({
    super.key,
    required this.selected,
    required this.onTapped,
    this.onAddMore,
  });

  final List<String> selected;
  final ValueChanged<String> onTapped;

  /// "+ เพิ่ม". The design shows the chip but defines nothing behind it, so it
  /// is inert until that flow exists — same as the create wizard's.
  final VoidCallback? onAddMore;

  /// The order the design lays them out in, which is not the order the labels
  /// are declared in.
  static const _order = <String>[
    'ธรรมชาติ',
    'คาเฟ่',
    'วัฒนธรรม',
    'อาหาร',
    'ทะเล',
    'ภูเขา',
    'เข้าถึงท้องถิ่น',
    'ไนท์ไลฟ์',
    'ช้อปปิ้ง',
    'ผจญภัย',
  ];

  /// One SVG per style, named for the wire value so the two cannot drift.
  ///
  /// ผจญภัย has no asset yet — the one handed over for it is the compass's
  /// outer ring with no needle, which reads as a plain circle — so it falls
  /// back to a Material compass rather than going bare.
  static const _fallbackIcons = <String, IconData>{
    'ผจญภัย': Icons.explore_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final label in _order)
          FilterPillChip(
            label: label,
            selected: selected.contains(label),
            onTap: () => onTapped(label),
            icon: (color) => _glyph(label, color),
          ),
        FilterPillChip(
          label: '+ เพิ่ม',
          selected: false,
          outlined: true,
          onTap: onAddMore ?? () {},
        ),
      ],
    );
  }

  Widget _glyph(String label, Color color) {
    final fallback = _fallbackIcons[label];
    if (fallback != null) return Icon(fallback, size: 17, color: color);

    final style = styleByLabel[label];
    return SvgPicture.asset(
      'assets/icons/styles/${style!.wire}.svg',
      width: 17,
      height: 17,
      // The assets ship in two different palettes; the chip decides the colour.
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

/// The ตกลง bar pinned to the foot of the sheet.
class FilterApplyBar extends StatelessWidget {
  const FilterApplyBar({super.key, required this.onApply});

  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: GestureDetector(
          onTap: onApply,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.paigunControl,
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text(
              'ตกลง',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
