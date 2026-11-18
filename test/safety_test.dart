import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/follow/presentation/user_profile_screen.dart';
import 'package:pluno/features/home/presentation/providers/home_feed_providers.dart';
import 'package:pluno/features/home/presentation/widgets/pun_guide_card.dart';
import 'package:pluno/features/home/presentation/widgets/pun_guide_grid.dart';
import 'package:pluno/features/safety/data/reported_content_store.dart';
import 'package:pluno/features/safety/presentation/blocked_users_screen.dart';
import 'package:pluno/features/safety/presentation/providers/safety_providers.dart';
import 'package:pluno/features/safety/presentation/safety_actions.dart';

import 'support/fake_api.dart';
import 'support/home_feed_fixtures.dart';

const _me = AuthSession(
  displayName: 'Nuy',
  handle: '@nuy',
  email: '',
  userId: 'me-1',
);

late FakeAdapter adapter;
late InMemoryReportedContentStore store;

/// A wall over Home's visible feed, with the real ⋯ wired in — what Home,
/// search and a profile all draw.
class _Wall extends ConsumerWidget {
  const _Wall();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(visibleHomeFeedProvider).valueOrNull ?? const [];
    return Scaffold(
      body: ListView(
        children: [
          PunGuideGrid(
            trips: rows,
            onOpen: (_) {},
            moreOf: tripMoreOf(context, ref),
          ),
        ],
      ),
    );
  }
}

