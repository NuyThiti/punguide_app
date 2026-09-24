import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/trip_detail/presentation/trip_detail_screen.dart';
import 'package:pluno/features/trips/presentation/providers/trip_providers.dart';

import 'support/fake_api.dart';

late FakeAdapter adapter;

/// A published post: two spots, the second carrying every extra the composer
/// can collect.
Map<String, dynamic> _postJson({List<Map<String, dynamic>>? contents}) =>
    <String, dynamic>{
      'id': 'trip-1',
      'ownerId': 'u1',
      'type': 'content',
      'title': 'ที่เที่ยวระยอง',
      'destination': 'เทศบาลนครระยอง · ระยอง',
      'description': 'ระยองเป็นจังหวัดที่มีสถานที่ท่องเที่ยวมากมาย',
      'status': 'published',
      'schedule': const <String, dynamic>{},
      'totalBudget': 0,
      'brief': const <String, dynamic>{
        'styles': <String>['mountain', 'cafe', 'local'],
      },
      'customer': const <String, dynamic>{
        'id': 'u1',
        'name': 'Thitichaya Butsala',
        'groupSize': 1,
      },
      'visibility': 'public',
      'isSaved': false,
      'isLiked': false,
      'likeCount': 0,
      'remixCount': 0,
      'days': const <Map<String, dynamic>>[],
      'contents': contents ?? _spots(),
      'createdAt': '2026-09-22T00:00:00.000Z',
      'updatedAt': '2026-09-22T00:00:00.000Z',
    };

/// A spot carrying four photos, the third of which the server lost.
List<Map<String, dynamic>> _photoSpot() => [
      <String, dynamic>{
        'title': 'พิพิธภัณฑ์เมืองระยอง',
        'content': 'เนื้อหา',
        'mediaIds': const <String>[
          '11111111-1111-4111-8111-111111111111',
          '22222222-2222-4222-8222-222222222222',
          '33333333-3333-4333-8333-333333333333',
          '44444444-4444-4444-8444-444444444444',
        ],
        'images': const <Map<String, dynamic>>[
          {
            'mediaId': '11111111-1111-4111-8111-111111111111',
            'urls': {'large': 'https://img/1-l', 'thumbnail': 'https://img/1-t'}
          },
          {
            'mediaId': '22222222-2222-4222-8222-222222222222',
            'urls': {'large': 'https://img/2-l', 'thumbnail': 'https://img/2-t'}
          },
          {
            'mediaId': '33333333-3333-4333-8333-333333333333',
            'unavailable': true
          },
          {
            'mediaId': '44444444-4444-4444-8444-444444444444',
            'urls': {'large': 'https://img/4-l', 'thumbnail': 'https://img/4-t'}
          },
        ],
      },
    ];

List<Map<String, dynamic>> _spots() => [
      <String, dynamic>{
        'title': 'วัดป่าประดู่ – ระยอง',
        'content': 'พระอารามหลวงแห่งแรกของระยอง มีพุทธสถาปัตยกรรมที่โดดเด่น',
        'opensAt': '08:00',
        'closesAt': '17:00',
        'location': {
          'status': 'confirmed',
          'name': 'วัดป่าประดู่ พระอารามหลวง',
        },
      },
      <String, dynamic>{
        'title': 'พิพิธภัณฑ์เมืองระยอง',
        'content': 'บ้านเดิมของขุนศรีอุทัยเขตร ไม่มีค่าเข้าชม',
        'opensAt': '09:00',
        'closesAt': '18:00',
        'contactInfo': '084-945-3939',
        'transportModes': <String>['MRT', 'เดิน'],
        'transportCost': 100,
        'tripHack': 'มาเย็น ๆ แสงสวย คนน้อย และร้านข้าง ๆ เพิ่งเปิดพอดี',
        'location': {
          'status': 'confirmed',
          'name': 'พิพิธภัณฑ์เมืองระยอง',
        },
      },
    ];

Widget _harness({AuthUser? viewer}) => ProviderScope(
      overrides: [
        plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
        selectedTripProvider.overrideWith((ref, tripId) async => null),
        currentUserProvider
            .overrideWith((ref) => Future<AuthUser?>.value(viewer)),
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
              path: '/home',
              name: AppRoute.home.name,
              builder: (_, __) => const Scaffold(body: Text('home page')),
            ),
          ],
        ),
      ),
    );

