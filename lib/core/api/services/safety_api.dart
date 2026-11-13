import '../../network/api_client.dart';
import '../models/json.dart';
import '../models/safety.dart';

/// Reporting and blocking — the App Store Guideline 1.2 pair.
///
/// Every call needs a token. All of them are idempotent, so a retry after a
/// timeout is safe.
class SafetyApi {
  const SafetyApi(this._client);

  final PlunoApiClient _client;

  /// The largest page `GET /users/me/blocks` accepts.
  static const maxBlocksPageSize = 100;

  /// The longest [report] `note` the server keeps.
  static const maxNoteLength = 1000;

  /// Files a report for the moderation team.
  ///
  /// `400` — reporting your own content or yourself; `404` — gone, or not
  /// visible to the caller; `429` — over 20 reports in 10 minutes.
  Future<ReportReceipt> report({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? note,
  }) async {
    final trimmed = note?.trim() ?? '';
    final body = await _client.post<Map<String, dynamic>>(
      '/reports',
      body: <String, dynamic>{
        'targetType': targetType.wire,
        'targetId': targetId,
        'reason': reason.wire,
        if (trimmed.isNotEmpty) 'note': trimmed,
      },
    );
    return ReportReceipt.fromJson(Json.asMap(body));
  }

  /// Blocks [userId] both ways and drops any follow between the two.
  /// `400` blocking yourself, `404` no such user, `429` too often.
  Future<bool> block(String userId) async {
    final body =
        await _client.post<Map<String, dynamic>>('/users/$userId/block');
    return Json.boolean(Json.asMap(body), 'isBlocked', fallback: true);
  }

  /// Lifts a block. Never a 404 — works on deleted accounts too. The follows
  /// the block removed do not come back.
  Future<bool> unblock(String userId) async {
    final body =
        await _client.delete<Map<String, dynamic>>('/users/$userId/block');
    return Json.boolean(Json.asMap(body), 'isBlocked');
  }

  /// The caller's blocked accounts, most recently blocked first.
  Future<BlockedUserPage> blocked({int limit = 20, int offset = 0}) async {
    final body = await _client.get<Map<String, dynamic>>(
      '/users/me/blocks',
      query: <String, dynamic>{'limit': limit, 'offset': offset},
    );
    return BlockedUserPage.fromJson(Json.asMap(body));
  }
}
