import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/report_subject.dart';

/// The red the report and block rows wear. [AppColors] has no danger colour;
/// this is the one the action sheet already uses for ลบ.
const safetyRed = AppColors.brandOrangeDeep;

/// How the report sheet closed.
enum ReportSheetOutcome {
  /// Never sent: dismissed before ส่งรายงาน landed.
  cancelled,

  /// Filed (new or repeat), then closed with เสร็จสิ้น or a swipe.
  sent,

  /// Filed, then บล็อก on the thank-you page.
  sentThenBlock,

  /// 401 — the token is gone; the caller sends them to sign in.
  signInNeeded,

  /// 404 — the thing is gone or no longer visible to the reporter.
  notFound,

  /// 429 — over the hourly allowance.
  rateLimited,

  /// 400 — their own content. Should not happen: the menu hides it.
  ownContent,
}

/// Opens "ทำไมคุณถึงรายงาน…?" for [subject] and files the report from inside
/// the sheet. The sheet turns into the thank-you page once it lands.
///
/// [blockLabel] is the "บล็อก @maki" button on that page; null leaves it off
/// (a user already blocked, or a subject with no owner to block).
Future<ReportSheetOutcome> showReportSheet(
  BuildContext context, {
  required ReportSubject subject,
  String? blockLabel,
}) async {
  final outcome = await showModalBottomSheet<ReportSheetOutcome>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => _ReportSheet(subject: subject, blockLabel: blockLabel),
  );
  return outcome ??
      _lastSent.remove(subject.key) ??
      ReportSheetOutcome.cancelled;
}

/// A sheet swiped away from its thank-you page pops with null, yet the report
/// was filed — so the sheet notes it here and [showReportSheet] reads it back.
final _lastSent = <String, ReportSheetOutcome>{};

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.subject, required this.blockLabel});

  final ReportSubject subject;
  final String? blockLabel;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final _note = TextEditingController();
  final _noteFocus = FocusNode();

  ReportReason? _reason;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _pick(ReportReason reason) {
    setState(() {
      _reason = reason;
      _error = null;
    });
    // "อื่นๆ" says nothing on its own; open the box so the team gets a line.
    if (reason == ReportReason.other) _noteFocus.requestFocus();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final api = await ref.read(plunoApiProvider.future);
      // A repeat comes back 201 with alreadyReported — the same page either way.
      await api.safety.report(
        targetType: widget.subject.type,
        targetId: widget.subject.id,
        reason: reason,
        note: _note.text,
      );
      if (!mounted) return;
      _lastSent[widget.subject.key] = ReportSheetOutcome.sent;
      setState(() {
        _sending = false;
        _sent = true;
      });
    } on ApiException catch (failure) {
      if (!mounted) return;
      final close = switch (failure.statusCode) {
        401 => ReportSheetOutcome.signInNeeded,
        404 => ReportSheetOutcome.notFound,
        429 => ReportSheetOutcome.rateLimited,
        400 => ReportSheetOutcome.ownContent,
        _ => null,
      };
      if (close != null) {
        Navigator.of(context).pop(close);
        return;
      }
      _failed();
    } catch (_) {
      if (mounted) _failed();
    }
  }

  void _failed() => setState(() {
        _sending = false;
        _error = 'ส่งรายงานไม่สำเร็จ ลองอีกครั้ง';
      });

  void _finish(ReportSheetOutcome outcome) {
    _lastSent.remove(widget.subject.key);
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
        child: Material(
          color: AppColors.screen,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D6D1),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Flexible(child: _sent ? _thanks(media) : _form(media)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(MediaQueryData media) {
    final reasons = ReportReason.offeredFor(widget.subject.type);
    final picked = _reason;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
          child: Text(
            'ทำไมคุณถึงรายงาน${widget.subject.noun}นี้?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 10),
          child: Text(
            'รายงานของคุณจะไม่ถูกเปิดเผยให้เจ้าของเนื้อหาทราบ',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final reason in reasons)
                _ReasonRow(
                  reason: reason,
                  selected: picked == reason,
                  onTap: _sending ? null : () => _pick(reason),
                ),
              if (picked != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                  child: TextField(
                    key: const Key('report-note'),
                    controller: _note,
                    focusNode: _noteFocus,
                    enabled: !_sending,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: SafetyApi.maxNoteLength,
                    decoration: InputDecoration(
                      hintText: 'รายละเอียดเพิ่มเติม (ไม่บังคับ)',
                      filled: true,
                      fillColor: AppColors.postField,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: safetyRed, fontSize: 13),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + media.padding.bottom),
          child: FilledButton(
            key: const Key('report-send'),
            onPressed: picked == null || _sending ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: safetyRed,
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'ส่งรายงาน',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _thanks(MediaQueryData media) {
    final blockLabel = widget.blockLabel;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 16 + media.padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 52,
            color: AppColors.postPurple,
          ),
          const SizedBox(height: 14),
          const Text(
            'ขอบคุณที่แจ้งให้เราทราบ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.foreground,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ทีมงานจะตรวจสอบรายงานของคุณโดยเร็วที่สุด',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 22),
          if (blockLabel != null) ...[
            OutlinedButton.icon(
              key: const Key('report-thanks-block'),
              onPressed: () => _finish(ReportSheetOutcome.sentThenBlock),
              icon: const Icon(Icons.block, size: 18),
              label: Text('บล็อก $blockLabel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: safetyRed,
                side: const BorderSide(color: safetyRed),
                minimumSize: const Size.fromHeight(46),
                shape: const StadiumBorder(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton(
            key: const Key('report-thanks-done'),
            onPressed: () => _finish(ReportSheetOutcome.sent),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.foreground,
              minimumSize: const Size.fromHeight(46),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'เสร็จสิ้น',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final ReportReason reason;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                reason.label,
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 22,
              color: selected ? safetyRed : AppColors.navIconMuted,
            ),
          ],
        ),
      ),
    );
  }
}
