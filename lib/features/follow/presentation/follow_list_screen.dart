import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import 'follow_actions.dart';
import 'providers/follow_providers.dart';
import 'widgets/follow_button.dart';

/// ผู้ติดตาม / กำลังติดตาม for one account, at `/users/:userId/follows`.
///
/// Every row's button is about the **viewer**, not the list's owner. On the
/// viewer's own followers list each row also gets ลบ, which takes that person
/// off their followers (not a block).
class FollowListScreen extends ConsumerWidget {
  const FollowListScreen({
    super.key,
    required this.userId,
    this.initial = FollowListKind.followers,
  });

  final String userId;
  final FollowListKind initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Already cached when arriving from their profile; a title is a nicety,
    // so a failed read just leaves it blank.
    final title = ref.watch(userProfileProvider(userId)).valueOrNull;

    return AppFrame(
      background: Colors.white,
      child: DefaultTabController(
        length: FollowListKind.values.length,
        initialIndex: initial.index,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            foregroundColor: AppColors.foreground,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              tooltip: 'ย้อนกลับ',
              icon: const Icon(Icons.chevron_left, size: 28),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(AppRoute.home.name),
            ),
            title: Text(
              title == null ? '' : '@${title.username}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            bottom: const TabBar(
              labelColor: AppColors.foreground,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.brandOrange,
              labelStyle: TextStyle(fontWeight: FontWeight.w700),
              tabs: [Tab(text: 'ผู้ติดตาม'), Tab(text: 'กำลังติดตาม')],
            ),
          ),
          body: TabBarView(
            children: [
              for (final kind in FollowListKind.values)
                _FollowListView(args: (userId: userId, kind: kind)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowListView extends ConsumerWidget {
  const _FollowListView({required this.args});

  final FollowListArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(followListProvider(args));
    final notifier = ref.read(followListProvider(args).notifier);
    final myId = ref.watch(authSessionProvider)?.userId;
    final myFollowers =
        myId == args.userId && args.kind == FollowListKind.followers;

    return rows.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _Message(
        text: 'โหลดรายชื่อไม่สำเร็จ',
        action: TextButton(
          onPressed: () => ref.invalidate(followListProvider(args)),
          child: const Text('ลองอีกครั้ง'),
        ),
      ),
      data: (users) {
        if (users.isEmpty) {
          return _Message(
            text: args.kind == FollowListKind.followers
                ? 'ยังไม่มีผู้ติดตาม'
                : 'ยังไม่ได้ติดตามใคร',
          );
        }
        final more = notifier.hasMore;
        return RefreshIndicator(
          onRefresh: notifier.refresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 300) notifier.loadMore();
              return false;
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: users.length + (more ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == users.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final user = users[index];
                return _FollowRow(
                  user: user,
                  isMe: user.id == myId,
                  removable: myFollowers,
                  onRemove: () => _remove(context, ref, user),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    FollowUser user,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบผู้ติดตาม?'),
        content: Text(
          'ลบ @${user.username} ออกจากผู้ติดตามของคุณ '
          'เขายังกดติดตามคุณใหม่ได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(followLedgerProvider.notifier).removeFollower(user.id);
      ref.read(followListProvider(args).notifier).drop(user.id);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('ลบผู้ติดตามไม่สำเร็จ')),
      );
    }
  }
}

class _FollowRow extends ConsumerWidget {
  const _FollowRow({
    required this.user,
    required this.isMe,
    required this.removable,
    required this.onRemove,
  });

  final FollowUser user;

  /// The viewer's own row: the server always says false for it, and there is
  /// nothing to follow, so no buttons at all.
  final bool isMe;

  /// The viewer's own followers list — the only place ลบ appears.
  final bool removable;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = resolveFollowing(ref, user.id, user.isFollowing);
    final avatar = user.avatarUrl;

    return InkWell(
      onTap: () => openUserProfile(context, user.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.line,
              ),
              child: avatar != null && avatar.isNotEmpty
                  ? CoverImage(source: avatar, fit: BoxFit.cover)
                  : const Icon(Icons.person, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (!isMe) ...[
              const SizedBox(width: 8),
              FollowButton(
                dense: true,
                following: following,
                // Everyone on your own followers list follows you.
                followsYou: removable,
                onPressed: () => toggleFollow(
                  context,
                  ref,
                  userId: user.id,
                  following: following,
                ),
              ),
              if (removable) ...[
                const SizedBox(width: 6),
                SizedBox(
                  height: 32,
                  child: TextButton(
                    onPressed: onRemove,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                        side: const BorderSide(color: AppColors.line),
                      ),
                    ),
                    child: const Text(
                      'ลบ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
