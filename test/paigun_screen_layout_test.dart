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
/// against the coordinates the request carried. A measured row always carries
/// the resolved place the measurement was made against — the last one has
/// neither, which is what comes back for a destination still held as free
/// text.
final _rows = <Map<String, dynamic>>[
  feedTripJson(
    id: 'bkk',
    title: 'เที่ยวย่านพระนคร เก็บโฮสเทล',
    destination: 'Phra Nakhon, Thai',
    country: 'ไทย',
    latitude: 13.7465,
    longitude: 100.4927,
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
    latitude: 18.6848,
    longitude: 100.8000,
    durationDays: 3,
    totalBudget: 550,
    creatorName: 'BKKwalker',
    likeCount: 10,
    remixCount: 5,
    distanceKm: 549,
  ),
  feedTripJson(id: 'lpq'),
  feedTripJson(
    id: 'post',
    type: 'content',
    title: 'เดินเล่นเมืองเก่าภูเก็ต',
    destination: 'ภูเก็ต',
    country: null,
    // A post carries neither of these, and the card must not print the trip
    // it describes as if they were the post's own.
    durationDays: 2,
    totalBudget: 4000,
    placeCount: 5,
    creatorName: 'BKKwalker',
    // A post has no resolved place of its own; the server measures it from
    // the nearest located section of its contents.
    distanceKm: 680,
  ),
];

/// A chip in the filter bar, not the same word printed on a card.
Finder _chip(String label) => find.descendant(
      of: find.byType(PaigunFilterBar),
      matching: find.text(label),
    );

/// Brings a chip into the row's viewport.
///
/// The row is a lazy horizontal list, so the last chip has no element at all
/// until it is scrolled to — `ensureVisible` would throw on nothing, and a tap
/// on a clipped chip lands on whatever is under it.
Future<void> _revealChip(WidgetTester tester, String label) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    if (_chip(label).evaluate().isNotEmpty) {
      await tester.ensureVisible(_chip(label));
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(find.byType(PaigunFilterBar), const Offset(-160, 0));
    await tester.pumpAndSettle();
  }
}

