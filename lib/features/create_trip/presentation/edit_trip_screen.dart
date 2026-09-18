import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/pluno_api.dart';
import '../../../core/config/maps_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/extensions/currency_extensions.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../trips/presentation/itinerary_display.dart';
import '../../trips/presentation/providers/trip_providers.dart';
import '../domain/plan_labels.dart';
import 'providers/edit_plan_providers.dart';
import 'widgets/add_place_sheet.dart';
import 'widgets/budget_sheets.dart';
import 'widgets/plan_budget_tab.dart';
import 'widgets/suggest_places_sheet.dart';

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
    final trip = ref.watch(apiTripProvider(widget.tripId));

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
          onRetry: () => ref.invalidate(apiTripProvider(widget.tripId)),
        ),
      ),
    );
  }

  /// 0 while the nav bar still sits over the hero, 1 once the hero has gone
  /// by and the bar has to stand on the page's own background.
  final _navT = ValueNotifier<double>(0);
  final _heroKey = GlobalKey();

  @override
  void dispose() {
    _navT.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    final box = _heroKey.currentContext?.findRenderObject() as RenderBox?;
    final heroHeight = box?.size.height ?? 320;
    // Start turning solid as the hero's last 60px pass under the bar.
    final start = (heroHeight - 60).clamp(0.0, double.infinity);
    final t = ((notification.metrics.pixels - start) / 60).clamp(0.0, 1.0);
    if ((_navT.value - t).abs() > 0.01) _navT.value = t;
    return false;
  }

  Widget _body(ApiTrip trip) {
    final plan = _PlanView.of(trip).withOrder(_localOrder);
    // A budget read that fails must not take the itinerary down with it, so
    // the lodging count falls back to zero rather than to an error state.
    final lodging =
        ref.watch(planAccommodationsProvider(widget.tripId)).valueOrNull ??
            const <BudgetItem>[];

    final topInset = MediaQuery.paddingOf(context).top;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Pinned first, so the tabs below stack under it rather than over it.
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyBar(
              extent: topInset + 60,
              builder: (context) => ValueListenableBuilder<double>(
                valueListenable: _navT,
                builder: (context, t, _) => _StickyNavBar(
                  t: t,
                  topInset: topInset,
                  avatarImage: ref.watch(authSessionProvider)?.avatarImage,
                  onBack: _back,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _PlanHero(
              key: _heroKey,
              plan: plan,
              lodgingCount: lodging.length,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyBar(
              extent: 90,
              builder: (context) => Container(
                color: AppColors.softScreen,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                child: _PlanTabs(
                  selectedIndex: _tab,
                  onChanged: (index) => setState(() => _tab = index),
                ),
              ),
            ),
          ),
          SliverPadding(
            // The map FAB floats over the bottom of the list on ทริปของฉัน, so
            // the last card needs room to clear it.
            padding: EdgeInsets.fromLTRB(20, 0, 20, _tab == 1 ? 96 : 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_tab == 0)
                  ..._planTab(plan, lodging)
                else if (_tab == 1)
                  ..._myTripTab(plan)
                else if (_tab == 3)
                  PlanBudgetTab(
                    tripId: widget.tripId,
                    groupSize: trip.customer?.groupSize ?? 1,
                    days: _budgetDays(plan),
                    onShare: () => _todo('แชร์สรุปงบยังไม่เปิดใช้งาน'),
                    onEditBudget: () => _editBudgetLimit(trip),
                    onAddExpense: () => _addExpense(plan),
                  )
                else
                  _ComingSoonPanel(label: _PlanTabs.labels[_tab]),
              ]),
            ),
          ),
        ],
      ),
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
            onNavigate: () => _todo('นำทางยังไม่เปิดใช้งาน'),
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
            onExplore: () => _explore(plan),
            onAddPlace: (day) => _addPlaceManually(plan, day),
            onAddTravel: (day) =>
                _todo('เพิ่มการเดินทางในวันที่ ${day.number} ยังไม่เปิดใช้งาน'),
            onEditStop: (stop) =>
                _todo('แก้ไข "${stop.title}" ยังไม่เปิดใช้งาน'),
            onDeleteStop: _deleteStop,
            onReorder: _reorderStops,
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

  /// Removes a stop, after asking. Deleting re-measures the legs around the
  /// gap it leaves, which is why [calculateTravelSegments] is left on.
  /// The order a day was just dragged into, until the server confirms it.
  ///
  /// Without this the row snaps back to the old position for as long as the
  /// request takes and then jumps again when the trip reloads.
  final Map<String, List<String>> _localOrder = {};

  /// Moves a stop inside its day and sends the new order up.
  ///
  /// `PATCH /days/:id/items/order` wants **every** stop of that day — one
  /// missing or one from elsewhere is a 400 — so the whole list goes, and the
  /// server recalculates the legs while it is there.
  Future<void> _reorderStops(_PlanDay day, int oldIndex, int newIndex) async {
    final target = newIndex;
    if (day.id.isEmpty || target == oldIndex) return;
    if (oldIndex < 0 || oldIndex >= day.stops.length) return;

    final ids = day.stops.map((stop) => stop.id).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(target.clamp(0, ids.length), moved);

    setState(() => _localOrder[day.id] = ids);
    try {
      final api = await ref.read(plunoApiProvider.future);
      await api.itinerary.reorderItems(day.id, ids);
    } on ApiException catch (failure) {
      if (mounted) {
        setState(() => _localOrder.remove(day.id));
        _todo(failure.isUnauthorized
            ? 'เข้าสู่ระบบก่อนจัดเรียงสถานที่'
            : 'จัดเรียงไม่สำเร็จ: ${failure.message}');
      }
      return;
    } catch (error) {
      if (mounted) {
        setState(() => _localOrder.remove(day.id));
        _todo('จัดเรียงไม่สำเร็จ: $error');
      }
      return;
    }
    if (!mounted) return;
    // The reload carries the server's order and its fresh legs; the local
    // stand-in has done its job.
    setState(() => _localOrder.remove(day.id));
    ref.invalidate(apiTripProvider(widget.tripId));
  }

  Future<void> _deleteStop(Activity stop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ลบสถานที่นี้?'),
        content: Text('"${stop.title}" จะถูกเอาออกจากแผน'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFE4574C)),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final api = await ref.read(plunoApiProvider.future);
      await api.itinerary.deleteItem(stop.id);
    } on ApiException catch (failure) {
      _todo(failure.isUnauthorized
          ? 'เข้าสู่ระบบก่อนลบสถานที่'
          : 'ลบไม่สำเร็จ: ${failure.message}');
      return;
    } catch (error) {
      _todo('ลบไม่สำเร็จ: $error');
      return;
    }
    if (!mounted) return;
    ref.invalidate(apiTripProvider(widget.tripId));
  }

  /// Opens แนะนำสถานที่ for [day] and folds whatever was added back into the
  /// trip.
  Future<void> _addPlaces(_PlanView plan, _PlanDay? day) async {
    if (day == null || day.id.isEmpty) {
      _todo('วันนี้ยังไม่มีในแผน เพิ่มวันก่อนจึงจะเพิ่มสถานที่ได้');
      return;
    }
    // A destination picked off the trending rail or out of recents carries no
    // placeId, so the trip has coordinates for nothing. Look them up from the
    // text before giving up on the explorer.
    final anchor = plan.anchor ?? await _resolveAnchor(plan.destination);
    if (anchor == null) {
      _todo('ยังไม่รู้พิกัดของทริปนี้ เลือกจุดหมายหรือเพิ่มสถานที่แรกก่อน');
      return;
    }
    if (!mounted) return;

    final added = await showSuggestPlacesSheet(
      context,
      tripId: widget.tripId,
      dayId: day.id,
      dayNumber: day.number,
      latitude: anchor.latitude,
      longitude: anchor.longitude,
    );
    if (!added || !mounted) return;
    ref.invalidate(apiTripProvider(widget.tripId));
  }

  /// เพิ่มสถานที่ — the form, for a stop the traveller already knows. The
  /// explorer is one tap away inside it, and opens here rather than on top of
  /// the sheet so only one scrim is ever in play.
  Future<void> _addPlaceManually(_PlanView plan, _PlanDay? day) async {
    final target = day ?? _firstRealDay(plan) ?? _firstDay(plan);
    if (target == null) {
      _todo('ยังไม่มีวันในแผนนี้');
      return;
    }

    // A plan straight out of POST /trips has a duration but no itinerary rows,
    // so every day on screen is a placeholder with no id. Give the tapped one
    // a row now — otherwise the day count is real but nothing can be added to
    // it, and the traveller is stuck.
    final dayId =
        target.id.isNotEmpty ? target.id : await _createDay(target.number);
    if (dayId == null || !mounted) return;

    final outcome = await showAddPlaceSheet(
      context,
      tripId: widget.tripId,
      days: [
        for (final planDay in plan.days)
          if (planDay.id.isNotEmpty || planDay.number == target.number)
            AddPlaceDay(
              // The day just created is not in `plan` yet, which was read
              // before the write.
              id: planDay.number == target.number ? dayId : planDay.id,
              number: planDay.number,
              label: planDay.dateLabel,
            ),
      ],
      initialDayId: dayId,
    );
    if (!mounted) return;

    switch (outcome) {
      case AddPlaceOutcome.added:
        ref.invalidate(apiTripProvider(widget.tripId));
      case AddPlaceOutcome.explore:
        await _addPlaces(
            plan,
            _PlanDay(
              id: dayId,
              number: target.number,
              dateLabel: target.dateLabel,
              date: target.date,
              stops: target.stops,
              segments: target.segments,
            ));
      case AddPlaceOutcome.cancelled:
        break;
    }
  }

  /// The banner's สำรวจ. Same trouble as adding a place by hand: on a new plan
  /// there is no day row to hang a stop off yet.
  Future<void> _explore(_PlanView plan) async {
    final target = _firstRealDay(plan) ?? _firstDay(plan);
    if (target == null) {
      _todo('ยังไม่มีวันในแผนนี้');
      return;
    }
    final dayId =
        target.id.isNotEmpty ? target.id : await _createDay(target.number);
    if (dayId == null || !mounted) return;

    await _addPlaces(
        plan,
        _PlanDay(
          id: dayId,
          number: target.number,
          dateLabel: target.dateLabel,
          date: target.date,
          stops: target.stops,
          segments: target.segments,
        ));
  }

  /// Turns the trip's destination text into coordinates, and remembers them on
  /// the trip so the next tap costs nothing.
  ///
  /// Two paid Google calls, which is why the result is written back. Only
  /// `destinationPlace` is sent: `update` rewrites the plan brief as a whole
  /// whenever any part of it is present, so the brief is left out entirely.
  Future<({double latitude, double longitude})?> _resolveAnchor(
    String destination,
  ) async {
    final query = destination.trim();
    if (query.isEmpty) return null;

    final PlaceLookup lookup;
    try {
      final api = await ref.read(plunoApiProvider.future);
      final session = PlacesSession();
      final hits =
          await api.places.autocomplete(query, sessionToken: session.token);
      if (hits.isEmpty) return null;
      lookup = await api.places.details(
        hits.first.externalRef,
        sessionToken: session.token,
      );
    } catch (error) {
      debugPrint('Anchor lookup failed for "$query": $error');
      return null;
    }

    final latitude = lookup.latitude;
    final longitude = lookup.longitude;
    if (latitude == null || longitude == null) return null;

    // Best effort: a failed write costs a repeat lookup, not the explorer.
    try {
      final api = await ref.read(plunoApiProvider.future);
      await api.trips.update(
        widget.tripId,
        destinationPlace: DestinationPlace(
          placeId: lookup.externalRef,
          name: lookup.name,
          latitude: latitude,
          longitude: longitude,
        ),
      );
      ref.invalidate(apiTripProvider(widget.tripId));
    } catch (error) {
      debugPrint('Could not store the resolved place: $error');
    }

    return (latitude: latitude, longitude: longitude);
  }

  /// Creates the itinerary row for [dayNumber] and returns its id, or null
  /// when the write failed and the traveller has been told why.
  ///
  /// The date is left to the server: it already knows the trip's schedule, and
  /// a plan with no dates has none to send.
  Future<String?> _createDay(int dayNumber) async {
    try {
      final api = await ref.read(plunoApiProvider.future);
      final created =
          await api.itinerary.addDay(widget.tripId, dayNumber: dayNumber);
      ref.invalidate(apiTripProvider(widget.tripId));
      return created.id;
    } on ApiException catch (failure) {
      _todo(failure.isUnauthorized
          ? 'เข้าสู่ระบบก่อนเพิ่มวัน'
          : 'เพิ่มวันที่ $dayNumber ไม่สำเร็จ: ${failure.message}');
      return null;
    } catch (error) {
      _todo('เพิ่มวันที่ $dayNumber ไม่สำเร็จ: $error');
      return null;
    }
  }

  _PlanDay? _firstDay(_PlanView plan) =>
      plan.days.isEmpty ? null : plan.days.first;

  _PlanDay? _firstRealDay(_PlanView plan) {
    for (final day in plan.days) {
      if (day.id.isNotEmpty) return day;
    }
    return null;
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

  /// The days a new expense can be filed under, in plan order.
  List<BudgetDayOption> _budgetDays(_PlanView plan) => [
        for (final day in plan.days)
          BudgetDayOption(
            number: day.number,
            label: day.dateLabel,
            date: day.date,
          ),
      ];

  /// แก้ไขงบ: the cap the สรุปงบ bar measures against. It lives on the trip,
  /// not in the budget, so this is a `trips.update` — and an empty field
  /// clears it, which is not the same as setting it to zero.
  Future<void> _editBudgetLimit(ApiTrip trip) async {
    final result = await showBudgetLimitSheet(
      context,
      current: trip.budgetLimit,
      groupSize: trip.customer?.groupSize ?? 1,
    );
    if (result == null || !mounted) return;

    try {
      final api = await ref.read(plunoApiProvider.future);
      await api.trips.update(widget.tripId, budgetLimit: result.limit ?? 0);
      ref.invalidate(apiTripProvider(widget.tripId));
      ref.invalidate(planBudgetProvider(widget.tripId));
      if (mounted) _todo('บันทึกงบแล้ว');
    } on ApiException catch (failure) {
      _todo(failure.isUnauthorized
          ? 'เข้าสู่ระบบก่อนแก้ไขงบ'
          : 'บันทึกงบไม่สำเร็จ: ${failure.message}');
    } catch (error) {
      _todo('บันทึกงบไม่สำเร็จ: $error');
    }
  }

  /// + เพิ่มค่าใช้จ่าย: a standalone cost. Stop and accommodation costs are
  /// not entered here — they already count towards the budget through their
  /// own columns.
  Future<void> _addExpense(_PlanView plan) async {
    final expense =
        await showAddExpenseSheet(context, days: _budgetDays(plan));
    if (expense == null || !mounted) return;

    try {
      final api = await ref.read(plunoApiProvider.future);
      await api.budget.addExpense(
        widget.tripId,
        title: expense.title,
        amount: expense.amount,
        category: expense.category,
        date: expense.date,
      );
      ref.invalidate(planBudgetProvider(widget.tripId));
      ref.invalidate(apiTripProvider(widget.tripId));
      if (mounted) _todo('เพิ่ม "${expense.title}" แล้ว');
    } on ApiException catch (failure) {
      _todo(failure.isUnauthorized
          ? 'เข้าสู่ระบบก่อนเพิ่มค่าใช้จ่าย'
          : 'เพิ่มค่าใช้จ่ายไม่สำเร็จ: ${failure.message}');
    } catch (error) {
      _todo('เพิ่มค่าใช้จ่ายไม่สำเร็จ: $error');
    }
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
    super.key,
    required this.plan,
    required this.lodgingCount,
  });

  final _PlanView plan;
  final int lodgingCount;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
        ],
      ),
    );
  }
}

