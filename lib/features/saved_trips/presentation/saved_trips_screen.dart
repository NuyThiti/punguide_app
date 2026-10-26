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
import '../../puntok/domain/models/puntok_post.dart';
import '../../puntok/presentation/puntok_viewer_screen.dart';

/// ทริปที่บันทึกไว้ — the traveller's bookmarks, from `GET /trips/saved`.
///
/// Reached from จัดการบัญชี. Reads the same shelf the bookmark button on
/// every card writes to, so a trip saved on Home shows up here.
class SavedTripsScreen extends ConsumerWidget {
  const SavedTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    final saved = ref.watch(savedFeedProvider);
    final bottomInset = AppBottomNav.heightOf(context) + 16;

    void unavailable(String message) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

    return AppFrame(
      background: AppColors.screen,
      child: Stack(
        children: [
          Column(
            children: [
              DarkSheetHeader(
                title: 'ทริปที่บันทึกไว้',
                coverImage: profileCoverImage,
                onBack: () => _close(context),
              ),
              Expanded(
                child: !signedIn
                    ? const _SavedNotice(
                        icon: Icons.lock_outline,
                        message: 'เข้าสู่ระบบเพื่อดูทริปที่บันทึกไว้',
                      )
                    : RefreshIndicator(
                        color: AppColors.loading,
                        onRefresh: () =>
                            ref.read(savedFeedProvider.notifier).refresh(),
                        child: saved.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) => _scrollable(
                            bottomInset,
                            _SavedNotice(
                              icon: Icons.cloud_off,
                              message: 'โหลดทริปที่บันทึกไว้ไม่สำเร็จ',
                              actionLabel: 'ลองอีกครั้ง',
                              onAction: () => ref
                                  .read(savedFeedProvider.notifier)
                                  .refresh(),
                            ),
                          ),
                          data: (trips) => trips.isEmpty
                              ? _scrollable(
                                  bottomInset,
                                  const _SavedNotice(
                                    icon: Icons.bookmark_border,
                                    message: 'ยังไม่ได้บันทึกทริปไหนไว้',
                                  ),
                                )
                              : ListView(
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  padding: EdgeInsets.only(bottom: bottomInset),
                                  children: [
                                    PunGuideGrid(
                                      trips: trips,
                                      // Every row here is bookmarked by
                                      // definition, whatever the row itself
                                      // was fetched saying.
                                      savedOf: (_) => true,
                                      onOpen: (trip) =>
                                          _open(context, trips, trip),
                                      onSave: (trip) => _unsave(
                                        context,
                                        ref,
                                        trip,
                                      ),
                                    ),
                                  ],
                                ),
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

  /// Un-bookmarking takes the row out of the wall — the wall *is* the
  /// bookmarks, so a row that stayed would be lying until the next read.
  Future<void> _unsave(
    BuildContext context,
    WidgetRef ref,
    TripListItem trip,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(savedFeedProvider.notifier).unsave(trip.id);
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

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

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.profile.name);
    }
  }

  /// Pull-to-refresh needs something scrollable even when the page is a
  /// single line of text.
  Widget _scrollable(double bottomInset, Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      children: [child],
    );
  }
}

class _SavedNotice extends StatelessWidget {
  const _SavedNotice({
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
