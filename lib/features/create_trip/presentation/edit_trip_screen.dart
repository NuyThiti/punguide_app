import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/config/maps_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/extensions/currency_extensions.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/plan_labels.dart';
import 'providers/edit_plan_providers.dart';

/// The deep green the design uses for the active tab and the day numbers. It
/// is darker than [AppColors.primary], which is the button green.
const _planGreen = Color(0xFF2E6B4C);

/// The panel behind a collapsible section.
const _panel = Color(0xFFF3F6F3);

/// Editing a plan: the trip's facts on a cover hero, then the itinerary the
/// traveller fills in day by day.
class EditTripScreen extends ConsumerStatefulWidget {
  const EditTripScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends ConsumerState<EditTripScreen> {
  int _tab = 0;

  /// Which day the ทริปของฉัน tab is showing. Clamped on read, so a trip that
  /// loses a day does not leave the picker pointing past the end.
  int _selectedDay = 0;

  /// So the map FAB can bring the card back into view from down the list.
  final _mapKey = GlobalKey();
  bool _lodgingOpen = false;
  bool _scheduleOpen = true;

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(editPlanProvider(widget.tripId));

    return Scaffold(
      backgroundColor: AppColors.softScreen,
      // The map shortcut belongs to ทริปของฉัน, and only once the trip loaded.
      floatingActionButton: _tab == 1 && trip.hasValue
          ? FloatingActionButton(
              onPressed: _scrollToMap,
              backgroundColor: AppColors.brandOrange,
              foregroundColor: Colors.white,
              tooltip: 'ดูบนแผนที่',
              child: const Icon(Icons.map_outlined),
            )
          : null,
      body: trip.when(
        data: _body,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorBody(
          error: error,
          onRetry: () => ref.invalidate(editPlanProvider(widget.tripId)),
        ),
      ),
    );
  }

