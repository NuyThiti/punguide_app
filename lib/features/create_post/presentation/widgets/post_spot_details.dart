import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/post_draft.dart';
import 'composer_sheet.dart';
import '../../../../shared/formatting/spot_detail_text.dart';

String _clock(TimeOfDay time) => '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// "06:00 AM", the way the filled row reads it back.
String _clock12(TimeOfDay time) => clock12Text(_clock(time));

/// The filled details under a spot's story, on one line.
///
/// Compact on purpose: these are notes beside the story, not the story — three
/// stacked two-line rows pushed the spot's own words off the screen. Tapping
/// one reopens its sheet.
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        // Every chip yields rather than only the last one: any of the three can
        // be long, and a chip that cannot shrink pushes the others off the
        // line instead of ellipsising its own text.
        children: [
          if (details.hasTime) ...[
            Flexible(
              child: _DetailChip(
                icon: Icons.schedule,
                text: _timeText(details),
                onTap: () => onEdit(PostSpotDetail.time),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (details.hasTransport) ...[
            Flexible(
              child: _DetailChip(
                icon: Icons.directions_bus_filled_outlined,
                text: _transportText(details),
                onTap: () => onEdit(PostSpotDetail.transport),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (details.hasContact) ...[
            Flexible(
              child: _DetailChip(
                icon: Icons.call_outlined,
                text: details.contactInfo.trim(),
                onTap: () => onEdit(PostSpotDetail.contact),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (details.hasHack)
            Flexible(
              child: _DetailChip(
                icon: Icons.info_outline,
                text: details.tripHack.trim(),
                onTap: () => onEdit(PostSpotDetail.hack),
              ),
            ),
        ],
      ),
    );
  }

  /// "6:00 AM", or the opening hours when that is all there is.
  static String _timeText(PostSpotDetails details) {
    final visited = details.visitedAt;
    if (visited != null) return _clock12(visited);
    return _hoursRange(details) ?? '';
  }

  /// "MRT · เดิน ฿100", dropping whichever half is missing.
  static String _transportText(PostSpotDetails details) =>
      transportText(details.transportModes, details.transportCost);

  /// "06.00 - 14.30 น.", or null when no hours were given.
  ///
  /// Shared with the viewer through the wire's `HH:mm`, so a spot reads the
  /// same in the composer and in the post.
  static String? _hoursRange(PostSpotDetails details) => hoursRangeText(
        details.opensAt == null ? null : _clock(details.opensAt!),
        details.closesAt == null ? null : _clock(details.closesAt!),
      );
}

/// Which of the three a row or chip stands for.
enum PostSpotDetail { time, transport, hack, contact }

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.postPurpleSoft,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.postPurple),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.postPurple,
                  fontSize: 11,
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

/// Which the Recommend Time sheet is showing.
enum _TimeMode { visited, manual, google }

/// Recommend Time — the hour the writer went, hours typed by hand, or (when
/// the spot is pinned to a real place) the place's own Google hours, offered
/// as a third, non-default way in rather than replacing the other two.
Future<PostSpotDetails?> showRecommendTimeSheet(
  BuildContext context, {
  required PostSpotDetails current,
  String? placeId,
}) {
  return showModalBottomSheet<PostSpotDetails>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecommendTimeSheet(current: current, placeId: placeId),
  );
}

class _RecommendTimeSheet extends ConsumerStatefulWidget {
  const _RecommendTimeSheet({required this.current, this.placeId});

  final PostSpotDetails current;
  final String? placeId;

  @override
  ConsumerState<_RecommendTimeSheet> createState() =>
      _RecommendTimeSheetState();
}

class _RecommendTimeSheetState extends ConsumerState<_RecommendTimeSheet> {
  late _TimeMode _mode = widget.current.visitedAt == null &&
          (widget.current.opensAt != null || widget.current.closesAt != null)
      ? _TimeMode.manual
      : _TimeMode.visited;

  late TimeOfDay _visited =
      widget.current.visitedAt ?? const TimeOfDay(hour: 6, minute: 0);
  late TimeOfDay _opens =
      widget.current.opensAt ?? const TimeOfDay(hour: 6, minute: 0);
  late TimeOfDay _closes =
      widget.current.closesAt ?? const TimeOfDay(hour: 14, minute: 30);

  /// Which of เปิด / ปิด the wheel is editing.
  bool _editingOpens = true;

  /// Which weekday the google tab is reading its pair off — `0` is Monday,
  /// same order Google's own `weekdayDescriptions` comes in. Null until the
  /// traveller has either opened that tab or picked a day of their own; while
  /// null the tab defaults to today.
  int? _googleDay;

  TimeOfDay get _wheelValue =>
      _mode == _TimeMode.visited ? _visited : (_editingOpens ? _opens : _closes);

  void _setWheel(TimeOfDay value) {
    setState(() {
      if (_mode == _TimeMode.visited) {
        _visited = value;
      } else if (_editingOpens) {
        _opens = value;
      } else {
        _closes = value;
      }
    });
  }

  TimeOfDay _parseClock(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    final placeId = widget.placeId;
    final hasPlace = placeId != null && placeId.isNotEmpty;
    final asyncDetails =
        hasPlace ? ref.watch(placeDetailsProvider(placeId)) : null;

    final details = asyncDetails?.valueOrNull;
    final googleHours =
        details?.currentOpeningHours ?? details?.regularOpeningHours;
    final googleDays = googleHours?.weekdayDescriptions ?? const <String>[];
    // Nothing to offer at all: Google simply has no hours for this place, so
    // the tab itself stays off rather than opening onto an empty promise.
    final hasGoogleHours = googleDays.length == 7;

    final selectedDay = _googleDay ?? (DateTime.now().weekday - 1);
    final googleLinePair =
        hasGoogleHours ? openCloseFromLine(googleDays[selectedDay]) : null;
    final googlePair = googleLinePair == null
        ? null
        : (_parseClock(googleLinePair.$1), _parseClock(googleLinePair.$2));

    return ComposerSheet(
      title: 'Recommend Time',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeTabs(
            mode: _mode,
            showGoogle: hasGoogleHours,
            onChanged: (mode) => setState(() => _mode = mode),
          ),
          if (_mode == _TimeMode.manual) ...[
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
          if (_mode == _TimeMode.google) ...[
            const SizedBox(height: 16),
            _GoogleHours(
              days: googleDays,
              openNow: googleHours?.openNow,
              selected: selectedDay,
              onSelect: (day) => setState(() => _googleDay = day),
            ),
          ] else ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 190,
              child: CupertinoDatePicker(
                key: ValueKey('$_mode-$_editingOpens'),
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
          ],
          const SizedBox(height: 12),
          _SheetActions(
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: switch (_mode) {
              _TimeMode.visited => () => Navigator.of(context)
                  .pop(widget.current.copyWith(visitedAt: _visited)),
              _TimeMode.manual => () => Navigator.of(context).pop(
                  widget.current.copyWith(opensAt: _opens, closesAt: _closes)),
              _TimeMode.google => googlePair == null
                  ? null
                  : () => Navigator.of(context).pop(widget.current.copyWith(
                      opensAt: googlePair.$1, closesAt: googlePair.$2)),
            },
          ),
        ],
      ),
    );
  }
}

/// The weekly hours Google has for a pinned place — each day tappable, so a
/// line other than today's can be the one ตกลง actually writes.
class _GoogleHours extends StatelessWidget {
  const _GoogleHours({
    required this.days,
    required this.openNow,
    required this.selected,
    required this.onSelect,
  });

  final List<String> days;
  final bool? openNow;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (openNow != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.postPurpleSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  openNow! ? 'เปิดอยู่ตอนนี้' : 'ปิดแล้วตอนนี้',
                  style: const TextStyle(
                    color: AppColors.postPurple,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        Container(
          constraints: const BoxConstraints(maxHeight: 170),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.screen,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < days.length; i++)
                  _DayRow(
                    text: days[i],
                    selected: i == selected,
                    onTap: () => onSelect(i),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.postPurpleSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: selected ? AppColors.postPurple : AppColors.muted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
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

/// ติดต่อ — one line, as the writer wants to give it.
Future<PostSpotDetails?> showContactSheet(
  BuildContext context, {
  required PostSpotDetails current,
}) {
  return showModalBottomSheet<PostSpotDetails>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContactSheet(current: current),
  );
}

class _ContactSheet extends StatefulWidget {
  const _ContactSheet({required this.current});

  final PostSpotDetails current;

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  late final TextEditingController _phone;
  late final TextEditingController _website;

  @override
  void initState() {
    super.initState();
    final (phone, website) = _splitContactInfo(widget.current.contactInfo);
    _phone = TextEditingController(text: phone);
    _website = TextEditingController(text: website);
  }

  /// Reverses `_contactInfoText`'s own `' · '` join — the same separator the
  /// AI assistant's suggestion already combines a phone and a website with,
  /// so a spot it filled in reopens with each half in its own field. A
  /// single segment with no separator (older freeform text, or the
  /// assistant's phone-only answer) goes to whichever field it reads like —
  /// a website if it looks like one, the phone field otherwise, so nothing
  /// ever silently disappears.
  static (String, String) _splitContactInfo(String raw) {
    final parts = raw
        .split(' · ')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return ('', '');
    if (parts.length == 1) {
      final only = parts.first;
      final looksLikeWebsite = only.startsWith('http://') ||
          only.startsWith('https://') ||
          only.startsWith('www.');
      return looksLikeWebsite ? ('', only) : (only, '');
    }
    return (parts.first, parts.skip(1).join(' · '));
  }

  @override
  void dispose() {
    _phone.dispose();
    _website.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ComposerSheet(
      title: 'Contact',
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ContactField(
            label: 'เบอร์ติดต่อ',
            icon: Icons.call_outlined,
            controller: _phone,
            hintText: '085 809 0835',
            keyboardType: TextInputType.phone,
            autofocus: true,
          ),
          const SizedBox(height: 14),
          _ContactField(
            label: 'เว็บไซต์',
            icon: Icons.link,
            controller: _website,
            hintText: 'https://...',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 20),
          _SheetActions(
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: () => Navigator.of(context).pop(
              widget.current.copyWith(
                contactInfo: [
                  if (_phone.text.trim().isNotEmpty) _phone.text.trim(),
                  if (_website.text.trim().isNotEmpty) _website.text.trim(),
                ].join(' · '),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactField extends StatelessWidget {
  const _ContactField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.autofocus = false,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetLabel(label),
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
              Icon(icon, size: 18, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: autofocus,
                  keyboardType: keyboardType,
                  maxLength: 240,
                  decoration: InputDecoration(
                    counterText: '',
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: const TextStyle(color: AppColors.postFieldHint),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Two tabs in one pill, the way Recommend Time splits its job.
/// Two or three tabs in one pill, the way Recommend Time splits its job — a
/// third, "ตามเวลาเปิดจริง" tab joins the other two only once the spot is
/// pinned to a place Google might know the hours of.
class _ModeTabs extends StatelessWidget {
  const _ModeTabs({
    required this.mode,
    required this.showGoogle,
    required this.onChanged,
  });

  final _TimeMode mode;
  final bool showGoogle;
  final ValueChanged<_TimeMode> onChanged;

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
          Expanded(
            child: _tab('เวลาที่ฉันไป', mode == _TimeMode.visited,
                () => onChanged(_TimeMode.visited)),
          ),
          Expanded(
            child: _tab('เวลาเปิด - ปิด', mode == _TimeMode.manual,
                () => onChanged(_TimeMode.manual)),
          ),
          if (showGoogle)
            Expanded(
              child: _tab('ตามเวลาเปิดจริง', mode == _TimeMode.google,
                  () => onChanged(_TimeMode.google)),
            ),
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

  /// Null disables ตกลง — the Google-hours tab with nothing yet to apply.
  final VoidCallback? onConfirm;

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
