import '../../network/api_client.dart';
import '../models/comment.dart';
import '../models/json.dart';

/// Comments under a trip — plans, posts and Puntok clips alike, since every
/// post is a trip.
///
/// Reads are optional-auth (anyone who can open the trip; `isMine` /
/// `canEdit` / `canDelete` are false without a token). Writing needs a
/// session. A trip the caller cannot see is a 404, not a 403.
class CommentsApi {
  const CommentsApi(this._client);

  final PlunoApiClient _client;

  /// The largest page either list accepts; above it is a 400.
  static const maxPageSize = 50;

  /// Top-level comments, newest first. Replies are not included — each
  /// carries its `replyCount`; fetch them with [replies].
  Future<CommentPage> list(
    String tripId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final body = await _client.get<Map<String, dynamic>>(
      '/trips/$tripId/comments',
      query: <String, dynamic>{'limit': limit, 'offset': offset},
    );
    return CommentPage.fromJson(Json.asMap(body));
  }

  /// One comment's replies, oldest first.
  Future<CommentPage> replies(
    String tripId,
    String commentId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final body = await _client.get<Map<String, dynamic>>(
      '/trips/$tripId/comments/$commentId/replies',
      query: <String, dynamic>{'limit': limit, 'offset': offset},
    );
    return CommentPage.fromJson(Json.asMap(body));
  }

  /// Comments, or replies when [parentId] is given — a reply's id is fine
  /// too; the server files it under that reply's top-level comment. [body]
  /// is trimmed server-side, 1–1000 characters. 30 a minute, then 429.
  Future<TripComment> create(
    String tripId, {
    required String body,
    String? parentId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/trips/$tripId/comments',
      body: Json.compact(<String, dynamic>{
        'body': body,
        'parentId': parentId,
      }),
    );
    return TripComment.fromJson(Json.asMap(response));
  }

  /// Rewrites the caller's own comment. 403 on anyone else's.
  Future<TripComment> edit(
    String tripId,
    String commentId, {
    required String body,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/trips/$tripId/comments/$commentId',
      body: <String, dynamic>{'body': body},
    );
    return TripComment.fromJson(Json.asMap(response));
  }

  /// The writer's own comment, or any under the caller's own trip. Deleting a
  /// top-level comment takes its replies with it. Idempotent: 204 either way.
  Future<void> delete(String tripId, String commentId) =>
      _client.delete<void>('/trips/$tripId/comments/$commentId');
}
