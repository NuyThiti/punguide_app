import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/profile/presentation/album_detail_screen.dart';

import 'support/fake_api.dart';

/// A post as `GET /trips/:id` hands it over: two sections, four pictures, one
/// of them withdrawn.
Map<String, dynamic> _albumJson({
  List<Map<String, dynamic>>? contents,
}) =>
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
      'mediaSummary': <String, dynamic>{},
      'isSaved': false,
      'isLiked': false,
      'likeCount': 0,
      'days': <dynamic>[],
      'coverImage': <String, dynamic>{
        'mediaId': 'm-cover',
        'urls': <String, dynamic>{
          'large': 'https://cdn.test/cover-large.jpg',
          'thumbnail': 'https://cdn.test/cover-thumb.jpg',
        },
      },
      'contents': contents ??
          <Map<String, dynamic>>[
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
                <String, dynamic>{'mediaId': 'm-gone', 'unavailable': true},
              ],
            },
            <String, dynamic>{
              'title': 'บ่าย',
              'content': 'ขนมปังปิ้ง',
              'images': <Map<String, dynamic>>[
                <String, dynamic>{
                  'mediaId': 'm-2',
                  'urls': <String, dynamic>{
                    'large': 'https://cdn.test/2-large.jpg',
                    'thumbnail': 'https://cdn.test/2-thumb.jpg',
                  },
                },
              ],
            },
          ],
      'createdAt': '2026-10-12T00:00:00.000Z',
      'updatedAt': '2026-10-12T00:00:00.000Z',
    };

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

FakeAdapter _adapter({Object? body, int status = 200}) =>
    FakeAdapter(<String, List<FakeReply>>{
      'GET /trips/album-1': <FakeReply>[
        FakeReply(status, body ?? _albumJson()),
      ],
    });

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the header prints the album title, date and photo count',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_adapter()));
    await tester.pumpAndSettle();

    expect(find.text('รวมคาเฟ่ลับย่านพระนคร'), findsOneWidget);
    // Two sections, three pictures listed, one of them withdrawn.
    expect(find.text('12 Oct 2026 • 2 รูป'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Share Album'), findsOneWidget);
  });

  testWidgets('the grid skips a picture the server withdrew', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_adapter()));
    await tester.pumpAndSettle();

    final trip = ApiTrip.fromJson(_albumJson());
    expect(
      albumPhotos(trip).map((photo) => photo.full),
      <String>['https://cdn.test/1-large.jpg', 'https://cdn.test/2-large.jpg'],
    );
  });

  test('raw links stand in only for a section with nothing resolved', () {
    final trip = ApiTrip.fromJson(_albumJson(
      contents: <Map<String, dynamic>>[
        <String, dynamic>{
          'title': 'ยังไม่ resolve',
          'content': 'ร่าง',
          'imageUrls': <String>['https://cdn.test/raw.jpg'],
        },
        <String, dynamic>{
          'title': 'resolve แล้ว',
          'content': 'จริง',
          'images': <Map<String, dynamic>>[
            <String, dynamic>{
              'mediaId': 'm-9',
              'urls': <String, dynamic>{
                'large': 'https://cdn.test/9-large.jpg',
                'thumbnail': 'https://cdn.test/9-thumb.jpg',
              },
            },
          ],
          // Ignored: the resolved list wins where it exists.
          'imageUrls': <String>['https://cdn.test/ignored.jpg'],
        },
      ],
    ));

    expect(
      albumPhotos(trip).map((photo) => photo.full),
      <String>['https://cdn.test/raw.jpg', 'https://cdn.test/9-large.jpg'],
    );
  });

  testWidgets('an album with no pictures says so', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(
      _adapter(body: _albumJson(contents: const <Map<String, dynamic>>[])),
    ));
    await tester.pumpAndSettle();

    expect(find.text('อัลบั้มนี้ยังไม่มีรูป'), findsOneWidget);
    expect(find.text('12 Oct 2026 • 0 รูป'), findsOneWidget);
  });

  testWidgets('a failed read offers to try again', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_adapter(status: 500, body: const {})));
    await tester.pumpAndSettle();

    expect(find.text('เปิดอัลบั้มไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
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
