import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/follow/presentation/follow_list_screen.dart';
import 'package:pluno/features/follow/presentation/user_profile_screen.dart';
import 'package:pluno/features/follow/presentation/providers/follow_providers.dart';
import 'package:pluno/features/follow/presentation/widgets/follow_button.dart';
import 'package:pluno/features/puntok/domain/models/puntok_post.dart';
import 'package:pluno/features/puntok/presentation/providers/puntok_providers.dart';

import 'support/fake_api.dart';
import 'support/home_feed_fixtures.dart';

const _me = AuthSession(
  displayName: 'Nuy',
  handle: '@nuy',
  email: '',
  userId: 'me-1',
);

Map<String, dynamic> _profile({
  String id = 'u9',
  bool isFollowing = false,
  bool followsYou = false,
  bool isMe = false,
  int followers = 128,
}) =>
    <String, dynamic>{
      'id': id,
      'username': 'maki',
      'name': 'Maki',
      'avatarUrl': null,
      'followerCount': followers,
      'followingCount': 42,
      'isFollowing': isFollowing,
      'followsYou': followsYou,
      'isMe': isMe,
    };

Map<String, dynamic> _summary({required int followers, required bool on}) =>
    <String, dynamic>{
      'followerCount': followers,
      'followingCount': 42,
      'isFollowing': on,
    };

late FakeAdapter adapter;

