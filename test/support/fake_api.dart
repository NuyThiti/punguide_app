import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:pluno/core/api/pluno_api.dart';

/// One canned answer for a request.
class FakeReply {
  const FakeReply(this.statusCode, this.body);

  final int statusCode;
  final Object? body;
}

/// A stand-in transport: records every request and replies from a queue keyed
/// by `METHOD /path`. Lets a widget test assert on the exact body that went up.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.replies);

  final Map<String, List<FakeReply>> replies;
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
      return ResponseBody.fromString(
        '{"message":"no stub for $key"}',
        500,
        headers: _jsonHeaders(),
      );
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

  Map<String, List<String>> _jsonHeaders() => <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      };

  /// The decoded JSON body of the first `METHOD /path` request, or null.
  Map<String, dynamic>? bodyOf(String key) {
    for (final request in requests) {
      if ('${request.method} ${request.path}' == key) {
        final data = request.data;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    }
    return null;
  }

  List<String> get paths =>
      requests.map((r) => '${r.method} ${r.path}').toList();
}

PlunoApi fakeApi(FakeAdapter adapter) {
  return PlunoApi(
    PlunoApiClient(
      config: const ApiConfig(baseUrl: 'http://localhost:4002'),
      tokenStore: AuthTokenStore(storage: InMemorySecretStore()),
      cookieJar: CookieJar(),
      dio: Dio()..httpClientAdapter = adapter,
      refreshDio: Dio()..httpClientAdapter = adapter,
    ),
  );
}

/// The shape `POST /trips` answers with — enough of a TripResponseDto for
/// `ApiTrip.fromJson` to parse.
Map<String, dynamic> createdTripJson({String id = 'trip-new'}) =>
    <String, dynamic>{
      'id': id,
      'ownerId': 'u1',
      'title': 'ทริปใหม่',
      'destination': 'ดานัง, เวียดนาม',
      'status': 'draft',
      'schedule': <String, dynamic>{},
      'totalBudget': 0,
      'tags': <String>[],
      'isSaved': false,
      'isLiked': false,
      'likeCount': 0,
      'remixCount': 0,
      'createdAt': '2026-09-09T00:00:00.000Z',
      'updatedAt': '2026-09-09T00:00:00.000Z',
    };
