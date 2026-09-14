import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/pluno_api.dart';

/// One canned answer for a request.
class _Reply {
  const _Reply(this.statusCode, this.body);

  final int statusCode;
  final Object? body;
}

/// A stand-in transport: it records every request and replies from a queue
/// keyed by `METHOD /path`.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.replies);

  final Map<String, List<_Reply>> replies;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final key = '${options.method} ${options.path}';
    final queue = replies[key];
    if (queue == null || queue.isEmpty) {
      return ResponseBody.fromString('{"message":"no stub for $key"}', 500,
          headers: _jsonHeaders());
    }
    final reply = queue.length == 1 ? queue.first : queue.removeAt(0);
    return ResponseBody.fromString(
      reply.body == null ? '' : jsonEncode(reply.body),
      reply.statusCode,
      headers: _jsonHeaders(),
    );
  }

  @override
  void close({bool force = false}) {}

  Map<String, List<String>>? _jsonHeaders() => <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      };

  /// Every `Authorization` header seen, in order.
  List<String?> get authHeaders => requests
      .map((request) => request.headers['Authorization'] as String?)
      .toList();

  List<String> get paths =>
      requests.map((request) => '${request.method} ${request.path}').toList();
}

PlunoApiClient _client(
  _FakeAdapter adapter, {
  AuthTokenStore? tokenStore,
}) {
  final dio = Dio()..httpClientAdapter = adapter;
  final refreshDio = Dio()..httpClientAdapter = adapter;
  return PlunoApiClient(
    config: const ApiConfig(baseUrl: 'http://localhost:4002'),
    tokenStore: tokenStore ?? AuthTokenStore(storage: InMemorySecretStore()),
    cookieJar: CookieJar(),
    dio: dio,
    refreshDio: refreshDio,
  );
}

