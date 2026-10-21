import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/puntok/domain/models/puntok_post.dart';
import 'package:pluno/features/puntok/presentation/puntok_screen.dart';
import 'package:pluno/features/puntok/presentation/providers/puntok_providers.dart';
import 'package:pluno/features/puntok/presentation/widgets/puntok_action_rail.dart';

import 'support/fake_api.dart';

/// A `content` row from `GET /trips`. A video cover keeps its file in
/// `urls.original`; [poster] null mimics the server that had no still to cut
/// and filled `large` with the video itself.
Map<String, dynamic> _row(
  String id, {
  required String author,
  required String caption,
  int likes = 0,
  bool video = true,
  bool liked = false,
  Map<String, dynamic>? linkedTrip,
}) =>
    <String, dynamic>{
      'id': id,
      'type': 'content',
      'title': 'title of $id',
      'description': caption,
      'destination': 'กรุงเทพ',
      'status': 'shared',
      'schedule': const <String, dynamic>{},
      'totalBudget': 0,
      'tags': const <String>[],
      'isSaved': false,
      'isLiked': liked,
      'likeCount': likes,
      'remixCount': 0,
      'creator': {
        'id': 'u-$id',
        'name': author,
        'avatarUrl': 'assets/images/puntok_avatar_1.jpg',
      },
      'coverImage': {
        'mediaId': 'm-$id',
        if (video) 'mediaType': 'video',
        'urls': video
            ? {
                'original': 'https://cdn.test/videos/$id.mov',
                'large': 'https://cdn.test/videos/$id.mov',
                'thumbnail': 'https://cdn.test/videos/$id.mov',
              }
            : {
                'original': 'https://cdn.test/photos/$id.webp',
                'large': 'https://cdn.test/photos/$id-large.webp',
                'thumbnail': 'https://cdn.test/photos/$id-thumb.webp',
              },
      },
      if (linkedTrip != null) 'linkedTrip': linkedTrip,
      'createdAt': '2026-10-20T00:00:00.000Z',
      'updatedAt': '2026-10-20T00:00:00.000Z',
    };

final _plan = <String, dynamic>{
  'id': 'plan-1',
  'title': 'จับมือเที่ยวย่านพระนครหนึ่งวัน',
  'coverImage': {
    'mediaId': 'm-plan',
    'urls': {
      'large': 'assets/images/puntok_osaka.jpg',
      'thumbnail': 'assets/images/puntok_osaka.jpg',
    },
  },
  'schedule': {'durationDays': 1, 'isDateFlexible': true},
  'placeCount': 11,
};

/// For you (`sort=recent`): two clips and a photo post that must not show.
List<Map<String, dynamic>> _recent() => [
      _row('a',
          author: 'cattarevel',
          caption: 'เราจะพาทุกคนไปเดินเที่ยว 1 Day Trip',
          likes: 5597,
          linkedTrip: _plan),
      _row('photo', author: 'PhotoOnly', caption: 'แค่รูป', video: false),
      _row('b', author: 'NamPloyWalks', caption: 'เดินเขาเช้าตรู่', likes: 12),
    ];

/// Top Punguide (`sort=popular`).
List<Map<String, dynamic>> _popular() => [
      _row('b', author: 'NamPloyWalks', caption: 'เดินเขาเช้าตรู่', likes: 12),
    ];

late FakeAdapter _adapter;

/// Answers the feed by its `sort`, which the plain path-keyed fake cannot.
class _FeedAdapter extends FakeAdapter {
  _FeedAdapter(super.replies);

  @override
  Future<ResponseBody> fetch(options, requestStream, cancelFuture) {
    if (options.method == 'GET' && options.path == '/trips') {
      final popular = options.queryParameters['sort'] == 'popular';
      replies['GET /trips'] = [FakeReply(200, popular ? _popular() : _recent())];
    }
    return super.fetch(options, requestStream, cancelFuture);
  }
}