  Widget _body(ApiTrip trip) {
    final plan = _PlanView.of(trip);
    // A budget read that fails must not take the itinerary down with it, so
    // the lodging count falls back to zero rather than to an error state.
    final lodging =
        ref.watch(planAccommodationsProvider(widget.tripId)).valueOrNull ??
            const <BudgetItem>[];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _PlanHero(
            plan: plan,
            lodgingCount: lodging.length,
            avatarImage: ref.watch(authSessionProvider)?.avatarImage,
            onBack: _back,
          ),
        ),
        SliverPadding(
          // The map FAB floats over the bottom of the list on ทริปของฉัน, so
          // the last card needs room to clear it.
          padding: EdgeInsets.fromLTRB(20, 20, 20, _tab == 1 ? 96 : 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _PlanTabs(
                selectedIndex: _tab,
                onChanged: (index) => setState(() => _tab = index),
              ),
              const SizedBox(height: 22),
              if (_tab == 0)
                ..._planTab(plan, lodging)
              else if (_tab == 1)
                ..._myTripTab(plan)
              else
                _ComingSoonPanel(label: _PlanTabs.labels[_tab]),
            ]),
          ),
        ),
      ],
    );
  }

  /// The ทริปของฉัน tab: the plan on a map, a day picker, then that day's
  /// stops in the fuller card the design uses here.
  List<Widget> _myTripTab(_PlanView plan) {
    final days = plan.days;
    final index = days.isEmpty ? 0 : _selectedDay.clamp(0, days.length - 1);
    final day = days.isEmpty ? null : days[index];

    return [
      _SectionHeading(
        title: 'ทริปของฉัน',
        onShare: () => _todo('แชร์แผนยังไม่เปิดใช้งาน'),
        action: _PillButton(
          label: 'แก้ไขทริป',
          icon: Icons.edit_outlined,
          color: AppColors.brandOrange,
          onTap: () => context.goNamed(
            AppRoute.editTripBrief.name,
            params: {'tripId': widget.tripId},
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Divider(height: 1, color: AppColors.line),
      const SizedBox(height: 16),
      _TripMapCard(
        key: _mapKey,
        stops: day?.stops ?? const <Activity>[],
        onMenu: () => _todo('ตัวเลือกแผนที่ยังไม่เปิดใช้งาน'),
      ),
      const SizedBox(height: 16),
      _DaySelector(
        days: days,
        selectedIndex: index,
        onSelect: (i) => setState(() => _selectedDay = i),
        onAddDay: () => _todo('เพิ่มวันยังไม่เปิดใช้งาน'),
      ),
      const SizedBox(height: 14),
      if (day == null || day.stops.isEmpty)
        const _EmptyNote('ยังไม่มีสถานที่ในวันนี้')
      else
        for (var i = 0; i < day.stops.length; i++) ...[
          _MyTripStopCard(
            stop: day.stops[i],
            position: i + 1,
            segment: day.segmentInto(day.stops[i]),
          ),
          if (i != day.stops.length - 1) const SizedBox(height: 12),
        ],
    ];
  }

  /// The จัดแผน tab: the plan's own heading, the lodging panel and the day
  /// schedule. The other three tabs have no design yet.
  List<Widget> _planTab(_PlanView plan, List<BudgetItem> lodging) {
    return [
      _SectionHeading(
        title: 'จัดแผนของคุณ',
        onShare: () => _todo('แชร์แผนยังไม่เปิดใช้งาน'),
        action: _PillButton(
          label: 'Remix Trip',
          icon: Icons.shuffle,
          color: AppColors.brandPurple,
          onTap: () => context.goNamed(
            AppRoute.remixTrip.name,
            params: {'tripId': widget.tripId},
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Divider(height: 1, color: AppColors.line),
      const SizedBox(height: 16),
      _CollapsibleSection(
        title: 'ที่พักของคุณ',
        expanded: _lodgingOpen,
        onToggle: () => setState(() => _lodgingOpen = !_lodgingOpen),
        child: _LodgingList(items: lodging),
      ),
      const SizedBox(height: 14),
      _CollapsibleSection(
        title: 'ตารางแผน',
        expanded: _scheduleOpen,
        onToggle: () => setState(() => _scheduleOpen = !_scheduleOpen),
        actions: [
          _MiniIconButton(
            icon: Icons.tune,
            tooltip: 'จัดเรียงวัน',
            onTap: () => _todo('จัดเรียงวันยังไม่เปิดใช้งาน'),
          ),
          _MiniIconButton(
            icon: Icons.more_vert,
            tooltip: 'ตัวเลือกเพิ่มเติม',
            onTap: _openScheduleMenu,
          ),
        ],
        child: _ScheduleList(
          days: plan.days,
          callbacks: _ScheduleCallbacks(
            onExplore: () => _todo('สำรวจสถานที่แนะนำยังไม่เปิดใช้งาน'),
            onAddPlace: (day) =>
                _todo('เพิ่มสถานที่ในวันที่ ${day.number} ยังไม่เปิดใช้งาน'),
            onAddTravel: (day) =>
                _todo('เพิ่มการเดินทางในวันที่ ${day.number} ยังไม่เปิดใช้งาน'),
            onEditStop: (stop) =>
                _todo('แก้ไข "${stop.title}" ยังไม่เปิดใช้งาน'),
            onDeleteStop: (stop) =>
                _todo('ลบ "${stop.title}" ยังไม่เปิดใช้งาน'),
            onReorder: (day) =>
                _todo('จัดเรียงสถานที่ในวันที่ ${day.number} ยังไม่เปิดใช้งาน'),
          ),
        ),
      ),
    ];
  }

  /// Back to wherever the editor was opened from, falling back to the trip
  /// itself when it was opened cold from a link.
  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(
      AppRoute.tripDetail.name,
      params: {'tripId': widget.tripId},
    );
  }

  void _openScheduleMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: _planGreen),
              title: const Text(
                'แก้ไขรายละเอียดทริป',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.goNamed(
                  AppRoute.editTripBrief.name,
                  params: {'tripId': widget.tripId},
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToMap() {
    final target = _mapKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
  }

  void _todo(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException && (error as ApiException).isNotFound
        ? 'ไม่พบทริปนี้'
        : 'โหลดแผนไม่สำเร็จ';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('ลองอีกครั้ง')),
        ],
      ),
    );
  }
}

/// The cover card: nav row, trip name, dates, brief chips and the four counts.
class _PlanHero extends StatelessWidget {
  const _PlanHero({
    required this.plan,
    required this.lodgingCount,
    required this.avatarImage,
    required this.onBack,
  });

  final _PlanView plan;
  final int lodgingCount;
  final String? avatarImage;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: Stack(
          children: [
            Positioned.fill(
              child: CoverImage(source: plan.coverImage, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.62),
                      Colors.black.withValues(alpha: 0.52),
                      Colors.black.withValues(alpha: 0.80),
                    ],
                    stops: const [0, 0.42, 1],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroNavRow(
                      avatarImage: avatarImage,
                      onBack: onBack,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      plan.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _HeroDateRow(plan: plan),
                    const SizedBox(height: 14),
                    if (plan.chips.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final chip in plan.chips) _HeroChip(label: chip),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    _HeroStats(plan: plan, lodgingCount: lodgingCount),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroNavRow extends StatelessWidget {
  const _HeroNavRow({required this.avatarImage, required this.onBack});

  final String? avatarImage;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassCircleButton(
          icon: Icons.arrow_back_ios_new,
          tooltip: 'ย้อนกลับ',
          onTap: onBack,
        ),
        const Expanded(
          child: Text(
            'สร้างทริป',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          width: 40,
          height: 40,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.8), width: 2),
            color: Colors.white.withValues(alpha: 0.24),
          ),
          child: avatarImage == null
              ? const Icon(Icons.person, size: 20, color: Colors.white)
              : CoverImage(source: avatarImage!, fit: BoxFit.cover),
        ),
      ],
    );
  }
}

