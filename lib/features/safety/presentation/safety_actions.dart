import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/feed_rows.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../follow/presentation/providers/follow_providers.dart';
import '../../home/presentation/providers/home_feed_providers.dart';
import '../../paigun/presentation/providers/paigun_providers.dart';
import '../../puntok/domain/models/puntok_post.dart';
import '../../puntok/presentation/providers/puntok_providers.dart';
import '../domain/report_subject.dart';
import 'providers/safety_providers.dart';
import 'widgets/report_sheet.dart';

export '../domain/report_subject.dart';

/// What a report or block did, so the screen can follow up — close a page
/// whose subject is now hidden, say.
enum SafetyResult {
  /// Nothing changed: cancelled, refused, or failed (already said so).
  none,

  /// Reported; the subject is now hidden on this device.
  reported,

  /// The owner is blocked (possibly after a report).
  blocked,

  /// The subject answered 404 and has been dropped from every list.
  gone,
}

/// The two rows a ⋯ menu gains.
enum SafetyAction { report, block }

/// Whether [userId] is the signed-in viewer. Report and block are never
/// offered on the viewer's own things — the server would 400 anyway.
bool isViewer(WidgetRef ref, String? userId) {
  if (userId == null) return false;
  // The session carries the id since the follow work; `/auth/me` covers a
  // session restored before it did.
  final me = ref.read(authSessionProvider)?.userId ??
      ref.read(currentUserProvider).valueOrNull?.id;
  return me == userId;
}

/// รายงาน… and บล็อก… for [subject], red, or nothing at all when it is the
/// viewer's own. A signed-out viewer still sees them; tapping asks for a
/// sign-in.
List<ActionSheetItem<SafetyAction>> safetyMenuItems(
  WidgetRef ref,
  ReportSubject subject,
) {
  if (isViewer(ref, subject.ownerId)) return const [];
  final ownerId = subject.ownerId;
  final canBlock =
      ownerId != null && !ref.read(contentFilterProvider).isBlocked(ownerId);
  return [
    ActionSheetItem(
      value: SafetyAction.report,
      icon: Icons.report_gmailerrorred_outlined,
      label: subject.menuLabel,
      destructive: true,
    ),
    if (canBlock)
      ActionSheetItem(
        value: SafetyAction.block,
        icon: Icons.block,
        label: 'บล็อก ${subject.ownerName}',
        destructive: true,
      ),
  ];
}

/// Carries out a row from [safetyMenuItems].
Future<SafetyResult> runSafetyAction(
  BuildContext context,
  WidgetRef ref,
  ReportSubject subject,
  SafetyAction action,
) {
  switch (action) {
    case SafetyAction.report:
      return reportContent(context, ref, subject);
    case SafetyAction.block:
      final ownerId = subject.ownerId;
      if (ownerId == null) return Future.value(SafetyResult.none);
      return blockUser(context, ref, userId: ownerId, label: subject.ownerName)
          .then((done) => done ? SafetyResult.blocked : SafetyResult.none);
  }
}

/// The ⋯ menu for something that carries nothing but report and block — a
/// feed card, a clip, a photo. Opens nothing for the viewer's own.
Future<SafetyResult> showSafetyMenu(
  BuildContext context,
  WidgetRef ref,
  ReportSubject subject,
) async {
  final items = safetyMenuItems(ref, subject);
  if (items.isEmpty) return SafetyResult.none;
  final action = await showActionSheet<SafetyAction>(
    context,
    items: items,
    cancelLabel: 'ยกเลิก',
  );
  if (action == null || !context.mounted) return SafetyResult.none;
  return runSafetyAction(context, ref, subject, action);
}

/// Sends a guest to sign in, bringing them back to this page after. True
/// when there is already a session.
bool ensureSignedIn(BuildContext context, WidgetRef ref) {
  if (ref.read(isSignedInProvider)) return true;
  _goSignIn(context);
  return false;
}

void _goSignIn(BuildContext context) {
  final router = GoRouter.of(context);
  router.pushNamed(
    AppRoute.login.name,
    queryParams: {'then': router.location},
  );
}