Future<ProviderContainer> _pumpPuntok(
  WidgetTester tester, {
  Map<String, List<FakeReply>> extra = const {},
}) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  _adapter = _FeedAdapter({...extra});
  final container = ProviderContainer(overrides: [
    plunoApiProvider.overrideWith((ref) async => fakeApi(_adapter)),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/puntok',
          routes: [
            GoRoute(
              path: '/puntok',
              name: AppRoute.puntok.name,
              builder: (_, __) => const PuntokScreen(),
            ),
            GoRoute(
              path: '/search',
              name: AppRoute.search.name,
              builder: (_, __) => const Scaffold(body: Text('search')),
            ),
            GoRoute(
              path: '/trips/:tripId',
              name: AppRoute.tripDetail.name,
              builder: (_, state) =>
                  Scaffold(body: Text('trip ${state.params['tripId']}')),
            ),
          ],
        ),
      ),
    ),
  );
  await _settle(tester);
  return container;
}

/// Lets the fake network answer — plain pumping never advances it.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }
  await tester.pump();
}

void main() {
  testWidgets('the header carries the title, the discs and the three tabs',
      (tester) async {
    await _pumpPuntok(tester);

    expect(find.text('Puntok'), findsWidgets);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('Top Punguide'), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('For you asks for recent content posts', (tester) async {
    await _pumpPuntok(tester);

    final request = _adapter.requests.firstWhere((r) => r.path == '/trips');
    expect(request.queryParameters['type'], 'content');
    expect(request.queryParameters['sort'], 'recent');
  });

  testWidgets('the first page is the first video post, photo posts skipped',
      (tester) async {
    await _pumpPuntok(tester);

    expect(find.text('cattarevel'), findsOneWidget);
    expect(find.text('เราจะพาทุกคนไปเดินเที่ยว 1 Day Trip'), findsOneWidget);
    expect(find.text('5,597'), findsOneWidget);
    expect(find.text('PhotoOnly'), findsNothing);
  });

  testWidgets('the แผนทริป card shows the synced plan and ↗ opens it',
      (tester) async {
    await _pumpPuntok(tester);

    expect(find.text('แผนทริป'), findsOneWidget);
    expect(find.text('จับมือเที่ยวย่านพระนครหนึ่งวัน'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_outward));
    await tester.pumpAndSettle();

    expect(find.text('trip plan-1'), findsOneWidget);
  });

  testWidgets('a post with no linkedTrip has no plan card', (tester) async {
    await _pumpPuntok(tester);

    await tester.fling(find.text('cattarevel'), const Offset(0, -600), 1200);
    await tester.pumpAndSettle();

    expect(find.text('NamPloyWalks'), findsOneWidget);
    expect(find.text('แผนทริป'), findsNothing);
  });

  testWidgets('liking sends the like, bumps the count and fills the heart',
      (tester) async {
    await _pumpPuntok(tester, extra: {
      'POST /trips/a/like': [const FakeReply(201, <String, dynamic>{})],
    });

    await tester.tap(find.byIcon(Icons.favorite_border));
    await _settle(tester);

    expect(find.text('5,598'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(_adapter.paths, contains('POST /trips/a/like'));
  });

  testWidgets('a like the server refuses flips back and asks to sign in',
      (tester) async {
    await _pumpPuntok(tester, extra: {
      'POST /trips/a/like': [
        const FakeReply(401, {'message': 'Unauthorized'}),
      ],
    });

    await tester.tap(find.byIcon(Icons.favorite_border));
    await _settle(tester);

    expect(find.text('5,597'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.textContaining('เข้าสู่ระบบก่อน'), findsOneWidget);
  });

  testWidgets('saving sends the save and fills the bookmark', (tester) async {
    await _pumpPuntok(tester, extra: {
      'POST /trips/a/save': [const FakeReply(201, <String, dynamic>{})],
    });

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await _settle(tester);

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(_adapter.paths, contains('POST /trips/a/save'));
  });

  testWidgets('the nav bar shows Puntok as the tab in force', (tester) async {
    await _pumpPuntok(tester);

    // Two "Puntok" labels: the header title and the nav item.
    expect(find.text('Puntok'), findsNWidgets(2));
  });

  testWidgets('Top Punguide asks for popular content posts', (tester) async {
    await _pumpPuntok(tester);

    await tester.tap(find.text('Top Punguide'));
    await _settle(tester);

    expect(
      _adapter.requests
          .where((r) => r.path == '/trips')
          .map((r) => r.queryParameters['sort']),
      contains('popular'),
    );
    expect(find.text('NamPloyWalks'), findsOneWidget);
    expect(find.text('cattarevel'), findsNothing);
  });

  testWidgets('Following says it is not open yet and asks for nothing',
      (tester) async {
    await _pumpPuntok(tester);
    final before = _adapter.requests.length;

    await tester.tap(find.text('Following'));
    await _settle(tester);

    expect(find.text('ฟีดคนที่คุณติดตามยังไม่เปิดใช้งาน'), findsOneWidget);
    expect(_adapter.requests.length, before);
  });

  testWidgets('a failed load offers to try again', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: [
      plunoApiProvider.overrideWith((ref) async => fakeApi(FakeAdapter({
            'GET /trips': [const FakeReply(500, {'message': 'down'})],
          }))),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: GoRouter(initialLocation: '/puntok', routes: [
          GoRoute(
            path: '/puntok',
            name: AppRoute.puntok.name,
            builder: (_, __) => const PuntokScreen(),
          ),
        ]),
      ),
    ));
    await _settle(tester);

    expect(find.text('โหลดคลิปไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
  });

  testWidgets('a clip shared this session leads For you', (tester) async {
    final container = await _pumpPuntok(tester);

    container.read(puntokFeedProvider.notifier).publish(const PuntokPost(
          id: 'mine',
          video: 'https://cdn.test/videos/mine.mov',
          author: 'Me',
          caption: 'คลิปใหม่ของฉัน',
          likes: 0,
        ));
    await tester.pump();

    expect(find.text('Me'), findsOneWidget);
  });

  test('a list row becomes a clip only when its cover is a video', () {
    final row = TripListItem.fromJson(_row('x', author: 'A', caption: 'c'));
    final clip = PuntokPost.fromListItem(row)!;
    expect(clip.video, 'https://cdn.test/videos/x.mov');
    // The server filled `large` with the video, so there is no still.
    expect(clip.poster, isNull);

    final photo = TripListItem.fromJson(
        _row('p', author: 'A', caption: 'c', video: false));
    expect(PuntokPost.fromListItem(photo), isNull);
  });

  test('a cover with no mediaType is a video when its file is one', () {
    final media = Media.fromJson({
      'mediaId': 'm',
      'urls': {
        'original': 'https://x.test/videos/a.MOV',
        'large': 'https://x.test/videos/a-large.webp',
        'thumbnail': 'https://x.test/videos/a-thumb.webp',
      },
    });
    expect(media.isVideo, isTrue);
    expect(media.stillUrl, 'https://x.test/videos/a-large.webp');
  });

  test('list rows read linkedTrip', () {
    final row = TripListItem.fromJson(
        _row('x', author: 'A', caption: 'c', linkedTrip: _plan));
    expect(row.linkedTrip?.id, 'plan-1');
    expect(row.linkedTrip?.placeCount, 11);
    expect(row.withSaved(true).linkedTrip?.id, 'plan-1');
  });

  test('counts carry thousands separators', () {
    expect(formatPuntokCount(5), '5');
    expect(formatPuntokCount(126), '126');
    expect(formatPuntokCount(5597), '5,597');
    expect(formatPuntokCount(48219), '48,219');
    expect(formatPuntokCount(1234567), '1,234,567');
  });
}
