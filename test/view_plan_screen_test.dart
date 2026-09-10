import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/core/theme/app_colors.dart';
import 'package:pluno/features/trip_detail/presentation/trip_detail_screen.dart';
import 'package:pluno/features/trips/presentation/providers/trip_providers.dart';
import 'package:pluno/shared/layout/screen_class.dart';

import 'support/fake_api.dart';

late FakeAdapter adapter;

/// Three stops over two days, a group of three, and counts big enough to be
/// worth grouping — enough for every figure the design prints.
Map<String, dynamic> _tripJson({
  List<Map<String, dynamic>>? days,
  Map<String, dynamic>? schedule,
  Map<String, dynamic>? customer,
  num totalBudget = 9000,
}) =>
    <String, dynamic>{
      'id': 'trip-1',
      'ownerId': 'u1',
      'title': 'ทริปหลวงพระบางสายชิล',
      'destination': 'Luang Prabang, Laos',
      'status': 'published',
      'schedule': schedule ??
          <String, dynamic>{
            'startDate': '2026-08-20',
            'endDate': '2026-08-22',
            'durationDays': 3,
            'durationNights': 2,
          },
      'totalBudget': totalBudget,
      'brief': <String, dynamic>{
        'styles': <String>['culture', 'food'],
      },
      'customer': customer ??
          <String, dynamic>{
            'id': 'u1',
            'name': 'makitravels',
            'groupSize': 3,
          },
      'visibility': 'public',
      'isSaved': false,
      'isLiked': false,
      'likeCount': 1721,
      'remixCount': 1111,
      'days': days ?? _twoDays(),
      'createdAt': '2026-09-10T00:00:00.000Z',
      'updatedAt': '2026-09-10T00:00:00.000Z',
    };

/// วันที่ 1 has two stops — the first with nothing to travel from, the second
/// reached by bicycle. The first stop's place name repeats its title.
List<Map<String, dynamic>> _twoDays() => [
      <String, dynamic>{
        'id': 'd1',
        'dayNumber': 1,
        'date': '2026-08-20',
        'activities': <Map<String, dynamic>>[
          {
            'id': 's1',
            'title': 'Le Banneton Café',
            'category': 'food',
            'order': 0,
            'time': '12:30',
            'cost': 0,
            'notes': 'ร้านเบเกอรี่เก่าแก่ของหลวงพระบาง',
            'location': {'name': 'Le Banneton Café'},
          },
          {
            'id': 's2',
            'title': 'ตลาดมืด',
            'category': 'sightseeing',
            'order': 1,
            'time': '18:00',
            'cost': 0,
            'location': {'name': 'ถนน Sisavangvong'},
            'travelFromPrevious': {'type': 'bicycle', 'durationMin': 8},
          },
        ],
        'travelSegments': const <Map<String, dynamic>>[],
      },
      <String, dynamic>{
        'id': 'd2',
        'dayNumber': 2,
        'date': '2026-08-21',
        'activities': <Map<String, dynamic>>[
          {
            'id': 's3',
            'title': 'น้ำตกกวางสี',
            'category': 'activity',
            'order': 0,
            'time': '10:00',
            'cost': 0,
          },
        ],
        'travelSegments': const <Map<String, dynamic>>[],
      },
    ];

/// The signed-in account, or null for a visitor. `ownerId` on the stub trip is
/// `u1`, so a viewer with that id owns it.
Widget _harness({AuthUser? viewer, bool viewerPending = false}) =>
    ProviderScope(
      overrides: [
        plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
        // The saved flag comes from the local Isar list, which a widget test
        // has no database for.
        selectedTripProvider.overrideWith((ref, tripId) async => null),
        currentUserProvider.overrideWith(
          (ref) => viewerPending
              ? Completer<AuthUser?>().future
              : Future<AuthUser?>.value(viewer),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              name: AppRoute.tripDetail.name,
              builder: (_, __) => const TripDetailScreen(tripId: 'trip-1'),
            ),
            GoRoute(
              path: '/remix/:tripId',
              name: AppRoute.remixTrip.name,
              builder: (_, __) => const Scaffold(body: Text('remix page')),
            ),
            GoRoute(
              path: '/home',
              name: AppRoute.home.name,
              builder: (_, __) => const Scaffold(body: Text('home page')),
            ),
            GoRoute(
              path: '/edit/:tripId',
              name: AppRoute.editTrip.name,
              builder: (_, __) => const Scaffold(body: Text('editor page')),
            ),
          ],
        ),
      ),
    );

