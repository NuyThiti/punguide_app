import 'package:flutter/material.dart';

import '../../core/api/models/enums.dart';
import '../../core/api/models/trip.dart';
import '../../core/theme/app_colors.dart';
import '../formatting/moderation_text.dart';

/// The three colours one moderation state is drawn in.
///
/// There is no danger or warning colour in [AppColors] yet, so they live here
/// — one place, so the card badge and the page notice can never drift apart.
@immutable
class _Tone {
  const _Tone(this.ink, this.well, this.line);

  final Color ink;
  final Color well;
  final Color line;

  static const _amber = _Tone(
    Color(0xFFB54708),
    Color(0xFFFFFAEB),
    Color(0xFFFEDF89),
  );
  static const _red = _Tone(
    Color(0xFFB42318),
    Color(0xFFFEF3F2),
    Color(0xFFFBD5D2),
  );
  static const _green = _Tone(
    Color(0xFF027A48),
    Color(0xFFECFDF3),
    Color(0xFFABEFC6),
  );

  static _Tone of(ModerationStatus status) => switch (status) {
        ModerationStatus.pending => _amber,
        ModerationStatus.reviewRequired => _amber,
        ModerationStatus.rejected => _red,
        ModerationStatus.approved => _green,
      };
}

IconData _iconFor(ModerationStatus status) => switch (status) {
      ModerationStatus.pending => Icons.hourglass_top_rounded,
      ModerationStatus.reviewRequired => Icons.visibility_outlined,
      ModerationStatus.rejected => Icons.report_gmailerrorred_rounded,
      ModerationStatus.approved => Icons.check_circle_outline_rounded,
    };

/// Whether [moderation] is worth saying anything about at all.
///
/// Approved is the ordinary case and says nothing; a post that was never
/// shared carries no `moderation` in the first place.
bool isModerationWorthShowing(Moderation? moderation) =>
    moderation != null && moderation.status != ModerationStatus.approved;

/// The small pill a card wears on the owner's own walls.
///
/// Only `GET /trips/mine` sends `moderation`, and only to the owner, so a
/// wall built from any other list simply never has one to draw.
class ModerationBadge extends StatelessWidget {
  const ModerationBadge({super.key, required this.status});

  final ModerationStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = _Tone.of(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.well,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(status), size: 11, color: tone.ink),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              moderationHeadline(status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tone.ink,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the owner sees on their own post while the content check has not
/// approved it: the verdict, the real reason, a reminder that nobody else can
/// see it yet, and — only where they help — a way to edit or to appeal.
class ModerationNotice extends StatelessWidget {
  const ModerationNotice({
    super.key,
    required this.moderation,
    this.onEdit,
    this.onAppeal,
    this.appealing = false,
  });

  final Moderation moderation;

  /// Takes the owner to the post's own editor. Editing and re-sharing is the
  /// way back from a refusal; appealing is for when nothing is wrong with it.
  final VoidCallback? onEdit;

  /// Null when the post may not be appealed — already appealed, or appeals
  /// are closed for it. The button is then absent rather than inert.
  final VoidCallback? onAppeal;

  final bool appealing;

  @override
  Widget build(BuildContext context) {
    final status = moderation.status;
    final tone = _Tone.of(status);
    final actions = <Widget>[
      if (onEdit != null)
        _NoticeButton(tone: tone, label: 'แก้ไขโพสต์', onTap: onEdit),
      if (onAppeal != null)
        _NoticeButton(
          tone: tone,
          label: 'ขออุทธรณ์',
          busy: appealing,
          onTap: onAppeal,
        ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: tone.well,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconFor(status), size: 20, color: tone.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moderationHeadline(status),
                      style: TextStyle(
                        color: tone.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // The reason behind the verdict, translated from
                      // `reasonCode`; the server's own English `message` is
                      // never put in front of the traveller.
                      moderationMessage(moderation),
                      style: const TextStyle(
                        color: AppColors.foreground,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status == ModerationStatus.rejected
                          ? 'โพสต์นี้ยังไม่ถูกเผยแพร่ ตอนนี้มีเพียงคุณที่เห็น'
                          : 'ระหว่างนี้มีเพียงคุณที่เห็นโพสต์นี้',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

class _NoticeButton extends StatelessWidget {
  const _NoticeButton({
    required this.tone,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final _Tone tone;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: busy ? null : onTap,
      style: TextButton.styleFrom(
        foregroundColor: tone.ink,
        backgroundColor: AppColors.screen,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: tone.line),
        ),
      ),
      child: busy
          ? SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(tone.ink),
              ),
            )
          : Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
