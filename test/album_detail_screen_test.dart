import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/profile/presentation/album_detail_screen.dart';
import 'package:pluno/shared/widgets/cover_image.dart';
import 'package:pluno/features/profile/presentation/providers/profile_providers.dart';

import 'support/fake_api.dart';

/// The trip itself. Its `contents` carry a single embedded picture on
/// purpose: the gallery holds more, and the grid must follow the gallery.
Map<String, dynamic> _tripJson({int totalImages = 4, bool hasMore = true}) =>
    <String, dynamic>{
      'id': 'album-1',
      'ownerId': 'u1',
      'type': 'content',
      'title': 'รวมคาเฟ่ลับย่านพระนคร',
      'destination': 'พระนคร, กรุงเทพฯ',
      'status': 'shared',
      'schedule': <String, dynamic>{},
      'totalBudget': 0,
      'tags': <String>[],
      'visibility': 'public',
      'remixCount': 0,
      'mediaSummary': <String, dynamic>{
        'totalImages': totalImages,
        'hasMore': hasMore,
        'galleryEndpoint': '/trips/album-1/media',
      },
      'isSaved': false,
      'isLiked': false,
      'likeCount': 0,
      'days': <dynamic>[],
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'title': 'เช้า',
          'content': 'กาแฟร้านแรก',
          'images': <Map<String, dynamic>>[
            <String, dynamic>{
              'mediaId': 'm-1',
              'urls': <String, dynamic>{
                'large': 'https://cdn.test/1-large.jpg',
                'thumbnail': 'https://cdn.test/1-thumb.jpg',
              },
            },
          ],
        },
      ],
      'createdAt': '2026-10-12T00:00:00.000Z',
      'updatedAt': '2026-10-12T00:00:00.000Z',
    };

Map<String, dynamic> _galleryPage({
  required int page,
  required List<String> ids,
  int total = 4,
  int limit = 30,
}) =>
    <String, dynamic>{
      'tripId': 'album-1',
      'total': total,
      'page': page,
      'limit': limit,
      'items': <Map<String, dynamic>>[
        for (final id in ids)
          <String, dynamic>{
            'id': id,
            'isCover': false,
            'urls': <String, dynamic>{
              'large': 'https://cdn.test/$id-large.jpg',
              'thumbnail': 'https://cdn.test/$id-thumb.jpg',
            },
          },
      ],
    };

FakeAdapter _adapter({
  List<FakeReply>? gallery,
  Map<String, dynamic>? trip,
}) =>
    FakeAdapter(<String, List<FakeReply>>{
      'GET /trips/album-1': <FakeReply>[FakeReply(200, trip ?? _tripJson())],
      'GET /trips/album-1/media': gallery ??
          <FakeReply>[
            FakeReply(200, _galleryPage(page: 1, ids: <String>['a', 'b'])),
          ],
    });

Widget _harness(FakeAdapter adapter) {
  return ProviderScope(
    overrides: <Override>[
      plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
      authSessionProvider
          .overrideWith((ref) => AuthController(AuthSession.demo)),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.albumDetail.name,
            builder: (_, __) => const AlbumDetailScreen(albumId: 'album-1'),
          ),
          GoRoute(
            path: '/profile',
            name: AppRoute.profile.name,
            builder: (_, __) => const Scaffold(body: Text('profile-stub')),
          ),
        ],
      ),
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

List<String> _paths(FakeAdapter adapter) =>
    adapter.requests.map((r) => '${r.method} ${r.path}').toList();

void main() {
  testWidgets('the pictures come from the gallery, not from contents',
      (tester) async {
    _phone(tester);
    final adapter = _adapter();

    await tester.pumpWidget(_harness(adapter));
    await tester.pumpAndSettle();

    expect(_paths(adapter), contains('GET /trips/album-1/media'));

    // Two tiles from the gallery — the single picture embedded in `contents`
    // is not what the grid is built from.
    expect(find.byType(CoverImage), findsWidgets);
    final gallery = adapter.requests
        .firstWhere((r) => r.path == '/trips/album-1/media');
    expect(gallery.queryParameters['page'], 1);
    expect(gallery.queryParameters['limit'], albumGalleryPageSize);
  });

  testWidgets('the header counts every picture the trip holds, not the page',
      (tester) async {
    _phone(tester);

    // Four in all, two on this page.
    await tester.pumpWidget(_harness(_adapter()));
    await tester.pumpAndSettle();

    expect(find.text('12 Oct 2026 • 4 รูป'), findsOneWidget);
  });

  testWidgets('more pages are offered and append', (tester) async {
    _phone(tester);
    final adapter = _adapter(gallery: <FakeReply>[
      FakeReply(200, _galleryPage(page: 1, ids: <String>['a', 'b'], limit: 2)),
      FakeReply(200, _galleryPage(page: 2, ids: <String>['c', 'd'], limit: 2)),
    ]);

    await tester.pumpWidget(_harness(adapter));
    await tester.pumpAndSettle();

    // page 1 of 2 with limit 2 and total 4: there is more.
    expect(find.text('โหลดรูปเพิ่ม'), findsOneWidget);

    await tester.tap(find.text('โหลดรูปเพิ่ม'));
    await tester.pumpAndSettle();

    expect(
      adapter.requests.where((r) => r.path == '/trips/album-1/media').length,
      2,
    );
    // The walk is spent, so the button goes.
    expect(find.text('โหลดรูปเพิ่ม'), findsNothing);
  });

  testWidgets('a single full page offers nothing more', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(
      _adapter(gallery: <FakeReply>[
        FakeReply(
          200,
          _galleryPage(page: 1, ids: <String>['a', 'b'], total: 2),
        ),
      ]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('โหลดรูปเพิ่ม'), findsNothing);
  });

  testWidgets('an empty gallery says so', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(
      _adapter(
        trip: _tripJson(totalImages: 0, hasMore: false),
        gallery: <FakeReply>[
          FakeReply(200, _galleryPage(page: 1, ids: <String>[], total: 0)),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('อัลบั้มนี้ยังไม่มีรูป'), findsOneWidget);
    expect(find.text('12 Oct 2026 • 0 รูป'), findsOneWidget);
  });

  testWidgets('a failed gallery offers to try again without losing the header',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(
      _adapter(gallery: <FakeReply>[const FakeReply(500, <String, dynamic>{})]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('โหลดรูปไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
    // The trip loaded, so its title and summary count still show.
    expect(find.text('รวมคาเฟ่ลับย่านพระนคร'), findsOneWidget);
    expect(find.text('12 Oct 2026 • 4 รูป'), findsOneWidget);
  });

  testWidgets('a failed trip read offers to try again', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(FakeAdapter(<String, List<FakeReply>>{
      'GET /trips/album-1': <FakeReply>[const FakeReply(500, <String, dynamic>{})],
    })));
    await tester.pumpAndSettle();

    expect(find.text('เปิดอัลบั้มไม่สำเร็จ'), findsOneWidget);
  });

  testWidgets('the actions with no API behind them say so', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_adapter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share Album'));
    await tester.pump();
    expect(find.text('แชร์อัลบั้มยังไม่เปิดใช้งาน'), findsOneWidget);

    await tester.tap(find.text('Select'));
    await tester.pump();
    expect(find.text('เลือกรูปยังไม่เปิดใช้งาน'), findsOneWidget);
  });
}