Future<void> _pumpTrip(
  WidgetTester tester, {
  Map<String, dynamic>? trip,
  int status = 200,
  AuthUser? viewer,
  bool viewerPending = false,
}) async {
  adapter = FakeAdapter({
    'GET /trips/trip-1': [FakeReply(status, trip ?? _tripJson())],
  });
  await tester.pumpWidget(
    _harness(viewer: viewer, viewerPending: viewerPending),
  );
  await tester.pumpAndSettle();
}

/// The trip's own owner, `u1`.
const _owner = AuthUser(id: 'u1', username: 'makitravels');

/// Somebody else entirely.
const _visitor = AuthUser(id: 'u2', username: 'someone');

/// Every control the design draws that has nothing to call yet, against the
/// message it must own up with.
final _unwired = <String, Finder Function()>{
  'แชร์ทริปยังไม่เปิดใช้งาน': () => find.byTooltip('แชร์'),
  'ติดตามยังไม่เปิดใช้งาน': () => find.text('ติดตาม'),
  'เพิ่มลงแผนของฉันยังไม่เปิดใช้งาน': () =>
      find.byTooltip('เพิ่มลงแผนของฉัน').first,
  'บันทึกสถานที่ยังไม่เปิดใช้งาน': () => find.text('บันทึก').first,
  'ดูบนแผนที่ยังไม่เปิดใช้งาน': () => find.text('Map').first,
};

