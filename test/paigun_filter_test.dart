import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/paigun/domain/nearby_trip.dart';
import 'package:pluno/features/paigun/domain/trip_filter.dart';
import 'package:pluno/features/paigun/presentation/paigun_filter_screen.dart';
import 'package:pluno/features/paigun/presentation/paigun_screen.dart';
import 'package:pluno/features/paigun/presentation/providers/paigun_providers.dart';

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
Map<String, dynamic> tieredTrip({
  required String id,
  required String title,
  String? tier,
  List<String> tags = const <String>['culture'],
  int? durationDays = 3,
  double totalBudget = 3000,
}) {
  return <String, dynamic>{
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
  };
}

Future<void> _openWizard(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.tune));
  await tester.pumpAndSettle();
}

/// Tap something inside the step's own scroll view.
///
/// The later chips in a wall sit below the fold on a phone, and a tap on a
/// clipped widget lands on the action bar instead — so scroll it into view
/// first.
Future<void> _tapInStep(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  group('the wizard', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: paigunOverrides(feedAdapter([feedTripJson(id: 'lpq')])),
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
      await _tapInStep(tester, find.text('3 วัน 2 คืน'));
      expect(find.text('3 Day 2 Night'), findsOneWidget);
      expect(find.text('ล้างที่เลือก'), findsOneWidget);

      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();

      // จำนวนคน — the chips answer the counter beside them.
      expect(find.text('จำนวนคน'), findsOneWidget);
      await _tapInStep(tester, find.text('2 คน').first);
      expect(find.text('ผู้ใหญ่ 2 คน'), findsOneWidget);

      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();

      // งบ — a bracket, read back by name.
      expect(find.text('งบเที่ยวของฉัน'), findsOneWidget);
      await _tapInStep(tester, find.text('Premium').first);
      // Once on the card, once in the summary.
      expect(find.text('Premium'), findsNWidgets(2));

      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();

      // สไตล์ — the last question, where ถัดไป becomes ตกลง.
      expect(find.text('สไตล์เที่ยวของฉัน'), findsOneWidget);
      expect(find.text('ถัดไป'), findsOneWidget);
      await _tapInStep(tester, find.text('ทะเล'));
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
      await _tapInStep(tester, find.text('1 สัปดาห์'));
      expect(find.text('7 Day 6 Night'), findsOneWidget);

      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();
      await _tapInStep(tester, find.text('4 คน').first);
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
      await _tapInStep(tester, find.text('1 วัน'));

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.text('ไปกัน'), findsOneWidget);
      // Nothing is applied until the last step is finished.
      expect(container.read(tripFilterProvider).isEmpty, isTrue);
    });
  });

  testWidgets('an applied filter goes up on the query and badges the control',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final adapter = feedAdapter([
      tieredTrip(id: 'sea', title: 'เกาะหลีเป๊ะ', tags: ['beach']),
    ]);
    final container = ProviderContainer(overrides: paigunOverrides(adapter));
    addTearDown(container.dispose);

    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();
    // Nothing answered yet: only the origin and the wall's own sort.
    expect(
      adapter.queriesOf('GET /trips').last.containsKey('styles'),
      isFalse,
    );

    container.read(tripFilterProvider.notifier).state =
        const TripFilter(styles: ['ทะเล']);
    await tester.pumpAndSettle();

    // The board does not sift the rows itself — it asks again, and the chip
    // rides along as the enum the API documents.
    for (final query in adapter.queriesOf('GET /trips').skip(2)) {
      expect(query['styles'], 'beach');
    }
    // The header says one question is narrowing the board.
    expect(find.text('1'), findsOneWidget);
  });

  group('TripFilter.toFeedQuery', () {
    Map<String, dynamic> queryOf(TripFilter filter) => filter
        .toFeedQuery(sort: FeedSort.nearest)
        .toQuery()
      ..removeWhere((_, value) => value == null);

    test('a chip with an enum goes up as a wire value, one without as text',
        () {
      const filter = TripFilter(
        styles: ['ทะเล', 'คาเฟ่', 'อิสลาม'],
        constraints: ['มีผู้สูงอายุ', 'มังสวิรัติ'],
      );

      final query = queryOf(filter);
      expect(query['styles'], 'beach,cafe');
      expect(query['constraints'], 'seniors');
      // Chips product added without waiting for a backend enum.
      expect(query['customStyles'], 'อิสลาม');
      expect(query['customConstraints'], 'มังสวิรัติ');
    });

    test('a calendar range is a window plus a ceiling, not a length', () {
      final filter = TripFilter(
        startDate: DateTime(2026, 9, 28),
        endDate: DateTime(2026, 9, 30),
      );

      final query = queryOf(filter);
      expect(query['dateFrom'], '2026-09-28');
      expect(query['dateTo'], '2026-09-30');
      // "What fits in these three days" — an exact durationDays would throw
      // away the two-day trips the wizard means to keep.
      expect(query['maxDurationDays'], 3);
      expect(query.containsKey('durationDays'), isFalse);
    });

    test('a half-drawn range reads as the single day the wizard shows', () {
      final filter = TripFilter(startDate: DateTime(2026, 9, 28));

      final query = queryOf(filter);
      expect(query['dateFrom'], '2026-09-28');
      expect(query['dateTo'], '2026-09-28');
    });

    test('the flexible stepper is an exact length', () {
      const filter = TripFilter(dateMode: FilterDateMode.flexible, days: 3);

      final query = queryOf(filter);
      expect(query['durationDays'], 3);
      expect(query.containsKey('dateFrom'), isFalse);
      expect(query.containsKey('maxDurationDays'), isFalse);
    });

    test('a typed figure overrides the bracket and carries its scope', () {
      const filter = TripFilter(
        adults: 2,
        children: 1,
        budgetTier: BudgetTier.premium,
        budgetAmount: 10000,
      );

      final query = queryOf(filter);
      expect(query['budgetMax'], 10000);
      // The server divides by the trip's own head count, so the figure goes up
      // as typed rather than pre-multiplied.
      expect(query['budgetScope'], 'per_person');
      expect(query.containsKey('budgetTiers'), isFalse);
      expect(query['adults'], 2);
      expect(query['children'], 1);
    });

    test('a bracket on its own goes up as a tier', () {
      const filter = TripFilter(budgetTier: BudgetTier.economy);

      expect(queryOf(filter)['budgetTiers'], 'economy');
    });

    test('an untouched sheet asks for nothing but the wall it is on', () {
      // Zero heads would read as "planned for at least nobody", and the
      // endpoint rejects any key it does not know — so an unanswered row has
      // to be absent, not empty.
      expect(queryOf(TripFilter.none).keys, <String>['sort']);
    });

    test('the origin rides along so the server can measure', () {
      const origin = PaigunOrigin(
        label: 'ตำแหน่งของฉัน',
        address: 'เขตพระนคร, กรุงเทพ 10200',
        latitude: 13.7563,
        longitude: 100.4930,
      );

      final query = TripFilter.none
          .toFeedQuery(sort: FeedSort.popular, origin: origin)
          .toQuery();
      expect(query['lat'], 13.7563);
      expect(query['lng'], 100.4930);
      expect(query['sort'], 'popular');
    });
  });
}
