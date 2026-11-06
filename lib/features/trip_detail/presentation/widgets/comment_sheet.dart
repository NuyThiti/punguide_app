import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/action_sheet.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../trips/presentation/providers/trip_comment_providers.dart';

/// The lime on the send button.
const _lime = Color(0xFFC8F04A);

/// "Comment" — the thread under a trip, post or Puntok clip, in a sheet over
/// the page.
///
/// [commentCount] is what the caller is showing now. Every post and delete
/// moves it in [tripCommentCountProvider] at once, so the 💬 behind the sheet
/// — and on any other screen showing the same trip — keeps up without a
/// re-read.
///
/// The design draws a heart and a count on each comment; the API has no
/// comment likes, so they are not drawn.
Future<void> showCommentSheet(
  BuildContext context, {
  required String tripId,
  required String ownerId,
  required int commentCount,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => _CommentSheet(
      tripId: tripId,
      ownerId: ownerId,
      commentCount: commentCount,
    ),
  );
}

/// One top-level comment and the replies opened under it so far.
class _Thread {
  _Thread(this.comment);

  TripComment comment;
  final replies = <TripComment>[];

  /// Whether every reply the server holds is in [replies].
  bool get repliesComplete => replies.length >= comment.replyCount;
  bool loadingReplies = false;
}

class _CommentSheet extends ConsumerStatefulWidget {
  const _CommentSheet({
    required this.tripId,
    required this.ownerId,
    required this.commentCount,
  });

  final String tripId;
  final String ownerId;

  /// The count as the caller showed it when the sheet opened.
  final int commentCount;