void main() {
  test('login stores the token and later calls carry it', () async {
    final adapter = _FakeAdapter(<String, List<_Reply>>{
      'POST /auth/login': [
        const _Reply(200, <String, dynamic>{
          'accessToken': 'token-1',
          'expiresIn': '15m',
          'user': <String, dynamic>{'id': 'u1', 'username': 'nichapa'},
        }),
      ],
      'GET /trips/mine': [const _Reply(200, <dynamic>[])],
    });
    final client = _client(adapter);
    final api = PlunoApi(client);

    final result =
        await api.auth.login(username: 'nichapa', password: 'secret123');
    expect(result.user.username, 'nichapa');
    expect(client.tokenStore.accessToken, 'token-1');
    expect(client.tokenStore.needsRefresh, isFalse);

    await api.trips.mine();
    // The login itself is exempt; the trip call carries the new token.
    expect(adapter.authHeaders.last, 'Bearer token-1');
  });

  test('an optional-auth call is still authenticated, for the quota', () async {
    final store = AuthTokenStore(storage: InMemorySecretStore());
    await store.save(accessToken: 'token-1', expiresIn: '15m');
    final adapter = _FakeAdapter(<String, List<_Reply>>{
      'GET /places/search': [const _Reply(200, <dynamic>[])],
    });
    final api = PlunoApi(_client(adapter, tokenStore: store));

    await api.places.search('วัด');
    expect(adapter.authHeaders.single, 'Bearer token-1');
  });

  test('a nearly expired token is refreshed before the request goes out',
      () async {
    final store = AuthTokenStore(storage: InMemorySecretStore());
    // Inside the refresh leeway, so this token must not be used as-is.
    await store.save(accessToken: 'stale', expiresIn: '30s');
    final adapter = _FakeAdapter(<String, List<_Reply>>{
      'POST /auth/refresh': [
        const _Reply(200, <String, dynamic>{
          'accessToken': 'token-2',
          'expiresIn': '15m',
        }),
      ],
      'GET /trips/mine': [const _Reply(200, <dynamic>[])],
    });
    final api = PlunoApi(_client(adapter, tokenStore: store));

    await api.trips.mine();

    expect(adapter.paths, <String>['POST /auth/refresh', 'GET /trips/mine']);
    expect(adapter.authHeaders.last, 'Bearer token-2');
  });

  test('concurrent calls share a single refresh', () async {
    final store = AuthTokenStore(storage: InMemorySecretStore());
    await store.save(accessToken: 'stale', expiresIn: '30s');
    final adapter = _FakeAdapter(<String, List<_Reply>>{
      'POST /auth/refresh': [
        const _Reply(200, <String, dynamic>{
          'accessToken': 'token-2',
          'expiresIn': '15m',
        }),
      ],
      'GET /trips/mine': [const _Reply(200, <dynamic>[])],
      'GET /trips/saved': [const _Reply(200, <dynamic>[])],
    });
    final api = PlunoApi(_client(adapter, tokenStore: store));

    await Future.wait<void>(<Future<void>>[
      api.trips.mine(),
      api.trips.saved(),
    ]);

    final refreshes =
        adapter.paths.where((path) => path == 'POST /auth/refresh').length;
    expect(refreshes, 1);
  });

  test('a 401 refreshes once and replays the request', () async {
    final store = AuthTokenStore(storage: InMemorySecretStore());
    // Comfortably valid, so only the 401 can trigger a refresh.
    await store.save(accessToken: 'token-1', expiresIn: '15m');
    final adapter = _FakeAdapter(<String, List<_Reply>>{
      'GET /trips/mine': [
        const _Reply(401, <String, dynamic>{'message': 'Unauthorized'}),
        const _Reply(200, <dynamic>[]),
      ],
      'POST /auth/refresh': [
        const _Reply(200, <String, dynamic>{
          'accessToken': 'token-2',
          'expiresIn': '15m',
        }),
      ],
    });
    final api = PlunoApi(_client(adapter, tokenStore: store));

    await api.trips.mine();

    expect(adapter.paths, <String>[
      'GET /trips/mine',
      'POST /auth/refresh',
      'GET /trips/mine',
    ]);
    expect(adapter.authHeaders.last, 'Bearer token-2');
  });

  test('a rejected refresh clears the session and announces it', () async {
    final store = AuthTokenStore(storage: InMemorySecretStore());
    await store.save(accessToken: 'token-1', expiresIn: '15m');
    final adapter = _FakeAdapter(<String, List<_Reply>>{
      'GET /trips/mine': [
        const _Reply(401, <String, dynamic>{'message': 'Unauthorized'}),
      ],
      'POST /auth/refresh': [
        const _Reply(401, <String, dynamic>{'message': 'Unauthorized'}),
      ],
    });
    final client = _client(adapter, tokenStore: store);
    final expired = Completer<void>();
    client.onSessionExpired.listen((_) => expired.complete());
    final api = PlunoApi(client);

    await expectLater(
      api.trips.mine(),
      throwsA(isA<ApiException>().having(
        (failure) => failure.isUnauthorized,
        'isUnauthorized',
        isTrue,
      )),
    );

    await expired.future;
    expect(store.hasToken, isFalse);
  });

  test('validation errors arrive as a joined list of messages', () async {
    final adapter = _FakeAdapter(<String, List<_Reply>>{
      'POST /trips': [
        const _Reply(400, <String, dynamic>{
          'statusCode': 400,
          'message': <String>[
            'startDate must be YYYY-MM-DD',
            'title should not be empty',
          ],
          'error': 'Bad Request',
        }),
      ],
    });
    final api = PlunoApi(_client(adapter));

    try {
      await api.trips.createDraft(title: '', destination: 'เชียงใหม่');
      fail('expected an ApiException');
    } on ApiException catch (failure) {
      expect(failure.isValidationError, isTrue);
      expect(failure.messages, hasLength(2));
      expect(failure.message, contains('title should not be empty'));
      expect(failure.error, 'Bad Request');
    }
  });

  test('a transport failure has no status code and a readable message',
      () async {
    final dio = Dio()
      ..httpClientAdapter = _ThrowingAdapter(DioExceptionType.connectionError);
    final client = PlunoApiClient(
      config: const ApiConfig(baseUrl: 'http://localhost:4002'),
      tokenStore: AuthTokenStore(storage: InMemorySecretStore()),
      cookieJar: CookieJar(),
      dio: dio,
      refreshDio: Dio()..httpClientAdapter = _FakeAdapter(const {}),
    );

    try {
      await PlunoApi(client).trips.feed();
      fail('expected an ApiException');
    } on ApiException catch (failure) {
      expect(failure.isNetworkFailure, isTrue);
      expect(failure.statusCode, isNull);
      expect(failure.message, isNotEmpty);
    }
  });

  test('itinerary writes can opt out of route calculation', () async {
    final adapter = _FakeAdapter(<String, List<_Reply>>{
      'PATCH /days/day-1/items/order': [
        const _Reply(200, <String, dynamic>{
          'id': 'day-1',
          'dayNumber': 1,
          'date': '',
          'activities': <dynamic>[],
          'travelSegments': <dynamic>[],
        }),
      ],
    });
    final api = PlunoApi(_client(adapter));

    await api.itinerary.reorderItems(
      'day-1',
      <String>['a', 'b'],
      calculateTravelSegments: false,
    );

    expect(
      adapter.requests.single.headers[PlunoHeaders.calculateTravelSegments],
      'false',
    );
  });

  test('an idempotency key is passed through on save-plan', () async {
    final adapter = _FakeAdapter(<String, List<_Reply>>{
      'POST /trips/create': [
        const _Reply(201, <String, dynamic>{
          'id': 't1',
          'ownerId': 'u1',
          'title': 'ทริป',
          'destination': 'เชียงใหม่',
          'status': 'draft',
          'schedule': <String, dynamic>{'isDateFlexible': false},
          'totalBudget': 0,
          'visibility': 'private',
          'remixCount': 0,
          'mediaSummary': <String, dynamic>{
            'totalImages': 0,
            'hasMore': false,
            'galleryEndpoint': '/trips/t1/media',
          },
          'isSaved': false,
          'isLiked': false,
          'likeCount': 0,
          'days': <dynamic>[],
          'createdAt': '2026-09-08T04:00:00.000Z',
          'updatedAt': '2026-09-08T04:00:00.000Z',
        }),
      ],
    });
    final api = PlunoApi(_client(adapter));

    final trip = await api.trips.createFromDraft(
      TripDraft(
        title: 'ทริป',
        destination: 'เชียงใหม่',
        days: const <DraftDay>[],
      ),
      idempotencyKey: 'key-1',
    );

    expect(trip.id, 't1');
    expect(
      adapter.requests.single.headers[PlunoHeaders.idempotencyKey],
      'key-1',
    );
  });

  test('a 204 delete resolves without a body', () async {
    final adapter = _FakeAdapter(<String, List<_Reply>>{
      'DELETE /trips/t1': [const _Reply(204, null)],
    });
    final api = PlunoApi(_client(adapter));

    await api.trips.delete('t1');
    expect(adapter.paths, <String>['DELETE /trips/t1']);
  });

  test('an unset query filter is left out of the URL', () async {
    final adapter = _FakeAdapter(<String, List<_Reply>>{
      'GET /trips': [const _Reply(200, <dynamic>[])],
    });
    final api = PlunoApi(_client(adapter));

    await api.trips.feed();
    expect(adapter.requests.single.queryParameters, isEmpty);

    await api.trips.feed(const TripFeedQuery(destination: 'เชียงใหม่'));
    expect(
      adapter.requests.last.queryParameters,
      <String, dynamic>{'destination': 'เชียงใหม่'},
    );
  });

  test('a filtered feed spells every row of the sheet onto the query',
      () async {
    final adapter = _FakeAdapter(<String, List<_Reply>>{
      'GET /trips': [const _Reply(200, <dynamic>[])],
    });
    final api = PlunoApi(_client(adapter));

    await api.trips.feed(
      TripFeedQuery(
        styles: const [TravelStyle.nature, TravelStyle.cafe],
        customStyles: const ['อิสลาม'],
        constraints: const [TripConstraint.seniors],
        adults: 2,
        children: 1,
        budgetTiers: const [BudgetTier.premium],
        budgetMax: 10000,
        budgetScope: FeedBudgetScope.perPerson,
        dateFrom: DateTime(2026, 9, 28),
        dateTo: DateTime(2026, 9, 30),
        maxDurationDays: 3,
        latitude: 13.7563,
        longitude: 100.5018,
        sort: FeedSort.nearest,
        limit: 20,
      ),
    );

    // Lists go up comma-joined, enums as their wire values, dates as
    // YYYY-MM-DD. Anything the sheet did not answer is absent entirely — the
    // endpoint runs forbidNonWhitelisted, so a stray key is a 400.
    expect(adapter.requests.last.queryParameters, <String, dynamic>{
      'styles': 'nature,cafe',
      'customStyles': 'อิสลาม',
      'constraints': 'seniors',
      'adults': 2,
      'children': 1,
      'budgetTiers': 'premium',
      'budgetMax': 10000.0,
      'budgetScope': 'per_person',
      'dateFrom': '2026-09-28',
      'dateTo': '2026-09-30',
      'maxDurationDays': 3,
      'lat': 13.7563,
      'lng': 100.5018,
      'sort': 'nearest',
      'limit': 20,
    });
  });

  test('half a fix measures nothing, so neither half is sent', () async {
    final adapter = _FakeAdapter(<String, List<_Reply>>{
      'GET /trips': [const _Reply(200, <dynamic>[])],
    });
    final api = PlunoApi(_client(adapter));

    await api.trips.feed(
      const TripFeedQuery(latitude: 13.7563, sort: FeedSort.nearest),
    );

    // Without a pair the server cannot measure, and it answers `recent`
    // anyway — sending one half would only look like a working filter.
    expect(
      adapter.requests.last.queryParameters,
      <String, dynamic>{'sort': 'nearest'},
    );
  });
}

/// An adapter that always fails, to exercise the no-response path.
class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this.type);

  final DioExceptionType type;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      throw DioException(requestOptions: options, type: type);

  @override
  void close({bool force = false}) {}
}