/// รายงาน → reasons → ส่งรายงาน → thank-you → optionally บล็อก.
///
/// On success the subject is hidden on this device at once and remembered,
/// because the server keeps it in everyone's feed — the reporter's included —
/// until enough people have reported it.
Future<SafetyResult> reportContent(
  BuildContext context,
  WidgetRef ref,
  ReportSubject subject,
) async {
  if (!ensureSignedIn(context, ref)) return SafetyResult.none;

  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final root = Navigator.of(context, rootNavigator: true).context;
  final filter = container.read(contentFilterProvider);
  final ownerId = subject.ownerId;
  final canBlock =
      ownerId != null && !isViewer(ref, ownerId) && !filter.isBlocked(ownerId);

  final outcome = await showReportSheet(
    context,
    subject: subject,
    blockLabel: canBlock ? subject.ownerName : null,
  );

  void say(String message) => messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));

  void hide() => container
      .read(contentFilterProvider.notifier)
      .markReported(subject.type, subject.id);

  switch (outcome) {
    case ReportSheetOutcome.cancelled:
      return SafetyResult.none;
    case ReportSheetOutcome.signInNeeded:
      if (root.mounted) _goSignIn(root);
      return SafetyResult.none;
    case ReportSheetOutcome.notFound:
      say('ไม่พบเนื้อหานี้แล้ว');
      if (subject.type != ReportTargetType.user) {
        container
            .read(contentFilterProvider.notifier)
            .markGone(subject.type, subject.id);
        return SafetyResult.gone;
      }
      return SafetyResult.none;
    case ReportSheetOutcome.rateLimited:
      say('คุณรายงานบ่อยเกินไป กรุณาลองใหม่ภายหลัง');
      return SafetyResult.none;
    case ReportSheetOutcome.ownContent:
      say('ไม่สามารถรายงานเนื้อหาของตัวเองได้');
      return SafetyResult.none;
    case ReportSheetOutcome.sent:
      hide();
      return SafetyResult.reported;
    case ReportSheetOutcome.sentThenBlock:
      // Asked before hiding, so the dialog is not shown over a page that has
      // just emptied under it.
      final blocked = ownerId != null &&
          root.mounted &&
          await _block(
            root,
            container,
            messenger,
            userId: ownerId,
            label: subject.ownerName,
          );
      hide();
      return blocked ? SafetyResult.blocked : SafetyResult.reported;
  }
}

/// "บล็อก @maki?" → `POST /users/:id/block` → their posts, clips and
/// comments leave every list on this device at once → snackbar with เลิกทำ.
///
/// True once the block has landed.
Future<bool> blockUser(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String label,
}) async {
  if (!ensureSignedIn(context, ref)) return false;
  if (isViewer(ref, userId)) return false;
  return _block(
    Navigator.of(context, rootNavigator: true).context,
    ProviderScope.containerOf(context, listen: false),
    ScaffoldMessenger.of(context),
    userId: userId,
    label: label,
  );
}

