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

/// The board with the sheet behind its ตัวกรอง control, so a test can walk the
/// real route rather than pumping the sheet on its own.
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

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.tune));
  await tester.pumpAndSettle();
}

/// Brings something below the fold into the sheet's viewport.
///
/// The list is lazy, so a question far down it has no element at all until it
/// is scrolled to — `ensureVisible` would throw on nothing.
Future<void> _scrollSheetTo(WidgetTester tester, Finder target) async {
  final list = find.descendant(
    of: find.byType(PaigunFilterScreen),
    matching: find.byType(ListView),
  );

  for (var attempt = 0; attempt < 10; attempt++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(list, const Offset(0, -220));
    await tester.pumpAndSettle();
  }
}

/// Tap something inside the sheet, scrolling to it first: a tap on a clipped
/// widget lands on the apply bar instead.
Future<void> _tapInSheet(WidgetTester tester, Finder target) async {
  await _scrollSheetTo(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  group('the sheet', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: paigunOverrides(feedAdapter([feedTripJson(id: 'lpq')])),
      );
    });

    tearDown(() => container.dispose());

    testWidgets('asks every question on one scroll', (tester) async {
      _phone(tester);

      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();
      await _openSheet(tester);

      expect(find.text('ตัวกรอง'), findsOneWidget);
      expect(find.text('รูปแบบโพสที่จะเห็น'), findsOneWidget);
      expect(find.text('วันที่เดินทาง'), findsOneWidget);
      expect(find.text('จำนวนผู้ร่วมทริป'), findsOneWidget);
      expect(find.text('งบประมาณต่อคน'), findsOneWidget);

      // The last two sit below the fold until the sheet is scrolled.
      await _scrollSheetTo(tester, find.text('สไตล์การเที่ยว'));
      expect(find.text('รัศมีสถานที่ห่างจากฉัน'), findsOneWidget);
      expect(find.text('ไม่จำกัด'), findsOneWidget);
      expect(find.text('ธรรมชาติ'), findsOneWidget);
      expect(find.text('+ เพิ่ม'), findsOneWidget);
    });

    testWidgets('opens on the answers already in force', (tester) async {
      _phone(tester);

      container.read(tripFilterProvider.notifier).state =
          const TripFilter(styles: ['ทะเล'], adults: 2, radiusKm: 25);
      container.read(paigunFilterProvider.notifier).state = PaigunFilter.guide;

      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();
      await _openSheet(tester);

      // The head count reads back…
      expect(find.text('2'), findsOneWidget);
      // …and so does the board's own chip row, which is this sheet's first
      // question rather than a second control.
      await _scrollSheetTo(tester, find.text('25 Km.'));
      expect(find.text('25 Km.'), findsOneWidget);
    });

    testWidgets('changes nothing until ตกลง', (tester) async {
      _phone(tester);

      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();
      await _openSheet(tester);

      await _tapInSheet(tester, find.text('ธรรมชาติ'));
      await _tapInSheet(tester, find.text('10 Km.'));

      // Still nothing behind the sheet.
      expect(container.read(tripFilterProvider).isEmpty, isTrue);

      // Backing out leaves the board exactly as it was found. The sheet has
      // its own back disc rather than a Material app bar, so `pageBack` has
      // nothing to find.
      await tester.tap(
        find.descendant(
          of: find.byType(PaigunFilterScreen),
          matching: find.byIcon(Icons.chevron_left),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(tripFilterProvider).isEmpty, isTrue);
      expect(find.text('ไปกัน'), findsOneWidget);
    });

    testWidgets('ตกลง applies the answers and the type chip together',
        (tester) async {
      _phone(tester);

      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();
      await _openSheet(tester);

      await _tapInSheet(tester, find.text('คู่มือ'));
      await _tapInSheet(tester, find.text('ธรรมชาติ'));
      await _tapInSheet(tester, find.text('10 Km.'));
      await _tapInSheet(tester, find.text('ตกลง'));

      final applied = container.read(tripFilterProvider);
      expect(applied.styles, <String>['ธรรมชาติ']);
      expect(applied.radiusKm, 10);
      expect(container.read(paigunFilterProvider), PaigunFilter.guide);
      // And it lands back on the board, which now says two questions narrow it.
      expect(find.text('ไปกัน'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('ล้างตัวกรอง wipes the sheet, not the board behind it',
        (tester) async {
      _phone(tester);

      container.read(tripFilterProvider.notifier).state =
          const TripFilter(styles: ['ทะเล']);

      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();
      await _openSheet(tester);

      await tester.tap(find.text('ล้างตัวกรอง'));
      await tester.pumpAndSettle();

      // The board keeps its answer until ตกลง says otherwise.
      expect(container.read(tripFilterProvider).styles, <String>['ทะเล']);

      await _tapInSheet(tester, find.text('ตกลง'));
      expect(container.read(tripFilterProvider).isEmpty, isTrue);
    });
  });

  group('TripFilter.toFeedQuery', () {
    Map<String, dynamic> queryOf(TripFilter filter) =>
        filter.toFeedQuery(sort: FeedSort.nearest).toQuery()
          ..removeWhere((_, value) => value == null);

    test('a chip with an enum goes up as a wire value, one without as text',
        () {
      const filter = TripFilter(styles: ['ทะเล', 'คาเฟ่', 'อิสลาม']);

      final query = queryOf(filter);
      expect(query['styles'], 'beach,cafe');
      // A chip product added without waiting for a backend enum.
      expect(query['customStyles'], 'อิสลาม');
    });

    test('a date window is a window plus a ceiling, not a length', () {
      final filter = TripFilter(
        startDate: DateTime(2026, 9, 28),
        endDate: DateTime(2026, 9, 30),
      );

      final query = queryOf(filter);
      expect(query['dateFrom'], '2026-09-28');
      expect(query['dateTo'], '2026-09-30');
      // "What fits in these three days" — an exact durationDays would throw
      // away the two-day trips the sheet means to keep.
      expect(query['maxDurationDays'], 3);
      expect(query.containsKey('durationDays'), isFalse);
    });

    test('a window with only a start reads as that single day', () {
      final filter = TripFilter(startDate: DateTime(2026, 9, 28));

      final query = queryOf(filter);
      expect(query['dateFrom'], '2026-09-28');
      expect(query['dateTo'], '2026-09-28');
      expect(query['maxDurationDays'], 1);
    });

    test('the budget slider goes up as typed, per person', () {
      const filter = TripFilter(adults: 2, children: 1, budgetPerPerson: 2500);

      final query = queryOf(filter);
      expect(query['budgetMax'], 2500);
      // The server divides the trip's own budget by the trip's own head
      // count, so the figure must not be pre-multiplied here.
      expect(query['budgetScope'], 'per_person');
      expect(query['adults'], 2);
      expect(query['children'], 1);
    });

    test('a slider left on the ceiling is not a budget answer', () {
      const filter = TripFilter(budgetPerPerson: TripFilter.budgetCeiling);

      expect(filter.hasBudget, isFalse);
      expect(queryOf(filter).containsKey('budgetMax'), isFalse);
    });

    test('a radius goes up only alongside the coordinates it measures from',
        () {
      const origin = PaigunOrigin(
        label: 'ตำแหน่งของฉัน',
        address: 'เขตพระนคร, กรุงเทพ 10200',
        latitude: 13.7563,
        longitude: 100.4930,
      );
      const filter = TripFilter(radiusKm: 25);

      final located = filter
          .toFeedQuery(sort: FeedSort.nearest, origin: origin)
          .toQuery();
      expect(located['radiusKm'], 25);
      expect(located['lat'], 13.7563);

      // Half a fix measures nothing, so the server is given neither — and a
      // radius around nowhere would silently hide every trip.
      expect(queryOf(filter).containsKey('radiusKm'), isFalse);
    });

    test('an untouched sheet asks for nothing but the wall it is on', () {
      // Zero heads would read as "planned for at least nobody", and the
      // endpoint rejects any key it does not know — so an unanswered row has
      // to be absent, not empty.
      expect(queryOf(TripFilter.none).keys, <String>['sort']);
    });

    test('the board\'s own controls ride along on the same request', () {
      final query = TripFilter.none
          .toFeedQuery(
            sort: FeedSort.popular,
            type: TripType.content,
            query: 'คาเฟ่',
          )
          .toQuery();

      expect(query['type'], 'content');
      expect(query['q'], 'คาเฟ่');
      expect(query['sort'], 'popular');
    });
  });
}
