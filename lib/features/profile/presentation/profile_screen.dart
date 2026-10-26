import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/create_sheet.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../../shared/models/feed_rows.dart';
import '../../home/presentation/widgets/pun_guide_grid.dart';
import '../../my_trips/presentation/delete_trip.dart';
import '../../paigun/domain/nearby_trip.dart';
import '../../puntok/domain/models/puntok_post.dart';
import '../../puntok/presentation/puntok_viewer_screen.dart';
import 'providers/profile_providers.dart';
import 'widgets/profile_albums_view.dart';
import 'widgets/profile_hero.dart';
import 'widgets/profile_tab_bar.dart';
import 'widgets/profile_top_bar.dart';

/// The header photo behind the avatar, shared with จัดการบัญชี.
///
/// The API has no cover-image field, so every profile shows the same bundled
/// shot. The design's own cover is a night alley strung with lanterns, which
/// is not among the bundled assets — drop that file in and change this one
/// line once it exists.
const profileCoverImage = 'assets/images/puntok_osaka.jpg';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _scrollController = ScrollController();

  /// How far the bar has handed over from "glyphs on the cover" to "solid bar
  /// with a title": 0 until the counts row is about to slide under it, 1 a
  /// short distance later. Kept as a notifier so scrolling repaints the bar
  /// alone rather than the whole wall.
  final _barProgress = ValueNotifier<double>(0);

  /// The hero is a little over 300pt tall; the hand-off runs across the last
  /// stretch of it so the bar is solid by the time the tabs reach the top.
  static const _handoffStart = 150.0;
  static const _handoffEnd = 210.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _barProgress.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    _barProgress.value =
        ((offset - _handoffStart) / (_handoffEnd - _handoffStart))
            .clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final tab = ref.watch(profileTabProvider);
    final rows = ref.watch(profileTabRowsProvider);

    void unavailable(String message) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

    return AppFrame(
      background: AppColors.screen,
      child: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: ProfileHero(
                  session: session,
                  coverImage: profileCoverImage,
                  onEditAvatar: () =>
                      unavailable('แก้ไขรูปโปรไฟล์ยังไม่เปิดใช้งาน'),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: ProfileTabBar(
                    active: tab,
                    onSelected: (next) =>
                        ref.read(profileTabProvider.notifier).state = next,
                  ),
                ),
              ),
              _TabBody(
                tab: tab,
                rows: rows,
                signedIn: session != null,
                bottomInset: AppBottomNav.heightOf(context) + 16,
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _barProgress,
              builder: (context, progress, _) => ProfileTopBar(
                progress: progress,
                title: session?.displayName ?? 'โปรไฟล์',
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.goNamed(AppRoute.home.name),
                onMenu: () => context.goNamed(AppRoute.profileAccount.name),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNav(
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
}

/// The wall under the tabs: a two-column grid of [PunGuideCard]s, or whatever
/// stands in for it when there is nothing to show.
class _TabBody extends ConsumerWidget {
  const _TabBody({
    required this.tab,
    required this.rows,
    required this.signedIn,
    required this.bottomInset,
  });

  final ProfileTab tab;
  final AsyncValue<List<TripListItem>>? rows;
  final bool signedIn;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!signedIn) {
      return _filler(
        const _ProfileNotice(
          icon: Icons.lock_outline,
          message: 'เข้าสู่ระบบเพื่อดูโพสต์และทริปของคุณ',
        ),
      );
    }

    if (tab == ProfileTab.albums) {
      return _filler(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ProfileAlbumsView(onOpen: (album) => _openAlbum(context, album)),
        ),
      );
    }

    return rows!.when(
      loading: () => _filler(
        const Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => _filler(
        _ProfileNotice(
          icon: Icons.cloud_off,
          message: 'โหลดไม่สำเร็จ\n$error',
        ),
      ),
      data: (trips) {
        if (trips.isEmpty) {
          return _filler(_ProfileNotice(icon: Icons.inbox, message: _empty));
        }

        // The badge ranks this wall's own rows, the same way Home and the
        // ไปกัน board rank theirs.
        final featured = {
          for (final row in decorateTrips(trips, saved: const {}))
            if (row.featured) row.trip.id,
        };

        return SliverPadding(
          padding: EdgeInsets.only(bottom: bottomInset),
          sliver: SliverToBoxAdapter(
            child: PunGuideGrid(
              trips: trips,
              featuredOf: (trip) => featured.contains(trip.id),
              onDelete: (trip) => confirmDeleteTrip(context, ref, trip),
              onOpen: (trip) => _open(context, trips, trip),
              onSave: (trip) => _toggleSaved(context, ref, trip),
            ),
          ),
        );
      },
    );
  }

  /// An album *is* a trip — a photo post or a clip — so it opens the same
  /// page any other row would.
  void _openAlbum(BuildContext context, TripListItem album) {
    context.goNamed(
      AppRoute.tripDetail.name,
      params: {'tripId': album.id},
    );
  }

  String get _empty => switch (tab) {
        ProfileTab.all => 'ยังไม่มีอะไรของคุณที่นี่',
        ProfileTab.content => 'ยังไม่มีโพสต์ของคุณ',
        ProfileTab.plans => 'ยังไม่มีแผนทริปของคุณ',
        ProfileTab.clips => 'ยังไม่มีคลิป Puntok ของคุณ',
        // Albums never reach here — that tab draws its own grid.
        ProfileTab.albums => 'ยังไม่มีอัลบั้ม',
      };

  /// A clip opens full screen with the rest of this wall still swipeable;
  /// anything else opens its trip page.
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

    // Only the rows with a playable cover can be paged through — a clip whose
    // video the server never finished would stall the pager on a blank page.
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

  /// Every wall here is the traveller's own, so there is no bookmark of
  /// theirs to flip — saving your own trip is not a thing.
  void _toggleSaved(
    BuildContext context,
    WidgetRef ref,
    TripListItem trip,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บันทึกทริปของตัวเองไม่ได้')),
    );
  }

  SliverToBoxAdapter _filler(Widget child) => SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: child,
        ),
      );
}

class _ProfileNotice extends StatelessWidget {
  const _ProfileNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
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
        ],
      ),
    );
  }
}