/// A sliver header of fixed height, so `pinned: true` makes it stick. Two of
/// these stack: the nav bar holds the top, the tabs come to rest beneath it.
class _StickyBar extends SliverPersistentHeaderDelegate {
  const _StickyBar({required this.extent, required this.builder});

  final double extent;
  final WidgetBuilder builder;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      SizedBox(height: extent, child: builder(context));

  @override
  bool shouldRebuild(covariant _StickyBar old) => old.extent != extent;
}

/// The nav row on its own bar. It starts as the hero's dark top — the same
/// wash the gradient opens with — and turns into the page background once the
/// hero has scrolled by, taking its contents from white to ink with it.
class _StickyNavBar extends StatelessWidget {
  const _StickyNavBar({
    required this.t,
    required this.topInset,
    required this.avatarImage,
    required this.onBack,
  });

  final double t;
  final double topInset;
  final String? avatarImage;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The bar covers the status bar, so the clock has to flip with it —
      // white over the hero's dark wash, ink once the bar turns pale.
      value: t < 0.5 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 10),
        decoration: BoxDecoration(
          color: Color.lerp(
            Colors.black.withValues(alpha: 0.62),
            AppColors.softScreen,
            t,
          ),
          border: Border(
            bottom: BorderSide(
              color: AppColors.line.withValues(alpha: t),
            ),
          ),
        ),
        child: _HeroNavRow(
          t: t,
          avatarImage: avatarImage,
          onBack: onBack,
        ),
      ),
    );
  }
}