class _HeroDateRow extends StatelessWidget {
  const _HeroDateRow({required this.plan});

  final _PlanView plan;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.92),
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
    return Row(
      children: [
        const Icon(Icons.calendar_today_outlined,
            size: 14, color: Colors.white),
        const SizedBox(width: 7),
        Flexible(child: Text(plan.dateLine, style: style, maxLines: 1)),
        if (plan.durationLine.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('•', style: style),
          ),
          Text(plan.durationLine, style: style),
        ],
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeroStats extends StatelessWidget {
  const _HeroStats({required this.plan, required this.lodgingCount});

  final _PlanView plan;
  final int lodgingCount;

  @override
  Widget build(BuildContext context) {
    final tiles = <_StatTile>[
      _StatTile(value: '${plan.sightCount}', label: 'ที่เที่ยว'),
      _StatTile(value: '${plan.restaurantCount}', label: 'ร้านอาหาร'),
      _StatTile(value: '$lodgingCount', label: 'ที่พัก'),
      _StatTile(value: plan.perDayBudgetLabel, label: 'งบ/วัน'),
    ];
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 9),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
      ),
      child: Column(
        children: [
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: AppColors.foreground),
        ),
      ),
    );
  }
}

/// The four plan views, as one segmented pill.
class _PlanTabs extends StatelessWidget {
  const _PlanTabs({required this.selectedIndex, required this.onChanged});

  static const labels = ['จัดแผน', 'ทริปของฉัน', 'สภาพอากาศ', 'สรุปงบ'];

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selectedIndex == i ? _planGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: FittedBox(
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        color:
                            selectedIndex == i ? Colors.white : AppColors.muted,
                        fontSize: 14,
                        fontWeight: selectedIndex == i
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A section title with share beside it and one coloured action pill —
/// "Remix Trip" on จัดแผน, "แก้ไขทริป" on ทริปของฉัน.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.onShare,
    required this.action,
  });

  final String title;
  final VoidCallback onShare;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Tooltip(
          message: 'แชร์แผน',
          child: GestureDetector(
            onTap: onShare,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.chipBorder),
              ),
              child: const Icon(
                Icons.ios_share,
                size: 18,
                color: AppColors.foreground,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        action,
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: Colors.white),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled panel that opens and closes, with optional header buttons.
class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.actions = const <Widget>[],
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final action in actions) ...[
                action,
                const SizedBox(width: 8),
              ],
              Tooltip(
                message: expanded ? 'ย่อ' : 'ขยาย',
                child: GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 14),
            child,
          ],
        ],
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppColors.foreground),
        ),
      ),
    );
  }
}

class _LodgingList extends StatelessWidget {
  const _LodgingList({required this.items});

