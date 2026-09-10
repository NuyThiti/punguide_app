import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/home/presentation/home_screen.dart';

import 'support/home_feed_fixtures.dart';

Widget _harness(List<TripListItem> trips) {
  return ProviderScope(
    overrides: homeOverrides(trips),
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.home.name,
            builder: (_, __) => const HomeScreen(),
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
  ),
];

void main() {
  testWidgets('home renders the feed without overflow on a phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(_trips));
    await tester.pumpAndSettle();

    expect(find.text('PunGuide'), findsOneWidget);
    expect(find.text('วันนี้อยากไปหรือปัน ?'), findsOneWidget);
    expect(find.text('ไปกัน'), findsOneWidget);
    expect(find.text('ปันไกด์'), findsOneWidget);
    // Each appears twice: once as a filter chip, once as a section heading.
    expect(find.text('Top Destination'), findsNWidgets(2));
    expect(find.text('Top PunGuide'), findsNWidgets(2));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Paigun'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Puntok'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text(_trips.first.title), findsOneWidget);
    expect(find.text('makitravels'), findsOneWidget);
  });

  testWidgets('the destination rail is derived from the feed', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(_trips));
    await tester.pumpAndSettle();

    // One card per country the feed mentions, not a hardcoded list.
    expect(find.text('ลาว'), findsOneWidget);
    expect(find.text('ไทย'), findsOneWidget);
    expect(find.text('ญี่ปุ่น'), findsNothing);
  });

  testWidgets('a row with no cover, schedule or creator still renders',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness([
        feedTrip(
          id: 'bare',
          title: 'ทริปที่ยังไม่มีข้อมูลครบ',
          country: null,
          durationDays: null,
          totalBudget: 0,
          coverUrl: null,
          creatorName: null,
          remixCount: 0,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('ทริปที่ยังไม่มีข้อมูลครบ'), findsOneWidget);
    expect(find.text('ผู้ใช้ที่ถูกลบ'), findsOneWidget);
    // No remixes means no badge.
    expect(find.text('Top Remix'), findsNothing);
  });

  testWidgets('home lays out on a narrow phone without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(_trips));
    await tester.pumpAndSettle();

    // Scroll the PunGuide grid fully into view so every tile gets laid out.
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Top PunGuide'), findsWidgets);
  });

  testWidgets('a two-line trip title still fits its grid tile', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const longTitle = 'ทริปหลวงพระบางสายชิล เที่ยวครบ 3 วัน 2 คืน';
    await tester.pumpWidget(
      _harness([
        feedTrip(id: 'a', title: longTitle),
        feedTrip(id: 'b', title: longTitle),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text(longTitle), findsWidgets);
  });

  testWidgets('home renders an empty state when the feed is empty',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(const []));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีทริป'), findsOneWidget);
    // With no trips there is nothing to derive a destination rail from.
    expect(find.text('Top Destination'), findsOneWidget);
  });
}
