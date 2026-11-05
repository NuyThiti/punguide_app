import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/trips/presentation/providers/trip_like_providers.dart';

import 'support/fake_api.dart';
import 'support/home_feed_fixtures.dart';

ProviderContainer _container(FakeAdapter adapter) {
  final container = ProviderContainer(
    overrides: <Override>[
      plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
      authSessionProvider.overrideWith((ref) => AuthController(AuthSession.demo)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a heart flips before the request and stays once it is accepted',
      () async {
    final adapter = FakeAdapter(<String, List<FakeReply>>{
      'POST /trips/trip-1/like': <FakeReply>[const FakeReply(204, null)],
    });
    final container = _container(adapter);

    final pending = container
        .read(tripLikedProvider.notifier)
        .toggle('trip-1', wasLiked: false);

    // Optimistic: the card fills before the server has answered.
    expect(container.read(tripLikedProvider)['trip-1'], isTrue);
    await pending;
    expect(container.read(tripLikedProvider)['trip-1'], isTrue);
    expect(adapter.requests.single.path, '/trips/trip-1/like');
  });

  test('a refused heart goes back the way it was', () async {
    final adapter = FakeAdapter(<String, List<FakeReply>>{
      'POST /trips/trip-1/like': <FakeReply>[
        const FakeReply(401, <String, dynamic>{'message': 'sign in'}),
      ],
    });
    final container = _container(adapter);

    await expectLater(
      container
          .read(tripLikedProvider.notifier)
          .toggle('trip-1', wasLiked: false),
      throwsA(isA<ApiException>()),
    );
    // Nothing left behind: the ledger never holds a flip the server refused.
    expect(container.read(tripLikedProvider).containsKey('trip-1'), isFalse);
  });

  test('un-hearting asks the server to delete, not to post', () async {
    final adapter = FakeAdapter(<String, List<FakeReply>>{
      'DELETE /trips/trip-1/like': <FakeReply>[const FakeReply(204, null)],
    });
    final container = _container(adapter);

    await container
        .read(tripLikedProvider.notifier)
        .toggle('trip-1', wasLiked: true);

    expect(container.read(tripLikedProvider)['trip-1'], isFalse);
    expect(adapter.requests.single.method, 'DELETE');
  });

  test('the ledger answers for a row, falling back to what it was fetched as',
      () {
    final container = _container(FakeAdapter(const <String, List<FakeReply>>{}));
    final trip = feedTrip();

    expect(likedNow(container.read(tripLikedProvider), trip), isFalse);

    container.read(tripLikedProvider.notifier).record(trip.id, liked: true);
    expect(likedNow(container.read(tripLikedProvider), trip), isTrue);
  });
}
