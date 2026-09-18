import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/features/create_trip/domain/plan_labels.dart';
import 'package:pluno/features/create_trip/presentation/widgets/budget_sheets.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/create_trip/presentation/edit_trip_screen.dart';
import 'package:pluno/features/create_trip/presentation/widgets/add_place_sheet.dart';
import 'package:pluno/features/create_trip/presentation/widgets/plan_budget_tab.dart';

import 'support/fake_api.dart';

late FakeAdapter adapter;

/// A trip with dates, a brief and a two-stop first day — enough for every
/// number the hero prints.
Map<String, dynamic> _tripJson({
  List<Map<String, dynamic>>? days,
  Map<String, dynamic>? schedule,
}) =>
    <String, dynamic>{
      'id': 'trip-1',
      'ownerId': 'u1',
      'title': 'หลวงพระบาง, ลาว',
      'destination': 'หลวงพระบาง, ลาว',
      'status': 'draft',
      'schedule': schedule ??
          <String, dynamic>{
            'startDate': '2026-08-20',
            'endDate': '2026-08-22',
            'durationDays': 3,
            'durationNights': 2,
          },
      'budgetLimit': 60000,
      'totalBudget': 0,
      'brief': <String, dynamic>{
        'intensity': 'active',
        'transport': <String>['public_transit'],
        'styles': <String>['culture', 'food', 'nightlife'],
      },
      'isSaved': false,
      'isLiked': false,
      'likeCount': 0,
      'remixCount': 0,
      'days': days ?? const <Map<String, dynamic>>[],
      'createdAt': '2026-09-09T00:00:00.000Z',
      'updatedAt': '2026-09-09T00:00:00.000Z',
    };

/// วันที่ 1 with two stops: the second describes how the traveller got there,
/// and the server measured the same leg.
List<Map<String, dynamic>> _filledDay() => [
      <String, dynamic>{
        'id': 'd1',
        'dayNumber': 1,
        'date': '2026-08-20',
        'activities': <Map<String, dynamic>>[
          {
            'id': 's1',
            'title': 'วัดเชียงทอง',
            'category': 'sightseeing',
            'order': 0,
            'time': '08:30',
            'notes': 'วัดคู่บ้านคู่เมือง ศิลปะล้านช้าง',
            'cost': 300,
          },
          {
            'id': 's2',
            'title': 'ตลาดมืด',
            'category': 'food',
            'order': 1,
            'time': '18:00',
            'cost': 0,
            'travelFromPrevious': {
              'type': 'rental_car',
              'durationMin': 15,
              'costAmount': 3500,
            },
          },
        ],
        'travelSegments': <Map<String, dynamic>>[
          {
            'id': 'seg1',
            'dayId': 'd1',
            'fromPlaceId': 's1',
            'toPlaceId': 's2',
            'order': 0,
            'travelMode': 'DRIVE',
            'routeStatus': 'CALCULATED',
            'durationMinutes': 12,
          },
        ],
      },
    ];

/// Day 1 from [_filledDay] plus a second day, to prove the picker swaps them.
List<Map<String, dynamic>> _twoDays() => [
      ..._filledDay(),
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
            'cost': 250,
            'notes': 'น้ำใสสีเทอร์ควอยซ์ ไปเช้าคนน้อย',
          },
        ],
      },
    ];

Map<String, dynamic> _budgetJson(List<Map<String, dynamic>> items) =>
    <String, dynamic>{
      'totalBudget': 0,
      'byCategory': const <Map<String, dynamic>>[],
      'byDay': const <Map<String, dynamic>>[],
      'items': items,
    };

/// A trip that has spent money: a cap, three categories and two days, which
/// is everything the สรุปงบ tab draws.
///
/// The cap is 24,000 on purpose — the hero's own งบ/วัน tile reads 20,000 on
/// this trip, so a 20,000 cap would make every assertion ambiguous.
Map<String, dynamic> _spentBudgetJson() => <String, dynamic>{
      'budgetLimit': 24000,
      'totalBudget': 15200,
      'byCategory': const <Map<String, dynamic>>[
        {'category': 'hotel', 'amount': 8000, 'percentage': 53, 'itemCount': 1},
        {'category': 'food', 'amount': 4200, 'percentage': 28, 'itemCount': 2},
        {
          'category': 'transport',
          'amount': 3000,
          'percentage': 19,
          'itemCount': 1,
        },
      ],
      'byDay': const <Map<String, dynamic>>[
        {'dayId': 'd1', 'dayNumber': 1, 'date': '2026-08-20', 'amount': 9200},
        {'dayId': 'd2', 'dayNumber': 2, 'date': '2026-08-21', 'amount': 6000},
      ],
      'items': const <Map<String, dynamic>>[
        {
          'id': 'a1',
          'title': 'Villa Maly',
          'category': 'hotel',
          'amount': 8000,
          'source': 'accommodation',
          'dayNumber': 1,
        },
        {
          'id': 'e1',
          'title': 'ตลาดมืด',
          'category': 'food',
          'amount': 1200,
          'source': 'expense',
          'dayNumber': 1,
        },
        {
          'id': 'e2',
          'title': 'ค่าน้ำมันขาไป',
          'category': 'transport',
          'amount': 3000,
          'source': 'expense',
          'dayNumber': 2,
        },
        {
          'id': 'e3',
          'title': 'ข้าวซอย',
          'category': 'food',
          'amount': 3000,
          'source': 'expense',
          'dayNumber': 2,
        },
      ],
    };

