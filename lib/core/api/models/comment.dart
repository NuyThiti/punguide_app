import 'package:flutter/foundation.dart';

import 'json.dart';

/// Who wrote a comment. Null on [TripComment.author] when the account is gone.
@immutable
class CommentAuthor {
  const CommentAuthor({
    required this.id,
    required this.username,
    this.name,
    this.avatarUrl,
  });

  factory CommentAuthor.fromJson(Map<String, dynamic> json) => CommentAuthor(
        id: Json.requiredString(json, 'id'),
        username: Json.string(json, 'username') ?? '',
        name: Json.string(json, 'name'),
        avatarUrl: Json.string(json, 'avatarUrl'),
      );

  static CommentAuthor? maybeFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    if (json.isEmpty) return null;
    return CommentAuthor.fromJson(json);
  }

  final String id;
  final String username;
  final String? name;
  final String? avatarUrl;

  /// The handle the design prints, falling back to the display name.
  String get label => username.isNotEmpty ? username : (name ?? '');
}

/// One comment under a trip or post — a top-level one, or a reply to one.
///
/// Threads are one level deep: a reply's [parentId] is always a top-level
/// comment, and its own [replyCount] is 0.
@immutable
class TripComment {
  const TripComment({
    required this.id,
    required this.tripId,
    required this.body,
    required this.createdAt,
    this.parentId,
    this.author,
    this.replyCount = 0,
    this.editedAt,
    this.isMine = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  factory TripComment.fromJson(Map<String, dynamic> json) => TripComment(
        id: Json.requiredString(json, 'id'),
        tripId: Json.string(json, 'tripId') ?? '',
        parentId: Json.string(json, 'parentId'),
        body: Json.string(json, 'body') ?? '',
        author: CommentAuthor.maybeFromJson(json['author']),
        replyCount: Json.integer(json, 'replyCount') ?? 0,
        createdAt: Json.timestamp(json, 'createdAt') ?? DateTime.now(),
        editedAt: Json.timestamp(json, 'editedAt'),
        isMine: Json.boolean(json, 'isMine'),
        canEdit: Json.boolean(json, 'canEdit'),
        canDelete: Json.boolean(json, 'canDelete'),
      );

  final String id;
  final String tripId;

  /// Null on a top-level comment.
  final String? parentId;
  final String body;

  /// Null when the writer deleted their account — shown as "ผู้ใช้ที่ถูกลบ".
  final CommentAuthor? author;
  final int replyCount;
  final DateTime createdAt;

  /// Null when never edited; otherwise "(แก้ไขแล้ว)".
  final DateTime? editedAt;
  final bool isMine;
  final bool canEdit;

  /// The writer's own comment, or any comment under the viewer's own trip.
  final bool canDelete;

  TripComment copyWith({String? body, int? replyCount, DateTime? editedAt}) =>
      TripComment(
        id: id,
        tripId: tripId,
        parentId: parentId,
        body: body ?? this.body,
        author: author,
        replyCount: replyCount ?? this.replyCount,
        createdAt: createdAt,
        editedAt: editedAt ?? this.editedAt,
        isMine: isMine,
        canEdit: canEdit,
        canDelete: canDelete,
      );
}

/// A page of [TripComment]s — `GET /comments` (newest first) or `/replies`
/// (oldest first).
@immutable
class CommentPage {
  const CommentPage({
    required this.items,
    required this.total,
    required this.hasMore,
  });

  factory CommentPage.fromJson(Map<String, dynamic> json) => CommentPage(
        items: Json.asMapList(json['items'])
            .map(TripComment.fromJson)
            .toList(growable: false),
        total: Json.integer(json, 'total') ?? 0,
        hasMore: Json.boolean(json, 'hasMore'),
      );

  final List<TripComment> items;
  final int total;
  final bool hasMore;
}