class _HeroNavRow extends StatelessWidget {
  const _HeroNavRow({
    required this.t,
    required this.avatarImage,
    required this.onBack,
  });

  /// 0 over the hero, 1 over the page background.
  final double t;
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
        Expanded(
          child: Text(
            'สร้างทริป',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color.lerp(Colors.white, AppColors.foreground, t),
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
              color: Color.lerp(
                Colors.white.withValues(alpha: 0.8),
                AppColors.chipBorder,
                t,
              )!,
              width: 2,
            ),
            color: Color.lerp(
              Colors.white.withValues(alpha: 0.24),
              AppColors.line,
              t,
            ),
          ),
          child: avatarImage == null
              ? Icon(
                  Icons.person,
                  size: 20,
                  color: Color.lerp(Colors.white, AppColors.muted, t),
                )
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
  /// Which day, and where the stop landed. `onReorderItem` hands over the
  /// final index, with the dropped row already taken out of the count.
  final void Function(_PlanDay day, int oldIndex, int newIndex) onReorder;
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
                  // The stops are draggable; the handle on each card starts
                  // the drag, so the default handles stay off. The leg above a
                  // stop travels with it, and the server recalculates every
                  // leg once the new order lands.
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorderItem: (oldIndex, newIndex) =>
                        callbacks.onReorder(day, oldIndex, newIndex),
                    children: [
                      for (var i = 0; i < day.stops.length; i++)
                        Column(
                          key: ValueKey(day.stops[i].id),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // The leg belongs to the stop it arrives at, so it
                            // is drawn above every stop but the first.
                            if (i > 0)
                              _LegRow(
                                stop: day.stops[i],
                                segment: day.segmentInto(day.stops[i]),
                              ),
                            _StopCard(
                              stop: day.stops[i],
                              position: i + 1,
                              onEdit: () => callbacks.onEditStop(day.stops[i]),
                              onDelete: () =>
                                  callbacks.onDeleteStop(day.stops[i]),
                            ),
                          ],
                        ),
                    ],
                  ),
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
  });

  final Activity stop;
  final int position;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
            // Press and hold, not a plain drag: the page's own scroll view
            // wins an immediate one, and the row never leaves the ground.
            message: 'กดค้างแล้วลากเพื่อจัดเรียงสถานที่',
            child: ReorderableDelayedDragStartListener(
              index: position - 1,
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
                    clockLabel(stop.time!),
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
                        categoryIcon(stop.category),
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
            Icon(legIcon(stop, segment), size: 15, color: AppColors.foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                legLabel(stop, segment),
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
    required this.id,
    required this.number,
    required this.dateLabel,
    this.date,
    this.stops = const <Activity>[],
    this.segments = const <TravelSegment>[],
  });

  /// The itinerary day's own id. Empty on a placeholder day the trip has no
  /// itinerary row for yet — nothing can be added to one of those.
  final String id;

  final int number;

  /// "Sat, 20 Aug", or empty on a trip whose dates are still open.
  final String dateLabel;

  /// The day's own date, for filing an expense under it. Null on a trip
  /// without fixed dates.
  final DateTime? date;

  /// In itinerary order. Empty on a day nobody has filled in yet, which is
  /// the state the design shows for วันที่ 2 and 3.
  final List<Activity> stops;

  /// The server's measured legs, used when the traveller did not describe one
  /// themselves.
  final List<TravelSegment> segments;

  /// The same day with its stops in [ids], for showing a drag before the
  /// server has confirmed it. Ids it does not know are ignored, and stops the
  /// list leaves out keep their place at the end — a stale order must never
  /// drop a stop off the page.
  _PlanDay reordered(List<String> ids) {
    final byId = {for (final stop in stops) stop.id: stop};
    final ordered = <Activity>[
      for (final id in ids)
        if (byId.containsKey(id)) byId.remove(id)!,
    ];
    return _PlanDay(
      id: id,
      number: number,
      dateLabel: dateLabel,
      date: date,
      stops: [...ordered, ...stops.where((stop) => byId.containsKey(stop.id))],
      segments: segments,
    );
  }

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
    required this.destination,
    required this.coverImage,
    required this.dateLine,
    required this.durationLine,
    required this.chips,
    required this.sightCount,
    required this.restaurantCount,
    required this.perDayBudgetLabel,
    required this.days,
    this.anchor,
  });

  /// The plan with any day the traveller has just dragged shown in that
  /// order. Empty map — the usual case — returns this view untouched.
  _PlanView withOrder(Map<String, List<String>> orders) {
    if (orders.isEmpty) return this;
    return _PlanView(
      title: title,
      destination: destination,
      coverImage: coverImage,
      dateLine: dateLine,
      durationLine: durationLine,
      chips: chips,
      sightCount: sightCount,
      restaurantCount: restaurantCount,
      perDayBudgetLabel: perDayBudgetLabel,
      anchor: anchor,
      days: [
        for (final day in days)
          if (day.id.isNotEmpty && orders[day.id] != null)
            day.reordered(orders[day.id]!)
          else
            day,
      ],
    );
  }

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
      destination: trip.destination,
      coverImage: trip.coverImage?.urls.large ?? AppConstants.defaultCoverImage,
      dateLine: start == null || end == null
          ? 'ยังไม่ระบุวันที่'
          : '${slashDate(start)} - ${slashDate(end)}',
      durationLine: dayCount > 0 ? '$dayCount วัน $nightCount คืน' : '',
      chips: _chipsOf(trip.brief),
      sightCount: sights,
      restaurantCount: restaurants,
      perDayBudgetLabel: perDay > 0 ? perDay.asBaht : '—',
      days: _daysOf(trip, dayCount, start),
      anchor: _anchorOf(trip),
    );
  }

  final String title;

  /// The free text the trip was created with — what the anchor is resolved
  /// from when the trip has no place attached.
  final String destination;
  final String coverImage;
  final String dateLine;
  final String durationLine;
  final List<String> chips;
  final int sightCount;
  final int restaurantCount;
  final String perDayBudgetLabel;
  final List<_PlanDay> days;

  /// Where to centre place suggestions. The destination is the right anchor,
  /// but it is often null on a hand-built trip, so an existing stop stands in.
  final ({double latitude, double longitude})? anchor;

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

  /// The destination's coordinates, else the first stop that has any. Null
  /// when the trip has neither, which is the one case suggestions cannot run.
  static ({double latitude, double longitude})? _anchorOf(ApiTrip trip) {
    final destination = trip.destinationPlace;
    if (destination?.latitude != null && destination?.longitude != null) {
      return (
        latitude: destination!.latitude!,
        longitude: destination.longitude!,
      );
    }
    for (final day in trip.days) {
      for (final stop in day.activities) {
        final location = stop.location;
        if (location != null && location.hasCoordinates) {
          return (
            latitude: location.latitude!,
            longitude: location.longitude!,
          );
        }
      }
    }
    return null;
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
            id: day.id,
            number: day.dayNumber,
            dateLabel: weekdayDate(
              day.date ?? start?.add(Duration(days: day.dayNumber - 1)),
            ),
            date: day.date ?? start?.add(Duration(days: day.dayNumber - 1)),
            stops: [...day.activities]
              ..sort((a, b) => a.order.compareTo(b.order)),
            segments: day.travelSegments,
          ),
      ];
    }
    return [
      for (var i = 0; i < dayCount; i++)
        _PlanDay(
          // A trip with no itinerary rows yet has no day to add a stop to.
          id: '',
          number: i + 1,
          dateLabel: weekdayDate(start?.add(Duration(days: i))),
          date: start?.add(Duration(days: i)),
        ),
    ];
  }
}

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
                  stops[i].time == null ? null : clockLabel(stops[i].time!),
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
class _MyTripStopCard extends StatefulWidget {
  const _MyTripStopCard({
    required this.stop,
    required this.position,
    required this.segment,
    required this.onNavigate,
  });

