import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/core/theme/app_colors.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/trip_detail/presentation/share_trip.dart';
import 'package:pluno/features/trip_detail/presentation/trip_detail_screen.dart';
import 'package:share_plus/share_plus.dart';

import 'support/fake_api.dart';

late FakeAdapter adapter;

/// What reached the share sheet, in order — the real sheet never opens.
final shared = <ShareParams>[];

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
      'saveCount': 7,
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
        shareSheetProvider
            .overrideWithValue((params) async => shared.add(params)),
        currentUserProvider.overrideWith(
          (ref) => viewerPending
              ? Completer<AuthUser?>().future
              : Future<AuthUser?>.value(viewer),
        ), // Liking and saving ask for an account first.
        isSignedInProvider.overrideWithValue(viewer != null),
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
              path: '/create',
              name: AppRoute.createTrip.name,
              builder: (_, __) => const Scaffold(body: Text('create page')),
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
  Map<String, List<FakeReply>> extra = const {},
}) async {
  shared.clear();
  adapter = FakeAdapter({
    'GET /trips/trip-1': [FakeReply(status, trip ?? _tripJson())],
    // The author chip reads whether the visitor already follows the owner.
    'GET /users/u1': [
      const FakeReply(200, {
        'id': 'u1',
        'username': 'maki',
        'followerCount': 0,
        'followingCount': 0,
        'isFollowing': false,
        'followsYou': false,
        'isMe': false,
      }),
    ],
    ...extra,
  });
  await tester.pumpWidget(
    _harness(viewer: viewer, viewerPending: viewerPending),
  );
  await tester.pumpAndSettle();
  // Knowing the viewer starts the author's profile read only after that
  // settle; one more pass lets it land.
  await tester.pump();
  await tester.pumpAndSettle();
}

/// The trip's own owner, `u1`.
const _owner = AuthUser(id: 'u1', username: 'makitravels');

/// Somebody else entirely.
const _visitor = AuthUser(id: 'u2', username: 'someone');

/// The traveller's own plans, for "เพิ่มลงทริป".
final _myPlans = <Map<String, dynamic>>[
  {
    'id': 'plan-9',
    'type': 'plan_trip',
    'title': 'เดินเล่นพระนคร',
    'destination': 'Bangkok',
    'status': 'draft',
    'schedule': {'durationDays': 2},
    'totalBudget': 0,
    'tags': <String>[],
    'placeCount': 3,
    'isSaved': false,
    'isLiked': false,
    'likeCount': 0,
    'remixCount': 0,
  },
];

/// plan-9 in full: two days, so the stop should land on the second.
final _planNine = <String, dynamic>{
  'id': 'plan-9',
  'ownerId': 'u2',
  'title': 'เดินเล่นพระนคร',
  'destination': 'Bangkok',
  'status': 'draft',
  'schedule': {'durationDays': 2},
  'totalBudget': 0,
  'days': [
    {'id': 'd9', 'dayNumber': 1, 'activities': <Map<String, dynamic>>[]},
    {'id': 'd10', 'dayNumber': 2, 'activities': <Map<String, dynamic>>[]},
  ],
};

