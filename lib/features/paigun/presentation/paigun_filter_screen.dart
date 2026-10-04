import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import '../domain/trip_filter.dart';
import 'providers/paigun_providers.dart';
import 'widgets/filter_sheet_parts.dart';

/// ตัวกรอง — one sheet over the ไปกัน board (Figma 2480-59246).
///
/// Every question on one scroll rather than the four-step wizard this
/// replaced: the answers are short, and a traveller narrowing a board wants to
/// see what they have already said while they say the rest.
///
/// Nothing is applied until ตกลง. The draft lives in this screen so backing
/// out leaves the board exactly as it was found — including the type chip,
/// which is the board's own row shown here as the first question.
class PaigunFilterScreen extends ConsumerStatefulWidget {
  const PaigunFilterScreen({super.key});

  @override
  ConsumerState<PaigunFilterScreen> createState() => _PaigunFilterScreenState();
}

class _PaigunFilterScreenState extends ConsumerState<PaigunFilterScreen> {
  late TripFilter _draft = ref.read(tripFilterProvider);
  late PaigunFilter _type = ref.read(paigunFilterProvider);

  void _edit(TripFilter next) => setState(() => _draft = next);

  void _clear() => setState(() {
        _draft = TripFilter.none;
        _type = PaigunFilter.all;
      });

  void _apply() {
    ref.read(tripFilterProvider.notifier).state = _draft;
    ref.read(paigunFilterProvider.notifier).state = _type;
    _close();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.paigun.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return AppFrame(
      background: AppColors.filterBackdrop,
      child: Column(
        children: [
          // The board reads through above the sheet, so the traveller can see
          // what they are narrowing.
          _Backdrop(topInset: topInset, onBack: _close),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.screen,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  const FilterGrabber(),
                  _SheetTitle(onClear: _clear),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        FilterSection(
                          title: 'รูปแบบโพสที่จะเห็น',
                          child: FilterTypeChips(
                            selected: _type,
                            onSelected: (next) => setState(() => _type = next),
                          ),
                        ),
                        FilterSection(
                          title: 'วันที่เดินทาง',
                          child: FilterDateRow(
                            startDate: _draft.startDate,
                            endDate: _draft.endDate,
                            onPick: (start, end) => _edit(
                              start == null
                                  ? _draft.copyWith(clearDates: true)
                                  : _draft.copyWith(
                                      startDate: start,
                                      endDate: end,
                                    ),
                            ),
                          ),
                        ),
                        FilterSection(
                          title: 'จำนวนผู้ร่วมทริป',
                          child: Column(
                            children: [
                              FilterCounterRow(
                                label: 'ผู้ใหญ่',
                                caption: 'อายุ 13 ปีขึ้นไป',
                                value: _draft.adults,
                                onChanged: (next) =>
                                    _edit(_draft.copyWith(adults: next)),
                              ),
                              const SizedBox(height: 18),
                              FilterCounterRow(
                                label: 'เด็ก',
                                caption: 'อายุ 2 - 12 ปี',
                                value: _draft.children,
                                onChanged: (next) =>
                                    _edit(_draft.copyWith(children: next)),
                              ),
                            ],
                          ),
                        ),
                        FilterSection(
                          title: 'งบประมาณต่อคน',
                          child: FilterBudgetSlider(
                            value: _draft.budgetPerPerson,
                            onChanged: (next) =>
                                _edit(_draft.copyWith(budgetPerPerson: next)),
                          ),
                        ),
                        FilterSection(
                          title: 'รัศมีสถานที่ห่างจากฉัน',
                          child: FilterRadiusPicker(
                            value: _draft.radiusKm,
                            onChanged: (next) => _edit(
                              next == null
                                  ? _draft.copyWith(clearRadius: true)
                                  : _draft.copyWith(radiusKm: next),
                            ),
                          ),
                        ),
                        FilterSection(
                          title: 'สไตล์การเที่ยว',
                          showDivider: false,
                          child: FilterStyleChips(
                            selected: _draft.styles,
                            onTapped: _toggleStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilterApplyBar(onApply: _apply),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleStyle(String label) {
    final next = List<String>.of(_draft.styles);
    next.contains(label) ? next.remove(label) : next.add(label);
    _edit(_draft.copyWith(styles: next));
  }
}

/// The strip of board left showing above the sheet, with the way back.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.topInset, required this.onBack});

  final double topInset;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, topInset + 6, 18, 12),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Text(
              'ไปกัน',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 22,
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

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            'ตัวกรอง',
            style: TextStyle(
              color: AppColors.foreground,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: const Text(
                'ล้างตัวกรอง',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
