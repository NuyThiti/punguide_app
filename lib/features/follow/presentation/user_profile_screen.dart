import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/formatting/compact_count.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../home/presentation/providers/home_feed_providers.dart';
import '../../home/presentation/widgets/pun_guide_grid.dart';
import '../../profile/presentation/profile_screen.dart' show profileCoverImage;
import '../../profile/presentation/widgets/profile_hero.dart';
import '../../profile/presentation/widgets/profile_top_bar.dart';
import '../../safety/presentation/providers/safety_providers.dart';
import '../../safety/presentation/safety_actions.dart';
import '../../safety/presentation/widgets/report_sheet.dart' show safetyRed;
import '../../trips/presentation/providers/trip_like_providers.dart';
import '../../trips/presentation/trip_like_action.dart';
import 'follow_actions.dart';
import 'providers/follow_providers.dart';
import 'widgets/follow_button.dart';

/// Someone's profile at `/users/:userId`: who they are, both counts, the
/// follow button, and their public posts and plans.
///
/// **The wall is the public feed filtered to this creator.** There is no
/// per-user trips endpoint; `GET /trips` with no query is every public trip,
/// unpaginated, so filtering it client-side is complete — the same trade the
/// search page makes. Clips are not in it (Home's feed drops them).
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(userId));

    void back() =>
        context.canPop() ? context.pop() : context.goNamed(AppRoute.home.name);

    return AppFrame(
      background: AppColors.screen,
      child: Stack(
        children: [
          profile.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _Failure(
              notFound: error is ApiException && error.isNotFound,
              onRetry: () => ref.invalidate(userProfileProvider(userId)),
            ),
            data: (profile) => _Body(profile: profile),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ProfileTopBar(
              // Solid while there is no cover under it to read against.
              progress: profile.hasValue ? 0 : 1,
              title: profile.valueOrNull?.displayName ?? '',
              onBack: back,
              // ⋯ — report and block — on anyone's profile but your own.
              onMenu: switch (profile.valueOrNull) {
                final shown? when !shown.isMe => () =>
                    _openMenu(context, ref, shown),
                _ => null,
              },
              menuIcon: Icons.more_horiz,
              menuTooltip: 'ตัวเลือกเพิ่มเติม',
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether the viewer has [profile] blocked: their own latest tap, else the
/// profile's `isBlocked`.
bool _blocked(WidgetRef ref, PublicUserProfile profile) =>
    ref.watch(contentFilterProvider).blockOf(profile.id) ?? profile.isBlocked;

String _handleOf(PublicUserProfile profile) =>
    userHandle(username: profile.username, name: profile.displayName);

enum _ProfileAction { report, block, unblock }

/// The ⋯ in the top bar: รายงานผู้ใช้, then บล็อก or เลิกบล็อก.
Future<void> _openMenu(
  BuildContext context,
  WidgetRef ref,
  PublicUserProfile profile,
) async {
  final blocked =
      ref.read(contentFilterProvider).blockOf(profile.id) ?? profile.isBlocked;
  final handle = _handleOf(profile);
  final action = await showActionSheet<_ProfileAction>(
    context,
    cancelLabel: 'ยกเลิก',
    items: [
      const ActionSheetItem(
        value: _ProfileAction.report,
        icon: Icons.report_gmailerrorred_outlined,
        label: 'รายงานผู้ใช้',
        destructive: true,
      ),
      blocked
          ? ActionSheetItem(
              value: _ProfileAction.unblock,
              icon: Icons.lock_open,
              label: 'เลิกบล็อก $handle',
            )
          : ActionSheetItem(
              value: _ProfileAction.block,
              icon: Icons.block,
              label: 'บล็อก $handle',
              destructive: true,
            ),
    ],
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _ProfileAction.report:
      await reportContent(
        context,
        ref,
        ReportSubject(
          type: ReportTargetType.user,
          id: profile.id,
          ownerId: profile.id,
          ownerLabel: handle,
        ),
      );
    case _ProfileAction.block:
      await blockUser(context, ref, userId: profile.id, label: handle);
    case _ProfileAction.unblock:
      await unblockUser(context, ref, userId: profile.id, label: handle);
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.profile});

  final PublicUserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(visibleHomeFeedProvider);
    final bottom = MediaQuery.of(context).padding.bottom + 24;

    if (!profile.isMe && _blocked(ref, profile)) {
      return CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _UserHero(profile: profile)),
          SliverToBoxAdapter(child: _BlockedBanner(profile: profile)),
        ],
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _UserHero(profile: profile)),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: Text(
              'โพสต์และทริป',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.only(bottom: bottom),
          sliver: SliverToBoxAdapter(
            child: feed.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const _Notice(
                icon: Icons.cloud_off,
                message: 'โหลดโพสต์ไม่สำเร็จ',
              ),
              data: (all) {
                final theirs = all
                    .where((trip) => trip.creator?.id == profile.id)
                    .toList(growable: false);
                if (theirs.isEmpty) {
                  return const _Notice(
                    icon: Icons.inbox,
                    message: 'ยังไม่มีโพสต์สาธารณะ',
                  );
                }
                return PunGuideGrid(
                  trips: theirs,
                  isMine: profile.isMe,
                  likedOf: (trip) =>
                      likedNow(ref.watch(tripLikedProvider), trip),
                  // Their own wall has nothing to heart; everyone else's does.
                  onLike: profile.isMe
                      ? null
                      : (trip) => toggleTripLike(context, ref, trip),
                  moreOf: profile.isMe ? null : tripMoreOf(context, ref),
                  onOpen: (trip) => context.pushNamed(
                    AppRoute.tripDetail.name,
                    params: {'tripId': trip.id},
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// The dark card: cover, avatar, name, the "ติดตามคุณ" badge, counts, and the
/// follow (or แก้ไขโปรไฟล์) button.
class _UserHero extends ConsumerWidget {
  const _UserHero({required this.profile});

  final PublicUserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(followLedgerProvider);
    final following = ledger.isFollowing(profile.id) ?? profile.isFollowing;
    // Follow / unfollow answer with fresh counts; prefer them to the read.
    final counts = ledger.summaries[profile.id];
    final followers = counts?.followerCount ?? profile.followerCount;
    final followings = counts?.followingCount ?? profile.followingCount;

    void open(FollowListKind kind) => context.pushNamed(
          AppRoute.userFollows.name,
          params: {'userId': profile.id},
          queryParams: {'tab': kind.path},
        );

    final avatar = profile.avatarUrl;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CoverImage(source: profileCoverImage, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.78)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              ProfileTopBar.heightOf(context) + 4,
              16,
              18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: ProfileHero.avatarSize,
                  height: ProfileHero.avatarSize,
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: avatar != null && avatar.isNotEmpty
                      ? CoverImage(source: avatar, fit: BoxFit.cover)
                      : const Icon(Icons.person, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 10),
                Text(
                  profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        '@${profile.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (profile.followsYou && !profile.isMe) ...[
                      const SizedBox(width: 6),
                      const _FollowsYouBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                ProfileCountsRow(
                  counts: [
                    (
                      value: compactCount(followers),
                      label: 'Follower',
                      onTap: () => open(FollowListKind.followers),
                    ),
                    (
                      value: compactCount(followings),
                      label: 'Following',
                      onTap: () => open(FollowListKind.following),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Blocked: no follow button — the banner below says why.
                if (!profile.isMe && _blocked(ref, profile))
                  const SizedBox.shrink()
                else
                  SizedBox(
                    width: 220,
                    child: profile.isMe
                        ? OutlinedButton(
                            onPressed: () =>
                                context.pushNamed(AppRoute.profileEdit.name),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                              minimumSize: const Size.fromHeight(40),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text(
                              'แก้ไขโปรไฟล์',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          )
                        : FollowButton(
                            following: following,
                            followsYou: profile.followsYou,
                            onPressed: () => toggleFollow(
                              context,
                              ref,
                              userId: profile.id,
                              following: following,
                              label: _handleOf(profile),
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
}

/// "คุณบล็อกผู้ใช้นี้อยู่" + เลิกบล็อก, where the wall would be.
class _BlockedBanner extends ConsumerWidget {
  const _BlockedBanner({required this.profile});

  final PublicUserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handle = _handleOf(profile);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: BoxDecoration(
          color: AppColors.softScreen,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            const Icon(Icons.block, size: 30, color: safetyRed),
            const SizedBox(height: 10),
            const Text(
              'คุณบล็อกผู้ใช้นี้อยู่',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'คุณจะไม่เห็นโพสต์ คลิป และความคิดเห็นของ $handle',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              key: const Key('profile-unblock'),
              onPressed: () => unblockUser(
                context,
                ref,
                userId: profile.id,
                label: handle,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.foreground,
                side: const BorderSide(color: AppColors.foreground),
                minimumSize: const Size(160, 40),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'เลิกบล็อก',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowsYouBadge extends StatelessWidget {
  const _FollowsYouBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'ติดตามคุณ',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.notFound, required this.onRetry});

  final bool notFound;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Notice(
            icon: notFound ? Icons.person_off_outlined : Icons.cloud_off,
            message: notFound ? 'ไม่พบผู้ใช้นี้' : 'โหลดโปรไฟล์ไม่สำเร็จ',
          ),
          if (!notFound)
            TextButton(onPressed: onRetry, child: const Text('ลองอีกครั้ง')),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: AppColors.navIconMuted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