Widget _harness() => ProviderScope(
      overrides: [
        plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              name: AppRoute.editTrip.name,
              builder: (_, __) => const EditTripScreen(tripId: 'trip-1'),
            ),
            GoRoute(
              path: '/detail/:tripId',
              name: AppRoute.tripDetail.name,
              builder: (_, __) => const Scaffold(body: Text('detail page')),
            ),
            GoRoute(
              path: '/remix/:tripId',
              name: AppRoute.remixTrip.name,
              builder: (_, __) => const Scaffold(body: Text('remix page')),
            ),
            GoRoute(
              path: '/brief/:tripId',
              name: AppRoute.editTripBrief.name,
              builder: (_, __) => const Scaffold(body: Text('brief page')),
            ),
          ],
        ),
      ),
    );

/// The value inside one hero stat tile. The tiles share their digits with the
/// numbered badges on the stop thumbnails, so a bare find.text is ambiguous.
void expectStat(WidgetTester tester, String label, String value) {
  final tile =
      find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
  expect(
    find.descendant(of: tile, matching: find.text(value)),
    findsOneWidget,
    reason: '$label should read $value',
  );
}

/// Opens สรุปงบ on a trip that has spent money.
Future<void> openBudgetTab(
  WidgetTester tester, {
  Map<String, dynamic>? trip,
  Map<String, dynamic>? budget,
}) async {
  // Taller than a phone on purpose: the tab stacks the stat cards, the
  // category card and a card per day, and a lazy list never builds what it
  // cannot show — which would hide the later days from the finders rather
  // than prove anything about them.
  tester.view.physicalSize = const Size(393 * 3, 2000 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  adapter.replies['GET /trips/trip-1'] = [
    FakeReply(200, trip ?? _tripJson(days: _twoDays()))
  ];
  adapter.replies['GET /trips/trip-1/budget'] = [
    FakeReply(200, budget ?? _spentBudgetJson())
  ];

  await tester.pumpWidget(_harness());
  await tester.pumpAndSettle();
  await tester.tap(find.text('สรุปงบ'));
  await tester.pumpAndSettle();
}

/// Text inside the tab itself, so the hero's own figures never match.
Finder inBudgetTab(String text) => find.descendant(
      of: find.byType(PlanBudgetTab),
      matching: find.text(text),
    );

void main() {
  setUp(() {
    adapter = FakeAdapter({
      'GET /trips/trip-1': [FakeReply(200, _tripJson())],
      'GET /trips/trip-1/budget': [
        FakeReply(
          200,
          _budgetJson([
            <String, dynamic>{
              'id': 'a1',
              'title': 'Villa Maly',
              'category': 'hotel',
              'amount': 4200,
              'source': 'accommodation',
            },
          ]),
        ),
      ],
    });
  });

  testWidgets('the hero prints the trip facts off the API trip',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('สร้างทริป'), findsOneWidget);
    expect(find.text('หลวงพระบาง, ลาว'), findsOneWidget);
    expect(find.text('20/08/2026 - 22/08/2026'), findsOneWidget);
    expect(find.text('3 วัน 2 คืน'), findsOneWidget);
  });

  testWidgets('the brief comes back as chips in pace, transport, style order',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    for (final label in [
      'Active',
      'รถสาธารณะ',
      'วัฒนธรรม',
      'อาหาร',
      'ไนท์ไลฟ์'
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('the budget stat is per day, not the stored trip total',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // 60,000 over three days.
    expect(find.text('฿20,000'), findsOneWidget);
    expect(find.text('งบ/วัน'), findsOneWidget);
  });

  testWidgets('stops are counted by category, lodging off the budget summary',
      (tester) async {
    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(
        200,
        _tripJson(days: [
          <String, dynamic>{
            'id': 'd1',
            'dayNumber': 1,
            'date': '2026-08-20',
            'activities': <Map<String, dynamic>>[
              {'id': 's1', 'title': 'วัดเชียงทอง', 'category': 'sightseeing'},
              {'id': 's2', 'title': 'ปีนภูสี', 'category': 'activity'},
              {'id': 's3', 'title': 'ตลาดเช้า', 'category': 'food'},
            ],
          },
        ]),
      ),
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expectStat(tester, 'ที่เที่ยว', '2'); // sightseeing + activity
    expectStat(tester, 'ร้านอาหาร', '1');
    expectStat(tester, 'ที่พัก', '1'); // off the budget summary
  });

  testWidgets('an unfilled plan still gets a row per day', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('วันที่ 1'), findsOneWidget);
    expect(find.text('Thu, 20 Aug'), findsOneWidget);
    expect(find.text('วันที่ 2'), findsOneWidget);
    expect(find.text('วันที่ 3'), findsOneWidget);
    expect(find.text('Sat, 22 Aug'), findsOneWidget);
    expect(find.text('สถานที่'), findsNWidgets(3));
  });

  testWidgets('ตารางแผน collapses and ที่พักของคุณ opens', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // The schedule starts open, lodging starts closed.
    expect(find.text('วันที่ 1'), findsOneWidget);
    expect(find.text('Villa Maly'), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pumpAndSettle();
    expect(find.text('วันที่ 1'), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pumpAndSettle();
    expect(find.text('Villa Maly'), findsOneWidget);
  });

  testWidgets('a failed budget read leaves the itinerary standing',
      (tester) async {
    adapter.replies['GET /trips/trip-1/budget'] = [
      FakeReply(500, <String, dynamic>{'message': 'boom'}),
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('วันที่ 1'), findsOneWidget);
    expect(find.text('ที่พัก'), findsOneWidget);
  });

  testWidgets('the overflow menu reaches the brief wizard', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('แก้ไขรายละเอียดทริป'));
    await tester.pumpAndSettle();

    expect(find.text('brief page'), findsOneWidget);
  });

  testWidgets('Remix Trip leaves for the remix route', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remix Trip'));
    await tester.pumpAndSettle();

    expect(find.text('remix page'), findsOneWidget);
  });

  testWidgets('a missing trip says so instead of throwing', (tester) async {
    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(404, <String, dynamic>{'message': 'not found'}),
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('ไม่พบทริปนี้'), findsOneWidget);
  });

  testWidgets('the page lays out on a phone viewport without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('จัดแผนของคุณ'), findsOneWidget);
    expect(find.text('ตารางแผน'), findsOneWidget);
  });

  testWidgets('the hero survives a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('ร้านอาหาร'), findsOneWidget);
    expect(find.text('งบ/วัน'), findsOneWidget);
  });

  testWidgets('สภาพอากาศ says so instead of reusing จัดแผน', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('ตารางแผน'), findsOneWidget);

    await tester.tap(find.text('สภาพอากาศ'));
    await tester.pumpAndSettle();

    expect(find.text('ตารางแผน'), findsNothing);
    expect(find.text('สภาพอากาศ ยังไม่เปิดใช้งาน'), findsOneWidget);

    await tester.tap(find.text('จัดแผน'));
    await tester.pumpAndSettle();
    expect(find.text('ตารางแผน'), findsOneWidget);
  });

  testWidgets('a stop shows its time, note, cost and position', (tester) async {
    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _filledDay()))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('08:30 AM'), findsOneWidget);
    expect(find.text('06:00 PM'), findsOneWidget);
    expect(find.text('วัดเชียงทอง'), findsOneWidget);
    expect(find.text('วัดคู่บ้านคู่เมือง ศิลปะล้านช้าง'), findsOneWidget);
    expect(find.text('฿300'), findsOneWidget);
    // The numbered badge on each thumbnail.
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets("the traveller's own leg beats the server's measurement",
      (tester) async {
    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _filledDay()))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // travelFromPrevious wins: รถเช่า / 15 นาที, not the segment's 12.
    expect(find.text('รถเช่า • 15 นาที • ฿3,500'), findsOneWidget);
  });

  testWidgets('a leg with no description falls back to the measured segment',
      (tester) async {
    final days = _filledDay();
    (days[0]['activities'] as List)[1].remove('travelFromPrevious');
    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: days))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('ขับรถ • 12 นาที'), findsOneWidget);
  });

  testWidgets('every stop control reports that it is not wired yet',
      (tester) async {
    // Tall enough that the whole day fits, so no control is under the
    // SnackBar the previous tap left on screen.
    tester.view.physicalSize = const Size(393 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _filledDay()))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Each tap replaces the last message, so settle between them: the new
    // SnackBar is queued behind the outgoing one and misses a single pump.
    // ลบ is wired now and has a test of its own.
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('แก้ไข "วัดเชียงทอง" ยังไม่เปิดใช้งาน'), findsOneWidget);

    await tester.tap(find.text('เพิ่มการเดินทาง'));
    await tester.pumpAndSettle();
    expect(
      find.text('เพิ่มการเดินทางในวันที่ 1 ยังไม่เปิดใช้งาน'),
      findsOneWidget,
    );

    // The drag handle is wired now and has a test of its own; a plain tap on
    // it does nothing, which is what a drag affordance should do.
    await tester.tap(find.byIcon(Icons.drag_handle).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('จัดเรียง'), findsNothing);
  });

  testWidgets('an empty day still shows only its header', (tester) async {
    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _filledDay()))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Day 1 is filled, so it has the add-travel rail; days 2 and 3 do not
    // exist on this trip at all.
    expect(find.text('เพิ่มการเดินทาง'), findsOneWidget);
    expect(find.text('วันที่ 1'), findsOneWidget);
    expect(find.text('วันที่ 2'), findsNothing);
  });

  testWidgets('a filled day lays out on a phone without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _filledDay()))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('วัดเชียงทอง'), findsOneWidget);
  });

  testWidgets('ทริปของฉัน swaps in its own heading, map and day picker',
      (tester) async {
    // A short viewport leaves the sliver below the fold unbuilt, so nothing
    // under the map would be findable.
    tester.view.physicalSize = const Size(393 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _twoDays()))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทริปของฉัน'));
    await tester.pumpAndSettle();

    // The จัดแผน heading and its purple action are gone.
    expect(find.text('จัดแผนของคุณ'), findsNothing);
    expect(find.text('Remix Trip'), findsNothing);

    expect(find.text('แก้ไขทริป'), findsOneWidget);
    // Tests run with no --dart-define=MAPS_API_KEY, so the card must fall
    // back rather than build a GoogleMap the SDK would throw on.
    expect(find.text('แผนที่ยังไม่ได้ตั้งค่า'), findsOneWidget);
    expect(find.byType(GoogleMap), findsNothing);
    expect(find.text('เพิ่มวัน'), findsOneWidget);
    expect(find.text('วันที่ 1'), findsOneWidget);
    expect(find.text('วันที่ 2'), findsOneWidget);
  });

  testWidgets('the day picker changes which stops are listed', (tester) async {
    // A short viewport leaves the sliver below the fold unbuilt, so nothing
    // under the map would be findable.
    tester.view.physicalSize = const Size(393 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _twoDays()))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทริปของฉัน'));
    await tester.pumpAndSettle();

    expect(find.text('วัดเชียงทอง'), findsOneWidget);
    expect(find.text('น้ำตกกวางสี'), findsNothing);

    await tester.tap(find.text('วันที่ 2'));
    await tester.pumpAndSettle();

    expect(find.text('วัดเชียงทอง'), findsNothing);
    expect(find.text('น้ำตกกวางสี'), findsOneWidget);
    expect(find.text('น้ำใสสีเทอร์ควอยซ์ ไปเช้าคนน้อย'), findsOneWidget);
  });

  testWidgets('a stop here shows its time in orange with leg and cost chips',
      (tester) async {
    // A short viewport leaves the sliver below the fold unbuilt, so nothing
    // under the map would be findable.
    tester.view.physicalSize = const Size(393 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _twoDays()))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทริปของฉัน'));
    await tester.pumpAndSettle();

    // The leg chip drops the cost — that has a chip of its own here.
    expect(find.text('รถเช่า • 15 นาที'), findsOneWidget);
    expect(find.text('฿300'), findsOneWidget);
    expect(find.text('฿0'), findsOneWidget);

    final time = tester.widget<Text>(find.text('08:30 AM'));
    expect(time.style?.color, const Color(0xFFF4703A));
  });

  testWidgets('แก้ไขทริป opens the brief wizard', (tester) async {
    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _twoDays()))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทริปของฉัน'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('แก้ไขทริป'));
    await tester.pumpAndSettle();
    expect(find.text('brief page'), findsOneWidget);
  });

  testWidgets('dragging a stop sends the whole day in its new order',
      (tester) async {
    // Tall enough that both stops of day 1 are built and draggable.
    tester.view.physicalSize = const Size(393 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    adapter.replies['GET /trips/trip-1'] = [
      // Twice: the page reads the trip, and reads it again after the reorder
      // lands so the legs come back recalculated.
      FakeReply(200, _tripJson(days: _filledDay())),
      FakeReply(200, _tripJson(days: _filledDay())),
    ];
    adapter.replies['PATCH /days/d1/items/order'] = [
      FakeReply(200, _filledDay().first)
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Day 1 reads s1 then s2; drag the second one above the first.
    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(2));

    // Press and hold to grab the row, then travel: one long drag reports a
    // single move, which the list cannot read as a drop target.
    final gesture = await tester.startGesture(tester.getCenter(handles.last));
    await tester.pump(const Duration(milliseconds: 700));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    // The request and the reload leave the framework, so they need real turns.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    await tester.pumpAndSettle();

    // The endpoint wants every stop of that day, in the order they now sit.
    expect(adapter.bodyOf('PATCH /days/d1/items/order'), {
      'itemIds': ['s2', 's1'],
    });
  });

  testWidgets('a stop opens its writing and offers นำทาง, then closes again',
      (tester) async {
    // Tall on purpose: the cards sit under the map and the day picker, and a
    // lazy list does not build what it cannot show.
    tester.view.physicalSize = const Size(393 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _twoDays()))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทริปของฉัน'));
    await tester.pumpAndSettle();

    // Closed, the only action a card offers is to open it.
    expect(find.text('นำทาง'), findsNothing);

    await tester.tap(find.text('รายละเอียด').first);
    await tester.pumpAndSettle();

    expect(find.text('นำทาง'), findsOneWidget);
    expect(find.text('ย่อรายละเอียด'), findsOneWidget);

    // It is a design row with nowhere to go yet, and says so rather than
    // doing nothing.
    await tester.tap(find.text('นำทาง'));
    await tester.pumpAndSettle();
    expect(find.text('นำทางยังไม่เปิดใช้งาน'), findsOneWidget);

    await tester.tap(find.text('ย่อรายละเอียด'));
    await tester.pumpAndSettle();
    expect(find.text('นำทาง'), findsNothing);
  });

  testWidgets('ทริปของฉัน lays out on a phone without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _twoDays()))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทริปของฉัน'));
    await tester.pumpAndSettle();

    expect(find.text('แก้ไขทริป'), findsOneWidget);
  });

  testWidgets('ลบ asks first, then deletes the stop and refreshes the plan',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _filledDay()))
    ];
    adapter.replies['DELETE /items/s1'] = [FakeReply(200, null)];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('ลบสถานที่นี้?'), findsOneWidget);

    // Backing out must not touch the server.
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(adapter.paths.contains('DELETE /items/s1'), isFalse);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบ').last);
    await tester.pumpAndSettle();

    expect(adapter.paths.contains('DELETE /items/s1'), isTrue);
    // The plan was re-read, so the list reflects the deletion.
    expect(
      adapter.paths.where((p) => p == 'GET /trips/trip-1').length,
      greaterThan(1),
    );
  });

  testWidgets('a signed-out delete says so instead of failing silently',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _filledDay()))
    ];
    adapter.replies['DELETE /items/s1'] = [
      FakeReply(401, {'message': 'Unauthorized'})
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบ').last);
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบก่อนลบสถานที่'), findsOneWidget);
  });

  group('เพิ่มสถานที่', () {
    /// Opens the sheet from วันที่ 1's "+ สถานที่" button.
    Future<void> openSheet(WidgetTester tester) async {
      adapter = FakeAdapter(<String, List<FakeReply>>{
        'GET /trips/trip-1': [FakeReply(200, _tripJson(days: _filledDay()))],
        'POST /days/d1/items': [
          FakeReply(201, <String, dynamic>{
            'activity': <String, dynamic>{
              'id': 'new-stop',
              'title': 'วัดเชียงทอง',
              'order': 2,
            },
          }),
        ],
        'POST /trips/trip-1/itinerary/travel-segments/retry': [
          FakeReply(200, <String, dynamic>{}),
        ],
      });
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      // The day cards sit well below the hero on a phone.
      final add = find.text('สถานที่').first;
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
    }

    /// Scoped to the sheet: the plan behind it has its own explore banner, and
    /// "เพิ่มสถานที่" is both the sheet's title and its button.
    Finder inSheet(String text) => find.descendant(
          of: find.byType(AddPlaceSheet),
          matching: find.text(text),
        );

    testWidgets('opens as a bottom sheet with the form the design shows',
        (tester) async {
      await openSheet(tester);

      expect(inSheet('เพิ่มสถานที่'), findsNWidgets(2)); // title and button
      expect(inSheet('ยังไม่รู้จะไปไหน? สำรวจสถานที่แนะนำ'), findsOneWidget);
      for (final label in [
        'ชื่อสถานที่ / กิจกรรม',
        'วัน',
        'เวลา',
        'ประเภท',
        'ค่าใช้จ่าย (ต่อคน)',
        'เพิ่มโน้ต',
      ]) {
        // "เวลา" is both a label and the empty field's own placeholder, as
        // the design has it.
        expect(inSheet(label), findsWidgets, reason: label);
      }
      expect(inSheet('เพิ่มรูป'), findsOneWidget);
      expect(inSheet('ยกเลิก'), findsOneWidget);
    });

    testWidgets('the add button waits for a name', (tester) async {
      await openSheet(tester);

      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: inSheet('เพิ่มสถานที่').last,
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'วัดเชียงทอง');
      await tester.pumpAndSettle();

      final enabled = tester.widget<FilledButton>(
        find.ancestor(
          of: inSheet('เพิ่มสถานที่').last,
          matching: find.byType(FilledButton),
        ),
      );
      expect(enabled.onPressed, isNotNull);
    });

    testWidgets('sends the form to the chosen day', (tester) async {
      await openSheet(tester);

      await tester.enterText(find.byType(TextField).first, 'วัดเชียงทอง');
      await tester.pumpAndSettle();
      await tester.tap(inSheet('เพิ่มสถานที่').last);
      await tester.pumpAndSettle();

      final body = adapter.bodyOf('POST /days/d1/items');
      expect(body, isNotNull);
      expect(body!['customName'], 'วัดเชียงทอง');
      // Nothing else was filled in, so nothing else is sent — an untouched
      // cost must not write a ฿0 line.
      expect(body.containsKey('costAmount'), isFalse);
      expect(body.containsKey('startTime'), isFalse);
      expect(body.containsKey('notes'), isFalse);
    });

    testWidgets('สำรวจ hands over to the explorer instead of stacking',
        (tester) async {
      await openSheet(tester);
      await tester.tap(inSheet('สำรวจ'));
      await tester.pumpAndSettle();

      // The form is gone before the explorer opens.
      expect(find.byType(AddPlaceSheet), findsNothing);
    });
  });

  testWidgets('the nav row and the tabs stay put while the plan scrolls',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    adapter = FakeAdapter(<String, List<FakeReply>>{
      'GET /trips/trip-1': [FakeReply(200, _tripJson(days: _filledDay()))],
    });
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final navAtRest = tester.getRect(find.text('สร้างทริป'));
    final tabsAtRest = tester.getRect(find.text('จัดแผน'));

    // Far enough that the hero is gone and the tabs have reached the top.
    await tester.drag(
        find.byType(CustomScrollView).first, const Offset(0, -400));
    await tester.pumpAndSettle();

    final navPinned = tester.getRect(find.text('สร้างทริป'));
    final tabsPinned = tester.getRect(find.text('จัดแผน'));

    // The nav row never moves — it is pinned from the first frame.
    expect(navPinned, navAtRest);
    // The tabs travel up out of the page and come to rest below it.
    expect(tabsPinned.top, lessThan(tabsAtRest.top));
    expect(tabsPinned.top, greaterThanOrEqualTo(navPinned.bottom));

    // Scrolling further leaves both exactly where they are.
    await tester.drag(
        find.byType(CustomScrollView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('สร้างทริป')), navPinned);
    expect(tester.getRect(find.text('จัดแผน')), tabsPinned);
  });

  testWidgets('a plan with no day rows yet creates one before adding',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Exactly what POST /trips leaves behind: three days of duration, no
    // itinerary rows at all.
    adapter = FakeAdapter(<String, List<FakeReply>>{
      'GET /trips/trip-1': [
        FakeReply(200, _tripJson(days: const <Map<String, dynamic>>[])),
      ],
      'POST /trips/trip-1/days': [
        FakeReply(201, <String, dynamic>{
          'id': 'day-new',
          'dayNumber': 1,
          'activities': <dynamic>[],
        }),
      ],
      'POST /days/day-new/items': [
        FakeReply(201, <String, dynamic>{
          'activity': <String, dynamic>{'id': 's9', 'title': 'x', 'order': 0},
        }),
      ],
      'POST /trips/trip-1/itinerary/travel-segments/retry': [
        FakeReply(200, <String, dynamic>{}),
      ],
    });

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final add = find.text('สถานที่').first;
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();

    // The day was created rather than the traveller being told to go away.
    expect(adapter.bodyOf('POST /trips/trip-1/days'), isNotNull);
    expect(find.byType(AddPlaceSheet), findsOneWidget);
    expect(
      find.textContaining('วันนี้ยังไม่มีในแผน'),
      findsNothing,
    );

    // And the stop goes onto the day that was just made.
    await tester.enterText(find.byType(TextField).first, 'วัดร่องขุ่น');
    await tester.pumpAndSettle();
    await tester.tap(find
        .descendant(
          of: find.byType(AddPlaceSheet),
          matching: find.text('เพิ่มสถานที่'),
        )
        .last);
    await tester.pumpAndSettle();

    expect(adapter.bodyOf('POST /days/day-new/items')?['customName'],
        'วัดร่องขุ่น');
  });

  testWidgets('สรุปงบ prints what was spent, the cap and what is left',
      (tester) async {
    await openBudgetTab(tester);

    expect(inBudgetTab('฿15,200'), findsOneWidget);
    expect(inBudgetTab('฿24,000'), findsOneWidget);
    expect(inBudgetTab('เหลือ ฿8,800 จะเท่างบ'), findsOneWidget);
  });

  testWidgets('a trip over its cap says so rather than showing a minus',
      (tester) async {
    final over = _spentBudgetJson()..['budgetLimit'] = 12000;
    await openBudgetTab(tester, budget: over);

    expect(inBudgetTab('เกินงบ ฿3,200'), findsOneWidget);
  });

  testWidgets('a trip with no cap set does not read as a zero cap',
      (tester) async {
    final none = _spentBudgetJson()..remove('budgetLimit');
    await openBudgetTab(tester, budget: none);

    expect(inBudgetTab('ยังไม่ได้ตั้งงบไว้'), findsOneWidget);
    expect(inBudgetTab('—'), findsOneWidget);
  });

  testWidgets('the pill divides every figure by the head count',
      (tester) async {
    await openBudgetTab(
      tester,
      trip: _tripJson(days: _twoDays())
        ..['customer'] = <String, dynamic>{
          'id': 'u1',
          'name': 'พี่นุ้ย',
          'groupSize': 2,
        },
    );

    // Per person is what the design leads with: 15,200 over two travellers.
    expect(inBudgetTab('฿7,600'), findsOneWidget);
    expect(inBudgetTab('฿15,200'), findsNothing);

    await tester.tap(inBudgetTab('ค่าใช้จ่ายต่อคน'));
    await tester.pumpAndSettle();

    expect(inBudgetTab('฿15,200'), findsOneWidget);
    expect(inBudgetTab('ค่าใช้จ่ายทั้งทริป'), findsOneWidget);
  });

  testWidgets('the legend lists each category with its own amount',
      (tester) async {
    await openBudgetTab(tester);

    expect(inBudgetTab('4 รายการ'), findsOneWidget);
    for (final pair in [
      ['ค่าที่พัก', '฿8,000'],
      ['ค่าอาหาร / ของกิน', '฿4,200'],
      ['ค่าเดินทาง', '฿3,000'],
    ]) {
      expect(inBudgetTab(pair[0]), findsWidgets, reason: pair[0]);
      expect(inBudgetTab(pair[1]), findsWidgets, reason: pair[1]);
    }
  });

  testWidgets('every day of the plan gets a card, spent on or not',
      (tester) async {
    // Everything landed on วันที่ 1; วันที่ 2 is in the plan regardless.
    final firstDayOnly = _spentBudgetJson()
      ..['byDay'] = const <Map<String, dynamic>>[
        {'dayId': 'd1', 'dayNumber': 1, 'date': '2026-08-20', 'amount': 9200},
      ]
      ..['items'] = const <Map<String, dynamic>>[
        {
          'id': 'a1',
          'title': 'Villa Maly',
          'category': 'hotel',
          'amount': 8000,
          'source': 'accommodation',
          'dayNumber': 1,
        },
      ];
    await openBudgetTab(tester, budget: firstDayOnly);

    expect(inBudgetTab('Thu, 20 Aug'), findsOneWidget);
    expect(inBudgetTab('฿9,200'), findsOneWidget);
    expect(inBudgetTab('Fri, 21 Aug'), findsOneWidget);
    expect(inBudgetTab('฿0'), findsOneWidget);
  });

  testWidgets('opening a day lists its own lines and nothing else',
      (tester) async {
    await openBudgetTab(tester);

    // Day 1 starts open, as the design shows.
    expect(inBudgetTab('รายการค่าใช้จ่าย'), findsOneWidget);
    expect(inBudgetTab('Villa Maly'), findsOneWidget);
    expect(inBudgetTab('ตลาดมืด'), findsOneWidget);
    expect(inBudgetTab('ค่าน้ำมันขาไป'), findsNothing);

    await tester.tap(inBudgetTab('฿6,000'));
    await tester.pumpAndSettle();

    expect(inBudgetTab('ค่าน้ำมันขาไป'), findsOneWidget);
    expect(inBudgetTab('ข้าวซอย'), findsOneWidget);
    expect(inBudgetTab('Villa Maly'), findsNothing);
  });

  testWidgets('ทุกหมวด narrows the open day to one category', (tester) async {
    await openBudgetTab(tester);

    await tester.tap(inBudgetTab('ทุกหมวด'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ค่าอาหาร / ของกิน').last);
    await tester.pumpAndSettle();

    expect(inBudgetTab('ตลาดมืด'), findsOneWidget);
    expect(inBudgetTab('Villa Maly'), findsNothing);
  });

  testWidgets('แก้ไขงบ PATCHes the cap onto the trip, not into the budget',
      (tester) async {
    await openBudgetTab(tester);
    adapter.replies['PATCH /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _twoDays()))
    ];

    await tester.tap(inBudgetTab('แก้ไขงบ'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '30000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึกงบ'));
    await tester.pumpAndSettle();

    expect(adapter.bodyOf('PATCH /trips/trip-1')?['budgetLimit'], 30000);
  });

  testWidgets('+ เพิ่มค่าใช้จ่าย files a line under its category and day',
      (tester) async {
    await openBudgetTab(
      tester,
      trip: _tripJson(days: _filledDay())
        ..['customer'] = <String, dynamic>{'groupSize': 2},
    );
    adapter.replies['POST /trips/trip-1/expenses'] = [
      FakeReply(201, <String, dynamic>{
        'id': 'e9',
        'tripId': 'trip-1',
        'title': 'การเดินทาง',
        'amount': 240,
      })
    ];

    await tester.tap(inBudgetTab('เพิ่มค่าใช้จ่าย'));
    await tester.pumpAndSettle();

    expect(find.text('รายการที่ 1'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '120');
    await tester.pumpAndSettle();

    // The type row opens a sheet of its own.
    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pumpAndSettle();
    expect(find.text('เลือกหมวดหมู่'), findsOneWidget);

    await tester.tap(find.byKey(expenseCategoryTileKey(ExpenseCategory.transport)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยัน'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'เพิ่มค่าใช้จ่าย'));
    await tester.pumpAndSettle();

    final body = adapter.bodyOf('POST /trips/trip-1/expenses');
    // The field says ต่อคน but TripExpense.amount is counted as-is, so the
    // sheet multiplies by the group of 2 before sending.
    expect(body?['amount'], 240);
    expect(body?['category'], 'transport');
    // No place was picked, so the category names the line.
    expect(body?['title'], 'การเดินทาง');
    // The first day of the plan is preselected, and it has a date.
    expect(body?['date'], '2026-08-20');
  });

  testWidgets('a picked stop becomes the expense title', (tester) async {
    await openBudgetTab(tester, trip: _tripJson(days: _filledDay()));
    adapter.replies['POST /trips/trip-1/expenses'] = [
      FakeReply(201, <String, dynamic>{
        'id': 'e9',
        'tripId': 'trip-1',
        'title': 'วัดเชียงทอง',
        'amount': 300,
      })
    ];

    await tester.tap(inBudgetTab('เพิ่มค่าใช้จ่าย'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '300');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pumpAndSettle();

    // จากสถานที่ในแผน lists the plan's own stops. The dropdown sits on its
    // null item, so ไม่ระบุสถานที่ is what opens it.
    await tester.tap(find.text('ไม่ระบุสถานที่'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('วัดเชียงทอง').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(expenseCategoryTileKey(ExpenseCategory.shopping)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยัน'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'เพิ่มค่าใช้จ่าย'));
    await tester.pumpAndSettle();

    final body = adapter.bodyOf('POST /trips/trip-1/expenses');
    expect(body?['title'], 'วัดเชียงทอง');
    expect(body?['category'], 'shopping');
  });

  testWidgets('the sheet stays blocked until a line has an amount and a type',
      (tester) async {
    await openBudgetTab(tester, trip: _tripJson(days: _filledDay()));

    await tester.tap(inBudgetTab('เพิ่มค่าใช้จ่าย'));
    await tester.pumpAndSettle();

    FilledButton confirm() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'เพิ่มค่าใช้จ่าย'));
    expect(confirm().onPressed, isNull);

    // An amount alone is not enough — the category is what files it.
    await tester.enterText(find.byType(TextField).first, '80');
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNull);

    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(expenseCategoryTileKey(ExpenseCategory.food)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยัน'));
    await tester.pumpAndSettle();

    expect(confirm().onPressed, isNotNull);
  });

  testWidgets('+ เพิ่มค่าใช้จ่าย adds a second line, and the bin removes it',
      (tester) async {
    await openBudgetTab(tester, trip: _tripJson(days: _filledDay()));

    await tester.tap(inBudgetTab('เพิ่มค่าใช้จ่าย'));
    await tester.pumpAndSettle();
    expect(find.text('รายการที่ 2'), findsNothing);

    // The orange add inside the sheet, not the budget tab's button behind it.
    await tester.tap(find.byKey(addExpenseLineKey));
    await tester.pumpAndSettle();
    expect(find.text('รายการที่ 2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    expect(find.text('รายการที่ 2'), findsNothing);
  });

  testWidgets('both expense sheets lay out on a narrow phone', (tester) async {
    await openBudgetTab(tester, trip: _tripJson(days: _filledDay()));
    // openBudgetTab uses a tall view; narrow it to the smallest phone the app
    // supports, which is where the mock's side-by-side labels stop fitting.
    tester.view.physicalSize = const Size(320 * 3, 1600 * 3);

    await tester.tap(inBudgetTab('เพิ่มค่าใช้จ่าย'));
    await tester.pumpAndSettle();
    expect(find.text('รายการที่ 1'), findsOneWidget);
    expect(find.text('ต่อคน'), findsOneWidget);
    // The ฿ shows on an untouched field, which prefixText would not do.
    expect(find.text('฿'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pumpAndSettle();

    // Six tiles wrap to three-up rather than overflowing.
    expect(find.text('จากสถานที่ในแผน'), findsOneWidget);
    expect(find.text('(ไม่บังคับ)'), findsOneWidget);
    for (final category in expenseCategoryTiles) {
      expect(find.byKey(expenseCategoryTileKey(category)), findsOneWidget);
    }
  });

  testWidgets('the map FAB hides the map, and brings it back', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _twoDays()))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทริปของฉัน'));
    await tester.pumpAndSettle();

    // The map is open to begin with, and the FAB offers to close it.
    expect(find.textContaining('แผนที่ยังไม่ได้ตั้งค่า'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('แผนที่ยังไม่ได้ตั้งค่า'), findsNothing);
    expect(find.byIcon(Icons.map_outlined), findsWidgets);
    // Folding the map away must not take the day's stops with it.
    expect(find.text('วันที่ 1'), findsOneWidget);
    expect(find.text('วัดเชียงทอง'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('แผนที่ยังไม่ได้ตั้งค่า'), findsOneWidget);
  });

  testWidgets('the map FAB belongs to ทริปของฉัน alone', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _twoDays()))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('ทริปของฉัน'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // Hiding the map then leaving the tab must not strand the FAB.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('จัดแผน'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('the pinned tab bar follows the tab that is showing',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _twoDays()))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    /// The selected tab is the white-on-green one.
    String selectedTab() => tester
        .widgetList<Text>(find.descendant(
          of: find.byType(AnimatedContainer),
          matching: find.byType(Text),
        ))
        .firstWhere((t) => t.style?.color == Colors.white)
        .data!;

    expect(selectedTab(), 'จัดแผน');

    await tester.tap(find.text('ทริปของฉัน'));
    await tester.pumpAndSettle();
    // The bar is a pinned SliverPersistentHeader, which will happily keep its
    // last build unless the delegate says otherwise.
    expect(selectedTab(), 'ทริปของฉัน');

    await tester.tap(find.text('สรุปงบ'));
    await tester.pumpAndSettle();
    expect(selectedTab(), 'สรุปงบ');
  });
}