  final Activity stop;
  final int position;
  final TravelSegment? segment;

  /// "นำทาง", which only shows once the card is open.
  final VoidCallback onNavigate;

  @override
  State<_MyTripStopCard> createState() => _MyTripStopCardState();
}

class _MyTripStopCardState extends State<_MyTripStopCard> {
  /// Cards start closed: the day reads as a list of stops, and the writing
  /// opens one at a time.
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final stop = widget.stop;
    final position = widget.position;
    final segment = widget.segment;
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
                        clockLabel(stop.time!),
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
                          icon: legIcon(stop, segment),
                          label: legShortLabel(stop, segment),
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
              // Closed, the note is a taste of what is there; open, it is the
              // whole thing, which is what the expander is for.
              maxLines: _open ? null : 2,
              overflow: _open ? TextOverflow.clip : TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (_open) ...[
            const SizedBox(height: 12),
            _NavigateButton(onTap: widget.onNavigate),
          ],
          const SizedBox(height: 10),
          _DetailsToggle(
            open: _open,
            onTap: () => setState(() => _open = !_open),
          ),
        ],
      ),
    );
  }
}

/// "นำทาง" — the one action the open card offers.
class _NavigateButton extends StatelessWidget {
  const _NavigateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.near_me_outlined, size: 19),
        label: const Text(
          'นำทาง',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

/// "รายละเอียด" when the card is closed, "ย่อรายละเอียด" when it is open.
class _DetailsToggle extends StatelessWidget {
  const _DetailsToggle({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.foreground,
          side: const BorderSide(color: AppColors.line),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              open ? 'ย่อรายละเอียด' : 'รายละเอียด',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 20, color: AppColors.muted),
          ],
        ),
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
