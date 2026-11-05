import '../../network/api_client.dart';
import '../models/follow.dart';
import '../models/json.dart';

/// Which side of a follow relationship a list shows.
enum FollowListKind {
  /// People who follow the account.
  followers('followers'),

  /// People the account follows.
  following('following');

  const FollowListKind(this.path);
  final String path;
}

/// Follow / unfollow, the counts, the two lists, and removing a follower.
///
/// Reads are optional-auth: send the token when there is one, or every
/// `isFollowing` / `followsYou` comes back false. The client attaches it
/// automatically whenever a session exists.
class FollowApi {
  const FollowApi(this._client);

  final PlunoApiClient _client;

  /// The largest page `/followers` and `/following` accept; above it is a 400.
  static const maxPageSize = 100;

  /// Someone's public profile with both counts and the relationship either
  /// way. 404 when there is no such user. `/users/me` is not a uuid and is a
  /// 400 — the account's own profile is `auth.me()`.
  Future<PublicUserProfile> profile(String userId) async {
    final body = await _client.get<Map<String, dynamic>>('/users/$userId');
    return PublicUserProfile.fromJson(Json.asMap(body));
  }

  /// Counts plus whether the caller follows [userId]. The way to read the
  /// account's own counts: pass its own id.
  Future<FollowSummary> summary(String userId) async {
    final body = await _client
        .get<Map<String, dynamic>>('/users/$userId/follow-summary');
    return FollowSummary.fromJson(Json.asMap(body));
  }

  /// Follows [userId] and returns **their** new summary. Idempotent. Following
  /// yourself is a 400; an unknown user is a 404.
  Future<FollowSummary> follow(String userId) async {
    final body =
        await _client.post<Map<String, dynamic>>('/users/$userId/follow');
    return FollowSummary.fromJson(Json.asMap(body));
  }

  /// Unfollows [userId] and returns their new summary. Idempotent, and never
  /// a 404 — even for an account that has since been deleted.
  Future<FollowSummary> unfollow(String userId) async {
    final body =
        await _client.delete<Map<String, dynamic>>('/users/$userId/follow');
    return FollowSummary.fromJson(Json.asMap(body));
  }

  /// One page of [userId]'s followers or followings, most recent first.
  ///
  /// [limit] is 1–[maxPageSize]. There is no total: a page shorter than
  /// [limit] is the last one.
  Future<List<FollowUser>> list(
    String userId,
    FollowListKind kind, {
    int limit = 20,
    int offset = 0,
  }) async {
    final body = await _client.get<List<dynamic>>(
      '/users/$userId/${kind.path}',
      query: <String, dynamic>{'limit': limit, 'offset': offset},
    );
    return FollowUser.listFrom(body);
  }

  /// Takes [userId] off the caller's followers and returns the **caller's**
  /// new summary. Not a block — they can follow again. Idempotent: someone
  /// who was not following, or no longer exists, is still a 200.
  Future<FollowSummary> removeFollower(String userId) async {
    final body = await _client
        .delete<Map<String, dynamic>>('/users/me/followers/$userId');
    return FollowSummary.fromJson(Json.asMap(body));
  }
}
