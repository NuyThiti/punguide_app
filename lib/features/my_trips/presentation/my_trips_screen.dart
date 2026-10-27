import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/feed_rows.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/create_sheet.dart';
import '../../../shared/widgets/dark_sheet_header.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../home/presentation/widgets/pun_guide_grid.dart';
import '../../profile/presentation/profile_screen.dart' show profileCoverImage;
import '../../profile/presentation/providers/profile_providers.dart';
import '../../profile/presentation/widgets/profile_tab_bar.dart';
import '../../puntok/domain/models/puntok_post.dart';
import '../../puntok/presentation/puntok_viewer_screen.dart';
import 'delete_trip.dart';
import 'providers/my_trips_providers.dart';

/// Save Draft — everything the traveller has started but not published, from
/// `GET /trips/mine`.
///
/// The one list in the app that shows a trip before the world sees it: drafts
/// never reach the feed, so without this page a plan that was closed halfway
/// through is unreachable.
class MyTripsScreen extends ConsumerWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    final tab = ref.watch(draftTabProvider);
    final rows = ref.watch(draftTabRowsProvider);

    void unavailable(String message) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

    return AppFrame(
      background: AppColors.screen,
      child: Stack(
        children: [
          Column(
            children: [
              DarkSheetHeader(
                title: 'Save Draft',
                coverImage: profileCoverImage,
                onBack: () => _close(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: ProfileTabBar(
                  active: tab,
                  onSelected: (next) =>
                      ref.read(draftTabProvider.notifier).state = next,
                ),
              ),
              Expanded(
                child: !signedIn
                    ? const _DraftNotice(
                        icon: Icons.lock_outline,
                        message: 'เข้าสู่ระบบเพื่อดูแบบร่างของคุณ',
                      )
                    : RefreshIndicator(
                        color: AppColors.loading,
                        onRefresh: () =>
                            ref.read(myTripsProvider.notifier).refresh(),
                        child: _DraftWall(
                          tab: tab,
                          rows: rows,
                          bottomInset: AppBottomNav.heightOf(context) + 16,
                          onRetry: () =>
                              ref.read(myTripsProvider.notifier).refresh(),
                        ),
                      ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNav(
              // Reached from the profile menu, so the tab the traveller came
              // through stays lit rather than nothing at all.
              active: AppRoute.profile,
              onTap: (route) => context.goNamed(route.name),
              onCreate: () => openCreateSheet(
                context,
                onOwnPlan: () => context.goNamed(AppRoute.createTrip.name),
                onPost: () => context.goNamed(AppRoute.createPost.name),
                onPuntok: () => context.goNamed(AppRoute.createPuntok.name),
                onUnavailable: unavailable,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.profile.name);
    }
  }
}

/// The two-column wall of drafts, each card tagged "Editing".
class _DraftWall extends ConsumerWidget {
  const _DraftWall({
    required this.tab,
    required this.rows,
    required this.bottomInset,
    required this.onRetry,
  });

  final ProfileTab tab;
  final AsyncValue<List<TripListItem>>? rows;
  final double bottomInset;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = this.rows;
    if (rows == null) {
      return _scrollable(
        _DraftNotice(icon: Icons.inbox_outlined, message: _nothingToDraft),
      );
    }

    return rows.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _scrollable(
        _DraftNotice(
          icon: Icons.cloud_off,
          message: 'โหลดแบบร่างไม่สำเร็จ',
          actionLabel: 'ลองอีกครั้ง',
          onAction: onRetry,
        ),
      ),
      data: (drafts) {
        if (drafts.isEmpty) {
          return _scrollable(
            _DraftNotice(icon: Icons.inbox_outlined, message: _empty),
          );
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.only(bottom: bottomInset),
          children: [
            PunGuideGrid(
              trips: drafts,
              // Every row here is a draft, so every card wears the tag.
              overlayOf: (_) => const _EditingTag(),
              onDelete: tripDeleteEnabled
                  ? (trip) => confirmDeleteTrip(context, ref, trip)
                  : null,
              onOpen: (trip) => _open(context, drafts, trip),
            ),
          ],
        );
      },
    );
  }

  /// A clip opens full screen with the rest of this wall still swipeable;
  /// anything else opens its editor, which is where a draft is headed.
  void _open(
    BuildContext context,
    List<TripListItem> wall,
    TripListItem trip,
  ) {
    if (!trip.isClip) {
      context.goNamed(
        AppRoute.tripDetail.name,
        params: {'tripId': trip.id},
      );
      return;
    }

    final posts = wall
        .map(PuntokPost.fromListItem)
        .whereType<PuntokPost>()
        .toList(growable: false);
    final index = posts.indexWhere((post) => post.id == trip.id);
    if (index < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คลิปนี้ยังเล่นไม่ได้')),
      );
      return;
    }

    context.pushNamed(
      AppRoute.puntokViewer.name,
      extra: PuntokViewerArgs(posts: posts, initialIndex: index),
    );
  }

  /// Pull-to-refresh needs something scrollable even when the page is a
  /// single line of text.
  Widget _scrollable(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      children: [child],
    );
  }

  String get _nothingToDraft => 'อัลบั้มไม่มีแบบร่าง';

  String get _empty => switch (tab) {
        ProfileTab.content => 'ยังไม่มีโพสต์ที่ค้างไว้',
        ProfileTab.plans => 'ยังไม่มีแผนทริปที่ค้างไว้',
        ProfileTab.clips => 'ยังไม่มีคลิปที่ค้างไว้',
        _ => 'ยังไม่มีแบบร่างที่ค้างไว้',
      };
}

/// The "Editing" tag on a draft's cover.
class _EditingTag extends StatelessWidget {
  const _EditingTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Editing',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DraftNotice extends StatelessWidget {
  const _DraftNotice({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 48),
      child: Column(
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
          if (actionLabel != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
