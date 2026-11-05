import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/api/pluno_api.dart' show PlunoHeaders;
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/remix_trip/presentation/remix_trip_screen.dart';
import 'package:pluno/features/trips/domain/models/trip.dart';
import 'package:pluno/features/trips/presentation/providers/trip_providers.dart';

import 'support/fake_api.dart';

const _remixPath = 'POST /trips/src-1/remix';

final _source = Trip(
  id: 'src-1',
  title: 'ซินจ่าว ดานัง',
  destination: 'ดานัง, เวียดนาม',
  coverImage: '',
  budget: 0,
  duration: 3,
  description: '',
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

Map<String, dynamic> _remixedJson() => <String, dynamic>{
      'id': 'remix-new',
      'ownerId': 'u1',
      'title': 'ซินจ่าว ดานัง Remix',
      'planMode': 'remixed',
      'status': 'draft',
      'visibility': 'private',
      'days': <dynamic>[],
      'createdAt': '2026-11-04T00:00:00.000Z',
    };

Future<void> _pump(WidgetTester tester, FakeAdapter adapter) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
        selectedTripProvider.overrideWith((ref, tripId) async => _source),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const RemixTripScreen(tripId: 'src-1'),
            ),
            GoRoute(
              path: '/done/:tripId',
              name: AppRoute.postDone.name,
              builder: (_, state) =>
                  Scaffold(body: Text('done ${state.params['tripId']}')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _createButton => find.text('Create remix and edit');

void main() {
  testWidgets('creating a remix posts to the API and opens the server copy',
      (tester) async {
    final adapter = FakeAdapter({
      _remixPath: [FakeReply(201, _remixedJson())],
    });
    await _pump(tester, adapter);

    await tester.tap(_createButton);
    await tester.pumpAndSettle();

    expect(adapter.paths, [_remixPath]);
    expect(adapter.bodyOf(_remixPath), {'title': 'ซินจ่าว ดานัง Remix'});
    expect(
      adapter.requests.single.headers[PlunoHeaders.idempotencyKey],
      isNotEmpty,
    );
    // The done screen gets the id the server minted, not a local stand-in.
    expect(find.text('done remix-new'), findsOneWidget);
  });

  testWidgets('a double tap creates one remix', (tester) async {
    final adapter = FakeAdapter({
      _remixPath: [FakeReply(201, _remixedJson())],
    });
    await _pump(tester, adapter);

    await tester.tap(_createButton);
    await tester.tap(_createButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(adapter.paths, [_remixPath]);
  });

  testWidgets('a refusal stays on the page and a retry reuses the key',
      (tester) async {
    final adapter = FakeAdapter({
      _remixPath: [
        const FakeReply(403, {
          'statusCode': 403,
          'message': 'Remixing is turned off for this trip',
          'error': 'Forbidden',
        }),
        FakeReply(201, _remixedJson()),
      ],
    });
    await _pump(tester, adapter);

    await tester.tap(_createButton);
    await tester.pumpAndSettle();

    expect(find.text('Remixing is turned off for this trip'), findsOneWidget);
    expect(find.textContaining('done'), findsNothing);

    await tester.tap(_createButton);
    await tester.pumpAndSettle();

    expect(find.text('done remix-new'), findsOneWidget);
    final keys = adapter.requests
        .map((request) => request.headers[PlunoHeaders.idempotencyKey])
        .toList();
    expect(keys, hasLength(2));
    expect(keys.first, keys.last);
  });
}
