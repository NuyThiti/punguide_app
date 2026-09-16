import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/create_trip/presentation/edit_trip_screen.dart';
import 'package:pluno/features/create_trip/presentation/widgets/suggest_places_sheet.dart';

import 'support/fake_api.dart';

late FakeAdapter adapter;

Map<String, dynamic> _place(
  String id,
  String name, {
  String category = 'attraction',
  double rating = 4.9,
  String address = 'หลวงพระบาง, ลาว',
}) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'address': address,
      'category': category,
      'rating': rating,
      'lat': 19.88,
      'lng': 102.13,
      'imageUrl': '',
    };

/// One day with a stop that has coordinates — the sheet needs an anchor, and
/// this trip has no destinationPlace, so the stop is where it comes from.
Map<String, dynamic> _tripJson({bool withCoordinates = true}) =>
    <String, dynamic>{
      'id': 'trip-1',
      'ownerId': 'u1',
      'title': 'หลวงพระบาง, ลาว',
      'destination': 'หลวงพระบาง, ลาว',
      'status': 'draft',
      'schedule': <String, dynamic>{
        'startDate': '2026-08-20',
        'endDate': '2026-08-22',
        'durationDays': 3,
        'durationNights': 2,
      },
      'totalBudget': 0,
      'isSaved': false,
      'isLiked': false,
      'likeCount': 0,
      'remixCount': 0,
      'days': [
        <String, dynamic>{
          'id': 'd1',
          'dayNumber': 1,
          'date': '2026-08-20',
          'activities': [
            <String, dynamic>{
              'id': 's1',
              'title': 'วัดเชียงทอง',
              'category': 'sightseeing',
              'order': 0,
              'cost': 0,
              if (withCoordinates)
                'location': {
                  'name': 'วัดเชียงทอง',
                  'lat': 19.8935,
                  'lng': 102.1357,
                },
            },
          ],
        },
      ],
      'createdAt': '2026-09-16T00:00:00.000Z',
      'updatedAt': '2026-09-16T00:00:00.000Z',
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
              builder: (_, __) => const Scaffold(body: Text('detail')),
            ),
            GoRoute(
              path: '/remix/:tripId',
              name: AppRoute.remixTrip.name,
              builder: (_, __) => const Scaffold(body: Text('remix')),
            ),
            GoRoute(
              path: '/brief/:tripId',
              name: AppRoute.editTripBrief.name,
              builder: (_, __) => const Scaffold(body: Text('brief')),
            ),
          ],
        ),
      ),
    );