void main() {
  setUp(() {
    adapter = FakeAdapter({});
  });

  testWidgets('the hero prints the trip\'s own facts, not a sample',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    expect(find.text('ทริปหลวงพระบางสายชิล'), findsOneWidget);
    expect(find.text('Luang Prabang, Laos'), findsOneWidget);
    expect(find.text('3 วัน 2 คืน'), findsOneWidget);
    // Three stops across the two days.
    expect(find.text('3 สถานที่'), findsOneWidget);
    // ฿9,000 over a group of three.
    expect(find.text('฿3,000 /คน'), findsOneWidget);
    expect(find.text('makitravels'), findsOneWidget);
    expect(find.text('Remix Trip'), findsOneWidget);
  });

  testWidgets('nothing is left of the hardcoded English mock', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    // The page used to invent these by string-matching the title.
    for (final invented in [
      'Sofia Chen',
      '@sofiatravel',
      'Pluno',
      '@pluno',
      'Arrival & First Look',
      'Golden hour walk',
      '2 people',
      '1.2k',
    ]) {
      expect(find.text(invented), findsNothing, reason: invented);
    }
  });

  testWidgets('Trip Overview carries the real counts, grouped',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    expect(find.text('Trip Overview'), findsOneWidget);
    expect(find.text('1,111'), findsOneWidget);
    expect(find.text('1,721'), findsOneWidget);
  });

  testWidgets('a stop shows its time, name, leg and note', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1100 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    expect(find.text('12:30 PM'), findsOneWidget);
    expect(find.text('Le Banneton Café'), findsOneWidget);
    expect(find.text('ร้านเบเกอรี่เก่าแก่ของหลวงพระบาง'), findsOneWidget);
    // Second stop: the traveller's own leg.
    expect(find.text('จักรยาน • 8 นาที'), findsOneWidget);
    // First stop has nothing to travel from, so it falls back to its category.
    expect(find.text('ร้านอาหาร'), findsOneWidget);
  });

  testWidgets('a place name that repeats the stop title is not shown twice',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1100 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    // s1's location.name equals its title; s2's differs and does show.
    expect(find.text('Le Banneton Café'), findsOneWidget);
    expect(find.text('ถนน Sisavangvong'), findsOneWidget);
  });

  testWidgets('the day tabs swap which stops are listed', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1100 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    expect(find.text('วันที่ 1'), findsOneWidget);
    expect(find.text('วันที่ 2'), findsOneWidget);
    // The strip is read-only — adding a day belongs to the editor.
    expect(find.text('เพิ่มวัน'), findsNothing);
    expect(find.text('Le Banneton Café'), findsOneWidget);
    expect(find.text('น้ำตกกวางสี'), findsNothing);

    await tester.tap(find.text('วันที่ 2'));
    await tester.pumpAndSettle();

    expect(find.text('น้ำตกกวางสี'), findsOneWidget);
    expect(find.text('Le Banneton Café'), findsNothing);
  });

  // One test per control, not one loop: `ScaffoldMessenger` keeps its state
  // across `pumpWidget` when the tree shape is unchanged, so a loop would
  // still be showing the previous control's SnackBar.
  _unwired.forEach((message, locate) {
    testWidgets('$message reports that it is not wired', (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 1100 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await _pumpTrip(tester);

      final target = locate();
      expect(target, findsOneWidget);
      // Some of these sit inside a scroll view, off the edge at this width.
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pump();

      expect(find.text(message), findsOneWidget);
    });
  });

  testWidgets('Remix Trip leaves for the remix route', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    await tester.tap(find.text('Remix Trip'));
    await tester.pumpAndSettle();

    expect(find.text('remix page'), findsOneWidget);
  });

  testWidgets('the action bar is pinned, not carried by the hero',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    final bar = find.byKey(const Key('plan-action-bar'));
    expect(bar, findsOneWidget);
    final barBefore = tester.getRect(bar);
    final overviewBefore = tester.getTopLeft(find.text('Trip Overview'));

    await tester.drag(find.text('Trip Overview'), const Offset(0, -300));
    await tester.pumpAndSettle();

    // The page scrolled under it; the bar did not move.
    expect(
      tester.getTopLeft(find.text('Trip Overview')).dy,
      lessThan(overviewBefore.dy),
    );
    expect(tester.getRect(bar), barBefore);
  });

  testWidgets('the action bar paints to the bottom edge under a notch',
      (tester) async {
    const inset = 34.0;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(bottom: inset * 3);
    tester.view.viewPadding = const FakeViewPadding(bottom: inset * 3);
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    final screenBottom = tester.getRect(find.byType(MaterialApp).first).bottom;

    // The painted panel, not the button: a SafeArea around the bar leaves the
    // button in exactly the same place and only the panel short of the edge,
    // so asserting on the label would prove nothing.
    expect(
      tester.getRect(find.byKey(const Key('plan-action-bar'))).bottom,
      screenBottom,
    );
    // …while the label still clears the home indicator.
    expect(
      tester.getRect(find.text('Remix Trip')).bottom,
      lessThan(screenBottom - inset),
    );
  });

  testWidgets('a trip that failed to load gets no action bar', (tester) async {
    await _pumpTrip(tester, trip: <String, dynamic>{}, status: 404);

    expect(find.text('ไม่พบทริปนี้'), findsOneWidget);
    expect(find.byKey(const Key('plan-action-bar')), findsNothing);
  });

  testWidgets("the owner gets an orange แก้ไข instead of Remix",
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester, viewer: _owner);

    expect(find.text('แก้ไข'), findsOneWidget);
    expect(find.text('Remix Trip'), findsNothing);

    final button = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const Key('plan-action-bar')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.brandOrange,
    );
  });

  testWidgets('แก้ไข opens the plan editor', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester, viewer: _owner);
    await tester.tap(find.text('แก้ไข'));
    await tester.pumpAndSettle();

    expect(find.text('editor page'), findsOneWidget);
  });

  testWidgets("somebody else's plan still offers Remix", (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester, viewer: _visitor);

    expect(find.text('Remix Trip'), findsOneWidget);
    expect(find.text('แก้ไข'), findsNothing);
  });

  testWidgets('a signed-out visitor gets Remix, not แก้ไข', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    expect(find.text('Remix Trip'), findsOneWidget);
    expect(find.text('แก้ไข'), findsNothing);
  });

  testWidgets('no bar at all until it is known who is looking',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // The trip has loaded but `/auth/me` has not answered. Guessing "visitor"
    // here would flash a purple Remix button on the owner's own plan.
    await _pumpTrip(tester, viewerPending: true);

    expect(find.text('ทริปหลวงพระบางสายชิล'), findsOneWidget);
    expect(find.byKey(const Key('plan-action-bar')), findsNothing);
    expect(find.text('Remix Trip'), findsNothing);
    expect(find.text('แก้ไข'), findsNothing);
  });

  testWidgets('a trip with no itinerary says so instead of showing samples',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      trip: _tripJson(days: const <Map<String, dynamic>>[]),
    );

    expect(find.text('ทริปนี้ยังไม่มีแผนการเดินทาง'), findsOneWidget);
    expect(find.text('0 สถานที่'), findsNothing);
  });

  testWidgets('a trip that adds up to nothing hides the per-head price',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester, trip: _tripJson(totalBudget: 0));

    expect(find.textContaining('/คน'), findsNothing);
  });

  testWidgets('a missing trip says so instead of throwing', (tester) async {
    await _pumpTrip(tester, trip: <String, dynamic>{}, status: 404);

    expect(find.text('ไม่พบทริปนี้'), findsOneWidget);
    expect(find.text('ลองอีกครั้ง'), findsNothing);
  });

  testWidgets('a tablet centres the content column instead of stretching it',
      (tester) async {
    // iPad landscape.
    tester.view.physicalSize = const Size(1194 * 3, 834 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    final panel = tester.getRect(find.byKey(const Key('plan-action-bar')));
    final pill = tester.getRect(find.byType(ElevatedButton));

    // The panel reads as the screen's edge…
    expect(panel.width, 1194);
    // …while the pill inside it stays at the column's width and centres.
    expect(pill.width, lessThanOrEqualTo(720));
    expect(pill.center.dx, closeTo(panel.center.dx, 0.5));
  });

  testWidgets('the cover photo stays full-bleed on a tablet', (tester) async {
    tester.view.physicalSize = const Size(1194 * 3, 834 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    // The photo spans the screen even though the text inside it does not.
    final cover = tester.getRect(find.byType(ClipRRect).first);
    expect(cover.left, 0);
    expect(cover.width, 1194);
    // The title follows the content column…
    expect(tester.getRect(find.text('ทริปหลวงพระบางสายชิล')).left, 237);
    expect(tester.getRect(find.text('Trip Overview')).left, 237);
    // …but the app bar belongs to the screen's edge, not the column.
    expect(tester.getRect(find.byTooltip('ย้อนกลับ')).left, 32);
  });

  testWidgets('the cover photo opens up as the screen class widens',
      (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // How far down the title sits is exactly the photo gap, since everything
    // above it is a fixed-height bar. The hero's *total* height is not a safe
    // thing to assert: it is content-driven, so a wider screen that fits the
    // title on one line can come out shorter than a narrower one that wraps.
    final titleTop = <ScreenClass, double>{};
    for (final size in <Size>[
      Size(393, 852), // compact
      Size(700, 1000), // medium
      Size(900, 1200), // expanded
    ]) {
      tester.view.physicalSize = size * 3;
      await _pumpTrip(tester);
      titleTop[ScreenClass.fromWidth(size.width)] =
          tester.getRect(find.text('ทริปหลวงพระบางสายชิล')).top;
    }

    expect(titleTop.keys, hasLength(3));
    expect(titleTop[ScreenClass.medium], greaterThan(titleTop[ScreenClass.compact]!));
    expect(titleTop[ScreenClass.expanded], greaterThan(titleTop[ScreenClass.medium]!));
  });

  testWidgets('the page lays out from a small phone to a tablet',
      (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    for (final size in <Size>[
      Size(320, 568), // the smallest phone still worth supporting
      Size(393, 852), // the design's frame
      Size(834, 1194), // iPad portrait
      Size(1194, 834), // iPad landscape
    ]) {
      tester.view.physicalSize = size * 3;
      await _pumpTrip(tester);
      expect(tester.takeException(), isNull, reason: '$size on load');

      await tester.drag(find.text('Trip Overview'), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size after scrolling');
    }
  });

  testWidgets('the page lays out on a phone viewport without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    expect(tester.takeException(), isNull);
    await tester.drag(find.text('Trip Overview'), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