Future<void> _pumpPost(
  WidgetTester tester, {
  Map<String, dynamic>? trip,
  AuthUser? viewer,
}) async {
  adapter = FakeAdapter({
    'GET /trips/trip-1': [FakeReply(200, trip ?? _postJson())],
  });
  await tester.pumpWidget(_harness(viewer: viewer));
  await tester.pumpAndSettle();
}

const _owner = AuthUser(id: 'u1', username: 'maki');
const _visitor = AuthUser(id: 'u2', username: 'someone');

void main() {
  setUp(() => adapter = FakeAdapter({}));

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(393 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('the header reads the post back the way it was written',
      (tester) async {
    phone(tester);
    await _pumpPost(tester);

    expect(find.text('ที่เที่ยวระยอง'), findsOneWidget);
    expect(find.text('เทศบาลนครระยอง · ระยอง'), findsOneWidget);
    expect(find.text('Thitichaya Butsala'), findsOneWidget);
    expect(
      find.text('ระยองเป็นจังหวัดที่มีสถานที่ท่องเที่ยวมากมาย'),
      findsOneWidget,
    );
    // Trip Activity, in the composer's own labels.
    expect(find.text('ภูเขา'), findsOneWidget);
    expect(find.text('คาเฟ่'), findsOneWidget);
    expect(find.text('เข้าถึงท้องถิ่น'), findsOneWidget);
  });

  testWidgets('the cover is not repeated above the spot it came from',
      (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      trip: <String, dynamic>{
        ..._postJson(contents: [
          <String, dynamic>{
            'title': 'จุดที่ปกมาจาก',
            'content': 'เนื้อหา',
            'imageUrls': const <String>['https://img/cover'],
          },
        ]),
        // The writer picked this spot's photo with "ใช้เป็นหน้าปก".
        'coverImage': const <String, dynamic>{
          'mediaId': '55555555-5555-4555-8555-555555555555',
          'urls': {
            'large': 'https://img/cover',
            'thumbnail': 'https://img/cover-t'
          },
        },
      },
    );

    // The photo appears once — in its spot — not again as a header.
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
  });

  testWidgets('spots are numbered and titled', (tester) async {
    phone(tester);
    await _pumpPost(tester);

    expect(find.text('จุด 1'), findsOneWidget);
    expect(find.text('จุด 2'), findsOneWidget);
    expect(find.text('วัดป่าประดู่ – ระยอง'), findsOneWidget);
    expect(find.text('พิพิธภัณฑ์เมืองระยอง'), findsWidgets);
  });

  testWidgets('a spot shows the extras the composer collected',
      (tester) async {
    phone(tester);
    await _pumpPost(tester);

    // Hours read the way the composer writes them.
    expect(find.text('08.00 - 17.00 น.'), findsOneWidget);
    expect(find.text('09.00 - 18.00 น.'), findsOneWidget);
    expect(find.text('084-945-3939'), findsOneWidget);
    expect(find.text('MRT · เดิน ฿100'), findsOneWidget);
  });

  testWidgets('a trip hack is shown in full, not clipped into a chip',
      (tester) async {
    phone(tester);
    await _pumpPost(tester);

    expect(find.text('Trip Hack'), findsOneWidget);
    final hack = find.text('มาเย็น ๆ แสงสวย คนน้อย และร้านข้าง ๆ เพิ่งเปิดพอดี');
    expect(hack, findsOneWidget);
    expect(tester.widget<Text>(hack).overflow, isNot(TextOverflow.ellipsis));
  });

  testWidgets('hours a spot does not have are left out', (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      trip: _postJson(contents: [
        <String, dynamic>{'title': 'จุดเงียบ ๆ', 'content': 'ไม่มีอะไรพิเศษ'},
      ]),
    );

    expect(find.text('จุดเงียบ ๆ'), findsOneWidget);
    expect(find.textContaining(' น.'), findsNothing);
    expect(find.text('Trip Hack'), findsNothing);
  });

  testWidgets('only a hand-pinned place is shown', (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      trip: _postJson(contents: [
        <String, dynamic>{
          'title': 'จุดที่ผู้ช่วยเดา',
          'content': 'เนื้อหา',
          // The assistant's guess: the server hides it from a public read, so
          // the viewer must not publish a name nobody confirmed.
          'location': {'status': 'suggested', 'name': 'ร้านที่เดาไว้'},
        },
      ]),
    );

    expect(find.text('ร้านที่เดาไว้'), findsNothing);
  });

  // A fresh tree per viewer: re-pumping an unchanged tree shape keeps the
  // state the last pump left behind, so the bar would still read the old one.
  testWidgets('the owner can edit the post', (tester) async {
    phone(tester);
    await _pumpPost(tester, viewer: _owner);

    expect(find.text('แก้ไขโพสต์'), findsOneWidget);
  });

  testWidgets('a visitor gets no action bar on a post', (tester) async {
    phone(tester);
    await _pumpPost(tester, viewer: _visitor);

    // A post is not remixable, so somebody else's gets no bar at all.
    expect(find.text('แก้ไขโพสต์'), findsNothing);
    expect(find.text('Remix Trip'), findsNothing);
  });

  /// The real value from the ระยอง post: `contactInfo` is free text, not a
  /// phone number, so it is the field that reaches the edge first.
  const longContact =
      'นายบุญนันต์ หมัดเชี่ยว ชมรมอนุรักษ์ฟื้นฟูเมืองเก่าระยอง 084-945-3939';

  testWidgets('a long contact wraps instead of running off the screen',
      (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      trip: _postJson(contents: [
        <String, dynamic>{
          'title': 'พิพิธภัณฑ์เมืองระยอง',
          'content': 'เนื้อหา',
          'contactInfo': longContact,
        },
      ]),
    );

    expect(tester.takeException(), isNull);

    final chip = find.text(longContact);
    expect(chip, findsOneWidget);
    // Nothing is clipped away: a truncated phone number is a broken one.
    expect(tester.widget<Text>(chip).overflow, isNot(TextOverflow.ellipsis));
    // And it stays inside the screen.
    expect(tester.getRect(chip).right, lessThanOrEqualTo(393));
  });

  testWidgets('every field holds its width when the writer runs long',
      (tester) async {
    // The narrowest phone still worth supporting: if it fits here it fits.
    tester.view.physicalSize = const Size(320 * 3, 2200 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const long = 'ชมรมอนุรักษ์ฟื้นฟูเมืองเก่าระยองและพิพิธภัณฑ์เมืองระยอง';

    await _pumpPost(
      tester,
      trip: <String, dynamic>{
        ..._postJson(contents: [
          <String, dynamic>{
            'title': '$long $long',
            'content': 'เนื้อหา',
            'contactInfo': longContact,
            'transportModes': <String>[long, 'รถตู้ / รถเหมา', long],
            'transportCost': 1234567,
            'tripHack': '$long $long',
            'visitedAt': '06:30',
            'location': {'status': 'confirmed', 'name': '$long $long'},
          },
        ]),
        'title': '$long $long',
        'destination': '$long $long',
        'description': '$long $long',
      },
    );

    expect(tester.takeException(), isNull, reason: 'on load');

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'after scrolling');
  });

  testWidgets('a photo says how many there are and opens full size',
      (tester) async {
    phone(tester);
    await _pumpPost(tester, trip: _postJson(contents: _photoSpot()));

    // Three loadable photos of four: the dead one is not counted.
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('3/3'), findsOneWidget);
    // The one that failed holds its place but offers nothing to open.
    expect(find.text('รูปนี้ไม่พร้อมใช้งาน'), findsOneWidget);

    await tester.tap(find.text('2/3'));
    await tester.pumpAndSettle();

    // Full screen, on the photo that was tapped.
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.byTooltip('ปิด'), findsOneWidget);
  });

  testWidgets('the full-size viewer swipes through the spot and closes',
      (tester) async {
    phone(tester);
    await _pumpPost(tester, trip: _postJson(contents: _photoSpot()));

    await tester.tap(find.text('1/3'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();

    // Back on the post.
    expect(find.text('ที่เที่ยวระยอง'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('a lone photo opens without a counter', (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      trip: _postJson(contents: [
        <String, dynamic>{
          'title': 'จุดเดียว',
          'content': 'เนื้อหา',
          'imageUrls': const <String>['https://img/only'],
        },
      ]),
    );

    // No "1/1" — a count means nothing when there is one.
    expect(find.textContaining('/'), findsNothing);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();

    expect(find.byTooltip('ปิด'), findsOneWidget);
    expect(find.textContaining(' / '), findsNothing);
  });

  testWidgets('the post lays out from a small phone to a tablet',
      (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    for (final size in <Size>[
      const Size(320, 900),
      const Size(393, 1400),
      const Size(834, 1400),
      const Size(1194, 900),
    ]) {
      tester.view.physicalSize = size * 3;
      await _pumpPost(tester);
      expect(tester.takeException(), isNull, reason: '$size on load');

      await tester.drag(find.text('ที่เที่ยวระยอง'), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size after scrolling');
    }
  });
}
