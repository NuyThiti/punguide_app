import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/search/presentation/search_screen.dart';

import 'support/home_feed_fixtures.dart';

Widget _harness(List<TripListItem> trips, {String? query}) {
  return ProviderScope(
    overrides: homeOverrides(trips),
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.search.name,
            builder: (_, __) => SearchScreen(initialQuery: query),
          ),
        ],
      ),
    ),
  );
}

final _trips = <TripListItem>[
  feedTrip(id: 'lpq'),
  feedTrip(
    id: 'cnx',
    title: 'เชียงใหม่ 2 วัน 1 คืน',
    destination: 'เชียงใหม่, ไทย',
    country: 'ไทย',
    durationDays: 2,
    totalBudget: 550,
    creatorName: 'thitichaya',
    likeCount: 9,
  ),
];

void main() {
  setUp(() {
    // A phone viewport, so the two-column wall is laid out the way it ships.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('an empty field browses instead of showing zero results',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(_trips));
    await tester.pumpAndSettle();

    expect(find.text('ค้นหาเมือง ประเทศ หรือชื่อทริป'), findsOneWidget);
    expect(find.text('จุดหมายยอดนิยม'), findsOneWidget);
    expect(find.text('กำลังมาแรง'), findsOneWidget);
    // No query yet, so neither the sort chips nor a count are on screen.
    expect(find.text('แนะนำ'), findsNothing);
    expect(find.textContaining('พบ '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing narrows the wall to the matching trips', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(_trips));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'เชียงใหม่');
    await tester.pumpAndSettle();

    expect(find.text('พบ 1 ทริป'), findsOneWidget);
    expect(find.text('เชียงใหม่ 2 วัน 1 คืน'), findsOneWidget);
    expect(find.text('หลวงพระบาง 3 วัน 2 คืน'), findsNothing);
  });

  testWidgets(
      'a query matches the creator and the country too, not just the title',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(_trips));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'makitravels');
    await tester.pumpAndSettle();
    expect(find.text('พบ 1 ทริป'), findsOneWidget);
    expect(find.text('หลวงพระบาง 3 วัน 2 คืน'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ลาว');
    await tester.pumpAndSettle();
    expect(find.text('พบ 1 ทริป'), findsOneWidget);
  });

  testWidgets('a query with no match explains itself', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(_trips));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('ไม่พบทริปสำหรับ "zzz"'), findsOneWidget);
    expect(find.textContaining('พบ '), findsNothing);
  });

  testWidgets('?q= prefills the field, runs the search and lands in recents',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(_trips, query: 'ไทย'));
    await tester.pumpAndSettle();

    expect(find.text('พบ 1 ทริป'), findsOneWidget);

    // Clearing falls back to browse, where the query is now a recent chip.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('ค้นหาล่าสุด'), findsOneWidget);
    // "ไทย" is also a popular-destination card, so pin the assertion to the
    // one chip that carries the history icon.
    expect(
      find.descendant(
        of: find
            .ancestor(
              of: find.byIcon(Icons.history),
              matching: find.byType(Row),
            )
            .first,
        matching: find.text('ไทย'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the sort row stays put while the results scroll',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Enough rows that the wall is taller than the frame.
    final many = <TripListItem>[
      for (var i = 0; i < 10; i++)
        feedTrip(id: 'trip-$i', title: 'ทริปทดสอบ $i วัน'),
    ];

    await tester.pumpWidget(_harness(many));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'วัน');
    await tester.pumpAndSettle();

    final sortChip = find.text('แนะนำ');
    expect(sortChip, findsOneWidget);
    final before = tester.getTopLeft(sortChip);

    // Scroll the result wall, not the chip strip.
    await tester.drag(find.text('พบ 10 ทริป'), const Offset(0, -400));
    await tester.pumpAndSettle();

    // The count scrolled away; the sort row did not move.
    expect(find.text('พบ 10 ทริป'), findsNothing);
    expect(sortChip, findsOneWidget);
    expect(tester.getTopLeft(sortChip), before);
  });

  testWidgets('the sort chips reorder the same results', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(_trips));
    await tester.pumpAndSettle();

    // "วัน" is in both titles, so both rows survive the filter.
    await tester.enterText(find.byType(TextField), 'วัน');
    await tester.pumpAndSettle();
    expect(find.text('พบ 2 ทริป'), findsOneWidget);

    // Relevance ties on both titles, so the better-liked trip leads.
    final chiangMai = find.text('เชียงใหม่ 2 วัน 1 คืน');
    final luangPrabang = find.text('หลวงพระบาง 3 วัน 2 คืน');
    expect(
      tester.getTopLeft(luangPrabang).dx,
      lessThan(tester.getTopLeft(chiangMai).dx),
    );

    // The last chip is built but sits past the right edge of the frame, so it
    // has to be scrolled into reach before it can be tapped.
    await tester.drag(find.text('แนะนำ'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('งบน้อยสุด'));
    await tester.pumpAndSettle();

    // ฿550 beats ฿3,000, so the cheaper trip takes over the left column.
    expect(find.text('พบ 2 ทริป'), findsOneWidget);
    expect(
      tester.getTopLeft(chiangMai).dx,
      lessThan(tester.getTopLeft(luangPrabang).dx),
    );
    expect(tester.takeException(), isNull);
  });
}