  @override
  ConsumerState<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends ConsumerState<_CommentSheet> {
  static const _pageSize = 20;

  final _threads = <_Thread>[];
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _loadError;

  /// The comment the next send answers, or null for a new top-level one.
  TripComment? _replyTo;

  /// The comment the next send rewrites, or null.
  TripComment? _editing;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _input.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<PlunoApi> get _api => ref.read(plunoApiProvider.future);

  /// Moves the trip's comment count everywhere it is shown.
  void _move(int by) {
    final counts = ref.read(tripCommentCountProvider);
    final now = counts[widget.tripId] ?? widget.commentCount;
    ref.read(tripCommentCountProvider.notifier).record(widget.tripId, now + by);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final page = await (await _api).comments.list(
            widget.tripId,
            limit: _pageSize,
          );
      if (!mounted) return;
      setState(() {
        _threads
          ..clear()
          ..addAll(page.items.map(_Thread.new));
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  void _maybeLoadMore() {
    if (!_hasMore || _loadingMore || !_scroll.hasClients) return;
    if (_scroll.position.extentAfter > 300) return;
    _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final page = await (await _api).comments.list(
            widget.tripId,
            limit: _pageSize,
            offset: _threads.length,
          );
      if (!mounted) return;
      final known = {for (final thread in _threads) thread.comment.id};
      setState(() {
        // A comment posted meanwhile shifts the window; skip what we have.
        _threads.addAll(
          page.items.where((c) => !known.contains(c.id)).map(_Thread.new),
        );
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadReplies(_Thread thread) async {
    setState(() => thread.loadingReplies = true);
    try {
      final page = await (await _api).comments.replies(
            widget.tripId,
            thread.comment.id,
            limit: CommentsApi.maxPageSize,
            offset: thread.replies.length,
          );
      if (!mounted) return;
      final known = {for (final reply in thread.replies) reply.id};
      setState(() {
        thread.replies.addAll(page.items.where((r) => !known.contains(r.id)));
        thread.loadingReplies = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => thread.loadingReplies = false);
      _snack('โหลดการตอบกลับไม่สำเร็จ');
    }
  }

  // ── Writing ────────────────────────────────────────────────────────────

  bool _ensureSignedIn() {
    if (ref.read(isSignedInProvider)) return true;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('เข้าสู่ระบบก่อนเพื่อแสดงความคิดเห็น'),
          action: SnackBarAction(
            label: 'เข้าสู่ระบบ',
            onPressed: () => context.goNamed(AppRoute.login.name),
          ),
        ),
      );
    return false;
  }

  void _startReply(TripComment comment) {
    if (!_ensureSignedIn()) return;
    setState(() {
      _editing = null;
      _replyTo = comment;
    });
    _focus.requestFocus();
  }

  void _startEdit(TripComment comment) {
    setState(() {
      _replyTo = null;
      _editing = comment;
      _input.text = comment.body;
    });
    _focus.requestFocus();
  }

  void _cancelTarget() => setState(() {
        if (_editing != null) _input.clear();
        _replyTo = null;
        _editing = null;
      });

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    if (!_ensureSignedIn()) return;
    setState(() => _sending = true);

    try {
      final api = await _api;
      final editing = _editing;
      if (editing != null) {
        final saved =
            await api.comments.edit(widget.tripId, editing.id, body: body);
        if (!mounted) return;
        setState(() => _replace(saved));
      } else {
        final created = await api.comments.create(
          widget.tripId,
          body: _addressed(body),
          parentId: _replyTo?.id,
        );
        if (!mounted) return;
        setState(() {
          _move(1);
          _insert(created);
        });
      }
      setState(() {
        _input.clear();
        _replyTo = null;
        _editing = null;
        _sending = false;
      });
    } on ApiException catch (failure) {
      if (!mounted) return;
      setState(() => _sending = false);
      _snack(switch (failure.statusCode) {
        401 => 'เข้าสู่ระบบก่อนเพื่อแสดงความคิดเห็น',
        429 => 'ส่งถี่เกินไป รอสักครู่แล้วลองใหม่',
        _ when failure.isNetworkFailure => 'เชื่อมต่อไม่ได้ ลองใหม่อีกครั้ง',
        _ => 'ส่งความคิดเห็นไม่สำเร็จ',
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      _snack('ส่งความคิดเห็นไม่สำเร็จ');
    }
  }

  /// Answering a reply files under its top-level comment, flat beside it, so
  /// the text names who it answers — "@mintwalks …" — unless it already does.
  String _addressed(String body) {
    final target = _replyTo;
    final handle = target?.author?.username ?? '';
    if (target?.parentId == null || handle.isEmpty) return body;
    final mention = '@$handle';
    return body.startsWith(mention) ? body : '$mention $body';
  }

  /// A new top-level comment goes first (the list is newest first); a reply
  /// goes last under its thread (replies read oldest first).
  void _insert(TripComment created) {
    final parentId = created.parentId;
    if (parentId == null) {
      _threads.insert(0, _Thread(created));
      return;
    }
    for (final thread in _threads) {
      if (thread.comment.id != parentId) continue;
      // Only shown when the thread is already open in full; otherwise the
      // count moves and "ดูการตอบกลับ" fetches it with the rest.
      final wasComplete = thread.repliesComplete;
      thread.comment =
          thread.comment.copyWith(replyCount: thread.comment.replyCount + 1);
      if (wasComplete) thread.replies.add(created);
      return;
    }
  }

  void _replace(TripComment saved) {
    for (final thread in _threads) {
      if (thread.comment.id == saved.id) {
        thread.comment = saved;
        return;
      }
      final i = thread.replies.indexWhere((r) => r.id == saved.id);
      if (i >= 0) {
        thread.replies[i] = saved;
        return;
      }
    }
  }

  Future<void> _openMenu(TripComment comment) async {
    if (!comment.canEdit && !comment.canDelete) return;
    final action = await showActionSheet<String>(
      context,
      items: [
        if (comment.canEdit)
          const ActionSheetItem(
            value: 'edit',
            icon: Icons.edit_outlined,
            label: 'แก้ไขความคิดเห็น',
          ),
        if (comment.canDelete)
          const ActionSheetItem(
            value: 'delete',
            icon: Icons.delete_outline,
            label: 'ลบความคิดเห็น',
            destructive: true,
          ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        _startEdit(comment);
      case 'delete':
        await _delete(comment);
    }
  }

  Future<void> _delete(TripComment comment) async {
    try {
      await (await _api).comments.delete(widget.tripId, comment.id);
    } catch (_) {
      _snack('ลบความคิดเห็นไม่สำเร็จ');
      return;
    }
    if (!mounted) return;
    setState(() {
      if (comment.parentId == null) {
        // Its replies go with it, counted or not.
        _threads.removeWhere((t) => t.comment.id == comment.id);
        _move(-(1 + comment.replyCount));
      } else {
        for (final thread in _threads) {
          if (thread.comment.id != comment.parentId) continue;
          thread.replies.removeWhere((r) => r.id == comment.id);
          thread.comment = thread.comment.copyWith(
            replyCount: (thread.comment.replyCount - 1).clamp(0, 1 << 30),
          );
        }
        _move(-1);
      }
      if (_editing?.id == comment.id || _replyTo?.id == comment.id) {
        _replyTo = null;
        _editing = null;
        _input.clear();
      }
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Layout ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.82;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: AppColors.screen,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: height,
          child: Column(
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
              const SizedBox(height: 16),
              const Text(
                'Comment',
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(child: _body()),
              _composer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'โหลดความคิดเห็นไม่สำเร็จ',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _load, child: const Text('ลองอีกครั้ง')),
          ],
        ),
      );
    }
    if (_threads.isEmpty) {
      return const Center(
        child: Text(
          'ยังไม่มีความคิดเห็น เป็นคนแรกเลย',
          style: TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      itemCount: _threads.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.line),
      itemBuilder: (context, index) {
        if (index == _threads.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _thread(_threads[index]);
      },
    );
  }

  Widget _thread(_Thread thread) {
    final hidden = thread.comment.replyCount - thread.replies.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentRow(
            comment: thread.comment,
            ownerId: widget.ownerId,
            onReply: () => _startReply(thread.comment),
            onMenu: () => _openMenu(thread.comment),
          ),
          if (thread.replies.isNotEmpty || hidden > 0)
            Padding(
              padding: const EdgeInsets.only(left: 46),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final reply in thread.replies)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _CommentRow(
                        comment: reply,
                        ownerId: widget.ownerId,
                        reply: true,
                        // Answering a reply files under the same thread.
                        onReply: () => _startReply(reply),
                        onMenu: () => _openMenu(reply),
                      ),
                    ),
                  if (hidden > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: thread.loadingReplies
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : GestureDetector(
                              onTap: () => _loadReplies(thread),
                              behavior: HitTestBehavior.opaque,
                              child: Text(
                                'ดูการตอบกลับ $hidden รายการ',
                                style: const TextStyle(
                                  color: AppColors.postPurple,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final target = _editing ?? _replyTo;
    final canSend = _input.text.trim().isNotEmpty && !_sending;

    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        10,
        18,
        12 +
            (MediaQuery.viewInsetsOf(context).bottom > 0
                ? 0
                : MediaQuery.paddingOf(context).bottom),
      ),
      decoration: const BoxDecoration(
        color: AppColors.screen,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (target != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _editing != null
                          ? 'กำลังแก้ไขความคิดเห็น'
                          : 'ตอบกลับ @${target.author?.label ?? 'ผู้ใช้ที่ถูกลบ'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelTarget,
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textInputAction: TextInputAction.newline,
                  onTap: _ensureSignedIn,
                  decoration: InputDecoration(
                    hintText: 'เพิ่มความคิดเห็น...',
                    hintStyle: const TextStyle(color: AppColors.muted),
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(color: AppColors.postPurple),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'ส่ง',
                child: Material(
                  color: canSend ? AppColors.foreground : AppColors.line,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: canSend ? _send : null,
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(15),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _lime,
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              size: 22,
                              color: canSend ? _lime : AppColors.muted,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One comment: avatar, name and age, the text, then ตอบกลับ.
///
/// The trip's owner is marked "เจ้าของทริป" in purple. A long press opens
/// แก้ไข / ลบ when the comment allows either.
class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.ownerId,
    required this.onReply,
    required this.onMenu,
    this.reply = false,
  });

  final TripComment comment;
  final String ownerId;
  final VoidCallback onReply;
  final VoidCallback onMenu;
  final bool reply;

  @override
  Widget build(BuildContext context) {
    final author = comment.author;
    final isOwner = author != null && author.id == ownerId;
    final name = author?.label ?? 'ผู้ใช้ที่ถูกลบ';
    final avatar = author?.avatarUrl;
    final size = reply ? 24.0 : 34.0;

    return GestureDetector(
      onLongPress: onMenu,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.foreground,
            ),
            child: avatar == null || avatar.isEmpty
                ? null
                : CoverImage(source: avatar, fit: BoxFit.cover),
          ),
          SizedBox(width: reply ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: name,
                        style: TextStyle(
                          color: isOwner
                              ? AppColors.postPurple
                              : AppColors.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isOwner)
                        const TextSpan(
                          text: ' · เจ้าของทริป',
                          style: TextStyle(
                            color: AppColors.postPurple,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      TextSpan(
                        text: '  ${commentAge(comment.createdAt)}'
                            '${comment.editedAt != null ? ' (แก้ไขแล้ว)' : ''}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  comment.body,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onReply,
                  behavior: HitTestBehavior.opaque,
                  child: const Text(
                    'ตอบกลับ',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (comment.canEdit || comment.canDelete)
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                tooltip: 'ตัวเลือกความคิดเห็น',
                padding: EdgeInsets.zero,
                iconSize: 18,
                onPressed: onMenu,
                icon: const Icon(Icons.more_horiz, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// "5 ชม." — how long ago, the way the design prints it.
String commentAge(DateTime createdAt, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(createdAt.toLocal());
  if (elapsed.inMinutes < 1) return 'เมื่อสักครู่';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes} นาที';
  if (elapsed.inDays < 1) return '${elapsed.inHours} ชม.';
  if (elapsed.inDays < 7) return '${elapsed.inDays} วัน';
  if (elapsed.inDays < 35) return '${elapsed.inDays ~/ 7} สัปดาห์';
  const months = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', //
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];
  final local = createdAt.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year + 543}';
}
