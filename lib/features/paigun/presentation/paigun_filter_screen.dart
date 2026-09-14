import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import '../domain/trip_filter.dart';
import 'providers/paigun_providers.dart';
import 'widgets/filter_budget_step.dart';
import 'widgets/filter_chrome.dart';
import 'widgets/filter_date_step.dart';
import 'widgets/filter_people_step.dart';
import 'widgets/filter_style_step.dart';

/// The four questions behind ไปกัน's filter button, in the order the design
/// asks them.
enum FilterStep {
  dates('วันที่ฉันจะไปเที่ยว'),
  people('จำนวนคน'),
  budget('งบเที่ยวของฉัน'),
  style('สไตล์เที่ยวของฉัน');

  const FilterStep(this.title);

  final String title;
}

/// ตัวกรอง — the wizard reached from the ไปกัน header's dark control.
///
/// One screen with an `int _step`, not four routes, the same shape the create
/// wizard uses: the illustration and the progress dots stay put while the
/// questions swap beneath them. Nothing is applied until the last step is
/// finished, so backing out of the middle leaves the board as it was.
class PaigunFilterScreen extends ConsumerStatefulWidget {
  const PaigunFilterScreen({super.key});

  @override
  ConsumerState<PaigunFilterScreen> createState() => _PaigunFilterScreenState();
}

class _PaigunFilterScreenState extends ConsumerState<PaigunFilterScreen> {
  int _step = 0;

  // Seeded in initState, so the default lives in [TripFilter] alone.
  late FilterDateMode _mode;
  int? _days;
  DateTime? _start;
  DateTime? _end;

  int _adults = 0;
  int _children = 0;

  final _amount = TextEditingController();
  BudgetScope _scope = BudgetScope.perPerson;
  BudgetTier? _tier;

  final _styles = <String>[];
  final _constraints = <String>[];

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Reopening the wizard shows what is already filtering the board, so a
    // traveller can widen one answer without retyping the other three.
    final applied = ref.read(tripFilterProvider);
    _mode = applied.dateMode;
    _days = applied.days;
    _start = applied.startDate;
    _end = applied.endDate;
    _adults = applied.adults;
    _children = applied.children;
    _scope = applied.budgetScope;
    _tier = applied.budgetTier;
    _styles.addAll(applied.styles);
    _constraints.addAll(applied.constraints);
    final amount = applied.budgetAmount;
    if (amount != null && amount > 0) _amount.text = _trimZeros(amount);
    _amount.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amount.removeListener(_onAmountChanged);
    _amount.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The action bar reads the typed figure back, so it has to rebuild as it is
  /// typed.
  void _onAmountChanged() => setState(() {});

  FilterStep get _current => FilterStep.values[_step];

  @override
  Widget build(BuildContext context) {
    return AppFrame(
      background: AppColors.screen,
      child: Column(
        children: [
          FilterHero(
            step: _step,
            total: FilterStep.values.length,
            onBack: _back,
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilterStepTitle(title: _current.title),
                  const SizedBox(height: 22),
                  _body(),
                ],
              ),
            ),
          ),
          FilterActionBar(
            summary: _summary(),
            primaryLabel: _primaryLabel(),
            onPrimary: _next,
            onClear: () => setState(_clearStep),
            onSkip: _skip,
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_current) {
      case FilterStep.dates:
        return FilterDateStep(
          mode: _mode,
          onModeChanged: (mode) => setState(() => _mode = mode),
          days: _days,
          onDaysChanged: (days) => setState(() => _days = days),
          start: _start,
          end: _end,
          onDayTapped: _pickDay,
        );
      case FilterStep.people:
        return FilterPeopleStep(
          adults: _adults,
          children: _children,
          onAdultsChanged: (value) => setState(() => _adults = value),
          onChildrenChanged: (value) => setState(() => _children = value),
        );
      case FilterStep.budget:
        return FilterBudgetStep(
          amount: _amount,
          scope: _scope,
          onScopeChanged: (scope) => setState(() => _scope = scope),
          tier: _tier,
          onTierChanged: (tier) => setState(() {
            // A bracket and a typed figure answer the same question, so one
            // replaces the other rather than fighting it — as ระบุเอง does in
            // the create wizard.
            _tier = _tier == tier ? null : tier;
            if (_tier != null) _amount.clear();
          }),
        );
      case FilterStep.style:
        return FilterStyleStep(
          styles: _styles,
          constraints: _constraints,
          onStyleTapped: (label) => setState(() => _toggle(_styles, label)),
          onConstraintTapped: (label) =>
              setState(() => _toggle(_constraints, label)),
        );
    }
  }