Widget _harness({
  required Widget home,
  Map<String, List<FakeReply>> replies = const {},
  List<TripListItem> feed = const <TripListItem>[],
  AuthSession? session = _me,
}) {
  adapter = FakeAdapter({...replies});
  store = InMemoryReportedContentStore();
  return ProviderScope(
    overrides: [
      ...homeOverrides(feed, session: session),
      plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
      reportedContentStoreProvider.overrideWithValue(store),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => home),
          GoRoute(
            path: '/login',
            name: AppRoute.login.name,
            builder: (_, __) => const Scaffold(body: Text('login page')),
          ),
          GoRoute(
            path: '/users/:userId/follows',
            name: AppRoute.userFollows.name,
            builder: (_, __) => const Scaffold(body: Text('list')),
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
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393 * 3, 1000 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Map<String, dynamic> _receipt({bool again = false}) => <String, dynamic>{
      'id': 'r1',
      'targetType': 'trip',
      'targetId': 'trip-1',
      'reason': 'spam',
      'status': 'open',
      'alreadyReported': again,
      'createdAt': '2026-11-12T08:00:00.000Z',
    };

Map<String, dynamic> _profile({bool isBlocked = false}) => <String, dynamic>{
      'id': 'u9',
      'username': 'maki',
      'name': 'Maki',
      'followerCount': 3,
      'followingCount': 4,
      'isFollowing': false,
      'followsYou': false,
      'isMe': false,
      'isBlocked': isBlocked,
    };

final _two = [
  feedTrip(id: 'trip-1', title: 'ทริปของมากิ', creatorName: 'makitravels'),
  feedTrip(id: 'trip-2', title: 'ทริปของคนอื่น', creatorName: 'other'),
];

/// Opens a feed card's safety menu the only way there is: a long press.
/// The cover wore a ⋯ until the card was given back its photo.
Future<void> _openFirstCardMenu(WidgetTester tester) async {
  await tester.longPress(find.byType(PunGuideCard).first);
  await tester.pumpAndSettle();
}

Future<void> _reportFirstCard(WidgetTester tester) async {
  await _openFirstCardMenu(tester);
  await tester.tap(find.text('รายงานโพสต์'));
  await tester.pumpAndSettle();
}

void main() {
  group('SafetyApi', () {
    test('a report sends type, id, reason and a trimmed note', () async {
      final fake = FakeAdapter({
        'POST /reports': [FakeReply(201, _receipt())],
      });
      final receipt = await fakeApi(fake).safety.report(
            targetType: ReportTargetType.comment,
            targetId: 'c1',
            reason: ReportReason.hateSpeech,
            note: '  ด่าคนอื่น  ',
          );
      expect(receipt.alreadyReported, isFalse);
      expect(fake.bodyOf('POST /reports'), {
        'targetType': 'comment',
        'targetId': 'c1',
        'reason': 'hate_speech',
        'note': 'ด่าคนอื่น',
      });
    });

    test('an empty note is left off', () async {
      final fake = FakeAdapter({
        'POST /reports': [FakeReply(201, _receipt(again: true))],
      });
      final receipt = await fakeApi(fake).safety.report(
            targetType: ReportTargetType.trip,
            targetId: 'trip-1',
            reason: ReportReason.spam,
            note: '   ',
          );
      expect(receipt.alreadyReported, isTrue);
      expect(fake.bodyOf('POST /reports')!.containsKey('note'), isFalse);
    });

    test('the blocked list pages by total', () async {
      final fake = FakeAdapter({
        'GET /users/me/blocks': [
          const FakeReply(200, {
            'items': [
              {
                'id': 'u9',
                'username': 'maki',
                'name': 'Maki',
                'blockedAt': '2026-11-12T08:00:00.000Z',
              },
            ],
            'total': 3,
            'limit': 1,
            'offset': 0,
          }),
        ],
      });
      final page = await fakeApi(fake).safety.blocked(limit: 1);
      expect(page.items.single.displayName, 'Maki');
      expect(page.hasMore, isTrue);
      expect(fake.queriesOf('GET /users/me/blocks').single,
          {'limit': 1, 'offset': 0});
    });

    test('impersonation is offered only for a user', () {
      expect(ReportReason.offeredFor(ReportTargetType.trip),
          isNot(contains(ReportReason.impersonation)));
      expect(ReportReason.offeredFor(ReportTargetType.user),
          contains(ReportReason.impersonation));
      expect(ReportReason.offeredFor(ReportTargetType.user).last,
          ReportReason.other);
    });
  });

  group('ContentFilter', () {
    test('hides reported trips and everything a blocked account wrote', () {
      final filter = ContentFilter(
        reported: {ContentFilter.keyOf(ReportTargetType.trip, 'trip-1')},
        blocks: const {'u-trip-2': true, 'u-trip-3': false},
      );
      final rows = [
        feedTrip(id: 'trip-1'),
        feedTrip(id: 'trip-2'),
        feedTrip(id: 'trip-3'),
      ];
      expect(filter.visibleTrips(rows).map((r) => r.id), ['trip-3']);
      // An unblock is remembered, but hides nothing.
      expect(filter.blockOf('u-trip-3'), isFalse);
      expect(filter.isBlocked('u-trip-3'), isFalse);
    });

    test('an empty filter hands the same list back', () {
      final rows = [feedTrip()];
      expect(identical(const ContentFilter().visibleTrips(rows), rows), isTrue);
    });
  });

  group('report from a feed card', () {
    testWidgets('the card leaves the wall and the id is remembered',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_harness(
        home: const _Wall(),
        feed: _two,
        replies: {
          'POST /reports': [FakeReply(201, _receipt())],
        },
      ));
      await tester.pumpAndSettle();
      expect(find.text('ทริปของมากิ'), findsOneWidget);

      await _reportFirstCard(tester);
      expect(find.text('ทำไมคุณถึงรายงานโพสต์นี้?'), findsOneWidget);
      expect(find.text('รายงานของคุณจะไม่ถูกเปิดเผยให้เจ้าของเนื้อหาทราบ'),
          findsOneWidget);
      // Not for a post.
      expect(find.text('แอบอ้างเป็นบุคคลอื่น'), findsNothing);

      // Nothing to send until a reason is picked.
      final send = find.byKey(const Key('report-send'));
      expect(tester.widget<FilledButton>(send).onPressed, isNull);

      await tester.tap(find.text('สแปม / โฆษณาขายของ'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('report-note')), 'ขายของ');
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(adapter.bodyOf('POST /reports'), {
        'targetType': 'trip',
        'targetId': 'trip-1',
        'reason': 'spam',
        'note': 'ขายของ',
      });
      expect(find.text('ขอบคุณที่แจ้งให้เราทราบ'), findsOneWidget);
      expect(find.text('บล็อก makitravels'), findsOneWidget);

      await tester.tap(find.byKey(const Key('report-thanks-done')));
      await tester.pumpAndSettle();

      expect(find.text('ทริปของมากิ'), findsNothing);
      expect(find.text('ทริปของคนอื่น'), findsOneWidget);
      expect(await store.read('me-1'), {'trip:trip-1'});
    });

    testWidgets('a repeat report thanks the same way', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_harness(
        home: const _Wall(),
        feed: _two,
        replies: {
          'POST /reports': [FakeReply(201, _receipt(again: true))],
        },
      ));
      await tester.pumpAndSettle();

      await _reportFirstCard(tester);
      await tester.tap(find.text('อื่นๆ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-send')));
      await tester.pumpAndSettle();

      expect(find.text('ขอบคุณที่แจ้งให้เราทราบ'), findsOneWidget);
    });

    testWidgets('429 closes the sheet and leaves the card', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_harness(
        home: const _Wall(),
        feed: _two,
        replies: {
          'POST /reports': [
            const FakeReply(429, {'message': 'Too Many Requests'}),
          ],
        },
      ));
      await tester.pumpAndSettle();

      await _reportFirstCard(tester);
      await tester.tap(find.text('สแปม / โฆษณาขายของ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-send')));
      await tester.pumpAndSettle();

      expect(
          find.text('คุณรายงานบ่อยเกินไป กรุณาลองใหม่ภายหลัง'), findsOneWidget);
      expect(find.text('ทำไมคุณถึงรายงานโพสต์นี้?'), findsNothing);
      expect(find.text('ทริปของมากิ'), findsOneWidget);
    });

    testWidgets('a server error keeps the sheet up to try again',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_harness(
        home: const _Wall(),
        feed: _two,
        replies: {
          'POST /reports': [
            const FakeReply(500, {'message': 'boom'}),
          ],
        },
      ));
      await tester.pumpAndSettle();

      await _reportFirstCard(tester);
      await tester.tap(find.text('สแปม / โฆษณาขายของ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-send')));
      await tester.pumpAndSettle();

      expect(find.text('ส่งรายงานไม่สำเร็จ ลองอีกครั้ง'), findsOneWidget);
      expect(find.text('ทำไมคุณถึงรายงานโพสต์นี้?'), findsOneWidget);
    });

    testWidgets('404 drops the card and says it is gone', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_harness(
        home: const _Wall(),
        feed: _two,
        replies: {
          'POST /reports': [
            const FakeReply(404, {'message': 'Not Found'}),
          ],
        },
      ));
      await tester.pumpAndSettle();

      await _reportFirstCard(tester);
      await tester.tap(find.text('สแปม / โฆษณาขายของ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-send')));
      await tester.pumpAndSettle();

      expect(find.text('ไม่พบเนื้อหานี้แล้ว'), findsOneWidget);
      expect(find.text('ทริปของมากิ'), findsNothing);
    });

    testWidgets('a guest is sent to sign in', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_harness(
        home: const _Wall(),
        feed: _two,
        session: null,
      ));
      await tester.pumpAndSettle();

      await _reportFirstCard(tester);

      expect(find.text('login page'), findsOneWidget);
      expect(adapter.paths, isNot(contains('POST /reports')));
    });

    testWidgets('the viewer\'s own card has no safety menu', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_harness(
        home: const _Wall(),
        feed: [feedTrip(id: 'mine')],
        // feedTrip's creator id is `u-<trip id>`.
        session: const AuthSession(
          displayName: 'Me',
          handle: '@me',
          email: '',
          userId: 'u-mine',
        ),
      ));
      await tester.pumpAndSettle();

      // Nothing on the cover said so even before; now the long press is the
      // whole menu, so pressing is what has to come up empty.
      await _openFirstCardMenu(tester);
      expect(find.text('รายงานโพสต์'), findsNothing);
      expect(find.textContaining('บล็อก'), findsNothing);
    });
  });

  group('block from a feed card', () {
    testWidgets('their cards go at once, and เลิกทำ brings them back',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_harness(
        home: const _Wall(),
        feed: _two,
        replies: {
          'POST /users/u-trip-1/block': [
            const FakeReply(200, {'userId': 'u-trip-1', 'isBlocked': true}),
          ],
          'DELETE /users/u-trip-1/block': [
            const FakeReply(200, {'userId': 'u-trip-1', 'isBlocked': false}),
          ],
        },
      ));
      await tester.pumpAndSettle();

      await _openFirstCardMenu(tester);
      await tester.tap(find.text('บล็อก makitravels'));
      await tester.pumpAndSettle();

      expect(find.text('บล็อก makitravels?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('block-confirm')));
      await tester.pumpAndSettle();

      expect(adapter.paths, contains('POST /users/u-trip-1/block'));
      expect(find.text('ทริปของมากิ'), findsNothing);
      expect(find.text('ทริปของคนอื่น'), findsOneWidget);
      expect(find.text('บล็อก makitravels แล้ว'), findsOneWidget);

      await tester.tap(find.text('เลิกทำ'));
      await tester.pumpAndSettle();

      expect(adapter.paths, contains('DELETE /users/u-trip-1/block'));
      expect(find.text('ทริปของมากิ'), findsOneWidget);
    });

    testWidgets('cancelling the dialog sends nothing', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_harness(home: const _Wall(), feed: _two));
      await tester.pumpAndSettle();

      await _openFirstCardMenu(tester);
      await tester.tap(find.text('บล็อก makitravels'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();

      expect(adapter.paths, isEmpty);
      expect(find.text('ทริปของมากิ'), findsOneWidget);
    });

    testWidgets('report, then บล็อก from the thank-you page', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_harness(
        home: const _Wall(),
        feed: _two,
        replies: {
          'POST /reports': [FakeReply(201, _receipt())],
          'POST /users/u-trip-1/block': [
            const FakeReply(200, {'userId': 'u-trip-1', 'isBlocked': true}),
          ],
        },
      ));
      await tester.pumpAndSettle();

      await _reportFirstCard(tester);
      await tester.tap(find.text('สแปม / โฆษณาขายของ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-send')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-thanks-block')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('block-confirm')));
      await tester.pumpAndSettle();

      expect(adapter.paths,
          containsAllInOrder(['POST /reports', 'POST /users/u-trip-1/block']));
      expect(find.text('ทริปของมากิ'), findsNothing);
    });
  });

  group('someone else\'s profile', () {
    testWidgets('⋯ → บล็อก swaps follow and the wall for the banner',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_harness(
        home: const UserProfileScreen(userId: 'u9'),
        replies: {
          'GET /users/u9': [FakeReply(200, _profile())],
          'POST /users/u9/block': [
            const FakeReply(200, {'userId': 'u9', 'isBlocked': true}),
          ],
        },
      ));
      await tester.pumpAndSettle();
      expect(find.text('ติดตาม'), findsOneWidget);

      await tester.tap(find.byTooltip('ตัวเลือกเพิ่มเติม'));
      await tester.pumpAndSettle();
      expect(find.text('รายงานผู้ใช้'), findsOneWidget);
      await tester.tap(find.text('บล็อก @maki'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('block-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('คุณบล็อกผู้ใช้นี้อยู่'), findsOneWidget);
      expect(find.text('ติดตาม'), findsNothing);
    });

    testWidgets('isBlocked: true shows the banner; เลิกบล็อก lifts it',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_harness(
        home: const UserProfileScreen(userId: 'u9'),
        replies: {
          'GET /users/u9': [FakeReply(200, _profile(isBlocked: true))],
          'DELETE /users/u9/block': [
            const FakeReply(200, {'userId': 'u9', 'isBlocked': false}),
          ],
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('คุณบล็อกผู้ใช้นี้อยู่'), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile-unblock')));
      await tester.pumpAndSettle();
      expect(find.text('เลิกบล็อก @maki?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('unblock-confirm')));
      await tester.pumpAndSettle();

      expect(adapter.paths, contains('DELETE /users/u9/block'));
      expect(find.text('คุณบล็อกผู้ใช้นี้อยู่'), findsNothing);
      expect(find.text('ติดตาม'), findsOneWidget);
    });

    testWidgets('a 404 profile never says you were blocked', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_harness(
        home: const UserProfileScreen(userId: 'u9'),
        replies: {
          'GET /users/u9': [
            const FakeReply(404, {'message': 'Not Found'}),
          ],
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('ไม่พบผู้ใช้นี้'), findsOneWidget);
      expect(find.textContaining('บล็อก'), findsNothing);
    });

    testWidgets('follow answering 403 offers to unblock, then follows',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_harness(
        home: const UserProfileScreen(userId: 'u9'),
        replies: {
          'GET /users/u9': [FakeReply(200, _profile())],
          'POST /users/u9/follow': [
            const FakeReply(403, {'message': 'Forbidden'}),
            const FakeReply(200, {
              'followerCount': 4,
              'followingCount': 4,
              'isFollowing': true,
            }),
          ],
          'DELETE /users/u9/block': [
            const FakeReply(200, {'userId': 'u9', 'isBlocked': false}),
          ],
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ติดตาม'));
      await tester.pumpAndSettle();
      expect(find.text('เลิกบล็อก @maki เพื่อติดตาม?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('unblock-confirm')));
      await tester.pumpAndSettle();

      expect(
        adapter.paths.where((p) => !p.startsWith('GET ')),
        [
          'POST /users/u9/follow',
          'DELETE /users/u9/block',
          'POST /users/u9/follow',
        ],
      );
      expect(find.text('กำลังติดตาม'), findsOneWidget);
    });
  });

  group('blocked users page', () {
    testWidgets('lists them and unblocks a row', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_harness(
        home: const BlockedUsersScreen(),
        replies: {
          'GET /users/me/blocks': [
            const FakeReply(200, {
              'items': [
                {'id': 'u9', 'username': 'maki', 'name': 'Maki'},
                {'id': 'u8', 'username': 'mint', 'name': null},
              ],
              'total': 2,
              'limit': 20,
              'offset': 0,
            }),
          ],
          'DELETE /users/u9/block': [
            const FakeReply(200, {'userId': 'u9', 'isBlocked': false}),
          ],
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('Maki'), findsOneWidget);
      expect(find.text('@maki'), findsOneWidget);
      expect(find.text('mint'), findsOneWidget);

      await tester.tap(find.text('เลิกบล็อก').first);
      await tester.pumpAndSettle();
      expect(find.text('@maki จะเห็นโพสต์ของคุณได้อีกครั้ง'), findsOneWidget);
      await tester.tap(find.byKey(const Key('unblock-confirm')));
      await tester.pumpAndSettle();

      expect(adapter.paths, contains('DELETE /users/u9/block'));
      expect(find.text('Maki'), findsNothing);
      expect(find.text('mint'), findsOneWidget);
    });

    testWidgets('an empty list says so', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_harness(
        home: const BlockedUsersScreen(),
        replies: {
          'GET /users/me/blocks': [
            const FakeReply(200, {
              'items': <Object>[],
              'total': 0,
              'limit': 20,
              'offset': 0,
            }),
          ],
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('คุณยังไม่ได้บล็อกใคร'), findsOneWidget);
    });
  });

  test('syncBlocks reads every page into the ledger', () async {
    final fake = FakeAdapter({
      'GET /users/me/blocks': [
        const FakeReply(200, {
          'items': [
            {'id': 'u9', 'username': 'maki'},
          ],
          'total': 1,
          'limit': 100,
          'offset': 0,
        }),
      ],
    });
    final container = ProviderContainer(overrides: [
      plunoApiProvider.overrideWith((ref) async => fakeApi(fake)),
      authSessionProvider.overrideWith((ref) => AuthController(_me)),
      reportedContentStoreProvider
          .overrideWithValue(InMemoryReportedContentStore()),
    ]);
    addTearDown(container.dispose);

    container.read(contentFilterProvider);
    await container.read(contentFilterProvider.notifier).syncBlocks();

    expect(container.read(contentFilterProvider).isBlocked('u9'), isTrue);
  });
}
