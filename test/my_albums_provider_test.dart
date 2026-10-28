import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/api/pluno_api.dart';
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
List<Map<String, dynamic>> _page(int count, {int from = 0}) => <Map<String,
    dynamic>>[
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

  test('a full page of clips means the shelf goes on, not that it ended',
      () async {
    // Twenty rows back, every one a clip: nothing survives the filter, but
    // the server clearly has more to give.
    final clips = <Map<String, dynamic>>[
      for (var i = 0; i < albumsPageSize; i++)
        feedTripJson(
          id: 'clip-$i',
          type: 'content',
          coverUrl: 'https://cdn.test/$i.mov',
          coverMediaType: 'video',
        ),
    ];
    final adapter = FakeAdapter(<String, List<FakeReply>>{
      'GET /trips/mine': <FakeReply>[
        FakeReply(200, clips),
        FakeReply(200, _page(2, from: 100)),
      ],
    });
    final container = _container(adapter);

    await container.read(myAlbumsProvider.future);
    expect(container.read(myAlbumsProvider).value, isEmpty);
    expect(container.read(myAlbumsProvider.notifier).hasMore, isTrue);

    await container.read(myAlbumsProvider.notifier).loadMore();

    // The second page is asked for past all twenty rows the server sent, not
    // past the nothing that survived them.
    expect(adapter.requests.last.queryParameters['offset'], albumsPageSize);
    expect(
      container.read(myAlbumsProvider).value!.map((album) => album.title),
      <String>['โพสต์ 100'],
    );
  });

  test('a short page ends the walk', () async {
    final adapter = FakeAdapter(<String, List<FakeReply>>{
      'GET /trips/mine': <FakeReply>[FakeReply(200, _page(2))],
    });
    final container = _container(adapter);

    await container.read(myAlbumsProvider.future);

    expect(container.read(myAlbumsProvider.notifier).hasMore, isFalse);
  });
}
