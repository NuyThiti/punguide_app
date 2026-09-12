import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/paigun/domain/trip_filter.dart';
import 'package:pluno/features/paigun/presentation/paigun_filter_screen.dart';
import 'package:pluno/features/paigun/presentation/paigun_screen.dart';
import 'package:pluno/features/paigun/presentation/providers/paigun_providers.dart';
import 'package:pluno/features/paigun/presentation/widgets/paigun_card.dart';

import 'support/home_feed_fixtures.dart';

/// The board with the wizard behind its dark control, so a test can walk the
/// real route rather than pumping the wizard on its own.
Widget _harness(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.paigun.name,
            builder: (_, __) => const PaigunScreen(),
          ),
          GoRoute(
            path: '/filter',
            name: AppRoute.paigunFilter.name,
            builder: (_, __) => const PaigunFilterScreen(),
          ),
        ],
      ),
    ),
  );
}

/// A feed row with a tier and a style the wizard can ask about.
TripListItem tieredTrip({
  required String id,
  required String title,
  String? tier,
  List<String> tags = const <String>['culture'],
  int? durationDays = 3,
  double totalBudget = 3000,
}) {
  return TripListItem.fromJson(<String, dynamic>{
    'id': id,
    'title': title,
    'destination': 'ภูเก็ต, ไทย',
    'status': 'published',
    'schedule': <String, dynamic>{
      if (durationDays != null) 'durationDays': durationDays,
    },
    'totalBudget': totalBudget,
    if (tier != null) 'budgetTier': tier,
    'tags': tags,
    'isSaved': false,
    'isLiked': false,
    'likeCount': 0,
    'remixCount': 0,
    'createdAt': '2026-09-01T00:00:00.000Z',
    'updatedAt': '2026-09-01T00:00:00.000Z',
  });
}

Future<void> _openWizard(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.tune));
  await tester.pumpAndSettle();
}

