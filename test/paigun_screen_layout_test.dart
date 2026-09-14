import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/paigun/presentation/paigun_screen.dart';
import 'package:pluno/features/paigun/presentation/widgets/paigun_card.dart';
import 'package:pluno/features/paigun/presentation/widgets/paigun_filter_bar.dart';

import 'support/fake_api.dart';
import 'support/home_feed_fixtures.dart';

Widget _harness(FakeAdapter adapter) {
  return ProviderScope(
    overrides: paigunOverrides(adapter),
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.paigun.name,
            builder: (_, __) => const PaigunScreen(),
          ),
        ],
      ),
    ),
  );
}

/// Rows as the server hands them over: already ordered, and already measured
/// against the coordinates the request carried. The third has no `distanceKm`
/// at all, which is what comes back for a destination the backend has not
/// resolved to a real place.
final _rows = <Map<String, dynamic>>[
  feedTripJson(
    id: 'bkk',
    title: 'เที่ยวย่านพระนคร เก็บโฮสเทล',
    destination: 'Phra Nakhon, Thai',
    country: 'ไทย',
    durationDays: 1,
    totalBudget: 200,
    creatorName: 'BKKwalker',
    likeCount: 2000,
    remixCount: 3500,
    distanceKm: 1.1,
  ),
  feedTripJson(
    id: 'nan',
    title: 'น่าน 3 วัน 2 คืน',
    destination: 'น่าน',
    country: 'ไทย',
    durationDays: 3,
    totalBudget: 550,
    creatorName: 'BKKwalker',
    likeCount: 10,
    remixCount: 5,
    distanceKm: 549,
  ),
  feedTripJson(id: 'lpq'),
];

void _phone(WidgetTester tester, {double height = 852}) {
  tester.view.physicalSize = Size(393 * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('paigun renders the header, chips and cards without overflow',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(feedAdapter(_rows)));
    await tester.pumpAndSettle();

    expect(find.text('ไปกัน'), findsOneWidget);
    expect(find.text('ตำแหน่งของฉัน'), findsOneWidget);
    expect(find.text('เขตพระนคร, กรุงเทพ 10200'), findsOneWidget);
    expect(find.text('ทั้งหมด'), findsOneWidget);
    // Each appears twice with ทั้งหมด selected: once as a chip, once as a
    // section heading.
    expect(find.text('Near Me'), findsNWidgets(2));
    expect(find.text('Top PunGuide'), findsAtLeastNWidgets(2));
    expect(find.text('Paigun'), findsOneWidget);
    // The Top PunGuide wall sits below the fold; its heading builds once the
    // list is scrolled to it.
    expect(find.byType(PaigunSectionHeader), findsOneWidget);
  });

  testWidgets('the sort chips stay put while the wall scrolls', (tester) async {
    _phone(tester, height: 640);

    await tester.pumpWidget(
      _harness(
        feedAdapter([for (var i = 0; i < 10; i++) feedTripJson(id: 'trip-$i')]),
      ),
    );
    await tester.pumpAndSettle();

    // "ทั้งหมด" belongs to the chip row alone; "Near Me" is also a heading.
    final chip = find.text('ทั้งหมด');
    final heading = find.text('Near Me').last;
    expect(chip, findsOneWidget);
    final chipBefore = tester.getTopLeft(chip);
    final headingBefore = tester.getTopLeft(heading);

    // Drag the wall itself: the chip row is a horizontal ListView too, and
    // dragging that one vertically would scroll nothing.
    await tester.drag(heading, const Offset(0, -450));
    await tester.pumpAndSettle();

    // The wall moved; the chips did not.
    expect(tester.getTopLeft(heading).dy, lessThan(headingBefore.dy));
    expect(chip, findsOneWidget);
    expect(tester.getTopLeft(chip), chipBefore);
  });

  testWidgets('the distance chip prints what the server measured',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(feedAdapter(_rows)));
    await tester.pumpAndSettle();

    expect(find.text('549 Km'), findsWidgets);
    expect(find.text('1.1 Km'), findsWidgets);
    // A row the server could not measure keeps its card and simply has no
    // chip — never a "0 Km".
    expect(find.text('หลวงพระบาง 3 วัน 2 คืน'), findsWidgets);
    expect(find.textContaining('0 Km'), findsNothing);
    // Duration and budget share one run of text under the divider.
    expect(find.textContaining('฿ ~200 /คน'), findsWidgets);
  });

  testWidgets('each wall asks the server for its own sort, measured from the '
      'traveller', (tester) async {
    _phone(tester);

    final adapter = feedAdapter(_rows);
    await tester.pumpWidget(_harness(adapter));
    await tester.pumpAndSettle();

    final queries = adapter.queriesOf('GET /trips');
    // ทั้งหมด shows both walls, so both questions go up — and both carry the
    // origin, because `distanceKm` is what puts the chip on a card.
    expect(
      queries.map((query) => query['sort']),
      containsAll(<String>['nearest', 'popular']),
    );
    for (final query in queries) {
      expect(query['lat'], 13.7563);
      expect(query['lng'], 100.4930);
      // Nothing was answered in the wizard, so nothing else may be sent: the
      // endpoint rejects a key it does not know.
      expect(query.keys.toSet(), <String>{'lat', 'lng', 'sort'});
    }
  });

  testWidgets('the Near Me chip leaves one wall, in the order it arrived',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(feedAdapter(_rows)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Near Me').first);
    await tester.pumpAndSettle();

    // One wall, not two: every card on the page belongs to Near Me.
    expect(find.byType(PaigunCard), findsNWidgets(_rows.length));
    expect(find.byType(PaigunSectionHeader), findsOneWidget);

    // The board does not re-sort what the server ordered. The wall is two
    // columns, so the first row lands top-left.
    final nearest = tester.getTopLeft(find.text('เที่ยวย่านพระนคร เก็บโฮสเทล'));
    final further = tester.getTopLeft(find.text('น่าน 3 วัน 2 คืน'));
    expect(nearest.dy, lessThanOrEqualTo(further.dy));
    expect(nearest.dx, lessThan(further.dx));
  });
}