/// Opens the sheet from วันที่ 1's "+ สถานที่".
Future<void> _openSheet(WidgetTester tester) async {
  await tester.pumpWidget(_harness());
  await tester.pumpAndSettle();
  await tester.tap(find.text('สถานที่').first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    adapter = FakeAdapter({
      'GET /trips/trip-1': [FakeReply(200, _tripJson())],
      'GET /trips/trip-1/budget': [
        FakeReply(200, {
          'totalBudget': 0,
          'byCategory': [],
          'byDay': [],
          'items': [],
        })
      ],
      'GET /places/suggest': [
        FakeReply(200, [
          _place('p1', 'พระราชวังหลวง'),
          _place('p2', 'Dyen Sabai', category: 'restaurant', rating: 4.5),
        ])
      ],
      'GET /places/search': [
        FakeReply(200, [_place('p9', 'พูสี (Mount Phousi)')])
      ],
      'POST /days/d1/items': [
        FakeReply(200, {
          'place': {
            'id': 'new-1',
            'title': 'พระราชวังหลวง',
            'category': 'sightseeing',
            'order': 1,
            'cost': 0,
          }
        })
      ],
      'POST /trips/trip-1/travel-segments/retry': [FakeReply(200, [])],
    });
  });

  testWidgets('+ สถานที่ opens แนะนำสถานที่ with places around the trip',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _openSheet(tester);

    expect(find.text('แนะนำสถานที่'), findsOneWidget);
    expect(find.text('พระราชวังหลวง'), findsOneWidget);
    expect(find.text('Dyen Sabai'), findsOneWidget);
    expect(find.text('ยังไม่ได้เลือกสถานที่'), findsOneWidget);

    // The anchor came off the stop, since this trip has no destinationPlace.
    final suggest = adapter.requests
        .firstWhere((r) => r.path == '/places/suggest');
    expect(suggest.queryParameters['lat'], 19.8935);
    expect(suggest.queryParameters['lng'], 102.1357);
  });

  testWidgets('picking a place flips its button and arms ถัดไป',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _openSheet(tester);
    expect(find.text('เพิ่มแล้ว'), findsNothing);

    await tester.tap(find.text('เพิ่มแผน').first);
    await tester.pumpAndSettle();

    expect(find.text('เพิ่มแล้ว'), findsOneWidget);
    expect(find.text('กด "ถัดไป" เพื่อใส่รายละเอียด'), findsOneWidget);
  });

  testWidgets('the details step names the day it will add to', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _openSheet(tester);
    await tester.tap(find.text('เพิ่มแผน').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();

    expect(find.text('รายละเอียดเพิ่มสถานที่'), findsOneWidget);
    expect(find.text('เพิ่มลงวันที่ 1'), findsOneWidget);
    expect(find.text('เพิ่มลงแผน'), findsOneWidget);

    // The form opens on the pencil, and the clock reads 12-hour like the rest
    // of the plan does — TimeOfDay.format would follow the device instead.
    // The edit page behind the sheet has a pencil of its own, so scope to the
    // sheet rather than matching both.
    await tester.tap(find.descendant(
      of: find.byType(SuggestPlacesSheet),
      matching: find.byIcon(Icons.edit_outlined),
    ));
    await tester.pumpAndSettle();
    expect(find.text('10:30 AM'), findsOneWidget);
    expect(find.text('ค่าใช้จ่าย (ต่อคน)'), findsOneWidget);
  });

  testWidgets('เพิ่มลงแผน posts the stop, then calculates the legs once',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _openSheet(tester);
    await tester.tap(find.text('เพิ่มแผน').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เพิ่มลงแผน'));
    await tester.pumpAndSettle();

    final body = adapter.bodyOf('POST /days/d1/items')!;
    expect(body['placeId'], 'p1');
    expect(body['startTime'], '10:30');
    // The place is an attraction, so the stop defaults to sightseeing.
    expect(body['category'], 'sightseeing');
    // An untouched cost field must not write a ฿0 line.
    expect(body.containsKey('costAmount'), isFalse);

    // Routing is left until the batch is in, so exactly one retry call.
    expect(
      adapter.paths
          .where((p) => p == 'POST /trips/trip-1/travel-segments/retry')
          .length,
      1,
    );
    // The sheet closed on success.
    expect(find.text('แนะนำสถานที่'), findsNothing);
  });

  testWidgets('a category chip narrows the request', (tester) async {
    // Wide enough that every chip is on screen: this test is about the query
    // the chip builds, not about the row scrolling.
    tester.view.physicalSize = const Size(900 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _openSheet(tester);
    // "สถานที่เที่ยว" is the one chip label that is not also a category badge
    // on a card in this fixture, so find.text cannot pick the wrong widget.
    await tester.tap(find.text('สถานที่เที่ยว'));
    await tester.pumpAndSettle();

    final last =
        adapter.requests.lastWhere((r) => r.path == '/places/suggest');
    expect(last.queryParameters['category'], 'activity');
  });

  testWidgets('typing searches instead of suggesting', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _openSheet(tester);
    await tester.tap(find.byIcon(Icons.search).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'พูสี');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('พูสี (Mount Phousi)'), findsOneWidget);
    final search =
        adapter.requests.firstWhere((r) => r.path == '/places/search');
    expect(search.queryParameters['q'], 'พูสี');
  });

  testWidgets('a trip with no coordinates says so instead of opening',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    adapter.replies['GET /trips/trip-1'] = [
      FakeReply(200, _tripJson(withCoordinates: false))
    ];

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('สถานที่').first);
    await tester.pumpAndSettle();

    expect(find.text('แนะนำสถานที่'), findsNothing);
    expect(
      find.textContaining('ยังไม่รู้พิกัดของทริปนี้'),
      findsOneWidget,
    );
  });
}