  final List<BudgetItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyNote('ยังไม่ได้เลือกที่พัก');
    }
    return Column(
      children: [
        for (final item in items) ...[
          _WhiteRow(
            child: Row(
              children: [
                const Icon(Icons.hotel_outlined, size: 18, color: _planGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  item.amount.asBaht,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (item != items.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Everything the schedule can do, bundled so the day cards do not each need
/// six constructor arguments.
class _ScheduleCallbacks {
  const _ScheduleCallbacks({
    required this.onExplore,
    required this.onAddPlace,
    required this.onAddTravel,
    required this.onEditStop,
    required this.onDeleteStop,
    required this.onReorder,
  });

  final VoidCallback onExplore;
  final ValueChanged<_PlanDay> onAddPlace;
  final ValueChanged<_PlanDay> onAddTravel;
  final ValueChanged<Activity> onEditStop;
  final ValueChanged<Activity> onDeleteStop;
  final ValueChanged<_PlanDay> onReorder;
}

class _ScheduleList extends StatelessWidget {
  const _ScheduleList({required this.days, required this.callbacks});

  final List<_PlanDay> days;
  final _ScheduleCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ExploreBanner(onTap: callbacks.onExplore),
        const SizedBox(height: 12),
        if (days.isEmpty)
          const _EmptyNote('ยังไม่มีวันในแผนนี้')
        else
          for (final day in days) ...[
            _DayCard(day: day, callbacks: callbacks),
            if (day != days.last) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

/// The nudge toward the place explorer, drawn with the design's dashed edge.
class _ExploreBanner extends StatelessWidget {
  const _ExploreBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: AppColors.brandOrange.withValues(alpha: 0.55),
        radius: 16,
      ),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4EE),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.explore_outlined,
                size: 18,
                color: AppColors.brandOrange,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'ยังไม่รู้จะไปไหน? สำรวจสถานที่แนะนำ',
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onTap,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: AppColors.brandOrange,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'สำรวจ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 17, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One day: the header the design always shows, then its stops with the legs
/// between them once there are any.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.callbacks});

  final _PlanDay day;
  final _ScheduleCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: _DayHeader(
              day: day,
              onAddPlace: () => callbacks.onAddPlace(day),
            ),
          ),
          if (day.stops.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                children: [
                  for (var i = 0; i < day.stops.length; i++) ...[
                    // The leg belongs to the stop it arrives at, so it is
                    // drawn above every stop but the first.
                    if (i > 0)
                      _LegRow(
                        stop: day.stops[i],
                        segment: day.segmentInto(day.stops[i]),
                      ),
                    _StopCard(
                      stop: day.stops[i],
                      position: i + 1,
                      onEdit: () => callbacks.onEditStop(day.stops[i]),
                      onDelete: () => callbacks.onDeleteStop(day.stops[i]),
                      onReorder: () => callbacks.onReorder(day),
                    ),
                  ],
                  _AddTravelRow(onTap: () => callbacks.onAddTravel(day)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.onAddPlace});

  final _PlanDay day;
  final VoidCallback onAddPlace;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'วันที่ ${day.number}',
          style: const TextStyle(
            color: _planGreen,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (day.dateLabel.isNotEmpty) ...[
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              day.dateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const Spacer(),
        GestureDetector(
          onTap: onAddPlace,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: AppColors.brandOrange.withValues(alpha: 0.6),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 15, color: AppColors.brandOrange),
                SizedBox(width: 4),
                Text(
                  'สถานที่',
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
      ],
    );
  }
}

/// A stop: drag handle, numbered thumbnail, time, name, note, cost, and the
/// delete and edit buttons.
class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.stop,
    required this.position,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
  });

  final Activity stop;
  final int position;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: 'จัดเรียงสถานที่',
            child: GestureDetector(
              onTap: onReorder,
              child: const Padding(
                padding: EdgeInsets.only(top: 18, right: 6),
                child:
                    Icon(Icons.drag_handle, size: 17, color: AppColors.muted),
              ),
            ),
          ),
          _StopThumbnail(stop: stop, position: position),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stop.time != null)
                  Text(
                    _clockLabel(stop.time!),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  stop.title,
                  // The design's names all fit one line; real ones like
                  // "Mercure Danang French Village" do not.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((stop.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    stop.notes!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _CostChip(amount: stop.cost),
                    const Spacer(),
                    _SquareIconButton(
                      icon: Icons.delete_outline,
                      color: const Color(0xFFE4574C),
                      tooltip: 'ลบสถานที่',
                      onTap: onDelete,
                    ),
                    const SizedBox(width: 8),
                    _SquareIconButton(
                      icon: Icons.edit_outlined,
                      color: AppColors.brandOrange,
                      tooltip: 'แก้ไขสถานที่',
                      onTap: onEdit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StopThumbnail extends StatelessWidget {
  const _StopThumbnail({
    required this.stop,
    required this.position,
    this.size = 58,
    this.badgeColor = AppColors.foreground,
  });

  final Activity stop;
  final int position;
  final double size;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final image = stop.location?.imageUrl;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: image == null || image.isEmpty
                  ? ColoredBox(
                      color: _panel,
                      child: Icon(
                        _categoryIcon(stop.category),
                        size: 22,
                        color: AppColors.muted,
                      ),
                    )
                  : CoverImage(source: image, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: -4,
            left: -4,
            child: Container(
              width: 21,
              height: 21,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                '$position',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CostChip extends StatelessWidget {
  const _CostChip({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.payments_outlined, size: 12, color: AppColors.muted),
          const SizedBox(width: 4),
          Text(
            amount.asBaht,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

/// The leg arriving at [stop], on the dotted rail the design runs between
/// cards.
class _LegRow extends StatelessWidget {
  const _LegRow({required this.stop, required this.segment});

  final Activity stop;

  /// The server's measurement of the same leg, or null when routing failed.
  final TravelSegment? segment;

  @override
  Widget build(BuildContext context) {
    return _RailRow(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Icon(_legIcon(stop, segment),
                size: 15, color: AppColors.foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _legLabel(stop, segment),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTravelRow extends StatelessWidget {
  const _AddTravelRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RailRow(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F7F2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.add, size: 15, color: _planGreen),
              SizedBox(width: 7),
              Text(
                'เพิ่มการเดินทาง',
                style: TextStyle(
                  color: _planGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row hung off the dotted timeline rail: dashes above, a green node beside
/// the content.
class _RailRow extends StatelessWidget {
  const _RailRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: CustomPaint(painter: const _RailPainter()),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final dots = Paint()
      ..color = AppColors.muted.withValues(alpha: 0.5)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // Dashes run from the card above down to the node.
    final nodeY = size.height / 2;
    for (var y = 2.0; y < nodeY - 6; y += 6) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 3), dots);
    }
    canvas.drawCircle(
      Offset(x, nodeY),
      4,
      Paint()..color = AppColors.primary,
    );
    for (var y = nodeY + 6; y < size.height - 2; y += 6) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 3), dots);
    }
  }

  @override
  bool shouldRepaint(_RailPainter oldDelegate) => false;
}

IconData _categoryIcon(ActivityCategory category) => switch (category) {
      ActivityCategory.food => Icons.restaurant,
      ActivityCategory.hotel => Icons.hotel_outlined,
      ActivityCategory.transport => Icons.directions_bus_filled_outlined,
      ActivityCategory.sightseeing => Icons.photo_camera_outlined,
      ActivityCategory.activity => Icons.hiking,
      ActivityCategory.other => Icons.place_outlined,
    };

IconData _travelTypeIcon(TravelType type) => switch (type) {
      TravelType.walk => Icons.directions_walk,
      TravelType.bicycle => Icons.directions_bike,
      TravelType.tukTuk => Icons.electric_rickshaw,
      TravelType.privateTransfer => Icons.local_taxi,
      TravelType.rentalCar => Icons.directions_car,
      TravelType.boat => Icons.directions_boat,
      TravelType.train => Icons.train,
      TravelType.airplane => Icons.flight,
      TravelType.other => Icons.more_horiz,
    };

IconData _travelModeIcon(TravelMode mode) => switch (mode) {
      TravelMode.drive => Icons.directions_car,
      TravelMode.walk => Icons.directions_walk,
      TravelMode.bicycle => Icons.directions_bike,
      TravelMode.transit => Icons.directions_bus_filled_outlined,
    };

IconData _legIcon(Activity stop, TravelSegment? segment) {
  final planned = stop.travelFromPrevious?.type;
  if (planned != null) return _travelTypeIcon(planned);
  if (segment != null) return _travelModeIcon(segment.travelMode);
  return Icons.trending_flat;
}

/// The pieces of a leg description, most specific source first: what the
/// traveller wrote, then what the server measured.
List<String> _legParts(
  Activity stop,
  TravelSegment? segment, {
  required bool withDistance,
  required bool withCost,
}) {
  final leg = stop.travelFromPrevious;
  return <String>[
    if (leg?.customType != null && leg!.customType!.isNotEmpty)
      leg.customType!
    else if (leg?.type != null)
      travelTypeLabels[leg!.type!]!
    else if (segment != null)
      travelModeLabels[segment.travelMode]!,
    if (leg?.durationMin != null)
      '${leg!.durationMin} นาที'
    else if (segment?.durationMinutes != null)
      '${segment!.durationMinutes} นาที',
    if (withDistance)
      if (leg?.distanceKm != null)
        '${_trimZero(leg!.distanceKm!)} กม.'
      else if (segment?.distanceKilometers != null)
        '${_trimZero(segment!.distanceKilometers!)} กม.',
    if (withCost && leg?.costAmount != null && leg!.costAmount! > 0)
      leg.costAmount!.asBaht,
  ];
}

/// "รถเช่า • 15 นาที • ฿3,500", for the rail on จัดแผน.
String _legLabel(Activity stop, TravelSegment? segment) {
  final parts = _legParts(stop, segment, withDistance: true, withCost: true);
  if (parts.isNotEmpty) return parts.join(' • ');
  // [Activity.travelNote] is the legacy pre-composed string; it is the last
  // thing to fall back on, not the first.
  return stop.travelNote ?? 'ยังไม่ได้ระบุการเดินทาง';
}

/// "รถเช่า • 15 นาที", for the chip on ทริปของฉัน, where cost has its own chip.
String _legShortLabel(Activity stop, TravelSegment? segment) {
  final parts = _legParts(stop, segment, withDistance: false, withCost: false);
  return parts.isEmpty ? 'ยังไม่ระบุ' : parts.join(' • ');
}

String _trimZero(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

/// "08:30" as the design's "08:30 AM". The API sends 24-hour `HH:mm`.
String _clockLabel(String time) {
  final parts = time.split(':');
  final hour = int.tryParse(parts.first);
  if (hour == null || parts.length < 2) return time;
  final suffix = hour < 12 ? 'AM' : 'PM';
  final display = hour % 12 == 0 ? 12 : hour % 12;
  return '${_two(display)}:${parts[1]} $suffix';
}

class _WhiteRow extends StatelessWidget {
  const _WhiteRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A dashed rounded rectangle. There is no dashed-border package in the app,
/// and the explore banner is the only place that needs one.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  static const dash = 5.0;
  static const gap = 4.0;

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// One row of the schedule.
class _PlanDay {
  const _PlanDay({
    required this.number,
    required this.dateLabel,
    this.stops = const <Activity>[],
    this.segments = const <TravelSegment>[],
  });

  final int number;

  /// "Sat, 20 Aug", or empty on a trip whose dates are still open.
  final String dateLabel;

  /// In itinerary order. Empty on a day nobody has filled in yet, which is
  /// the state the design shows for วันที่ 2 and 3.
  final List<Activity> stops;

  /// The server's measured legs, used when the traveller did not describe one
  /// themselves.
  final List<TravelSegment> segments;

  /// Matched by stop id, never by index — a leg that failed to calculate must
  /// not shift the rest onto the wrong gaps.
  TravelSegment? segmentInto(Activity stop) {
    for (final segment in segments) {
      if (segment.toPlaceId == stop.id) return segment;
    }
    return null;
  }
}

/// Everything the page renders, derived once from the API trip.
class _PlanView {
  const _PlanView({
    required this.title,
    required this.coverImage,
    required this.dateLine,
    required this.durationLine,
    required this.chips,
    required this.sightCount,
    required this.restaurantCount,
    required this.perDayBudgetLabel,
    required this.days,
  });

  factory _PlanView.of(ApiTrip trip) {
    final schedule = trip.schedule;
    final start = schedule.startDate;
    final end = schedule.endDate;

    // The server derives the duration from the dates whenever it has both, so
    // the stored figures are only trusted on a trip that has none.
    final dayCount = schedule.durationDays ??
        (start != null && end != null ? end.difference(start).inDays + 1 : 0);
    final nightCount =
        schedule.durationNights ?? (dayCount > 0 ? dayCount - 1 : 0);

    var sights = 0;
    var restaurants = 0;
    for (final day in trip.days) {
      for (final activity in day.activities) {
        switch (activity.category) {
          case ActivityCategory.food:
            restaurants++;
          case ActivityCategory.sightseeing:
          case ActivityCategory.activity:
            sights++;
          case ActivityCategory.transport:
          case ActivityCategory.hotel:
          case ActivityCategory.other:
            break;
        }
      }
    }

    // The hero shows a daily figure; the trip stores a whole-trip total.
    final total = trip.budgetLimit ?? trip.totalBudget;
    final perDay = dayCount > 0 ? total / dayCount : total;

    return _PlanView(
      title: trip.title.trim().isEmpty ? trip.destination : trip.title,
      coverImage: trip.coverImage?.urls.large ?? AppConstants.defaultCoverImage,
      dateLine: start == null || end == null
          ? 'ยังไม่ระบุวันที่'
          : '${_slashDate(start)} - ${_slashDate(end)}',
      durationLine: dayCount > 0 ? '$dayCount วัน $nightCount คืน' : '',
      chips: _chipsOf(trip.brief),
      sightCount: sights,
      restaurantCount: restaurants,
      perDayBudgetLabel: perDay > 0 ? perDay.asBaht : '—',
      days: _daysOf(trip, dayCount, start),
    );
  }

  final String title;
  final String coverImage;
  final String dateLine;
  final String durationLine;
  final List<String> chips;
  final int sightCount;
  final int restaurantCount;
  final String perDayBudgetLabel;
  final List<_PlanDay> days;

  /// Pace first, then how they get around, then the styles — the order the
  /// design reads them in.
  static List<String> _chipsOf(TripPlanBrief? brief) {
    if (brief == null) return const <String>[];
    return <String>[
      if (brief.intensity != null) intensityLabels[brief.intensity!]!,
      ...brief.transport.map(transportLabel).whereType<String>(),
      ...brief.customTransport,
      ...brief.styles.map(styleLabel).whereType<String>(),
      ...brief.customStyles,
    ];
  }

  /// The itinerary's own days, or a placeholder row per day so a plan that has
  /// not been filled in yet still shows somewhere to add the first stop.
  static List<_PlanDay> _daysOf(ApiTrip trip, int dayCount, DateTime? start) {
    if (trip.days.isNotEmpty) {
      final ordered = [...trip.days]
        ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
      return [
        for (final day in ordered)
          _PlanDay(
            number: day.dayNumber,
            dateLabel: _weekdayDate(
              day.date ?? start?.add(Duration(days: day.dayNumber - 1)),
            ),
            stops: [...day.activities]
              ..sort((a, b) => a.order.compareTo(b.order)),
            segments: day.travelSegments,
          ),
      ];
    }
    return [
      for (var i = 0; i < dayCount; i++)
        _PlanDay(
          number: i + 1,
          dateLabel: _weekdayDate(start?.add(Duration(days: i))),
        ),
    ];
  }
}

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const _monthNames = [
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

String _slashDate(DateTime date) =>
    '${_two(date.day)}/${_two(date.month)}/${date.year}';

/// "Sat, 20 Aug". Empty when the trip has no dates to hang the day off.
String _weekdayDate(DateTime? date) {
  if (date == null) return '';
  return '${_weekdayNames[date.weekday - 1]}, '
      '${date.day} ${_monthNames[date.month - 1]}';
}

String _two(int value) => value.toString().padLeft(2, '0');

/// The day's stops on a Google map, with the design's own chrome over it.
///
/// Falls back to a labelled placeholder when the build has no Maps key (see
/// [MapsConfig]) or when nothing on the day has coordinates yet — the SDK
/// throws rather than degrading, so the map must not be built in either case.
class _TripMapCard extends StatefulWidget {
  const _TripMapCard({
    super.key,
    required this.stops,
    required this.onMenu,
  });

  final List<Activity> stops;
  final VoidCallback onMenu;

  @override
  State<_TripMapCard> createState() => _TripMapCardState();
}

class _TripMapCardState extends State<_TripMapCard> {
  GoogleMapController? _controller;

  List<Activity> get _plottable => widget.stops
      .where((stop) => stop.location?.hasCoordinates ?? false)
      .toList(growable: false);

  @override
  void didUpdateWidget(_TripMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching day keeps the same map, so move the camera to the new stops.
    if (!identical(oldWidget.stops, widget.stops)) _frameStops();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 250,
        child: Stack(
          children: [
            Positioned.fill(child: _surface()),
            Positioned(
              top: 12,
              left: 12,
              child: _MapControl(
                icon: Icons.more_vert,
                tooltip: 'ตัวเลือกแผนที่',
                onTap: widget.onMenu,
                circular: true,
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  _MapControl(
                    icon: Icons.add,
                    tooltip: 'ขยาย',
                    onTap: () => _zoom(1),
                  ),
                  const SizedBox(height: 8),
                  _MapControl(
                    icon: Icons.remove,
                    tooltip: 'ย่อ',
                    onTap: () => _zoom(-1),
                  ),
                  const SizedBox(height: 8),
                  _MapControl(
                    icon: Icons.near_me_outlined,
                    tooltip: 'จัดกรอบให้พอดี',
                    onTap: _frameStops,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _surface() {
    final stops = _plottable;
    if (!MapsConfig.isConfigured || stops.isEmpty) {
      return _MapPlaceholder(
        message: !MapsConfig.isConfigured
            ? 'แผนที่ยังไม่ได้ตั้งค่า'
            : 'สถานที่ในวันนี้ยังไม่มีพิกัด',
      );
    }
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _positionOf(stops.first),
        zoom: 12,
      ),
      markers: _markers(stops),
      polylines: _route(stops),
      onMapCreated: (controller) {
        _controller = controller;
        _frameStops();
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      // The card's own buttons sit over these corners.
      compassEnabled: false,
    );
  }

  Set<Marker> _markers(List<Activity> stops) => {
        for (var i = 0; i < stops.length; i++)
          Marker(
            markerId: MarkerId(stops[i].id),
            position: _positionOf(stops[i]),
            infoWindow: InfoWindow(
              title: '${i + 1}. ${stops[i].title}',
              snippet:
                  stops[i].time == null ? null : _clockLabel(stops[i].time!),
            ),
          ),
      };

  /// The day's order, drawn as one line so the shape of the day reads at a
  /// glance. Only meaningful with two stops or more.
  Set<Polyline> _route(List<Activity> stops) {
    if (stops.length < 2) return const <Polyline>{};
    return {
      Polyline(
        polylineId: const PolylineId('day-route'),
        points: stops.map(_positionOf).toList(growable: false),
        color: _planGreen,
        width: 3,
      ),
    };
  }

  LatLng _positionOf(Activity stop) => LatLng(
        stop.location!.latitude!,
        stop.location!.longitude!,
      );

  Future<void> _zoom(double by) async {
    await _controller?.animateCamera(CameraUpdate.zoomBy(by));
  }

  /// Fits every plottable stop in view. This is what the locate button does:
  /// nothing here asks for the device's location, because reframing the day is
  /// what a traveller reading a plan actually wants.
  /// A single stop has no bounds to fit, so
  /// it is centred instead.
  Future<void> _frameStops() async {
    final controller = _controller;
    final stops = _plottable;
    if (controller == null || stops.isEmpty) return;

    if (stops.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(_positionOf(stops.first), 14),
      );
      return;
    }

    final positions = stops.map(_positionOf);
    final lats = positions.map((p) => p.latitude);
    final lngs = positions.map((p) => p.longitude);
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
          northeast: LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
        ),
        48,
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE9EFE8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 30, color: AppColors.muted),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
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

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.circular = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: circular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circular ? null : BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 19, color: AppColors.foreground),
        ),
      ),
    );
  }
}

/// วันที่ 1 / 2 / 3 and "+ เพิ่มวัน", scrolling sideways once a trip is long.
class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.days,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAddDay,
  });

  final List<_PlanDay> days;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAddDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5EC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < days.length; i++) ...[
              _DayChip(
                label: 'วันที่ ${days[i].number}',
                selected: i == selectedIndex,
                onTap: () => onSelect(i),
              ),
              const SizedBox(width: 4),
            ],
            _DayChip(
              label: 'เพิ่มวัน',
              selected: false,
              filled: true,
              icon: Icons.add,
              onTap: onAddDay,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.filled = false,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// "+ เพิ่มวัน" is white like the selected chip without being a selection.
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final onWhite = selected || filled;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onWhite ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.foreground),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: onWhite ? AppColors.foreground : AppColors.muted,
                fontSize: 14,
                fontWeight: onWhite ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stop as ทริปของฉัน shows it: a bigger thumbnail, the time in orange, the
/// leg and cost as chips, and the note in full underneath.
class _MyTripStopCard extends StatelessWidget {
  const _MyTripStopCard({
    required this.stop,
    required this.position,
    required this.segment,
  });

  final Activity stop;
  final int position;
  final TravelSegment? segment;

  @override
  Widget build(BuildContext context) {
    final note = stop.notes ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StopThumbnail(
                stop: stop,
                position: position,
                size: 80,
                badgeColor: _planGreen,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.foreground,
                        fontSize: 17,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (stop.time != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        _clockLabel(stop.time!),
                        style: const TextStyle(
                          color: AppColors.brandOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _InfoChip(
                          icon: _legIcon(stop, segment),
                          label: _legShortLabel(stop, segment),
                        ),
                        _InfoChip(
                          icon: Icons.monetization_on_outlined,
                          label: stop.cost.asBaht,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              note,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F2),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tab the design has not reached yet. Better an honest note than the
/// จัดแผน content silently standing in for it.
class _ComingSoonPanel extends StatelessWidget {
  const _ComingSoonPanel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.hourglass_empty, size: 26, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            '$label ยังไม่เปิดใช้งาน',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