Future<void> _tapChip(WidgetTester tester, String label) async {
  await _revealChip(tester, label);
  await tester.tap(_chip(label));
  await tester.pumpAndSettle();
}

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
    // One line for the origin now — the caption above it said nothing the pin
    // did not already say — and the search box under it.
    expect(find.text('เขตพระนคร, กรุงเทพ 10200'), findsOneWidget);
    expect(find.text('ตำแหน่งของฉัน'), findsNothing);
    expect(find.text('สถานที่ใกล้คุณ'), findsOneWidget);

    // Four chips over one wall, with ตัวกรอง at the head of the row. Scoped
    // to the bar: a card wears its own type pill reading "คู่มือ" too.
    for (final label in const ['ทั้งหมด', 'คู่มือ', 'แผนทริป']) {
      expect(_chip(label), findsOneWidget, reason: label);
    }
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.text('Paigun'), findsOneWidget);
    // The fourth chip sits past the fold of a scrolling row — asserted last,
    // because reaching it carries ตัวกรอง off the other end.
    await _revealChip(tester, 'Top PunGuide');
    expect(_chip('Top PunGuide'), findsOneWidget);
    // One wall under one row of chips — the headings the two walls used to
    // carry are gone with them.
    expect(find.text('Near Me'), findsNothing);
  });

  testWidgets('the sort chips stay put while the wall scrolls', (tester) async {
    _phone(tester, height: 640);

    await tester.pumpWidget(
      _harness(
        feedAdapter([for (var i = 0; i < 10; i++) feedTripJson(id: 'trip-$i')]),
      ),
    );
    await tester.pumpAndSettle();

    final chip = find.text('ทั้งหมด');
    final heading = find.text('หลวงพระบาง 3 วัน 2 คืน').first;
    expect(chip, findsOneWidget);
    final chipBefore = tester.getTopLeft(chip);
    final headingBefore = tester.getTopLeft(heading);

    // Drag a card, not the chips: the chip row is a horizontal ListView too,
    // and dragging that one vertically would scroll nothing.
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
    // Exact, not `textContaining`: a genuine "680 Km" contains "0 Km" too.
    expect(find.text('0 Km'), findsNothing);
    // Duration and budget share one run of text under the divider.
    expect(
      find.textContaining('฿ 200 /คน', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('a post prints its places where a plan prints days and budget',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(feedAdapter(_rows)));
    await tester.pumpAndSettle();

    // The post's own fact, not the schedule or budget of the trip it is about.
    expect(find.text('5 สถานที่'), findsWidgets);
    expect(
      find.textContaining('฿ 4,000', findRichText: true),
      findsNothing,
    );
    expect(find.textContaining('2 วัน'), findsNothing);
    // The plan beside it still reads as a plan.
    expect(
      find.textContaining('฿ 200 /คน', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('the board asks one question, measured from the traveller',
      (tester) async {
    _phone(tester);

    final adapter = feedAdapter(_rows);
    await tester.pumpWidget(_harness(adapter));
    await tester.pumpAndSettle();

    // One wall, one request — and it carries the origin, because `distanceKm`
    // is what puts the chip on a card.
    final queries = adapter.queriesOf('GET /trips');
    expect(queries, hasLength(1));
    // Nothing was answered in the wizard and nothing typed, so nothing else
    // may be sent: the endpoint rejects a key it does not know.
    expect(queries.single, <String, dynamic>{
      'lat': 13.7563,
      'lng': 100.4930,
      'sort': 'nearest',
    });
  });

  testWidgets('a type chip asks the server for that type, still nearest first',
      (tester) async {
    _phone(tester);

    final adapter = feedAdapter(_rows);
    await tester.pumpWidget(_harness(adapter));
    await tester.pumpAndSettle();

    await _tapChip(tester, 'คู่มือ');

    final guide = adapter.queriesOf('GET /trips').last;
    expect(guide['type'], 'content');
    // A type chip answers a different question from a sort, so the wall stays
    // nearest-first under it.
    expect(guide['sort'], 'nearest');

    await _tapChip(tester, 'แผนทริป');
    expect(adapter.queriesOf('GET /trips').last['type'], 'plan_trip');

    await _tapChip(tester, 'Top PunGuide');
    final top = adapter.queriesOf('GET /trips').last;
    expect(top['sort'], 'popular');
    // Top PunGuide re-orders rather than narrowing, so it names no type.
    expect(top.containsKey('type'), isFalse);
  });

  testWidgets('the search box narrows the wall by free text', (tester) async {
    _phone(tester);

    final adapter = feedAdapter(_rows);
    await tester.pumpWidget(_harness(adapter));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '  พระนคร  ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // Trimmed, and sent as `q` — which reads every word a trip shows, not
    // only where it goes — rather than taking the traveller to another screen.
    final searched = adapter.queriesOf('GET /trips').last;
    expect(searched['q'], 'พระนคร');
    expect(searched.containsKey('destination'), isFalse);
    expect(searched['sort'], 'nearest');
    expect(find.byType(PaigunCard), findsWidgets);
  });

  testWidgets('the wall keeps the order the server sent', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(feedAdapter(_rows)));
    await tester.pumpAndSettle();

    expect(find.byType(PaigunCard), findsNWidgets(_rows.length));

    // The board does not re-sort what the server ordered. The wall is two
    // columns, so the first row lands top-left.
    final nearest = tester.getTopLeft(find.text('เที่ยวย่านพระนคร เก็บโฮสเทล'));
    final further = tester.getTopLeft(find.text('น่าน 3 วัน 2 คืน'));
    expect(nearest.dy, lessThanOrEqualTo(further.dy));
    expect(nearest.dx, lessThan(further.dx));
  });
}
