import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/create_sheet.dart';
import '../domain/models/puntok_post.dart';
import 'providers/puntok_providers.dart';
import 'widgets/puntok_player_pager.dart';
import 'widgets/puntok_top_bar.dart';

/// Puntok: a full-screen vertical feed of trip clips (Figma "Puntok" board).
///
/// The clips are content posts with a video cover, from `GET /trips` — see
/// [puntokFeedProvider]. Only the page in view and the one after it hold a
/// decoded player; the rest show their poster until they come into range.
class PuntokScreen extends ConsumerStatefulWidget {
  const PuntokScreen({super.key});

  @override
  ConsumerState<PuntokScreen> createState() => _PuntokScreenState();
}

class _PuntokScreenState extends ConsumerState<PuntokScreen> {
  final _pageController = PageController();

  /// Lets a tab switch rebuild the player window after the list underneath
  /// has been swapped wholesale.
  final _pagerKey = GlobalKey<State<PuntokPlayerPager>>();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(puntokFeedProvider);
    final posts = feed.valueOrNull ?? const <PuntokPost>[];
    final tab = ref.watch(puntokFeedTabProvider);
    final navHeight = AppBottomNav.heightOf(context);

    return AppFrame(
      background: Colors.black,
      child: Stack(
        children: [
          if (posts.isEmpty && feed.isLoading)
            Padding(
              padding: EdgeInsets.only(bottom: navHeight),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
            )
          else if (posts.isEmpty && feed.hasError)
            _FeedMessage(
              bottomInset: navHeight,
              icon: Icons.wifi_off_rounded,
              text: 'โหลดคลิปไม่สำเร็จ',
              actionLabel: 'ลองอีกครั้ง',
              onAction: () => ref.invalidate(puntokFeedProvider),
            )
          else if (posts.isEmpty)
            _FeedMessage(
              bottomInset: navHeight,
              icon: tab == PuntokFeed.following
                  ? Icons.people_outline
                  : Icons.video_library_outlined,
              // No follow API yet, so Following can never fill — say so
              // rather than implying the traveller follows nobody.
              text: tab == PuntokFeed.following
                  ? 'ฟีดคนที่คุณติดตามยังไม่เปิดใช้งาน'
                  : 'ยังไม่มีคลิป Puntok',
            )
          else
            PuntokPlayerPager(
              key: _pagerKey,
              controller: _pageController,
              posts: posts,
              bottomInset: navHeight,
              onLike: (post) => _act(() => _feed.toggleLike(post.id)),
              onSave: (post) => _act(() => _feed.toggleSave(post.id)),
              onFollow: () => _notYet('ติดตาม'),
              onOpenPlan: (planId) => context.pushNamed(
                AppRoute.tripDetail.name,
                params: {'tripId': planId},
              ),
              onComment: () => _notYet('คอมเมนต์'),
              onShare: () => _notYet('แชร์'),
              onCreator: () => _notYet('โปรไฟล์ครีเอเตอร์'),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PuntokTopBar(
              activeTab: tab,
              onTab: _selectTab,
              onBack: _goBack,
              onSearch: () => context.goNamed(AppRoute.search.name),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNav(
              active: AppRoute.puntok,
              onTap: (route) => context.goNamed(route.name),
              onCreate: _openCreate,
            ),
          ),
        ],
      ),
    );
  }

  PuntokFeedNotifier get _feed => ref.read(puntokFeedProvider.notifier);

  void _selectTab(PuntokFeed tab) {
    if (tab == ref.read(puntokFeedTabProvider)) return;

    ref.read(puntokFeedTabProvider.notifier).state = tab;
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  /// Runs a like or a save; the page has already flipped, and flips back on
  /// failure, so all that is left is saying why.
  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (error) {
      _showMessage(error.statusCode == 401
          ? 'เข้าสู่ระบบก่อน จึงจะกดถูกใจหรือบันทึกได้'
          : 'ทำรายการไม่สำเร็จ ลองอีกครั้ง');
    } catch (_) {
      _showMessage('ทำรายการไม่สำเร็จ ลองอีกครั้ง');
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.home.name);
    }
  }

  void _openCreate() {
    openCreateSheet(
      context,
      onOwnPlan: () => context.goNamed(AppRoute.createTrip.name),
      onPost: () => context.goNamed(AppRoute.createPost.name),
      onPuntok: () => context.goNamed(AppRoute.createPuntok.name),
      onUnavailable: _showMessage,
    );
  }

  void _notYet(String label) => _showMessage('$label — เร็วๆ นี้');

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Stands in for the feed when there is nothing to swipe: a load that
/// failed, an empty tab, or Following, which has no API behind it yet.
class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
    required this.bottomInset,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final double bottomInset;
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
