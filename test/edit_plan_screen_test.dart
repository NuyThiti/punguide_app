import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/create_trip/presentation/edit_trip_screen.dart';

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
  final tile = find
      .ancestor(of: find.text(label), matching: find.byType(Column))
      .first;
  expect(
    find.descendant(of: tile, matching: find.text(value)),
    findsOneWidget,
    reason: '$label should read $value',
  );
}

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

    for (final label in ['Active', 'รถสาธารณะ', 'วัฒนธรรม', 'อาหาร', 'ไนท์ไลฟ์']) {
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

  testWidgets('the other three tabs say so instead of reusing จัดแผน',
      (tester) async {
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

    await tester.tap(find.byIcon(Icons.drag_handle).first);
    await tester.pumpAndSettle();
    expect(
      find.text('จัดเรียงสถานที่ในวันที่ 1 ยังไม่เปิดใช้งาน'),
      findsOneWidget,
    );
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

  testWidgets('the map shortcut belongs to ทริปของฉัน alone', (tester) async {
    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(days: _twoDays()))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('ทริปของฉัน'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.text('สรุปงบ'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
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
}
