import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/post_draft.dart';
import '../../../../shared/extensions/currency_extensions.dart';
import 'composer_sheet.dart';

String _clock(TimeOfDay time) => '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// "06:00 AM", the way the filled row reads it back.
String _clock12(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
}

/// The filled rows under a spot's story: one per detail that has something in
/// it. Tapping a row opens its sheet again.
class PostSpotDetailRows extends StatelessWidget {
  const PostSpotDetailRows({
    super.key,
    required this.details,
    required this.onEdit,
  });

  final PostSpotDetails details;
  final ValueChanged<PostSpotDetail> onEdit;

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (details.hasTime)
          _DetailRow(
            icon: Icons.schedule,
            // With a visit time the hours are the second line; without one
            // they are the row itself, and repeating the label would say the
            // same thing twice.
            title: details.visitedAt == null
                ? 'เวลาเปิด / ปิด'
                : 'เวลาที่ไป ${_clock12(details.visitedAt!)}',
            subtitle: details.visitedAt == null
                ? _hoursRange(details)
                : _hoursLine(details),
            onTap: () => onEdit(PostSpotDetail.time),
          ),
        if (details.hasTransport)
          _DetailRow(
            icon: Icons.directions_bus_filled_outlined,
            title: details.transportModes.isEmpty
                ? 'การเดินทาง'
                : details.transportModes.join(' · '),
            subtitle: details.transportCost == null
                ? null
                : 'ค่ารถ · ${details.transportCost!.asBaht}',
            onTap: () => onEdit(PostSpotDetail.transport),
          ),
        if (details.hasHack)
          _DetailRow(
            icon: Icons.info_outline,
            title: details.tripHack.trim(),
            onTap: () => onEdit(PostSpotDetail.hack),
          ),
      ],
    );
  }

  /// "เวลาเปิด / ปิด · 06.00 - 14.30 น.", or nothing when no hours were given.
  static String? _hoursLine(PostSpotDetails details) {
    final range = _hoursRange(details);
    return range == null ? null : 'เวลาเปิด / ปิด · $range';
  }

  /// Just "06.00 - 14.30 น.".
  static String? _hoursRange(PostSpotDetails details) {
    final opens = details.opensAt;
    final closes = details.closesAt;
    if (opens == null && closes == null) return null;
    final from = opens == null ? '—' : _clock(opens).replaceAll(':', '.');
    final to = closes == null ? '—' : _clock(closes).replaceAll(':', '.');
    return '$from - $to น.';
  }
}

/// Which of the three a row or chip stands for.
enum PostSpotDetail { time, transport, hack }

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: AppColors.postPurple),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recommend Time — either the hour the writer went, or the place's own hours.
Future<PostSpotDetails?> showRecommendTimeSheet(
  BuildContext context, {
  required PostSpotDetails current,
}) {
  return showModalBottomSheet<PostSpotDetails>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecommendTimeSheet(current: current),
  );
}

class _RecommendTimeSheet extends StatefulWidget {
  const _RecommendTimeSheet({required this.current});

  final PostSpotDetails current;

  @override
  State<_RecommendTimeSheet> createState() => _RecommendTimeSheetState();
}

class _RecommendTimeSheetState extends State<_RecommendTimeSheet> {
  late bool _hoursTab = widget.current.visitedAt == null &&
      (widget.current.opensAt != null || widget.current.closesAt != null);

  late TimeOfDay _visited =
      widget.current.visitedAt ?? const TimeOfDay(hour: 6, minute: 0);
  late TimeOfDay _opens =
      widget.current.opensAt ?? const TimeOfDay(hour: 6, minute: 0);
  late TimeOfDay _closes =
      widget.current.closesAt ?? const TimeOfDay(hour: 14, minute: 30);

  /// Which of เปิด / ปิด the wheel is editing.
  bool _editingOpens = true;

  TimeOfDay get _wheelValue =>
      !_hoursTab ? _visited : (_editingOpens ? _opens : _closes);

