import 'package:flutter/foundation.dart';

import '../../../core/api/pluno_api.dart';

/// Something the viewer can report, and whose it is.
///
/// [ownerId] is who a follow-up block would block — the trip's `ownerId` /
/// `creator.id`, the comment's `author.id`, the post's owner for a photo, the
/// account itself for a user. [ownerLabel] is how the menu names them:
/// `@username` when the payload has one, the display name when it does not
/// (feed cards carry only `creator.name`).
@immutable
class ReportSubject {
  const ReportSubject({
    required this.type,
    required this.id,
    this.ownerId,
    this.ownerLabel,
    this.isClip = false,
  });

  final ReportTargetType type;
  final String id;
  final String? ownerId;
  final String? ownerLabel;

  /// A Puntok trip — "คลิป" rather than "โพสต์" in the wording.
  final bool isClip;

  String get key => '${type.wire}:$id';

  /// The word that goes into "ทำไมคุณถึงรายงาน…นี้?".
  String get noun => switch (type) {
        ReportTargetType.trip => isClip ? 'คลิป' : 'โพสต์',
        ReportTargetType.media => 'รูปภาพ/วิดีโอ',
        ReportTargetType.comment => 'ความคิดเห็น',
        ReportTargetType.user => 'ผู้ใช้',
      };

  /// The menu row that opens the sheet.
  String get menuLabel => switch (type) {
        ReportTargetType.trip => isClip ? 'รายงานคลิป' : 'รายงานโพสต์',
        ReportTargetType.media => 'รายงานรูปภาพ/วิดีโอนี้',
        ReportTargetType.comment => 'รายงานความคิดเห็น',
        ReportTargetType.user => 'รายงานผู้ใช้',
      };

  /// What the block rows and dialogs call the owner.
  String get ownerName {
    final label = ownerLabel?.trim() ?? '';
    return label.isEmpty ? 'ผู้ใช้นี้' : label;
  }
}

/// `@maki` from a username, or the display name when there is no username.
String userHandle({String? username, String? name}) {
  final handle = username?.trim() ?? '';
  if (handle.isNotEmpty) return '@$handle';
  final display = name?.trim() ?? '';
  return display;
}
