import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../safety/presentation/safety_actions.dart';
import 'providers/follow_providers.dart';

/// Whether the viewer follows [userId]: their own latest tap if there was
/// one, else what the screen's own response said.
bool resolveFollowing(WidgetRef ref, String userId, bool fromServer) =>
    ref.watch(followLedgerProvider).isFollowing(userId) ?? fromServer;

/// Opens someone's profile page.
void openUserProfile(BuildContext context, String userId) =>
    context.pushNamed(AppRoute.userProfile.name, params: {'userId': userId});

/// The one place a follow button's tap goes. A guest is asked to sign in
/// rather than sent a 401; a refused call is undone and said out loud.
Future<void> toggleFollow(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required bool following,

  /// How the 403 dialog names them — "เลิกบล็อก @maki เพื่อติดตาม?".
  String? label,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final session = ref.read(authSessionProvider);
  if (session == null) {
    messenger.showSnackBar(
      SnackBar(
        content: const Text('เข้าสู่ระบบเพื่อติดตาม'),
        action: SnackBarAction(
          label: 'เข้าสู่ระบบ',
          onPressed: () => context.goNamed(AppRoute.login.name),
        ),
      ),
    );
    return;
  }

  // Following yourself is a 400; your own clip or post has nothing to do.
  if (session.userId == userId) return;

  try {
    await ref
        .read(followLedgerProvider.notifier)
        .setFollowing(userId, !following);
  } on ApiException catch (failure) {
    // 403 on follow: the viewer has them blocked. Unblock first, then follow.
    if (!following && failure.isForbidden && context.mounted) {
      final name = label ?? 'ผู้ใช้นี้';
      final unblocked = await unblockUser(
        context,
        ref,
        userId: userId,
        label: name,
        title: 'เลิกบล็อก $name เพื่อติดตาม?',
        message: 'การติดตามเดิมจะไม่กลับมาเอง',
      );
      if (unblocked && context.mounted) {
        return toggleFollow(
          context,
          ref,
          userId: userId,
          following: false,
          label: label,
        );
      }
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(following ? 'เลิกติดตามไม่สำเร็จ' : 'ติดตามไม่สำเร็จ'),
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(following ? 'เลิกติดตามไม่สำเร็จ' : 'ติดตามไม่สำเร็จ'),
      ),
    );
  }
}