  void _setWheel(TimeOfDay value) {
    setState(() {
      if (!_hoursTab) {
        _visited = value;
      } else if (_editingOpens) {
        _opens = value;
      } else {
        _closes = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ComposerSheet(
      title: 'Recommend Time',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segmented(
            left: 'เวลาที่ฉันไป',
            right: 'เวลาเปิด - ปิด',
            rightSelected: _hoursTab,
            onChanged: (hours) => setState(() => _hoursTab = hours),
          ),
          if (_hoursTab) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TimeBox(
                    label: 'เปิด',
                    value: _clock(_opens),
                    active: _editingOpens,
                    onTap: () => setState(() => _editingOpens = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeBox(
                    label: 'ปิด',
                    value: _clock(_closes),
                    active: !_editingOpens,
                    onTap: () => setState(() => _editingOpens = false),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child: CupertinoDatePicker(
              key: ValueKey('$_hoursTab-$_editingOpens'),
              mode: CupertinoDatePickerMode.time,
              use24hFormat: true,
              minuteInterval: 1,
              initialDateTime: DateTime(
                2026,
                1,
                1,
                _wheelValue.hour,
                _wheelValue.minute,
              ),
              onDateTimeChanged: (value) => _setWheel(
                TimeOfDay(hour: value.hour, minute: value.minute),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SheetActions(
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: () => Navigator.of(context).pop(
              _hoursTab
                  ? widget.current.copyWith(opensAt: _opens, closesAt: _closes)
                  : widget.current.copyWith(visitedAt: _visited),
            ),
          ),
        ],
      ),
    );
  }
}

/// การเดินทาง — how the writer got there, and what it cost.
Future<PostSpotDetails?> showTransportSheet(
  BuildContext context, {
  required PostSpotDetails current,
}) {
  return showModalBottomSheet<PostSpotDetails>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TransportSheet(current: current),
  );
}

class _TransportSheet extends StatefulWidget {
  const _TransportSheet({required this.current});

  final PostSpotDetails current;

  @override
  State<_TransportSheet> createState() => _TransportSheetState();
}

class _TransportSheetState extends State<_TransportSheet> {
  late final List<String> _chosen = [...widget.current.transportModes];

  /// Anything the traveller typed themselves, kept beside the built-in list.
  late final List<String> _custom = [
    for (final mode in widget.current.transportModes)
      if (!spotTransportModes.contains(mode)) mode,
  ];

  late final TextEditingController _cost = TextEditingController(
    text: widget.current.transportCost == null
        ? ''
        : _plain(widget.current.transportCost!),
  );

  static String _plain(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';

  double? get _typedCost {
    final parsed = double.tryParse(_cost.text.trim().replaceAll(',', ''));
    return parsed != null && parsed > 0 ? parsed : null;
  }

  @override
  void dispose() {
    _cost.dispose();
    super.dispose();
  }

  Future<void> _addCustom() async {
    final added = await showDialog<String>(
      context: context,
      builder: (_) => const _AddModeDialog(),
    );
    final value = added?.trim() ?? '';
    if (value.isEmpty) return;
    setState(() {
      if (!_custom.contains(value) && !spotTransportModes.contains(value)) {
        _custom.add(value);
      }
      if (!_chosen.contains(value)) _chosen.add(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ComposerSheet(
      title: 'การเดินทาง',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetLabel('รูปแบบการเดินทาง'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in [...spotTransportModes, ..._custom])
                  _ModeChip(
                    label: mode,
                    selected: _chosen.contains(mode),
                    onTap: () => setState(() => _chosen.contains(mode)
                        ? _chosen.remove(mode)
                        : _chosen.add(mode)),
                  ),
                _ModeChip(label: '+ เพิ่ม', accent: true, onTap: _addCustom),
              ],
            ),
            const SizedBox(height: 18),
            const _SheetLabel('ค่าเดินทาง / ค่าน้ำมัน'),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: AppColors.screen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cost,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '0',
                        hintStyle: TextStyle(color: AppColors.postFieldHint),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Baht only: the section has no currency of its own, and a
                  // picker over one option is a lie about what is stored.
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: const Text(
                      'THB',
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SheetActions(
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: () => Navigator.of(context).pop(
                widget.current.copyWith(
                  transportModes: List<String>.unmodifiable(_chosen),
                  transportCost: _typedCost,
                  clearTransportCost: _typedCost == null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trip Hack — the one thing the writer wishes they had been told.
Future<PostSpotDetails?> showTripHackSheet(
  BuildContext context, {
  required PostSpotDetails current,
}) {
  return showModalBottomSheet<PostSpotDetails>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TripHackSheet(current: current),
  );
}

class _TripHackSheet extends StatefulWidget {
  const _TripHackSheet({required this.current});

  final PostSpotDetails current;

  @override
  State<_TripHackSheet> createState() => _TripHackSheetState();
}

class _TripHackSheetState extends State<_TripHackSheet> {
  late final TextEditingController _text =
      TextEditingController(text: widget.current.tripHack);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ComposerSheet(
      title: 'Trip Hack',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              'ทริคในการเที่ยวที่อยากแบ่งปันให้นักเดินทางคนอื่น',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          Container(
            height: 118,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.screen,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: TextField(
              controller: _text,
              maxLines: null,
              expands: true,
              autofocus: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'เช่น ไปเช้าคนน้อย ไม่ต้องรอคิว',
                hintStyle: TextStyle(color: AppColors.postFieldHint),
              ),
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
          ),
          const SizedBox(height: 20),
          _SheetActions(
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: () => Navigator.of(context).pop(
              widget.current.copyWith(tripHack: _text.text.trim()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two tabs in one pill, the way Recommend Time splits its job.
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.left,
    required this.right,
    required this.rightSelected,
    required this.onChanged,
  });

  final String left;
  final String right;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.postField,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          Expanded(child: _tab(left, !rightSelected, () => onChanged(false))),
          Expanded(child: _tab(right, rightSelected, () => onChanged(true))),
        ],
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.sheetConfirm : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.foreground : AppColors.line,
            width: active ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.accent = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final on = selected || accent;

    return Material(
      color: selected ? AppColors.postPurpleSoft : AppColors.screen,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: on ? AppColors.postPurple : AppColors.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? AppColors.postPurple : AppColors.foreground,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Owns its controller so the field survives the dialog's exit animation.
class _AddModeDialog extends StatefulWidget {
  const _AddModeDialog();

  @override
  State<_AddModeDialog> createState() => _AddModeDialogState();
}

class _AddModeDialogState extends State<_AddModeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เพิ่มรูปแบบการเดินทาง'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'เช่น สองแถว'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('เพิ่ม'),
        ),
      ],
    );
  }
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({required this.onCancel, required this.onConfirm});

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              child: const Text(
                'ยกเลิก',
                style: TextStyle(
                  color: AppColors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sheetConfirm,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              child: const Text(
                'ตกลง',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
