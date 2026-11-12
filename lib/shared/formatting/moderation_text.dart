import '../../core/api/models/enums.dart';
import '../../core/api/models/trip.dart';

/// The copy for one [Moderation.reasonCode] — stable across the three stages
/// that can produce it (rules, AI safety, AI travel relevance), so this never
/// needs to know which one actually decided.
///
/// Two codes genuinely land under either [ModerationStatus.reviewRequired]
/// or [ModerationStatus.rejected] depending on severity (`DUPLICATE_CONTENT`,
/// `POSTING_TOO_FREQUENTLY`) — their copy holds for both, which is why this
/// keys on the code alone and never also switches on [Moderation.status].
const Map<String, String> _reasonCodeText = {
  'UNDER_REVIEW': 'กำลังตรวจสอบโพสต์ของคุณ',
  'APPROVED': 'เผยแพร่แล้ว',
  'LEGACY_CONTENT': 'เผยแพร่แล้ว',
  'MODERATOR_APPROVED': 'เผยแพร่แล้ว',
  'TRAVEL_RELEVANCE_UNCERTAIN': 'ทีมงานขอตรวจสอบโพสต์นี้ก่อนเผยแพร่',
  'IMAGE_ANALYSIS_INCONCLUSIVE': 'ทีมงานขอตรวจสอบโพสต์นี้ก่อนเผยแพร่',
  'PROMOTIONAL_CONTENT': 'ทีมงานขอตรวจสอบโพสต์นี้ก่อนเผยแพร่',
  'SAFETY_REVIEW_REQUIRED': 'ทีมงานขอตรวจสอบโพสต์นี้ก่อนเผยแพร่',
  'SUSPICIOUS_LINKS': 'โพสต์มีลิงก์ที่ต้องตรวจสอบก่อนเผยแพร่',
  'SPAM_REPEATED_TEXT': 'ข้อความดูซ้ำกันหลายครั้ง ทีมงานขอตรวจสอบก่อน',
  'DUPLICATE_CONTENT': 'โพสต์นี้คล้ายกับที่คุณเคยแชร์แล้ว',
  'POSTING_TOO_FREQUENTLY': 'คุณแชร์ถี่เกินไป ทีมงานขอตรวจสอบก่อน',
  'MODERATION_UNAVAILABLE': 'ทีมงานขอตรวจสอบโพสต์นี้ก่อนเผยแพร่',
  'APPEAL_SUBMITTED': 'ได้รับคำอุทธรณ์แล้ว กำลังตรวจสอบ',
  'EMPTY_CONTENT': 'เพิ่มรูป สถานที่ หรือข้อความก่อนแชร์',
  'NOT_TRAVEL_RELATED':
      'PunGuide เป็นพื้นที่แชร์ประสบการณ์ท่องเที่ยว โพสต์นี้ดูไม่เกี่ยวกับการท่องเที่ยว',
  'UNSAFE_CONTENT': 'โพสต์นี้ขัดกับแนวทางของชุมชน',
  'SPAM_PATTERN': 'โพสต์นี้ดูเป็นสแปม ไม่สามารถเผยแพร่ได้',
  'MODERATOR_REJECTED': 'ทีมงานตรวจสอบแล้ว ไม่สามารถเผยแพร่โพสต์นี้ได้',
};

/// Copy for a [status] this build does not recognise a [reasonCode] under —
/// a new code the server started sending falls back here rather than onto
/// a blank line.
String _fallbackFor(ModerationStatus status) => switch (status) {
      ModerationStatus.pending => 'กำลังตรวจสอบ',
      ModerationStatus.reviewRequired => 'รอทีมงานตรวจสอบ',
      ModerationStatus.rejected => 'ไม่สามารถเผยแพร่ได้',
      ModerationStatus.approved => 'เผยแพร่แล้ว',
    };

/// What to show the owner for [moderation] — [Moderation.reasonCode]
/// translated to Thai, [Moderation.message] (the server's own English
/// fallback) never shown directly to the traveller, and a [status]-based
/// fallback for a code this build has never seen.
String moderationMessage(Moderation moderation) {
  final code = moderation.reasonCode;
  if (code != null && _reasonCodeText.containsKey(code)) {
    return _reasonCodeText[code]!;
  }
  return _fallbackFor(moderation.status);
}
