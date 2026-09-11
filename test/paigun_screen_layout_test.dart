import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/paigun/presentation/paigun_screen.dart';
import 'package:pluno/features/paigun/presentation/widgets/paigun_card.dart';
import 'package:pluno/features/paigun/presentation/widgets/paigun_filter_bar.dart';
import 'package:pluno/features/home/presentation/providers/home_feed_providers.dart';
import 'package:pluno/features/paigun/presentation/providers/paigun_providers.dart';

import 'support/home_feed_fixtures.dart';

Widget _harness(List<TripListItem> trips) {
  return ProviderScope(
    overrides: homeOverrides(trips),
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

/// Two rows the origin can measure against — Wat Pho is a short walk from the
/// header's เขตพระนคร, Chiang Mai is several hundred kilometres off — plus one
/// the backend has not resolved coordinates for.
final _trips = <TripListItem>[
  feedTrip(
    id: 'cnx',
    title: 'เชียงใหม่ 2 วัน 1 คืน',
    destination: 'เชียงใหม่, ไทย',
    country: 'ไทย',
    latitude: 18.7883,
    longitude: 98.9853,
    durationDays: 2,
    totalBudget: 550,
    creatorName: 'BKKwalker',
    likeCount: 10,
    remixCount: 5,
  ),
  feedTrip(
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
  ),
  feedTrip(id: 'lpq'),
];

void main() {
  testWidgets('paigun renders the header, chips and cards without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(_trips));
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
    tester.view.physicalSize = const Size(393 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness([for (var i = 0; i < 10; i++) feedTrip(id: 'trip-$i')]),
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

  testWidgets('a card carries the distance from the traveller, when known',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(_trips));
    await tester.pumpAndSettle();

    // Wat Pho against the header's เขตพระนคร origin — roughly a kilometre.
    expect(find.text('1.1 Km'), findsWidgets);
    // The unresolved row keeps its card; it just has no chip to show.
    expect(find.text('หลวงพระบาง 3 วัน 2 คืน'), findsWidgets);
    // Duration and budget share one run of text under the divider.
    expect(find.textContaining('฿ ~200 /คน'), findsWidgets);
  });

  testWidgets('the Near Me chip drops the Top PunGuide wall and leads with the '
      'closest trip', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(_trips));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Near Me').first);
    await tester.pumpAndSettle();

    // One wall, not two: every card on the page belongs to Near Me.
    expect(find.byType(PaigunCard), findsNWidgets(_trips.length));
    expect(find.byType(PaigunSectionHeader), findsOneWidget);

    // The wall is two columns, so "first" is the top-left slot.
    final nearest = tester.getTopLeft(find.text('เที่ยวย่านพระนคร เก็บโฮสเทล'));
    final furthest = tester.getTopLeft(find.text('เชียงใหม่ 2 วัน 1 คืน'));
    expect(nearest.dy, lessThanOrEqualTo(furthest.dy));
    expect(nearest.dx, lessThan(furthest.dx));
  });

  test('rows without resolved coordinates keep their place at the end',
      () async {
    final container = ProviderContainer(overrides: homeOverrides(_trips));
    addTearDown(container.dispose);

    // The stub feed resolves synchronously, but the notifier still has to
    // build before the derived lists have anything to order.
    await container.read(homeFeedProvider.future);

    final rows = container.read(nearMeTripsProvider).requireValue;
    expect(rows.map((row) => row.trip.id), <String>['bkk', 'cnx', 'lpq']);
    expect(rows.last.distanceKm, isNull);
    expect(rows.last.distanceLabel, isNull);

    final top = container.read(topPunGuideTripsProvider).requireValue;
    // Ranked on remixes plus likes, so the 3.5K/2K row leads however far away
    // it is.
    expect(top.map((row) => row.trip.id), <String>['bkk', 'lpq', 'cnx']);
    expect(top.every((row) => row.featured), isTrue);
  });
}
