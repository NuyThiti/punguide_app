import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/trip_detail/presentation/trip_detail_screen.dart';
import 'package:pluno/features/trip_detail/presentation/widgets/comment_sheet.dart';
import 'package:pluno/features/trip_detail/presentation/widgets/trip_content_sections.dart';
import 'package:pluno/features/trips/presentation/providers/trip_providers.dart';
import 'package:pluno/shared/widgets/cover_image.dart';

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

Widget _harness({AuthUser? viewer, bool viewerPending = false}) =>
    ProviderScope(
      overrides: [
        // Signed in exactly when there is a viewer, so the bookmark can save.
        isSignedInProvider.overrideWithValue(viewer != null),
        plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
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
              path: '/home',
              name: AppRoute.home.name,
              builder: (_, __) => const Scaffold(body: Text('home page')),
            ),
            GoRoute(
              path: '/remix/:tripId',
              name: AppRoute.remixTrip.name,
              builder: (_, __) => const Scaffold(body: Text('remix page')),
            ),
            GoRoute(
              path: '/share/:tripId',
              name: AppRoute.shareSettings.name,
              builder: (_, __) => const Scaffold(body: Text('share settings')),
            ),
          ],
        ),
      ),
    );

Future<void> _pumpPost(
  WidgetTester tester, {
  Map<String, dynamic>? trip,
  AuthUser? viewer,
  bool viewerPending = false,
  Map<String, List<FakeReply>> extra = const {},
}) async {
  adapter = FakeAdapter({
    'GET /trips/trip-1': [FakeReply(200, trip ?? _postJson())],
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

const _owner = AuthUser(id: 'u1', username: 'maki');
const _visitor = AuthUser(id: 'u2', username: 'someone');

/// Opens every spot's details drawer — the extras are collapsed by default.
Future<void> _openDetails(WidgetTester tester) async {
  for (final toggle in find.text('ดูรายละเอียด').evaluate().toList()) {
    await tester.tap(find.byWidget(toggle.widget));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

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
    expect(find.text('ติดตาม'), findsOneWidget);
    expect(
      find.text('ระยองเป็นจังหวัดที่มีสถานที่ท่องเที่ยวมากมาย'),
      findsOneWidget,
    );
    expect(find.text('Trip Overview'), findsOneWidget);
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

    // The cover backs the hero; the only openable photo is the spot's own.
    expect(find.bySemanticsLabel('ดูรูปเต็ม'), findsOneWidget);
  });

  testWidgets('each spot is a heading over a card naming its place',
      (tester) async {
    phone(tester);
    await _pumpPost(tester);

    // The heading is the section's title…
    expect(find.text('วัดป่าประดู่ – ระยอง'), findsOneWidget);
    // …and the card names the place, once, not the title again.
    expect(find.text('วัดป่าประดู่ พระอารามหลวง'), findsOneWidget);
    expect(find.text('พิพิธภัณฑ์เมืองระยอง'), findsNWidgets(2));
  });

  testWidgets('a heading collapses the cards under it', (tester) async {
    phone(tester);
    await _pumpPost(tester);

    expect(find.text('วัดป่าประดู่ พระอารามหลวง'), findsOneWidget);

    await tester.tap(find.text('วัดป่าประดู่ – ระยอง'));
    await tester.pumpAndSettle();

    // The heading stays; its card is gone.
    expect(find.text('วัดป่าประดู่ – ระยอง'), findsOneWidget);
    expect(find.text('วัดป่าประดู่ พระอารามหลวง'), findsNothing);
  });

  testWidgets('a spot shows the extras the composer collected', (tester) async {
    phone(tester);
    await _pumpPost(tester);
    await _openDetails(tester);

    // Hours read the way the composer writes them.
    expect(find.text('เปิด/ปิด 08.00 - 17.00 น.'), findsOneWidget);
    expect(find.text('เปิด/ปิด 09.00 - 18.00 น.'), findsOneWidget);
    expect(find.text('084-945-3939'), findsOneWidget);
    expect(find.text('MRT · เดิน ฿100'), findsOneWidget);
  });

  testWidgets('a spot that names both hours prints them on one line',
      (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      trip: _postJson(contents: [
        <String, dynamic>{
          'title': 'จุดเดียว',
          'content': 'เนื้อหา',
          'visitedAt': '06:00',
          'opensAt': '06:00',
          'closesAt': '14:30',
        },
      ]),
    );

    await _openDetails(tester);

    // The design shows both halves; the composer's chip had room for one.
    expect(
      find.text('ไปตอน 06.00 น. | เปิด/ปิด 06.00 - 14.30 น.'),
      findsOneWidget,
    );
  });

  testWidgets('a trip hack is shown in full, not clipped into a chip',
      (tester) async {
    phone(tester);
    await _pumpPost(tester);
    await _openDetails(tester);

    expect(find.text('Trip Hack'), findsOneWidget);
    final hack =
        find.text('มาเย็น ๆ แสงสวย คนน้อย และร้านข้าง ๆ เพิ่งเปิดพอดี');
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

  testWidgets('a post with no headings still shows its cards', (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      trip: _postJson(contents: [
        <String, dynamic>{
          'content': 'เนื้อหาไม่มีหัวข้อ',
          'location': {'status': 'confirmed', 'name': 'ร้านลับ'},
        },
      ]),
    );

    // "case ไม่มีหัวข้อ": no heading to collapse, the card is simply open.
    expect(find.text('ร้านลับ'), findsOneWidget);
    expect(find.text('เนื้อหาไม่มีหัวข้อ'), findsOneWidget);
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
  testWidgets("the owner's hero carries no button at all", (tester) async {
    phone(tester);
    await _pumpPost(tester, viewer: _owner);

    // Editing moved to the header's ☰; the hero is Remix's, and only for
    // visitors.
    expect(find.text('แก้ไขโพสต์'), findsNothing);
    expect(find.text('Remix Trip'), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('a visitor gets no action bar on a post', (tester) async {
    phone(tester);
    await _pumpPost(tester, viewer: _visitor);

    // No edit bar — but Remix Trip is in the hero for everyone now.
    expect(find.text('แก้ไขโพสต์'), findsNothing);
    expect(find.text('Remix Trip'), findsOneWidget);
  });

  group('comments', () {
    Map<String, dynamic> comment(
      String id,
      String body, {
      String authorId = 'u9',
      String username = 'pongsak.t',
      String? parentId,
      int replyCount = 0,
      bool canEdit = false,
      bool canDelete = false,
    }) =>
        <String, dynamic>{
          'id': id,
          'tripId': 'trip-1',
          'parentId': parentId,
          'body': body,
          'author': {'id': authorId, 'username': username},
          'replyCount': replyCount,
          'createdAt': DateTime.now()
              .subtract(const Duration(hours: 5))
              .toUtc()
              .toIso8601String(),
          'editedAt': null,
          'isMine': canEdit,
          'canEdit': canEdit,
          'canDelete': canDelete,
        };

    Map<String, dynamic> page(List<Map<String, dynamic>> items) =>
        <String, dynamic>{
          'items': items,
          'total': items.length,
          'limit': 20,
          'offset': 0,
          'hasMore': false,
        };

    final thread = [
      comment('c1', 'remix ไปแล้ว งบรวม ฿1,200 พอดี'),
      comment(
        'c2',
        'On Lok Yun ไปกี่โมงดีคะ',
        authorId: 'u8',
        username: 'mintwalks',
        replyCount: 1,
      ),
    ];

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('comment-chip')));
      await tester.pumpAndSettle();
    }

    testWidgets('a post shows 💬 with its count', (tester) async {
      phone(tester);
      await _pumpPost(
        tester,
        viewer: _visitor,
        trip: {..._postJson(), 'commentCount': 200},
      );

      final chip = find.byKey(const Key('comment-chip'));
      expect(chip, findsOneWidget);
      expect(
        find.descendant(of: chip, matching: find.text('200')),
        findsOneWidget,
      );
    });

    // A fresh test, not a re-pump: an unchanged tree keeps the cached trip.
    testWidgets('a plan has no 💬', (tester) async {
      phone(tester);
      await _pumpPost(
        tester,
        viewer: _visitor,
        trip: {..._postJson(), 'type': 'plan_trip'},
      );
      expect(find.byKey(const Key('comment-chip')), findsNothing);
    });

    testWidgets('the sheet lists the thread, marks the owner, opens replies',
        (tester) async {
      phone(tester);
      await _pumpPost(
        tester,
        viewer: _visitor,
        extra: {
          'GET /trips/trip-1/comments': [FakeReply(200, page(thread))],
          'GET /trips/trip-1/comments/c2/replies': [
            FakeReply(
              200,
              page([
                comment(
                  'r1',
                  'ไปก่อน 08:00 ครับ',
                  authorId: 'u1',
                  username: 'cattravel',
                  parentId: 'c2',
                ),
              ]),
            ),
          ],
        },
      );
      await openSheet(tester);

      expect(find.text('Comment'), findsOneWidget);
      expect(find.text('remix ไปแล้ว งบรวม ฿1,200 พอดี'), findsOneWidget);
      expect(find.textContaining('5 ชม.', findRichText: true), findsWidgets);
      expect(find.text('ดูการตอบกลับ 1 รายการ'), findsOneWidget);

      await tester.tap(find.text('ดูการตอบกลับ 1 รายการ'));
      await tester.pumpAndSettle();

      expect(find.text('ไปก่อน 08:00 ครับ'), findsOneWidget);
      expect(find.text('ดูการตอบกลับ 1 รายการ'), findsNothing);
      // u1 owns the post.
      expect(find.textContaining('เจ้าของทริป', findRichText: true),
          findsOneWidget);
    });

    testWidgets(
        'sending a comment posts it, shows it first, and counts it at '
        'once', (tester) async {
      phone(tester);
      await _pumpPost(
        tester,
        viewer: _visitor,
        trip: {..._postJson(), 'commentCount': 2},
        extra: {
          'GET /trips/trip-1/comments': [FakeReply(200, page(thread))],
          'POST /trips/trip-1/comments': [
            FakeReply(201, comment('c3', 'สวยมากค่ะ', canEdit: true)),
          ],
        },
      );
      await openSheet(tester);

      await tester.enterText(find.byType(TextField), '  สวยมากค่ะ  ');
      await tester.pump();
      await tester.tap(find.byTooltip('ส่ง'));
      await tester.pumpAndSettle();

      expect(
          adapter.bodyOf('POST /trips/trip-1/comments'), {'body': 'สวยมากค่ะ'});
      expect(
        tester.getTopLeft(find.text('สวยมากค่ะ')).dy,
        lessThan(
          tester.getTopLeft(find.text('remix ไปแล้ว งบรวม ฿1,200 พอดี')).dy,
        ),
      );

      // The 💬 behind the sheet moved without the trip being read again.
      final chip = find.byKey(const Key('comment-chip'));
      expect(
          find.descendant(of: chip, matching: find.text('3')), findsOneWidget);
      expect(
        adapter.paths.where((p) => p == 'GET /trips/trip-1'),
        hasLength(1),
      );
    });

    testWidgets('answering a reply names who it answers', (tester) async {
      phone(tester);
      await _pumpPost(
        tester,
        viewer: _visitor,
        extra: {
          'GET /trips/trip-1/comments': [FakeReply(200, page(thread))],
          'GET /trips/trip-1/comments/c2/replies': [
            FakeReply(
              200,
              page([
                comment(
                  'r1',
                  'ไปก่อน 08:00 ครับ',
                  authorId: 'u1',
                  username: 'cattravel',
                  parentId: 'c2',
                ),
              ]),
            ),
          ],
          'POST /trips/trip-1/comments': [
            FakeReply(
              201,
              comment('r2', '@cattravel ขอบคุณค่ะ', parentId: 'c2'),
            ),
          ],
        },
      );
      await openSheet(tester);
      await tester.tap(find.text('ดูการตอบกลับ 1 รายการ'));
      await tester.pumpAndSettle();

      // ตอบกลับ under cattravel's reply — the last one on screen.
      await tester.tap(find.text('ตอบกลับ').last);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'ขอบคุณค่ะ');
      await tester.pump();
      await tester.tap(find.byTooltip('ส่ง'));
      await tester.pumpAndSettle();

      expect(adapter.bodyOf('POST /trips/trip-1/comments'), {
        'body': '@cattravel ขอบคุณค่ะ',
        'parentId': 'r1',
      });
    });

    testWidgets('ตอบกลับ sends the comment as parentId', (tester) async {
      phone(tester);
      await _pumpPost(
        tester,
        viewer: _visitor,
        extra: {
          'GET /trips/trip-1/comments': [FakeReply(200, page(thread))],
          'POST /trips/trip-1/comments': [
            FakeReply(201, comment('r9', 'ขอบคุณค่ะ', parentId: 'c1')),
          ],
        },
      );
      await openSheet(tester);

      await tester.tap(find.text('ตอบกลับ').first);
      await tester.pump();
      expect(find.text('ตอบกลับ @pongsak.t'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ขอบคุณค่ะ');
      await tester.pump();
      await tester.tap(find.byTooltip('ส่ง'));
      await tester.pumpAndSettle();

      expect(adapter.bodyOf('POST /trips/trip-1/comments'),
          {'body': 'ขอบคุณค่ะ', 'parentId': 'c1'});
      expect(find.text('ขอบคุณค่ะ'), findsOneWidget);
    });

    testWidgets('signed out, writing asks for an account and sends nothing',
        (tester) async {
      phone(tester);
      await _pumpPost(
        tester,
        extra: {
          'GET /trips/trip-1/comments': [FakeReply(200, page(thread))],
        },
      );
      await openSheet(tester);

      await tester.tap(find.text('ตอบกลับ').first);
      await tester.pump();

      expect(find.text('เข้าสู่ระบบก่อนเพื่อแสดงความคิดเห็น'), findsOneWidget);
      expect(find.text('ตอบกลับ @pongsak.t'), findsNothing);
      expect(adapter.paths, isNot(contains('POST /trips/trip-1/comments')));
    });

    testWidgets('a deletable comment can be removed from its menu',
        (tester) async {
      phone(tester);
      await _pumpPost(
        tester,
        viewer: _visitor,
        extra: {
          'GET /trips/trip-1/comments': [
            FakeReply(
              200,
              page([
                comment('c1', 'ของฉันเอง', canEdit: true, canDelete: true),
                ...thread.skip(1),
              ]),
            ),
          ],
          'DELETE /trips/trip-1/comments/c1': [const FakeReply(204, null)],
        },
      );
      await openSheet(tester);

      // Only the deletable one offers a menu.
      expect(find.byTooltip('ตัวเลือกความคิดเห็น'), findsOneWidget);
      await tester.tap(find.byTooltip('ตัวเลือกความคิดเห็น'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ลบความคิดเห็น'));
      await tester.pumpAndSettle();

      expect(adapter.paths, contains('DELETE /trips/trip-1/comments/c1'));
      expect(find.text('ของฉันเอง'), findsNothing);
      expect(find.text('On Lok Yun ไปกี่โมงดีคะ'), findsOneWidget);
    });
  });

  test('commentAge reads like the design', () {
    final now = DateTime(2026, 11, 5, 12);
    expect(commentAge(now.subtract(const Duration(seconds: 20)), now: now),
        'เมื่อสักครู่');
    expect(commentAge(now.subtract(const Duration(minutes: 7)), now: now),
        '7 นาที');
    expect(
        commentAge(now.subtract(const Duration(hours: 5)), now: now), '5 ชม.');
    expect(
        commentAge(now.subtract(const Duration(days: 3)), now: now), '3 วัน');
    expect(commentAge(DateTime(2026, 3, 7), now: now), '7 มี.ค. 2569');
  });

  testWidgets('back and ☰ are see-through glass, not solid discs',
      (tester) async {
    phone(tester);
    await _pumpPost(tester, viewer: _visitor);

    for (final tooltip in ['ย้อนกลับ', 'เมนู']) {
      final button = find.byTooltip(tooltip);
      // The cover is blurred through the button…
      expect(
        find.descendant(of: button, matching: find.byType(BackdropFilter)),
        findsOneWidget,
        reason: tooltip,
      );
      // …under a light wash, not the old 90% white.
      final face = tester.widget<Container>(
        find.descendant(of: button, matching: find.byType(Container)).first,
      );
      final fill = (face.decoration! as BoxDecoration).color!;
      expect(fill.a, lessThan(0.5), reason: tooltip);
    }
  });

  testWidgets('the bar has no bookmark and no avatar', (tester) async {
    phone(tester);
    await _pumpPost(tester, viewer: _visitor);

    // Saving lives in Trip Overview's row now.
    expect(find.byTooltip('บันทึกทริป'), findsNothing);
    expect(find.byTooltip('เลิกบันทึก'), findsNothing);
    // The author is a name alone — no avatar circle before it.
    expect(find.text('Thitichaya Butsala'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsNothing);
  });

  testWidgets('a visitor bookmarks the trip from Trip Overview',
      (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      viewer: _visitor,
      extra: {
        'POST /trips/trip-1/save': [const FakeReply(204, null)],
        'DELETE /trips/trip-1/save': [const FakeReply(204, null)],
      },
    );

    await tester.tap(find.byTooltip('บันทึก'));
    await tester.pumpAndSettle();
    expect(adapter.paths, contains('POST /trips/trip-1/save'));
    expect(find.byTooltip('เอาออกจากที่บันทึก'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);

    await tester.tap(find.byTooltip('เอาออกจากที่บันทึก'));
    await tester.pumpAndSettle();
    expect(adapter.paths, contains('DELETE /trips/trip-1/save'));
    expect(find.byTooltip('บันทึก'), findsOneWidget);
  });

  testWidgets('a refused save puts the bookmark back', (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      viewer: _visitor,
      extra: {
        'POST /trips/trip-1/save': [
          const FakeReply(404, {'message': 'Trip not found'}),
        ],
      },
    );

    await tester.tap(find.byTooltip('บันทึก'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('บันทึก'), findsOneWidget);
    expect(find.textContaining('บันทึกทริปไม่สำเร็จ'), findsOneWidget);
  });

  testWidgets('a trip saved earlier shows a filled bookmark', (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      viewer: _visitor,
      trip: {..._postJson(), 'isSaved': true},
    );
    expect(find.byTooltip('เอาออกจากที่บันทึก'), findsOneWidget);
  });

  testWidgets('แก้ไขทริป in the ☰ opens the post settings', (tester) async {
    phone(tester);
    await _pumpPost(tester, viewer: _owner);

    await tester.tap(find.byTooltip('เมนู'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('แก้ไขทริป'));
    await tester.pumpAndSettle();

    expect(find.text('share settings'), findsOneWidget);
  });

  testWidgets('no hero action at all until it is known who is looking',
      (tester) async {
    phone(tester);
    await _pumpPost(tester, viewerPending: true);

    // Guessing "visitor" would flash Remix on the owner's own post.
    expect(find.text('Remix Trip'), findsNothing);
    expect(find.text('แก้ไขโพสต์'), findsNothing);
    // The title still renders, so the page itself is not waiting.
    expect(find.text('ที่เที่ยวระยอง'), findsOneWidget);
  });

  testWidgets(
      "a post's Remix offers its linked plan's stops, with the post "
      'as the source', (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      viewer: _visitor,
      trip: {
        ..._postJson(),
        'linkedTrip': {
          'id': 'plan-7',
          'title': 'ระยอง 2 วัน',
          'schedule': <String, dynamic>{},
        },
      },
      extra: {
        'GET /trips/plan-7': [
          FakeReply(200, <String, dynamic>{
            'id': 'plan-7',
            'ownerId': 'u1',
            'title': 'ระยอง 2 วัน',
            'destination': 'ระยอง',
            'status': 'published',
            'schedule': <String, dynamic>{},
            'totalBudget': 0,
            'days': [
              {
                'id': 'pd1',
                'dayNumber': 1,
                'activities': [
                  {'id': 'ps1', 'title': 'หาดแม่รำพึง', 'order': 0},
                ],
              },
            ],
          }),
        ],
        'GET /trips/mine': [
          FakeReply(200, [
            {
              'id': 'mine-1',
              'title': 'ทริปของฉัน',
              'destination': 'ระยอง',
              'status': 'draft',
              'schedule': <String, dynamic>{},
              'totalBudget': 0,
              'isSaved': false,
              'isLiked': false,
              'likeCount': 0,
              'remixCount': 0,
            },
          ]),
        ],
        'POST /trips/trip-1/remix/items/into/mine-1': [
          FakeReply(200, <String, dynamic>{
            'id': 'mine-1',
            'title': 'ทริปของฉัน',
            'replayed': false,
            'addedItemIds': ['x1'],
            'skippedItemIds': <String>[],
            'stagedItems': <Map<String, dynamic>>[],
          }),
        ],
      },
    );

    await tester.tap(find.text('Remix Trip'));
    await tester.pumpAndSettle();
    expect(find.text('เลือกสถานที่จะ Remix'), findsOneWidget);
    expect(find.text('หาดแม่รำพึง'), findsOneWidget);

    await tester.tap(find.text('หาดแม่รำพึง'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'ถัดไป'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทริปของฉัน'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
    await tester.pumpAndSettle();

    // The post is the source; the ids are its linked plan's stops.
    expect(
      adapter.bodyOf('POST /trips/trip-1/remix/items/into/mine-1'),
      {
        'itemIds': ['ps1'],
      },
    );
    expect(find.text('Remix 1 สถานที่ลง ทริปของฉัน แล้ว'), findsOneWidget);
  });

  testWidgets('a post with no linked plan keeps the remix route',
      (tester) async {
    phone(tester);
    await _pumpPost(tester, viewer: _visitor);

    await tester.tap(find.text('Remix Trip'));
    await tester.pumpAndSettle();

    expect(find.text('remix page'), findsOneWidget);
  });

  testWidgets('the top bar stays put while the page slides under it',
      (tester) async {
    // A real phone's height, so the page actually overflows and scrolls.
    tester.view.physicalSize = const Size(393 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await _pumpPost(tester);

    final bar = find.byTooltip('ย้อนกลับ');
    final before = tester.getRect(bar);
    expect(before.top, lessThan(100));

    // The hero's own content scrolls away…
    expect(find.text('Remix Trip'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Remix Trip'), findsNothing);

    // …while the bar, the author and the menu stay exactly where they were.
    expect(tester.getRect(bar), before);
    expect(find.text('Thitichaya Butsala'), findsOneWidget);
    expect(find.byTooltip('เมนู'), findsOneWidget);
  });

  testWidgets('a spot keeps its details shut until asked', (tester) async {
    phone(tester);
    await _pumpPost(tester);

    // Collapsed: the hours are behind the toggle.
    expect(find.text('ดูรายละเอียด'), findsWidgets);
    expect(find.text('เปิด/ปิด 08.00 - 17.00 น.'), findsNothing);

    await tester.tap(find.text('ดูรายละเอียด').first);
    await tester.pumpAndSettle();

    expect(find.text('เปิด/ปิด 08.00 - 17.00 น.'), findsOneWidget);
    expect(find.text('ย่อรายละเอียด'), findsOneWidget);
  });

  // ---- Google's own hours, phone and website for a pinned place ----------

  const placeId = '7f1c2a9e-4b3d-4e8a-9c21-5d6e7f8a9b0c';

  Map<String, dynamic> pinnedSpot({String opens = '06:00'}) => {
        'title': 'ร้านอาหารที่ต้องแวะ',
        'content': 'มื้อเช้าคลาสสิก',
        'opensAt': opens,
        'closesAt': '14:30',
        'location': {
          'status': 'confirmed',
          'name': 'On Lok Yun',
          'placeId': placeId,
        },
      };

  Map<String, List<FakeReply>> google({String hours = '6:00–14:30'}) => {
        'GET /places/$placeId': [
          FakeReply(200, {
            'externalRef': 'g-1',
            'name': 'On Lok Yun',
            'nationalPhoneNumber': '085 809 0835',
            'internationalPhoneNumber': '+66 85 809 0835',
            'websiteUri': 'https://onlokyun.example',
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
                  '$day: $hours',
              ],
            },
          }),
        ],
      };

  testWidgets("a pinned spot shows Google's address as a map link",
      (tester) async {
    phone(tester);
    final reply = google();
    final body = Map<String, dynamic>.from(
      reply['GET /places/$placeId']!.single.body! as Map,
    )..['address'] = 'ถนนพระสุเมรุ แขวงบวรนิเวศ เขตพระนคร';
    await _pumpPost(
      tester,
      trip: _postJson(contents: [pinnedSpot()]),
      extra: {
        'GET /places/$placeId': [FakeReply(200, body)],
      },
    );

    final link = find.byKey(const Key('spot-map-link'));
    expect(link, findsOneWidget);
    // Shown without opening the details — it is the place's own line.
    expect(
      find.descendant(
        of: link,
        matching: find.text('ถนนพระสุเมรุ แขวงบวรนิเวศ เขตพระนคร'),
      ),
      findsOneWidget,
    );
    final uri = tester.widget<SpotMapLink>(find.byType(SpotMapLink)).uri;
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['query_place_id'], 'g-1');
  });

  testWidgets('a pin Google says nothing about still opens the map',
      (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      trip: _postJson(contents: [pinnedSpot()]),
    );

    expect(find.text('เปิดในแผนที่'), findsOneWidget);
    final uri = tester.widget<SpotMapLink>(find.byType(SpotMapLink)).uri;
    expect(uri.queryParameters['query'], 'On Lok Yun');
  });

  testWidgets("a pin holding Google's own id reads that place's address",
      (tester) async {
    phone(tester);
    const googleId = 'ChIJ0QDC8BOZ4jARY7WqIrAOkck';
    await _pumpPost(
      tester,
      trip: _postJson(contents: [
        {
          'title': 'ของหวาน',
          'content': 'ขนมปังปิ้ง',
          'location': {
            'status': 'confirmed',
            'name': 'มนต์นมสด',
            'placeId': googleId,
            'latitude': 13.754154,
            'longitude': 100.501137,
          },
        },
      ]),
      extra: {
        'GET /places/google/$googleId': [
          const FakeReply(200, {
            'externalRef': googleId,
            'name': 'มนต์นมสด',
            'address': '160/1-3 ถนนดินสอ เขตพระนคร',
          }),
        ],
      },
    );

    expect(find.text('160/1-3 ถนนดินสอ เขตพระนคร'), findsOneWidget);
    final uri = tester.widget<SpotMapLink>(find.byType(SpotMapLink)).uri;
    expect(uri.queryParameters['query'], '13.754154,100.501137');
    expect(uri.queryParameters['query_place_id'], googleId);
  });

  test('the map link prefers Google, then coordinates, then the name', () {
    expect(
      const SpotMapLink(
        name: 'On Lok Yun',
        latitude: 13.75,
        longitude: 100.5,
        googleMapsUri: 'https://maps.google.com/?cid=123',
      ).uri.toString(),
      'https://maps.google.com/?cid=123',
    );
    expect(
      const SpotMapLink(name: 'On Lok Yun', latitude: 13.75, longitude: 100.5)
          .uri
          .queryParameters['query'],
      '13.75,100.5',
    );
    expect(
      const SpotMapLink(name: 'On Lok Yun').uri.queryParameters['query'],
      'On Lok Yun',
    );
  });

  testWidgets("the writer's hours borrow Google's days when they agree",
      (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      trip: _postJson(contents: [pinnedSpot()]),
      extra: google(),
    );
    await _openDetails(tester);

    expect(find.text('จ - อา : 06.00 - 14.30 น.'), findsOneWidget);
  });

  testWidgets('hours Google disagrees with keep their own wording, no days',
      (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      trip: _postJson(contents: [pinnedSpot(opens: '07:00')]),
      extra: google(),
    );
    await _openDetails(tester);

    // Days are never invented around hours Google does not confirm.
    expect(find.text('เปิด/ปิด 07.00 - 14.30 น.'), findsOneWidget);
    expect(find.textContaining('จ - อา'), findsNothing);
  });

  testWidgets("the place's phone and website share one row of links",
      (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      trip: _postJson(contents: [pinnedSpot()]),
      extra: google(),
    );
    await _openDetails(tester);

    final number = find.text('085 809 0835');
    final web = find.text('เว็บร้าน');
    expect(number, findsOneWidget);
    expect(web, findsOneWidget);
    // One row, not two.
    expect(tester.getCenter(number).dy, closeTo(tester.getCenter(web).dy, 2));
    // The raw address never shows; the link carries it.
    expect(find.text('https://onlokyun.example'), findsNothing);
  });

  // ---- ดูรูป (N) --------------------------------------------------------------

  testWidgets('ดูรูป counts every openable photo and opens them together',
      (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      trip: _postJson(contents: [
        ..._photoSpot(), // three loadable, one lost
        <String, dynamic>{
          'title': 'อีกจุด',
          'content': 'เนื้อหา',
          'imageUrls': const ['https://img/a', 'https://img/b'],
        },
      ]),
    );

    expect(find.text('ดูรูป (5)'), findsOneWidget);

    await tester.tap(find.text('ดูรูป (5)'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 5'), findsOneWidget);
  });

  testWidgets('a post with no photos offers no ดูรูป', (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      trip: _postJson(contents: [
        <String, dynamic>{'title': 'ไม่มีรูป', 'content': 'เนื้อหา'},
      ]),
    );

    expect(find.textContaining('ดูรูป'), findsNothing);
  });

  testWidgets('a spot with nothing extra is offered no drawer', (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      trip: _postJson(contents: [
        <String, dynamic>{'title': 'จุดเปล่า', 'content': 'เนื้อหา'},
      ]),
    );

    // An empty drawer is worse than none.
    expect(find.text('ดูรายละเอียด'), findsNothing);
  });

  testWidgets('the counts read compactly and the facts sit under Trip Overview',
      (tester) async {
    phone(tester);
    await _pumpPost(
      tester,
      trip: <String, dynamic>{
        ..._postJson(),
        'remixCount': 1111,
        'likeCount': 1721,
      },
    );

    expect(find.text('1.1K'), findsOneWidget);
    expect(find.text('1.7K'), findsOneWidget);

    // The facts moved off the hero: they now sit below Trip Overview.
    final overview = tester.getRect(find.text('Trip Overview'));
    final place = tester.getRect(find.text('เทศบาลนครระยอง · ระยอง'));
    expect(place.top, greaterThan(overview.top));
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

    await _openDetails(tester);
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

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'after scrolling');
  });

  testWidgets('photos run to the screen edge while the text keeps the gutter',
      (tester) async {
    phone(tester);
    await _pumpPost(tester, trip: _postJson(contents: _photoSpot()));

    // The photo breaks out of the column…
    final photo = tester.getRect(find.byType(PageView).first);
    expect(photo.left, 0);
    expect(photo.width, 393);

    // …while everything written lines up with Trip Overview above it.
    final overview = tester.getTopLeft(find.text('Trip Overview')).dx;
    expect(tester.getTopLeft(find.text('พิพิธภัณฑ์เมืองระยอง')).dx, overview);
    expect(overview, greaterThan(0));
  });

  testWidgets('a spot with several photos swipes through them in place',
      (tester) async {
    phone(tester);
    await _pumpPost(tester, trip: _postJson(contents: _photoSpot()));

    // One counter for the card, not one per photo: the photos are a carousel.
    expect(find.text('1/4'), findsOneWidget);
    expect(find.text('2/4'), findsNothing);

    await tester.drag(find.byType(PageView).first, const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('2/4'), findsOneWidget);
  });

  testWidgets('a photo that failed still holds its place in the carousel',
      (tester) async {
    phone(tester);
    await _pumpPost(tester, trip: _postJson(contents: _photoSpot()));

    // Four pages, three of them openable.
    expect(find.text('1/4'), findsOneWidget);
    expect(find.bySemanticsLabel('ดูรูปเต็ม'), findsWidgets);

    await tester.drag(find.byType(PageView).first, const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView).first, const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('3/4'), findsOneWidget);
    expect(find.text('รูปนี้ไม่พร้อมใช้งาน'), findsOneWidget);
  });

  testWidgets('tapping a photo opens the spot full size and closes',
      (tester) async {
    phone(tester);
    await _pumpPost(tester, trip: _postJson(contents: _photoSpot()));

    await tester.tap(find.bySemanticsLabel('ดูรูปเต็ม').first);
    await tester.pumpAndSettle();

    // The gallery holds only the photos a reader can actually see.
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.drag(find.byType(PageView).last, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();

    expect(find.text('ที่เที่ยวระยอง'), findsOneWidget);
  });

  testWidgets('the full-size photo fills the screen rather than its own size',
      (tester) async {
    phone(tester);
    await _pumpPost(tester, trip: _postJson(contents: _photoSpot()));

    await tester.tap(find.bySemanticsLabel('ดูรูปเต็ม').first);
    await tester.pumpAndSettle();

    // The photo's box is the viewport, which is what lets BoxFit.contain
    // letterbox it into the middle. Sized to the image instead, it lays out at
    // its own pixel size and sits pinned to the top of a black screen.
    final box = tester.getSize(
      find
          .descendant(
            of: find.byType(InteractiveViewer),
            matching: find.byType(CoverImage),
          )
          .first,
    );
    expect(box.width, 393);
    expect(box.height, 1400);
  });

  testWidgets('a lone photo gets no counter and no dots', (tester) async {
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

    // A count means nothing when there is one.
    expect(find.textContaining('/'), findsNothing);

    await tester.tap(find.bySemanticsLabel('ดูรูปเต็ม'));
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
