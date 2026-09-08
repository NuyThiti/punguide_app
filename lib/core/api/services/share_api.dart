import '../../network/api_client.dart';
import '../models/json.dart';
import '../models/share.dart';

/// Share links — the owner's side, and the read-only public side.
class ShareApi {
  const ShareApi(this._client);

  final PlunoApiClient _client;

  /// Opens sharing and returns the link.
  ///
  /// Idempotent while a link is live, so a URL already pasted into a chat keeps
  /// working. A revoked or expired link is replaced by a new token, and the old
  /// URL is dead for good.
  Future<TripShare> create(String tripId) async {
    final body =
        await _client.post<Map<String, dynamic>>('/trips/$tripId/share');
    return TripShare.fromJson(Json.asMap(body));
  }

  /// The current share settings. 404 means sharing was never turned on —
  /// call [create] first.
  Future<TripShare> read(String tripId) async {
    final body =
        await _client.get<Map<String, dynamic>>('/trips/$tripId/share');
    return TripShare.fromJson(Json.asMap(body));
  }

  /// Changes a live link. Sharing has to be on already, or this is a 404.
  ///
  /// [isActive] false revokes it, and true re-enables it with the same token.
  /// [expiresAt] as `Patch.clear()` makes the link permanent; omitting it
  /// leaves the expiry alone. [regenerate] mints a new token and kills the old
  /// URL immediately.
  Future<TripShare> update(
    String tripId, {
    bool? isActive,
    Patch<DateTime>? expiresAt,
    bool? regenerate,
  }) async {
    final body = await _client.patch<Map<String, dynamic>>(
      '/trips/$tripId/share',
      body: Json.compact(<String, dynamic>{
        'isActive': isActive,
        'expiresAt': expiresAt == null
            ? null
            : expiresAt.isClear
                ? const Patch<String>.clear()
                : Patch<String>.value(
                    expiresAt.value!.toUtc().toIso8601String(),
                  ),
        'regenerate': regenerate,
      }),
    );
    return TripShare.fromJson(Json.asMap(body));
  }

  /// Revokes the link. Idempotent, including on a trip that was never shared.
  /// A later [create] mints a new token rather than reviving the old one.
  Future<void> revoke(String tripId) =>
      _client.delete<void>('/trips/$tripId/share');

  /// Reads a shared trip with no sign-in — the token is the authorisation.
  ///
  /// A narrow public projection: no ids, no money, no private notes. Every
  /// failure mode (unknown, revoked, expired, trip deleted) answers 404, so a
  /// dead link cannot be told apart from a wrong one.
  Future<PublicSharedTrip> readShared(String shareToken) async {
    final body =
        await _client.get<Map<String, dynamic>>('/shared-trips/$shareToken');
    return PublicSharedTrip.fromJson(Json.asMap(body));
  }
}
