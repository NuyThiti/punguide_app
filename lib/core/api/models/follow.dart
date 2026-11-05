import 'package:flutter/foundation.dart';

import 'json.dart';

/// Follower / following counts for one account, plus whether the caller
/// follows it.
///
/// What follow, unfollow and remove-follower answer with — always the summary
/// of the account the counts belong to: the followee for follow / unfollow,
/// the caller themself for remove-follower.
@immutable
class FollowSummary {
  const FollowSummary({
    required this.followerCount,
    required this.followingCount,
    required this.isFollowing,
  });

  factory FollowSummary.fromJson(Map<String, dynamic> json) => FollowSummary(
        followerCount: Json.integer(json, 'followerCount') ?? 0,
        followingCount: Json.integer(json, 'followingCount') ?? 0,
        isFollowing: Json.boolean(json, 'isFollowing'),
      );

  final int followerCount;
  final int followingCount;

  /// Always false for an anonymous caller.
  final bool isFollowing;
}

/// Someone else's public profile, from `GET /users/:userId`.
///
/// Never carries an email — the endpoint is readable by anyone. The account's
/// own profile still comes from `GET /auth/me`.
@immutable
class PublicUserProfile {
  const PublicUserProfile({
    required this.id,
    required this.username,
    required this.followerCount,
    required this.followingCount,
    required this.isFollowing,
    required this.followsYou,
    required this.isMe,
    this.name,
    this.avatarUrl,
  });

  factory PublicUserProfile.fromJson(Map<String, dynamic> json) =>
      PublicUserProfile(
        id: Json.requiredString(json, 'id'),
        username: Json.requiredString(json, 'username'),
        name: Json.string(json, 'name'),
        avatarUrl: Json.string(json, 'avatarUrl'),
        followerCount: Json.integer(json, 'followerCount') ?? 0,
        followingCount: Json.integer(json, 'followingCount') ?? 0,
        isFollowing: Json.boolean(json, 'isFollowing'),
        followsYou: Json.boolean(json, 'followsYou'),
        isMe: Json.boolean(json, 'isMe'),
      );

  final String id;
  final String username;
  final String? name;
  final String? avatarUrl;
  final int followerCount;
  final int followingCount;

  /// The caller follows this account. False when signed out.
  final bool isFollowing;

  /// This account follows the caller — the "ติดตามคุณ" badge, and the reason
  /// the button reads "ติดตามกลับ" while [isFollowing] is false.
  final bool followsYou;

  /// The caller is looking at their own profile: no follow button.
  final bool isMe;

  String get displayName => name?.isNotEmpty == true ? name! : username;
}

/// One row of a followers / following list.
@immutable
class FollowUser {
  const FollowUser({
    required this.id,
    required this.username,
    required this.isFollowing,
    this.name,
    this.avatarUrl,
  });

  factory FollowUser.fromJson(Map<String, dynamic> json) => FollowUser(
        id: Json.requiredString(json, 'id'),
        username: Json.requiredString(json, 'username'),
        name: Json.string(json, 'name'),
        avatarUrl: Json.string(json, 'avatarUrl'),
        isFollowing: Json.boolean(json, 'isFollowing'),
      );

  static List<FollowUser> listFrom(Object? value) =>
      Json.asMapList(value).map(FollowUser.fromJson).toList(growable: false);

  final String id;
  final String username;
  final String? name;
  final String? avatarUrl;

  /// Whether **the caller** follows this row — not the list's owner. On your
  /// own followers list, false means you have not followed them back. Always
  /// false on the caller's own row.
  final bool isFollowing;

  String get displayName => name?.isNotEmpty == true ? name! : username;
}