void main() {
  group('the wizard', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: homeOverrides([feedTrip(id: 'lpq')]),
      );
    });

    tearDown(() => container.dispose());

    testWidgets('opens on วันที่ฉันจะไปเที่ยว with the calendar showing',
        (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();
      await _openWizard(tester);

      expect(find.text('วันที่ฉันจะไปเที่ยว'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Flexible'), findsOneWidget);
      // The rolling calendar draws its weekday header once, above the months.
      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      // Untouched: no summary line, so no way to clear it either.
      expect(find.text('ล้างที่เลือก'), findsNothing);
      expect(find.text('ถัดไป'), findsOneWidget);
      expect(find.text('ข้ามไปก่อน'), findsOneWidget);
    });

    testWidgets('reads each answer back in the action bar and applies them to '
        'the board', (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();
      await _openWizard(tester);

      // วันที่ — a popular length, which the wheel follows.
      await tester.tap(find.text('Flexible'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 วัน 2 คืน'));
      await tester.pumpAndSettle();
      expect(find.text('3 Day 2 Night'), findsOneWidget);
      expect(find.text('ล้างที่เลือก'), findsOneWidget);

      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();

      // จำนวนคน — the chips answer the counter beside them.
      expect(find.text('จำนวนคน'), findsOneWidget);
      await tester.tap(find.text('2 คน').first);
      await tester.pumpAndSettle();
      expect(find.text('ผู้ใหญ่ 2 คน'), findsOneWidget);

      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();

      // งบ — a bracket, read back by name.
      expect(find.text('งบเที่ยวของฉัน'), findsOneWidget);
      await tester.tap(find.text('Premium').first);
      await tester.pumpAndSettle();
      // Once on the card, once in the summary.
      expect(find.text('Premium'), findsNWidgets(2));

      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();

      // สไตล์ — the last question, where ถัดไป becomes ตกลง.
      expect(find.text('สไตล์เที่ยวของฉัน'), findsOneWidget);
      expect(find.text('ถัดไป'), findsOneWidget);
      await tester.tap(find.text('ทะเล'));
      await tester.pumpAndSettle();
      expect(find.text('1 รายการ'), findsOneWidget);
      expect(find.text('ถัดไป'), findsNothing);
      expect(find.text('ตกลง'), findsOneWidget);

      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      // Back on the board, with everything the wizard collected in force.
      expect(find.text('ไปกัน'), findsOneWidget);
      final applied = container.read(tripFilterProvider);
      expect(applied.dateMode, FilterDateMode.flexible);
      expect(applied.days, 3);
      expect(applied.adults, 2);
      expect(applied.budgetTier, BudgetTier.premium);
      expect(applied.styles, <String>['ทะเล']);
      expect(applied.answeredCount, 4);
    });

    testWidgets('ล้างที่เลือก wipes the step on screen and nothing behind it',
        (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();
      await _openWizard(tester);

      await tester.tap(find.text('Flexible'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 สัปดาห์'));
      await tester.pumpAndSettle();
      expect(find.text('7 Day 6 Night'), findsOneWidget);

      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 คน').first);
      await tester.pumpAndSettle();
      expect(find.text('ผู้ใหญ่ 4 คน'), findsOneWidget);

      await tester.tap(find.text('ล้างที่เลือก'));
      await tester.pumpAndSettle();
      expect(find.text('ผู้ใหญ่ 4 คน'), findsNothing);

      // The length chosen a step earlier is still there.
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('7 Day 6 Night'), findsOneWidget);
    });

    testWidgets('backing out of the first step leaves the board untouched',
        (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();
      await _openWizard(tester);

      await tester.tap(find.text('Flexible'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 วัน'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.text('ไปกัน'), findsOneWidget);
      // Nothing is applied until the last step is finished.
      expect(container.read(tripFilterProvider).isEmpty, isTrue);
    });
  });

  testWidgets('an applied filter narrows the board and badges the control',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: homeOverrides([
        tieredTrip(id: 'sea', title: 'เกาะหลีเป๊ะ', tags: ['beach']),
        tieredTrip(id: 'wat', title: 'วัดในเมืองเก่า', tags: ['culture']),
      ]),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();
    expect(find.byType(PaigunCard), findsNWidgets(4));

    container.read(tripFilterProvider.notifier).state =
        const TripFilter(styles: ['ทะเล']);
    await tester.pumpAndSettle();

    // One row per wall now, and the header says one question is narrowing it.
    expect(find.byType(PaigunCard), findsNWidgets(2));
    expect(find.text('วัดในเมืองเก่า'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  group('TripFilter.matches', () {
    test('keeps a trip that fits in the time asked for', () {
      const filter = TripFilter(dateMode: FilterDateMode.flexible, days: 3);

      expect(filter.matches(tieredTrip(id: 'a', title: 'a', durationDays: 2)),
          isTrue);
      expect(filter.matches(tieredTrip(id: 'b', title: 'b', durationDays: 3)),
          isTrue);
      expect(filter.matches(tieredTrip(id: 'c', title: 'c', durationDays: 5)),
          isFalse);
      // A row that never said how long it runs is unknown, not a mismatch.
      expect(
        filter.matches(tieredTrip(id: 'd', title: 'd', durationDays: null)),
        isTrue,
      );
    });

    test('a calendar range counts both of its endpoints', () {
      final filter = TripFilter(
        dateMode: FilterDateMode.calendar,
        startDate: DateTime(2026, 9, 28),
        endDate: DateTime(2026, 9, 30),
      );

      expect(filter.lengthInDays, 3);
      // Half-drawn reads as a single day.
      expect(
        TripFilter(
          dateMode: FilterDateMode.calendar,
          startDate: DateTime(2026, 9, 28),
        ).lengthInDays,
        1,
      );
    });

    test('a bracket matches the trip\'s own tier, and spares the untiered', () {
      const filter = TripFilter(budgetTier: BudgetTier.premium);

      expect(
        filter.matches(tieredTrip(id: 'a', title: 'a', tier: 'premium')),
        isTrue,
      );
      expect(
        filter.matches(tieredTrip(id: 'b', title: 'b', tier: 'economy')),
        isFalse,
      );
      expect(filter.matches(tieredTrip(id: 'c', title: 'c')), isTrue);
    });

    test('a typed figure is scaled by the group and overrides the bracket', () {
      const filter = TripFilter(
        adults: 2,
        budgetTier: BudgetTier.luxury,
        budgetAmount: 1000,
      );

      // 1,000 a head across two heads — a 2,000 baht ceiling for the trip.
      expect(filter.wholeTripCap, 2000);
      expect(
        filter.matches(tieredTrip(id: 'a', title: 'a', totalBudget: 1800)),
        isTrue,
      );
      expect(
        filter.matches(tieredTrip(id: 'b', title: 'b', totalBudget: 3000)),
        isFalse,
      );

      // The same figure read as the whole group's bill is a tighter ceiling.
      const everyone = TripFilter(
        adults: 2,
        budgetAmount: 1000,
        budgetScope: BudgetScope.everyone,
      );
      expect(everyone.wholeTripCap, 1000);
      expect(
        everyone.matches(tieredTrip(id: 'c', title: 'c', totalBudget: 1800)),
        isFalse,
      );
    });

    test('a style chip matches the wire tag the feed carries', () {
      const filter = TripFilter(styles: ['ทะเล', 'ภูเขา']);

      expect(
        filter.matches(tieredTrip(id: 'a', title: 'a', tags: ['beach'])),
        isTrue,
      );
      expect(
        filter.matches(tieredTrip(id: 'b', title: 'b', tags: ['culture'])),
        isFalse,
      );
      // A declared-empty list is an answer, not an unknown.
      expect(
        filter.matches(tieredTrip(id: 'c', title: 'c', tags: [])),
        isFalse,
      );
    });

    test('head count and constraints are collected but narrow nothing', () {
      const filter = TripFilter(
        adults: 2,
        children: 1,
        constraints: ['มีเด็กเล็ก'],
      );

      expect(filter.heads, 3);
      expect(filter.answeredCount, 2);
      expect(filter.matches(tieredTrip(id: 'a', title: 'a')), isTrue);
    });
  });
}
