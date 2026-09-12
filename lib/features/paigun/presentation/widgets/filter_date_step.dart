import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/trip_filter.dart';
import 'filter_chrome.dart';

/// วันที่ฉันจะไปเที่ยว — the wizard's first question, in either of its two
/// moods: exact days off a calendar, or a length with no dates behind it.
///
/// The parent owns every answer so the summary in the action bar can read them;
/// this widget owns only the wheel's scroll position.
class FilterDateStep extends StatefulWidget {
  const FilterDateStep({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.days,
    required this.onDaysChanged,
    required this.start,
    required this.end,
    required this.onDayTapped,
  });

  final FilterDateMode mode;
  final ValueChanged<FilterDateMode> onModeChanged;

  /// The Flexible wheel's length. Null before it is touched, which still shows
  /// [defaultDays] under the marker — a wheel has to point at something.
  final int? days;
  final ValueChanged<int> onDaysChanged;

  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime> onDayTapped;

  /// Where the wheel rests before anything is chosen.
  static const int defaultDays = 3;

  /// The longest trip the wheel offers.
  static const int maxDays = 30;

  /// How far ahead the calendar runs. A year is deeper than anyone plans a
  /// weekend, and it all builds inside the page's own scroll view.
  static const int monthsAhead = 12;

  @override
  State<FilterDateStep> createState() => _FilterDateStepState();
}

class _FilterDateStepState extends State<FilterDateStep> {
  late final FixedExtentScrollController _wheel;

