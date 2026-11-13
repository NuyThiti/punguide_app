import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/profile/presentation/providers/profile_providers.dart';

import 'support/fake_api.dart';
import 'support/home_feed_fixtures.dart';

ProviderContainer _container(FakeAdapter adapter) {
  final container = ProviderContainer(
    overrides: <Override>[
      plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
      authSessionProvider
          .overrideWith((ref) => AuthController(AuthSession.demo)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// A page of `limit` rows, every other one a clip the server still labels
/// `content`.
List<Map<String, dynamic>> _page(int count, {int from = 0}) =>
    <Map<String, dynamic>>[
      for (var i = from; i < from + count; i++)
        if (i.isEven)
          feedTripJson(id: 'post-$i', title: 'โพสต์ $i', type: 'content')
        else
          feedTripJson(
            id: 'clip-$i',
            title: 'คลิป $i',
            type: 'content',
            coverUrl: 'https://cdn.test/$i.mov',
            coverMediaType: 'video',
          ),
    ];

void main() {
  test('asks for posts and plans, never puntok', () async {
    final adapter = FakeAdapter(<String, List<FakeReply>>{
      'GET /trips/mine': <FakeReply>[FakeReply(200, _page(2))],
    });

    await _container(adapter).read(myAlbumsProvider.future);

    expect(
      adapter.requests.single.queryParameters['type'],
      'content,plan_trip',
    );
  });

  test('drops the clips the server answers as content anyway', () async {
    final adapter = FakeAdapter(<String, List<FakeReply>>{
      'GET /trips/mine': <FakeReply>[FakeReply(200, _page(4))],
    });

    final albums = await _container(adapter).read(myAlbumsProvider.future);

    expect(
      albums.map((album) => album.title),
      <String>['โพสต์ 0', 'โพสต์ 2'],
    );
  });

  test('sends no window: the server would read it as rows, not trips',
      () async {
    final adapter = FakeAdapter(<String, List<FakeReply>>{
      'GET /trips/mine': <FakeReply>[FakeReply(200, _page(2))],
    });

    await _container(adapter).read(myAlbumsProvider.future);

    // `limit` on this endpoint counts the rows a trip joins to, so one plan
    // with two dozen stops swallows the whole window and the shelf comes
    // back holding a single album. The whole shelf is read instead.
    final query = adapter.requests.single.queryParameters;
    expect(query.containsKey('limit'), isFalse);
    expect(query.containsKey('offset'), isFalse);
  });

  test('signed out is an empty shelf, not an error', () async {
    final adapter = FakeAdapter(<String, List<FakeReply>>{
      'GET /trips/mine': <FakeReply>[FakeReply(200, _page(2))],
    });
    final container = ProviderContainer(
      overrides: <Override>[
        plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
        authSessionProvider.overrideWith((ref) => AuthController(null)),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(myAlbumsProvider.future), isEmpty);
    expect(adapter.requests, isEmpty);
  });
}
