import 'package:flutter/foundation.dart';

import 'json.dart';

/// What a report points at — `targetType` on `POST /reports`.
enum ReportTargetType {
  /// A PunGuide post, a Puntok clip or a plan — every trip type.
  trip('trip'),

  /// One picture or video inside a post.
  media('media'),

  /// A comment or a reply.
  comment('comment'),

  /// An account: its name, its picture, how it behaves.
  user('user');

  const ReportTargetType(this.wire);
  final String wire;
}

/// Why something is reported — `reason` on `POST /reports`.
///
/// Declared in the order the reason sheet lists them.
enum ReportReason {
  spam('spam', 'สแปม / โฆษณาขายของ'),
  nuditySexual('nudity_sexual', 'ภาพโป๊เปลือย หรือเนื้อหาทางเพศ'),
  harassment('harassment', 'กลั่นแกล้ง / คุกคาม'),
  hateSpeech('hate_speech', 'ถ้อยคำแสดงความเกลียดชัง'),
  violence('violence', 'ความรุนแรง หรือเนื้อหาน่ากลัว'),
  selfHarm('self_harm', 'การทำร้ายตัวเอง'),
  illegal('illegal', 'สิ่งผิดกฎหมาย'),
  scamFraud('scam_fraud', 'หลอกลวง / มิจฉาชีพ'),

  /// Offered only when the target is a user.
  impersonation('impersonation', 'แอบอ้างเป็นบุคคลอื่น'),
  intellectualProperty('intellectual_property', 'ละเมิดลิขสิทธิ์'),
  misleading('misleading', 'ข้อมูลเท็จ / ทำให้เข้าใจผิด'),
  other('other', 'อื่นๆ');

  const ReportReason(this.wire, this.label);
  final String wire;
  final String label;

  /// The reasons that make sense for [target], in sheet order.
  static List<ReportReason> offeredFor(ReportTargetType target) => [
        for (final reason in values)
          if (reason != impersonation || target == ReportTargetType.user)
            reason,
      ];
}

/// What `POST /reports` answers with (201).
///
/// A repeat report of the same thing is still a 201 — the original report
/// comes back with [alreadyReported] true, and the app treats both the same.
@immutable
class ReportReceipt {
  const ReportReceipt({
    required this.id,
    required this.alreadyReported,
    this.status,
  });

  factory ReportReceipt.fromJson(Map<String, dynamic> json) => ReportReceipt(
        id: Json.string(json, 'id') ?? '',
        status: Json.string(json, 'status'),
        alreadyReported: Json.boolean(json, 'alreadyReported'),
      );

  final String id;

  /// `open` until the moderation team rules on it.
  final String? status;
  final bool alreadyReported;
}

/// One row of `GET /users/me/blocks`.
@immutable
class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.username,
    this.name,
    this.avatarUrl,
    this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
        id: Json.requiredString(json, 'id'),
        username: Json.string(json, 'username') ?? '',
        name: Json.string(json, 'name'),
        avatarUrl: Json.string(json, 'avatarUrl'),
        blockedAt: Json.timestamp(json, 'blockedAt'),
      );

  final String id;
  final String username;
  final String? name;
  final String? avatarUrl;
  final DateTime? blockedAt;

  String get displayName => name?.isNotEmpty == true ? name! : username;
}

/// A page of the blocked list. Unlike the follow lists this one reports a
/// [total], so the end is `offset + items.length >= total`.
@immutable
class BlockedUserPage {
  const BlockedUserPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory BlockedUserPage.fromJson(Map<String, dynamic> json) {
    final items = Json.asMapList(json['items'])
        .map(BlockedUser.fromJson)
        .toList(growable: false);
    return BlockedUserPage(
      items: items,
      total: Json.integer(json, 'total') ?? items.length,
      limit: Json.integer(json, 'limit') ?? items.length,
      offset: Json.integer(json, 'offset') ?? 0,
    );
  }

  final List<BlockedUser> items;
  final int total;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < total;
}