Widget _harness(
  Map<String, List<FakeReply>> replies, {
  required Widget home,
  AuthSession? session = _me,
  List<TripListItem> feed = const <TripListItem>[],
}) {
  adapter = FakeAdapter(replies);
  return ProviderScope(
    overrides: [
      ...homeOverrides(feed, session: session),
      plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
      authSessionProvider.overrideWith((ref) => AuthController(session)),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => home),
          GoRoute(
            path: '/users/:userId',
            name: AppRoute.userProfile.name,
            builder: (_, state) =>
                Scaffold(body: Text('profile ${state.params['userId']}')),
          ),
          GoRoute(
            path: '/users/:userId/follows',
            name: AppRoute.userFollows.name,
            builder: (_, state) => Scaffold(
              body: Text(
                'list ${state.params['userId']} ${state.queryParams['tab']}',
              ),
            ),
          ),
          GoRoute(
            path: '/trips/:tripId',
            name: AppRoute.tripDetail.name,
            builder: (_, __) => const Scaffold(body: Text('trip page')),
          ),
          GoRoute(
            path: '/profile/edit',
            name: AppRoute.profileEdit.name,
            builder: (_, __) => const Scaffold(body: Text('edit page')),
          ),
          GoRoute(
            path: '/login',
            name: AppRoute.login.name,
            builder: (_, __) => const Scaffold(body: Text('login page')),
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

void main() {
  group('FollowApi', () {
    test('reads a profile without an email and with both relationships',
        () async {
      final fake = FakeAdapter({
        'GET /users/u9': [
          FakeReply(200, {..._profile(followsYou: true), 'email': 'x@y.z'}),
        ],
      });
      final profile = await fakeApi(fake).follows.profile('u9');
      expect(profile.displayName, 'Maki');
      expect(profile.followerCount, 128);
      expect(profile.followsYou, isTrue);
      expect(profile.isFollowing, isFalse);
      expect(profile.isMe, isFalse);
    });

    test('follow / unfollow answer with the followee summary', () async {
      final fake = FakeAdapter({
        'POST /users/u9/follow': [
          FakeReply(200, _summary(followers: 129, on: true))
        ],
        'DELETE /users/u9/follow': [
          FakeReply(200, _summary(followers: 128, on: false)),
        ],
      });
      final api = fakeApi(fake);
      expect((await api.follows.follow('u9')).followerCount, 129);
      expect((await api.follows.unfollow('u9')).isFollowing, isFalse);
    });

    test('lists page by limit and offset, and each row is about the caller',
        () async {
      final fake = FakeAdapter({
        'GET /users/u9/following': [
          const FakeReply(200, [
            {
              'id': 'a',
              'username': 'nori',
              'name': 'Nori',
              'isFollowing': false
            },
            {'id': 'b', 'username': 'maki', 'isFollowing': true},
          ]),
        ],
      });
      final rows = await fakeApi(fake)
          .follows
          .list('u9', FollowListKind.following, limit: 20, offset: 40);
      expect(fake.queriesOf('GET /users/u9/following').single,
          {'limit': 20, 'offset': 40});
      expect(rows.map((r) => r.displayName), ['Nori', 'maki']);
      expect(rows.last.isFollowing, isTrue);
    });

    test('removing a follower goes to /users/me/followers/:id', () async {
      final fake = FakeAdapter({
        'DELETE /users/me/followers/a': [
          FakeReply(200, _summary(followers: 127, on: false)),
        ],
      });
      final mine = await fakeApi(fake).follows.removeFollower('a');
      expect(mine.followerCount, 127);
    });
  });

  group('someone else\'s profile', () {
    testWidgets('a follower who is not followed back gets ติดตามกลับ',
        (tester) async {
      await tester.pumpWidget(_harness(
        {
          'GET /users/u9': [FakeReply(200, _profile(followsYou: true))],
          'POST /users/u9/follow': [
            FakeReply(200, _summary(followers: 129, on: true)),
          ],
        },
        home: const UserProfileScreen(userId: 'u9'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Maki'), findsWidgets);
      expect(find.text('@maki'), findsOneWidget);
      expect(find.text('ติดตามคุณ'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);

      await tester.tap(find.text('ติดตามกลับ'));
      await tester.pumpAndSettle();

      expect(adapter.paths, contains('POST /users/u9/follow'));
      expect(find.text('กำลังติดตาม'), findsOneWidget);
      // The follow answered with fresh counts.
      expect(find.text('129'), findsOneWidget);
    });

    testWidgets('a refused follow flips back and says so', (tester) async {
      await tester.pumpWidget(_harness(
        {
          'GET /users/u9': [FakeReply(200, _profile())],
          'POST /users/u9/follow': [
            const FakeReply(500, {'message': 'boom'})
          ],
        },
        home: const UserProfileScreen(userId: 'u9'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ติดตาม'));
      await tester.pumpAndSettle();

      expect(find.text('ติดตาม'), findsOneWidget);
      expect(find.text('กำลังติดตาม'), findsNothing);
      expect(find.text('ติดตามไม่สำเร็จ'), findsOneWidget);
    });

    testWidgets('a guest is asked to sign in instead of sending a 401',
        (tester) async {
      await tester.pumpWidget(_harness(
        {
          'GET /users/u9': [FakeReply(200, _profile())],
        },
        home: const UserProfileScreen(userId: 'u9'),
        session: null,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ติดตาม'));
      await tester.pumpAndSettle();

      expect(find.text('เข้าสู่ระบบเพื่อติดตาม'), findsOneWidget);
      expect(adapter.paths, isNot(contains('POST /users/u9/follow')));
    });

    testWidgets('your own profile offers แก้ไขโปรไฟล์ and no follow button',
        (tester) async {
      await tester.pumpWidget(_harness(
        {
          'GET /users/me-1': [FakeReply(200, _profile(id: 'me-1', isMe: true))],
        },
        home: const UserProfileScreen(userId: 'me-1'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('แก้ไขโปรไฟล์'), findsOneWidget);
      expect(find.text('ติดตาม'), findsNothing);
    });

    testWidgets('the counts open the lists; the wall is their public trips',
        (tester) async {
      await tester.pumpWidget(_harness(
        {
          'GET /users/u9': [FakeReply(200, _profile())],
        },
        home: const UserProfileScreen(userId: 'u9'),
        feed: [
          TripListItem.fromJson({
            ...feedTripJson(id: 'mine', title: 'ทริปของมากิ'),
            'creator': {'id': 'u9', 'name': 'Maki'},
          }),
          feedTrip(id: 'other', title: 'ทริปคนอื่น', creatorName: 'Nori'),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('ทริปของมากิ'), findsOneWidget);
      expect(find.text('ทริปคนอื่น'), findsNothing);

      await tester.tap(find.text('Following'));
      await tester.pumpAndSettle();
      expect(find.text('list u9 following'), findsOneWidget);
    });

    testWidgets('an unknown user says so', (tester) async {
      await tester.pumpWidget(_harness(
        {
          'GET /users/u9': [
            const FakeReply(404, {'message': 'not found'})
          ],
        },
        home: const UserProfileScreen(userId: 'u9'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ไม่พบผู้ใช้นี้'), findsOneWidget);
    });
  });

  group('follow lists', () {
    final followers = <Map<String, dynamic>>[
      {'id': 'a', 'username': 'nori', 'name': 'Nori', 'isFollowing': false},
      {'id': 'b', 'username': 'maki', 'name': 'Maki', 'isFollowing': true},
      // The caller's own row, which the server always marks false.
      {'id': 'me-1', 'username': 'nuy', 'name': 'Nuy', 'isFollowing': false},
    ];

    testWidgets('your followers offer ติดตามกลับ and ลบ; your own row nothing',
        (tester) async {
      await tester.pumpWidget(_harness(
        {
          'GET /users/me-1': [FakeReply(200, _profile(id: 'me-1', isMe: true))],
          'GET /users/me-1/followers': [FakeReply(200, followers)],
          'GET /users/me-1/following': [const FakeReply(200, [])],
          'DELETE /users/me/followers/a': [
            FakeReply(200, _summary(followers: 1, on: false)),
          ],
        },
        home: const FollowListScreen(userId: 'me-1'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ติดตามกลับ'), findsOneWidget);
      // The tab is also called กำลังติดตาม, so look inside the buttons.
      expect(find.widgetWithText(FollowButton, 'กำลังติดตาม'), findsOneWidget);
      // Nori and Maki, not the caller.
      expect(find.text('ลบ'), findsNWidgets(2));

      await tester.tap(find.text('ลบ').first);
      await tester.pumpAndSettle();
      expect(find.text('ลบผู้ติดตาม?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'ลบ').last);
      await tester.pumpAndSettle();

      expect(adapter.paths, contains('DELETE /users/me/followers/a'));
      expect(find.text('Nori'), findsNothing);
      expect(find.text('Maki'), findsOneWidget);
    });

    testWidgets('someone else\'s list has follow buttons but no ลบ',
        (tester) async {
      await tester.pumpWidget(_harness(
        {
          'GET /users/u9': [FakeReply(200, _profile())],
          'GET /users/u9/followers': [FakeReply(200, followers)],
          'GET /users/u9/following': [const FakeReply(200, [])],
        },
        home: const FollowListScreen(userId: 'u9'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ลบ'), findsNothing);
      expect(find.text('ติดตาม'), findsOneWidget);
      expect(find.widgetWithText(FollowButton, 'กำลังติดตาม'), findsOneWidget);
    });

    testWidgets('a row opens that person\'s profile', (tester) async {
      await tester.pumpWidget(_harness(
        {
          'GET /users/u9': [FakeReply(200, _profile())],
          'GET /users/u9/followers': [FakeReply(200, followers)],
          'GET /users/u9/following': [const FakeReply(200, [])],
        },
        home: const FollowListScreen(userId: 'u9'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nori'));
      await tester.pumpAndSettle();
      expect(find.text('profile a'), findsOneWidget);
    });
  });

  test('Puntok: your own clip has no follow control; others follow the ledger',
      () {
    const mine = PuntokPost(
        id: 'c1',
        video: 'v',
        author: 'Nuy',
        caption: '',
        likes: 0,
        authorId: 'me-1');
    const theirs = PuntokPost(
        id: 'c2',
        video: 'v',
        author: 'Maki',
        caption: '',
        likes: 0,
        authorId: 'u9');
    final out = withFollowState(
      const [mine, theirs],
      const FollowLedger(following: {'u9': true}),
      myId: 'me-1',
    );
    expect(out[0].followable, isFalse);
    expect(out[1].followable, isTrue);
    expect(out[1].following, isTrue);
  });
}