  /// Midnight today: everything before it is unpickable.
  late final DateTime _today;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _wheel = FixedExtentScrollController(initialItem: _wheelIndex);
  }

  @override
  void didUpdateWidget(FilterDateStep old) {
    super.didUpdateWidget(old);
    // A tap on จำนวนวันยอดนิยม changes the answer from outside the wheel; the
    // wheel has to follow it. Guarded, or the wheel's own scroll would chase
    // itself.
    if (_wheel.hasClients && _wheel.selectedItem != _wheelIndex) {
      _wheel.animateToItem(
        _wheelIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _wheel.dispose();
    super.dispose();
  }

  int get _wheelIndex => (widget.days ?? FilterDateStep.defaultDays) - 1;

  @override
  Widget build(BuildContext context) {
    final flexible = widget.mode == FilterDateMode.flexible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModeToggle(mode: widget.mode, onChanged: widget.onModeChanged),
        const SizedBox(height: 22),
        if (flexible) ..._flexible() else ..._calendar(),
      ],
    );
  }

  List<Widget> _flexible() {
    return [
      const FilterGroupLabel(label: 'จำนวนวัน'),
      const SizedBox(height: 10),
      SizedBox(
        height: 156,
        child: Stack(
          children: [
            // The well marks the row the wheel will settle on, so it is drawn
            // behind the numbers rather than around the chosen one.
            Center(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.filterWheelWell,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            ListWheelScrollView.useDelegate(
              controller: _wheel,
              itemExtent: 52,
              diameterRatio: 2.4,
              perspective: 0.002,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) => widget.onDaysChanged(index + 1),
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: FilterDateStep.maxDays,
                builder: (context, index) {
                  final value = index + 1;
                  final chosen =
                      value == (widget.days ?? FilterDateStep.defaultDays);
                  return Center(
                    child: Text(
                      '$value',
                      style: TextStyle(
                        fontSize: chosen ? 30 : 20,
                        fontWeight: chosen ? FontWeight.w800 : FontWeight.w400,
                        color: chosen
                            ? AppColors.foreground
                            : const Color(0xFFC9C4BC),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const Divider(height: 1, color: AppColors.filterDivider),
      const SizedBox(height: 18),
      const FilterGroupLabel(label: 'จำนวนวันยอดนิยม'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 12,
        children: [
          for (final preset in _presets)
            FilterAnswerChip(
              label: preset.$1,
              active: widget.days == preset.$2,
              onTap: () => widget.onDaysChanged(preset.$2),
            ),
        ],
      ),
    ];
  }

  List<Widget> _calendar() {
    final months = [
      for (var i = 0; i < FilterDateStep.monthsAhead; i++)
        DateTime(_today.year, _today.month + i),
    ];

    return [
      Row(
        children: [
          for (final label in _weekdays)
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.filterSelectedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 14),
      for (final month in months) ...[
        _Month(
          month: month,
          today: _today,
          start: widget.start,
          end: widget.end,
          onTap: widget.onDayTapped,
        ),
        const SizedBox(height: 6),
      ],
    ];
  }
}

/// Calendar | Flexible, the pill in force filled coral.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final FilterDateMode mode;
  final ValueChanged<FilterDateMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.filterTrack,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          _ModeHalf(
            label: 'Calendar',
            active: mode == FilterDateMode.calendar,
            onTap: () => onChanged(FilterDateMode.calendar),
          ),
          _ModeHalf(
            label: 'Flexible',
            active: mode == FilterDateMode.flexible,
            onTap: () => onChanged(FilterDateMode.flexible),
          ),
        ],
      ),
    );
  }
}

class _ModeHalf extends StatelessWidget {
  const _ModeHalf({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.filterAction : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// One month of the rolling calendar: its name, then its days under the
/// weekday header the step draws once at the top.
class _Month extends StatelessWidget {
  const _Month({
    required this.month,
    required this.today,
    required this.start,
    required this.end,
    required this.onTap,
  });

  final DateTime month;
  final DateTime today;
  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.sunday is 7; the grid starts on Sunday.
    final leading = DateTime(month.year, month.month).weekday % 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          // English and the Gregorian year, as the design writes it — the
          // create wizard's calendar is Thai and Buddhist-era, this one is not.
          '${filterMonthNames[month.month - 1]} ${month.year}',
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.05,
          children: [
            for (var i = 0; i < leading; i++) const SizedBox.shrink(),
            for (var day = 1; day <= daysInMonth; day++)
              _DayCell(
                date: DateTime(month.year, month.month, day),
                today: today,
                start: start,
                end: end,
                onTap: onTap,
              ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.today,
    required this.start,
    required this.end,
    required this.onTap,
  });

  final DateTime date;
  final DateTime today;
  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final past = date.isBefore(today);
    final isStart = start != null && _sameDay(date, start!);
    final isEnd = end != null && _sameDay(date, end!);
    final between = start != null &&
        end != null &&
        date.isAfter(start!) &&
        date.isBefore(end!);
    final endpoint = isStart || isEnd;

    return Stack(
      children: [
        // The band runs behind the endpoints so a range reads as one stretch
        // rather than two circles with a gap.
        if (between || (isStart && end != null) || isEnd)
          Positioned.fill(
            child: Center(
              child: Container(
                height: 40,
                margin: EdgeInsets.only(
                  left: isStart && end != null ? 16 : 0,
                  right: isEnd ? 16 : 0,
                ),
                color: AppColors.filterSelected,
              ),
            ),
          ),
        Positioned.fill(
          child: Center(
            child: GestureDetector(
              onTap: past ? null : () => onTap(date),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: endpoint ? AppColors.filterAction : Colors.transparent,
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: endpoint ? FontWeight.w700 : FontWeight.w400,
                    color: endpoint
                        ? Colors.white
                        : past
                            ? const Color(0xFFC9C4BC)
                            : AppColors.foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// จำนวนวันยอดนิยม, as label and day count.
const _presets = <(String, int)>[
  ('1 วัน', 1),
  ('2 วัน 1 คืน', 2),
  ('3 วัน 2 คืน', 3),
  ('4 วัน 3 คืน', 4),
  ('1 สัปดาห์', 7),
  ('1 เดือน', 30),
];

const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// Month names as the calendar and the summary line both write them.
const filterMonthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