Future<bool> _block(
  BuildContext dialogContext,
  ProviderContainer container,
  ScaffoldMessengerState messenger, {
  required String userId,
  required String label,
}) async {
  final confirmed = await showDialog<bool>(
    context: dialogContext,
    builder: (context) => AlertDialog(
      title: Text('บล็อก $label?'),
      content: Text(
        'คุณจะไม่เห็นโพสต์ คลิป และความคิดเห็นของ $label อีก '
        'และ $label จะไม่เห็นของคุณเช่นกัน '
        'การติดตามระหว่างกันจะถูกยกเลิก\n\n'
        '$label จะไม่ได้รับการแจ้งเตือนว่าถูกบล็อก',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('ยกเลิก'),
        ),
        TextButton(
          key: const Key('block-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: safetyRed),
          child: const Text(
            'บล็อก',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  void say(String message, {SnackBarAction? action}) => messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message), action: action));

  try {
    final api = await container.read(plunoApiProvider.future);
    await api.safety.block(userId);
  } on ApiException catch (failure) {
    say(switch (failure.statusCode) {
      400 => 'ไม่สามารถบล็อกตัวเองได้',
      401 => 'เข้าสู่ระบบก่อน จึงจะบล็อกได้',
      404 => 'ไม่พบผู้ใช้นี้',
      429 => 'ทำรายการบ่อยเกินไป กรุณาลองใหม่ภายหลัง',
      _ => 'บล็อกไม่สำเร็จ ลองอีกครั้ง',
    });
    return false;
  } catch (_) {
    say('บล็อกไม่สำเร็จ ลองอีกครั้ง');
    return false;
  }

  container
      .read(contentFilterProvider.notifier)
      .recordBlock(userId, blocked: true);
  container.read(followLedgerProvider.notifier).forgetAfterBlock(userId);

  say(
    'บล็อก $label แล้ว',
    action: SnackBarAction(
      label: 'เลิกทำ',
      textColor: AppColors.brandOrange,
      onPressed: () => _unblock(container, messenger, userId: userId),
    ),
  );
  return true;
}

/// เลิกบล็อก, after "เลิกบล็อก @maki?" unless [confirm] is false.
///
/// [message] replaces the dialog's body — the follow button's 403 asks
/// "เลิกบล็อก @maki เพื่อติดตาม?" with nothing under it. The follows the
/// block removed do not come back.
Future<bool> unblockUser(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String label,
  bool confirm = true,
  String? title,
  String? message,
}) async {
  if (!ensureSignedIn(context, ref)) return false;
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  if (confirm) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? 'เลิกบล็อก $label?'),
        content: Text(message ?? '$label จะเห็นโพสต์ของคุณได้อีกครั้ง'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            key: const Key('unblock-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'เลิกบล็อก',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return false;
  }
  return _unblock(container, messenger, userId: userId);
}

Future<bool> _unblock(
  ProviderContainer container,
  ScaffoldMessengerState messenger, {
  required String userId,
}) async {
  try {
    final api = await container.read(plunoApiProvider.future);
    await api.safety.unblock(userId);
  } on ApiException catch (failure) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(
          failure.isRateLimited
              ? 'ทำรายการบ่อยเกินไป กรุณาลองใหม่ภายหลัง'
              : 'เลิกบล็อกไม่สำเร็จ ลองอีกครั้ง',
        ),
      ));
    return false;
  } catch (_) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('เลิกบล็อกไม่สำเร็จ ลองอีกครั้ง')),
      );
    return false;
  }
  container
      .read(contentFilterProvider.notifier)
      .recordBlock(userId, blocked: false);
  // The server dropped their rows from any feed read while the block stood;
  // only a re-read brings them back.
  container
    ..invalidate(homeFeedProvider)
    ..invalidate(paigunFeedProvider)
    ..invalidate(puntokFeedProvider)
    ..invalidate(userProfileProvider(userId));
  return true;
}

/// The ⋯ for a feed card: report the post (or clip) and block its creator.
/// Null for the viewer's own rows, so their cards carry no ⋯ at all.
VoidCallback? Function(TripListItem trip) tripMoreOf(
  BuildContext context,
  WidgetRef ref,
) =>
    (trip) {
      final ownerId = trip.creator?.id;
      if (isViewer(ref, ownerId)) return null;
      return () => showSafetyMenu(context, ref, tripSubject(trip));
    };

/// [trip] as something to report.
ReportSubject tripSubject(TripListItem trip) => ReportSubject(
      type: ReportTargetType.trip,
      id: trip.id,
      ownerId: trip.creator?.id,
      ownerLabel: trip.creator?.name,
      isClip: trip.isClip,
    );

/// The ⋯ on a Puntok clip; null on the viewer's own.
VoidCallback? Function(PuntokPost post) clipMoreOf(
  BuildContext context,
  WidgetRef ref,
) =>
    (post) {
      if (isViewer(ref, post.authorId)) return null;
      return () => showSafetyMenu(
            context,
            ref,
            ReportSubject(
              type: ReportTargetType.trip,
              id: post.id,
              ownerId: post.authorId,
              ownerLabel: post.author,
              isClip: true,
            ),
          );
    };

extension ClipFilter on ContentFilter {
  /// The clip queue minus what is reported, blocked or gone. Dropping the
  /// clip on screen moves the pager straight on to the next one.
  List<PuntokPost> visibleClips(List<PuntokPost> posts) {
    if (isEmpty) return posts;
    return [
      for (final post in posts)
        if (!hidesTrip(post.id, ownerId: post.authorId)) post,
    ];
  }
}