Future<void> _openMenu(WidgetTester tester, {int index = 0}) async {
  final menu = find.byTooltip('ตัวเลือก').at(index);
  await tester.ensureVisible(menu);
  await tester.pumpAndSettle();
  await tester.tap(menu);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    adapter = FakeAdapter({});
  });

  testWidgets("Trip Overview prints the trip's own facts, not a sample",
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    expect(find.text('ทริปหลวงพระบางสายชิล'), findsOneWidget);
    expect(find.text('Luang Prabang, Laos'), findsOneWidget);
    expect(find.text('3 วัน'), findsOneWidget);
    // Three stops across the two days.
    expect(find.text('3 สถานที่'), findsOneWidget);
    // ฿9,000 over a group of three.
    expect(find.text('฿3,000/คน'), findsOneWidget);
    // The author sits in the pinned bar, as on a post.
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
    ]) {
      expect(find.text(invented), findsNothing, reason: invented);
    }
  });

  testWidgets('Trip Overview carries the real counts, compacted',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    expect(find.text('Trip Overview'), findsOneWidget);
    expect(find.text('1.1K'), findsOneWidget);
    expect(find.text('1.7K'), findsOneWidget);
    // With no description of its own, the plan's styles stand in.
    expect(find.text('วัฒนธรรม · อาหาร'), findsOneWidget);
  });

  testWidgets('Trip Overview reads remix · heart · bookmark on one row',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester, viewer: _visitor);

    final heart = find.byKey(const Key('like-chip'));
    final save = find.byKey(const Key('save-chip'));
    expect(heart, findsOneWidget);
    expect(save, findsOneWidget);
    final row = tester.getCenter(find.text('Trip Overview')).dy;
    expect(tester.getCenter(heart).dy, closeTo(row, 2));
    expect(tester.getCenter(save).dy, closeTo(row, 2));
    // Each carries its own count.
    expect(
      find.descendant(of: heart, matching: find.text('1.7K')),
      findsOneWidget,
    );
    expect(find.descendant(of: save, matching: find.text('7')), findsOneWidget);
  });

  testWidgets('tapping the bookmark saves the trip and counts it at once',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      viewer: _visitor,
      extra: {
        'POST /trips/trip-1/save': [const FakeReply(204, null)],
        'DELETE /trips/trip-1/save': [const FakeReply(204, null)],
      },
    );
    final save = find.byKey(const Key('save-chip'));

    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(adapter.paths, contains('POST /trips/trip-1/save'));
    expect(find.descendant(of: save, matching: find.text('8')), findsOneWidget);

    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(adapter.paths, contains('DELETE /trips/trip-1/save'));
    expect(find.descendant(of: save, matching: find.text('7')), findsOneWidget);
  });

  testWidgets('tapping the heart likes the trip and counts it at once',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      viewer: _visitor,
      trip: {..._tripJson(), 'likeCount': 41},
      extra: {
        'POST /trips/trip-1/like': [const FakeReply(204, null)],
        'DELETE /trips/trip-1/like': [const FakeReply(204, null)],
      },
    );
    final heart = find.byKey(const Key('like-chip'));
    expect(
        find.descendant(of: heart, matching: find.text('41')), findsOneWidget);

    await tester.tap(heart);
    await tester.pumpAndSettle();
    expect(adapter.paths, contains('POST /trips/trip-1/like'));
    expect(
        find.descendant(of: heart, matching: find.text('42')), findsOneWidget);
    expect(find.descendant(of: heart, matching: find.byIcon(Icons.favorite)),
        findsOneWidget);

    await tester.tap(heart);
    await tester.pumpAndSettle();
    expect(adapter.paths, contains('DELETE /trips/trip-1/like'));
    expect(
        find.descendant(of: heart, matching: find.text('41')), findsOneWidget);
  });

  testWidgets('a refused like puts the heart and the count back',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      viewer: _visitor,
      trip: {..._tripJson(), 'likeCount': 41},
      extra: {
        'POST /trips/trip-1/like': [
          const FakeReply(404, {'message': 'Trip not found'}),
        ],
      },
    );
    final heart = find.byKey(const Key('like-chip'));
    await tester.tap(heart);
    await tester.pumpAndSettle();

    expect(
        find.descendant(of: heart, matching: find.text('41')), findsOneWidget);
    expect(
      find.descendant(of: heart, matching: find.byIcon(Icons.favorite_border)),
      findsOneWidget,
    );
    expect(find.textContaining('ถูกใจทริปไม่สำเร็จ'), findsOneWidget);
  });

  testWidgets("the owner's bookmark is a readout, and gone at zero",
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester, viewer: _owner);

    expect(find.byKey(const Key('like-chip')), findsOneWidget);
    final save = find.byKey(const Key('save-chip'));
    expect(find.descendant(of: save, matching: find.text('7')), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(adapter.paths, isNot(contains('POST /trips/trip-1/save')));
  });

  testWidgets("the owner's row has no bookmark nobody has saved",
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      viewer: _owner,
      trip: {..._tripJson(), 'saveCount': 0},
    );

    expect(find.byKey(const Key('like-chip')), findsOneWidget);
    expect(find.byKey(const Key('save-chip')), findsNothing);
  });

  testWidgets('the stops sit under ตารางแผน on white, not cream',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1100 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    expect(find.text('ตารางแผน'), findsOneWidget);
    final band = find.ancestor(
      of: find.text('ตารางแผน'),
      matching: find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == AppColors.screen,
      ),
    );
    expect(band, findsOneWidget);
    expect(tester.getRect(band).width, 393);
  });

  testWidgets('a stop shows its time, name, mode and note', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1100 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    expect(find.text('12:30 PM'), findsOneWidget);
    expect(find.text('Le Banneton Café'), findsOneWidget);
    expect(find.text('ร้านเบเกอรี่เก่าแก่ของหลวงพระบาง'), findsOneWidget);
    // Second stop: the chip names the mode; the minutes wait in the details.
    expect(find.text('จักรยาน'), findsOneWidget);
    expect(find.text('จักรยาน • 8 นาที'), findsNothing);
    // First stop has nothing to travel from, so it falls back to its category.
    expect(find.text('ร้านอาหาร'), findsOneWidget);
    // The position badge.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('ดูรายละเอียด opens the way there and closes again',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1100 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    // Only the bicycle stop has anything behind the toggle.
    expect(find.text('ดูรายละเอียด'), findsOneWidget);
    expect(find.text('จักรยาน · 8 นาที'), findsNothing);

    await tester.tap(find.text('ดูรายละเอียด'));
    await tester.pumpAndSettle();
    expect(find.text('จักรยาน · 8 นาที'), findsOneWidget);
    expect(find.text('ย่อรายละเอียด'), findsOneWidget);

    await tester.tap(find.text('ย่อรายละเอียด'));
    await tester.pumpAndSettle();
    expect(find.text('จักรยาน · 8 นาที'), findsNothing);
  });

  testWidgets("Google's hours, phone and website fill a linked stop's details",
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1100 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const placeId = '7f1c2a9e-4b3d-4e8a-9c21-5d6e7f8a9b0c';
    final days = _twoDays();
    final first = (days.first['activities'] as List).first as Map;
    first['location'] = {'name': 'Le Banneton Café', 'placeId': placeId};

    await _pumpTrip(
      tester,
      trip: _tripJson(days: days),
      extra: {
        'GET /places/$placeId': [
          FakeReply(200, <String, dynamic>{
            'id': placeId,
            'name': 'Le Banneton Café',
            'nationalPhoneNumber': '085 809 0835',
            'websiteUri': 'https://lebanneton.example',
            'regularOpeningHours': {
              'weekdayDescriptions': [
                for (final day in [
                  'วันจันทร์',
                  'วันอังคาร',
                  'วันพุธ',
                  'วันพฤหัสบดี',
                  'วันศุกร์',
                  'วันเสาร์',
                  'วันอาทิตย์',
                ])
                  '$day: 06:00–14:30',
              ],
            },
          }),
        ],
      },
    );

    await tester.tap(find.text('ดูรายละเอียด').first);
    await tester.pumpAndSettle();

    expect(find.text('จ - อา : 06.00 - 14.30 น.'), findsOneWidget);
    expect(find.text('085 809 0835'), findsOneWidget);
    expect(find.text('เว็บร้าน'), findsOneWidget);
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

    await tester.ensureVisible(find.text('วันที่ 2'));
    await tester.tap(find.text('วันที่ 2'));
    await tester.pumpAndSettle();

    expect(find.text('น้ำตกกวางสี'), findsOneWidget);
    expect(find.text('Le Banneton Café'), findsNothing);
  });

  testWidgets('a one-day plan draws no day tabs', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1100 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      trip: _tripJson(
        days: [_twoDays().first],
        schedule: {'durationDays': 1},
      ),
    );

    expect(find.text('วันที่ 1'), findsNothing);
    expect(find.text('Le Banneton Café'), findsOneWidget);
  });

  testWidgets('the ⋮ menu offers map, save and add-to-trip', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1100 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);
    await _openMenu(tester);

    expect(find.text('นำทางบน Map'), findsOneWidget);
    expect(find.text('บันทึก'), findsOneWidget);
    expect(find.text('เพิ่มลงทริป'), findsOneWidget);
    // On a bottom sheet headed by the stop it acts on, not a popup.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(PopupMenuItem<Object>), findsNothing);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Le Banneton Café'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('บันทึก reports that it is not wired', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1100 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);
    await _openMenu(tester);
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    expect(find.text('บันทึกสถานที่ยังไม่เปิดใช้งาน'), findsOneWidget);
  });

  Future<void> openTripMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('เมนู'));
    await tester.pumpAndSettle();
  }

  testWidgets('the header has a ☰ menu instead of a share button',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester, viewer: _visitor);

    expect(find.byTooltip('แชร์'), findsNothing);
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });

  testWidgets("somebody else's trip menu offers only แชร์", (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester, viewer: _visitor);
    await openTripMenu(tester);

    expect(find.text('แชร์'), findsOneWidget);
    expect(find.text('แก้ไขทริป'), findsNothing);
    expect(find.text('ลบทริป'), findsNothing);
  });

  testWidgets('the menu offers only แชร์ until it is known who is looking',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester, viewerPending: true);
    await openTripMenu(tester);

    expect(find.text('แชร์'), findsOneWidget);
    expect(find.text('ลบทริป'), findsNothing);
  });

  testWidgets('the owner gets แก้ไขทริป, ลบทริป and แชร์', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester, viewer: _owner);
    await openTripMenu(tester);

    expect(find.text('แก้ไขทริป'), findsOneWidget);
    expect(find.text('ลบทริป'), findsOneWidget);
    expect(find.text('แชร์'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets("the owner's แชร์ shares the server's link with the title",
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      viewer: _owner,
      extra: {
        'POST /trips/trip-1/share': [
          FakeReply(201, <String, dynamic>{
            'id': 'share-1',
            'shareUrl': 'https://paigun-punguide.vercel.app/shared-trips/tok',
            'shareToken': 'tok',
            'accessLevel': 'view',
            'isActive': true,
          }),
        ],
      },
    );
    await openTripMenu(tester);
    await tester.tap(find.text('แชร์'));
    await tester.pumpAndSettle();

    expect(adapter.paths, contains('POST /trips/trip-1/share'));
    expect(shared, hasLength(1));
    expect(
      shared.single.text,
      'ทริปหลวงพระบางสายชิล\n'
      'https://paigun-punguide.vercel.app/shared-trips/tok',
    );
    expect(shared.single.subject, 'ทริปหลวงพระบางสายชิล');
  });

  testWidgets("the owner's แชร์ says so when the link cannot be made",
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      viewer: _owner,
      extra: {
        'POST /trips/trip-1/share': [
          FakeReply(500, <String, dynamic>{'message': 'boom'}),
        ],
      },
    );
    await openTripMenu(tester);
    await tester.tap(find.text('แชร์'));
    await tester.pumpAndSettle();

    expect(shared, isEmpty);
    expect(find.text('สร้างลิงก์แชร์ไม่สำเร็จ ลองอีกครั้ง'), findsOneWidget);
  });

  testWidgets("a visitor's แชร์ reports that it is not wired", (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);
    await openTripMenu(tester);
    await tester.tap(find.text('แชร์'));
    await tester.pumpAndSettle();

    expect(find.text('แชร์ทริปยังไม่เปิดใช้งาน'), findsOneWidget);
  });

  testWidgets('แก้ไขทริป opens the plan editor', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester, viewer: _owner);
    await openTripMenu(tester);
    await tester.tap(find.text('แก้ไขทริป'));
    await tester.pumpAndSettle();

    expect(find.text('editor page'), findsOneWidget);
  });

  testWidgets('ลบทริป asks first, deletes, then leaves the page',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      viewer: _owner,
      extra: {
        'DELETE /trips/trip-1': [const FakeReply(204, null)],
      },
    );
    await openTripMenu(tester);
    await tester.tap(find.text('ลบทริป'));
    await tester.pumpAndSettle();

    expect(find.text('ลบทริปนี้'), findsOneWidget);
    expect(adapter.paths, isNot(contains('DELETE /trips/trip-1')));

    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();

    expect(adapter.paths, contains('DELETE /trips/trip-1'));
    expect(find.text('home page'), findsOneWidget);
    expect(find.text('ลบทริปแล้ว'), findsOneWidget);
  });

  testWidgets('cancelling ลบทริป deletes nothing', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester, viewer: _owner);
    await openTripMenu(tester);
    await tester.tap(find.text('ลบทริป'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();

    expect(adapter.paths, isNot(contains('DELETE /trips/trip-1')));
    expect(find.text('ทริปหลวงพระบางสายชิล'), findsOneWidget);
  });

  testWidgets('a failed delete stays on the page and says so', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      viewer: _owner,
      extra: {
        'DELETE /trips/trip-1': [const FakeReply(500, null)],
      },
    );
    await openTripMenu(tester);
    await tester.tap(find.text('ลบทริป'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();

    expect(find.text('home page'), findsNothing);
    expect(find.text('ทริปหลวงพระบางสายชิล'), findsOneWidget);
  });

  testWidgets(
      'เพิ่มลงทริป copies the stop onto the last day of the picked plan',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      viewer: _visitor,
      extra: {
        'GET /trips/mine': [FakeReply(200, _myPlans)],
        'GET /trips/plan-9': [FakeReply(200, _planNine)],
        'POST /days/d10/items': [
          FakeReply(201, <String, dynamic>{
            'place': {'id': 'copied', 'title': 'Le Banneton Café', 'order': 0},
          }),
        ],
      },
    );
    await _openMenu(tester);
    await tester.tap(find.text('เพิ่มลงทริป'));
    await tester.pumpAndSettle();

    expect(find.text('เพิ่มลงทริปใหม่'), findsOneWidget);
    expect(find.text('เดินเล่นพระนคร'), findsOneWidget);

    // ตกลง waits for a pick.
    final ok = find.widgetWithText(FilledButton, 'ตกลง');
    expect(tester.widget<FilledButton>(ok).onPressed, isNull);

    await tester.tap(find.text('เดินเล่นพระนคร'));
    await tester.pumpAndSettle();
    await tester.tap(ok);
    await tester.pumpAndSettle();

    final body = adapter.bodyOf('POST /days/d10/items');
    expect(body, isNotNull);
    // Le Banneton Café was typed by hand, so it goes up by name.
    expect(body!['customName'], 'Le Banneton Café');
    expect(body['category'], 'food');
    expect(body['notes'], 'ร้านเบเกอรี่เก่าแก่ของหลวงพระบาง');
    expect(find.text('เพิ่ม Le Banneton Café ลง เดินเล่นพระนคร แล้ว'),
        findsOneWidget);
  });

  testWidgets('a failed add keeps the sheet open and says so', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      extra: {
        'GET /trips/mine': [FakeReply(200, _myPlans)],
        'GET /trips/plan-9': [FakeReply(200, _planNine)],
        'POST /days/d10/items': [const FakeReply(500, null)],
      },
    );
    await _openMenu(tester);
    await tester.tap(find.text('เพิ่มลงทริป'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เดินเล่นพระนคร'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
    await tester.pumpAndSettle();

    expect(find.text('เพิ่มลงทริปไม่สำเร็จ ลองอีกครั้ง'), findsOneWidget);
    expect(find.text('เพิ่มลงทริปใหม่'), findsOneWidget);
  });

  testWidgets('เพิ่มลงทริปใหม่ opens the plan wizard', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      extra: {
        'GET /trips/mine': [FakeReply(200, _myPlans)],
      },
    );
    await _openMenu(tester);
    await tester.tap(find.text('เพิ่มลงทริป'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เพิ่มลงทริปใหม่'));
    await tester.pumpAndSettle();

    expect(find.text('create page'), findsOneWidget);
  });

  testWidgets('Remix Trip sits in the hero and opens the Remix sheet',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    // Above Trip Overview, not pinned to the foot of the screen.
    expect(
      tester.getRect(find.text('Remix Trip')).bottom,
      lessThan(tester.getRect(find.text('Trip Overview')).top),
    );

    await tester.tap(find.text('Remix Trip'));
    await tester.pumpAndSettle();

    expect(find.text('เลือกสถานที่จะ Remix'), findsOneWidget);
    expect(find.text('remix page'), findsNothing);
    // Every stop of every day, not only the day on screen.
    expect(find.text('0 / 3 รายการ', findRichText: true), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('น้ำตกกวางสี'),
      ),
      findsOneWidget,
    );
    // ถัดไป waits for a pick.
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'ถัดไป'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('เลือก Remix ทั้งหมด ticks every stop; ล้างที่เลือก clears them',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);
    await tester.tap(find.text('Remix Trip'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('เลือก Remix ทั้งหมด'));
    await tester.pump();
    expect(find.text('3 / 3 รายการ', findRichText: true), findsOneWidget);

    await tester.tap(find.text('ล้างที่เลือก'));
    await tester.pump();
    expect(find.text('0 / 3 รายการ', findRichText: true), findsOneWidget);
  });

  /// Ticks the waterfall (day 2) then the café (day 1), goes to the trip step
  /// and confirms เดินเล่นพระนคร.
  Future<void> remixTwoStops(WidgetTester tester) async {
    await tester.tap(find.text('Remix Trip'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('น้ำตกกวางสี')),
    );
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Le Banneton Café')),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'ถัดไป'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เดินเล่นพระนคร'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
    await tester.pumpAndSettle();
  }

  const remixPath = 'POST /trips/trip-1/remix/items/into/plan-9';

  Map<String, dynamic> remixed({
    List<String> added = const ['n1', 'n2'],
    List<String> skipped = const [],
    bool replayed = false,
  }) =>
      <String, dynamic>{
        'id': 'plan-9',
        'title': 'เดินเล่นพระนคร',
        'replayed': replayed,
        'addedItemIds': added,
        'skippedItemIds': skipped,
        'stagedItems': [
          {'id': 'n1', 'title': 'Le Banneton Café', 'order': 0},
          {'id': 'n2', 'title': 'น้ำตกกวางสี', 'order': 1},
        ],
      };

  testWidgets('Remix sends the picked stop ids, in plan order, to the shelf',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      viewer: _visitor,
      extra: {
        'GET /trips/mine': [FakeReply(200, _myPlans)],
        remixPath: [FakeReply(200, remixed())],
      },
    );
    await remixTwoStops(tester);

    final request = adapter.requests.singleWhere(
      (r) => '${r.method} ${r.path}' == remixPath,
    );
    // Day 1's café before day 2's waterfall, though ticked the other way.
    expect((request.data as Map)['itemIds'], ['s1', 's3']);
    expect(request.headers['Idempotency-Key'], isNotNull);
    // Nothing is written stop by stop any more.
    expect(
      adapter.paths.where((path) => path.startsWith('POST /days/')),
      isEmpty,
    );
    expect(find.text('Remix 2 สถานที่ลง เดินเล่นพระนคร แล้ว'), findsOneWidget);
  });

  testWidgets('places already on the shelf are reported, not hidden',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      viewer: _visitor,
      extra: {
        'GET /trips/mine': [FakeReply(200, _myPlans)],
        remixPath: [
          FakeReply(200, remixed(added: ['n1'], skipped: ['s3'])),
        ],
      },
    );
    await remixTwoStops(tester);

    expect(
      find.text(
        'Remix 1 สถานที่ลง เดินเล่นพระนคร แล้ว · 1 สถานที่อยู่ในทริปแล้ว',
      ),
      findsOneWidget,
    );
  });

  testWidgets("a refused remix keeps the sheet open with the server's reason",
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      viewer: _visitor,
      extra: {
        'GET /trips/mine': [FakeReply(200, _myPlans)],
        remixPath: [
          const FakeReply(403, {'message': 'เจ้าของปิดการ remix ทริปนี้'}),
        ],
      },
    );
    await remixTwoStops(tester);

    expect(find.text('เจ้าของปิดการ remix ทริปนี้'), findsOneWidget);
    expect(find.text('Remix ไปลงทริปไหน?'), findsOneWidget);
  });

  testWidgets('a retry after a failure reuses its Idempotency-Key',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      viewer: _visitor,
      extra: {
        'GET /trips/mine': [FakeReply(200, _myPlans)],
        remixPath: [
          const FakeReply(500, null),
          FakeReply(200, remixed()),
        ],
      },
    );
    await remixTwoStops(tester);
    expect(find.text('Remix ไม่สำเร็จ ลองอีกครั้ง'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
    await tester.pumpAndSettle();

    final keys = adapter.requests
        .where((r) => '${r.method} ${r.path}' == remixPath)
        .map((r) => r.headers['Idempotency-Key'])
        .toList();
    expect(keys, hasLength(2));
    expect(keys.first, isNotNull);
    expect(keys.last, keys.first);
    expect(find.text('Remix 2 สถานที่ลง เดินเล่นพระนคร แล้ว'), findsOneWidget);
  });

  testWidgets('changing the picks after a failure mints a new key',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      viewer: _visitor,
      extra: {
        'GET /trips/mine': [FakeReply(200, _myPlans)],
        remixPath: [
          const FakeReply(500, null),
          FakeReply(200, remixed()),
        ],
      },
    );
    await remixTwoStops(tester);

    // Back, take every stop, and confirm again.
    await tester.tap(find.widgetWithText(OutlinedButton, 'ย้อนกลับ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เลือก Remix ทั้งหมด'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'ถัดไป'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เดินเล่นพระนคร'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
    await tester.pumpAndSettle();

    final sent = adapter.requests
        .where((r) => '${r.method} ${r.path}' == remixPath)
        .toList();
    expect(sent, hasLength(2));
    expect((sent.last.data as Map)['itemIds'], ['s1', 's2', 's3']);
    expect(
      sent.last.headers['Idempotency-Key'],
      isNot(sent.first.headers['Idempotency-Key']),
    );
  });

  testWidgets('canRemix false hides Remix Trip from a visitor', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      viewer: _visitor,
      trip: {..._tripJson(), 'canRemix': false},
    );

    expect(find.text('Remix Trip'), findsNothing);
    expect(find.text('ทริปหลวงพระบางสายชิล'), findsOneWidget);
  });

  testWidgets('the trip step can go back to the stops it came from',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      extra: {
        'GET /trips/mine': [FakeReply(200, _myPlans)],
      },
    );
    await tester.tap(find.text('Remix Trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เลือก Remix ทั้งหมด'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'ถัดไป'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('เลือกสถานที่จะ Remix'), findsOneWidget);
    // The picks survive the round trip.
    expect(find.text('3 / 3 รายการ', findRichText: true), findsOneWidget);
  });

  testWidgets("the trip you are remixing from is not offered as a target",
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      viewer: _visitor,
      extra: {
        'GET /trips/mine': [
          FakeReply(200, [
            ..._myPlans,
            {..._myPlans.first, 'id': 'trip-1', 'title': 'ทริปต้นทาง'},
          ]),
        ],
      },
    );
    await tester.tap(find.text('Remix Trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เลือก Remix ทั้งหมด'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'ถัดไป'));
    await tester.pumpAndSettle();

    expect(find.text('เดินเล่นพระนคร'), findsOneWidget);
    expect(find.text('ทริปต้นทาง'), findsNothing);
  });

  testWidgets('a plan with no stops keeps the whole-trip remix route',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(
      tester,
      trip: _tripJson(days: const <Map<String, dynamic>>[]),
    );
    await tester.tap(find.text('Remix Trip'));
    await tester.pumpAndSettle();

    expect(find.text('remix page'), findsOneWidget);
  });

  testWidgets('the top bar stays pinned while the page scrolls',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    final back = tester.getRect(find.byTooltip('ย้อนกลับ'));
    final overviewBefore = tester.getTopLeft(find.text('Trip Overview'));

    await tester.drag(find.text('Trip Overview'), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Trip Overview')).dy,
      lessThan(overviewBefore.dy),
    );
    expect(tester.getRect(find.byTooltip('ย้อนกลับ')), back);
  });

  testWidgets("the owner's hero carries no button at all", (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester, viewer: _owner);

    // Editing lives in the header's ☰ — see แก้ไขทริป above.
    expect(find.text('แก้ไข'), findsNothing);
    expect(find.text('Remix Trip'), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    // With no pill to stretch the hero, the title must still centre.
    expect(
      tester.getCenter(find.text('ทริปหลวงพระบางสายชิล')).dx,
      closeTo(393 / 2, 0.5),
    );
  });

  testWidgets("somebody else's plan still offers Remix", (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester, viewer: _visitor);

    expect(find.text('Remix Trip'), findsOneWidget);
    expect(find.text('แก้ไข'), findsNothing);
  });

  testWidgets('no action at all until it is known who is looking',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // The trip has loaded but `/auth/me` has not answered. Guessing "visitor"
    // here would flash a purple Remix button on the owner's own plan.
    await _pumpTrip(tester, viewerPending: true);

    expect(find.text('ทริปหลวงพระบางสายชิล'), findsOneWidget);
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

  testWidgets('a part-filled plan still shows every day the trip claims',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Three days long, but only day 1 has an itinerary row — a row is only
    // created when a stop is added to that day.
    await _pumpTrip(
      tester,
      trip: _tripJson(days: <Map<String, dynamic>>[
        {
          'id': 'd1',
          'dayNumber': 1,
          'date': '2026-08-20',
          'activities': <Map<String, dynamic>>[
            {'id': 's1', 'title': 'วัดเชียงทอง', 'order': 0},
          ],
        },
      ]),
    );

    // Trip Overview says three days, so the tab strip must not say one.
    for (final day in ['วันที่ 1', 'วันที่ 2', 'วันที่ 3']) {
      expect(find.text(day), findsWidgets, reason: day);
    }
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
    expect(find.text('Remix Trip'), findsNothing);
  });

  testWidgets('a tablet centres the content column; the cover stays full-bleed',
      (tester) async {
    tester.view.physicalSize = const Size(1194 * 3, 834 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpTrip(tester);

    final cover = tester.getRect(find.byType(ClipRRect).first);
    expect(cover.left, 0);
    expect(cover.width, 1194);
    expect(tester.getRect(find.text('Trip Overview')).left, 237);
    // The bar belongs to the screen's edge, not the column.
    expect(tester.getRect(find.byTooltip('ย้อนกลับ')).left, 32);
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
}