  void _toggle(List<String> into, String label) {
    if (!into.remove(label)) into.add(label);
  }

  /// A third tap starts a new range rather than extending the old one.
  void _pickDay(DateTime day) {
    setState(() {
      if (_start == null || _end != null || day.isBefore(_start!)) {
        _start = day;
        _end = null;
      } else {
        _end = day;
      }
    });
  }

  // --- the action bar -------------------------------------------------------

  /// What this step has collected, in the design's own words. Null leaves the
  /// summary row — and ล้างที่เลือก with it — off the panel.
  String? _summary() {
    switch (_current) {
      case FilterStep.dates:
        final length = _filter.lengthInDays;
        if (length == null) return null;
        if (_mode == FilterDateMode.flexible) return _lengthLabel(length);
        return '${_rangeLabel()} · ${_lengthLabel(length)}';
      case FilterStep.people:
        if (_adults == 0 && _children == 0) return null;
        return [
          if (_adults > 0) 'ผู้ใหญ่ $_adults คน',
          if (_children > 0) 'เด็ก $_children คน',
        ].join(' · ');
      case FilterStep.budget:
        final typed = _typedAmount();
        if (typed != null) {
          return '฿${_trimZeros(typed)} ${_scope.label}';
        }
        final tier = _tier;
        if (tier == null) return null;
        return FilterBudgetStep.brackets
            .firstWhere((bracket) => bracket.$1 == tier)
            .$2;
      case FilterStep.style:
        final count = _styles.length + _constraints.length;
        return count == 0 ? null : '$count รายการ';
    }
  }

  /// "ถัดไป" all the way through, except on the last step with something
  /// chosen — the design turns that one into ตกลง, because there is nothing
  /// left to go on to.
  String _primaryLabel() {
    final last = _step == FilterStep.values.length - 1;
    return last && _summary() != null ? 'ตกลง' : 'ถัดไป';
  }

  void _next() {
    if (_step == FilterStep.values.length - 1) {
      _apply();
      return;
    }
    setState(() {
      _step++;
      _scroll.jumpTo(0);
    });
  }

  /// ข้ามไปก่อน — leave this question unanswered and carry on. Skipping means
  /// not answering, so whatever the step collected goes with it; the steps
  /// already behind it are untouched.
  void _skip() {
    setState(_clearStep);
    _next();
  }

  void _back() {
    if (_step == 0) {
      _leave();
      return;
    }
    setState(() {
      _step--;
      _scroll.jumpTo(0);
    });
  }

  /// Wipes only the step on screen.
  void _clearStep() {
    switch (_current) {
      case FilterStep.dates:
        _days = null;
        _start = null;
        _end = null;
      case FilterStep.people:
        _adults = 0;
        _children = 0;
      case FilterStep.budget:
        _tier = null;
        _amount.clear();
      case FilterStep.style:
        _styles.clear();
        _constraints.clear();
    }
  }

  void _apply() {
    ref.read(tripFilterProvider.notifier).state = _filter;
    _leave();
  }

  /// Reached by a push from the board, but the board is not always behind it —
  /// a deep link lands here with nothing to pop.
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.paigun.name);
    }
  }

  // --- reading the answers back --------------------------------------------

  TripFilter get _filter => TripFilter(
        dateMode: _mode,
        startDate: _mode == FilterDateMode.calendar ? _start : null,
        endDate: _mode == FilterDateMode.calendar ? _end : null,
        days: _mode == FilterDateMode.flexible ? _days : null,
        adults: _adults,
        children: _children,
        budgetTier: _tier,
        budgetAmount: _typedAmount(),
        budgetScope: _scope,
        styles: List<String>.unmodifiable(_styles),
        constraints: List<String>.unmodifiable(_constraints),
      );

  double? _typedAmount() {
    final value = double.tryParse(_amount.text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  /// "3 Day 2 Night", as the design counts a trip.
  String _lengthLabel(int days) =>
      days <= 1 ? '1 Day' : '$days Day ${days - 1} Night';

  /// "Sep 28 - 30", or "Sep 28 - Oct 2" when the trip crosses a month.
  String _rangeLabel() {
    final start = _start;
    if (start == null) return '';
    final from = '${filterMonthNames[start.month - 1]} ${start.day}';
    final end = _end;
    if (end == null) return from;
    if (end.month == start.month && end.year == start.year) {
      return '$from - ${end.day}';
    }
    return '$from - ${filterMonthNames[end.month - 1]} ${end.day}';
  }
}

/// 1200.0 reads as "1200", 1200.5 keeps its half.
String _trimZeros(double value) {
  final whole = value.truncateToDouble() == value;
  return whole ? value.toStringAsFixed(0) : value.toString();
}
