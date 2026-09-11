import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/create_sheet.dart';
import '../domain/models/puntok_post.dart';
import 'providers/puntok_providers.dart';
import 'widgets/puntok_post_view.dart';
import 'widgets/puntok_top_bar.dart';

/// Puntok: a full-screen vertical feed of trip clips (Figma "Puntok" board).
///
/// The feed is mock — see [puntokFeedProvider]. Clips are bundled assets, so
/// only the page in view and the one after it hold a decoded player; the rest
/// show their poster until they come into range.
class PuntokScreen extends ConsumerStatefulWidget {
  const PuntokScreen({super.key});

  @override
  ConsumerState<PuntokScreen> createState() => _PuntokScreenState();
}

class _PuntokScreenState extends ConsumerState<PuntokScreen>
    with WidgetsBindingObserver {
  final _pageController = PageController();

  /// Players keyed by post id, so switching tabs reuses what is already
  /// decoded instead of re-reading the asset.
  final _players = <String, VideoPlayerController>{};

  int _index = 0;
  bool _paused = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPlayers());
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
    _pageController.dispose();
    super.dispose();
  }

  /// Nothing should keep playing behind a backgrounded app or another route.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncPlayers();
    } else {
      for (final player in _players.values) {
        player.pause();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(puntokFeedProvider);
    final tab = ref.watch(puntokFeedTabProvider);
    final navHeight = AppBottomNav.heightOf(context);

    // A like can reorder Top Punguide and an unfollow can drop the page out
    // of Following — either way the player window has to be recomputed, or a
    // clip that is no longer on screen keeps its audio running.
    ref.listen<List<PuntokPost>>(puntokFeedProvider, (previous, next) {
      if (_activeId(previous) != _activeId(next)) _syncPlayers();
    });

    // A tab can be shorter than the page we were on, or empty.
    if (posts.isNotEmpty && _index >= posts.length) {
      _index = posts.length - 1;
    }

    return AppFrame(
      background: Colors.black,
      child: Stack(
        children: [
          if (posts.isEmpty)
            _EmptyFeed(bottomInset: navHeight)
          else
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: posts.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final post = posts[index];
                return PuntokPostView(
                  post: post,
                  controller: _players[post.id],
                  paused: _paused && index == _index,
                  bottomInset: navHeight,
                  onTogglePlay: _togglePlay,
                  onLike: () => _feed.toggleLike(post.id),
                  onSave: () => _feed.toggleSave(post.id),
                  onFollow: () => _feed.toggleFollow(post.id),
                  onComment: () => _notYet('คอมเมนต์'),
                  onShare: () => _notYet('แชร์'),
                  onCreator: () => _notYet('โปรไฟล์ครีเอเตอร์'),
                );
              },
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

  /// Id of the post the current page lands on in [posts], or null if that list
  /// cannot fill the page.
  String? _activeId(List<PuntokPost>? posts) {
    if (posts == null || posts.isEmpty) return null;
    return posts[_index.clamp(0, posts.length - 1)].id;
  }

  void _onPageChanged(int index) {
    setState(() {
      _index = index;
      _paused = false;
    });
    _syncPlayers();
  }

  void _selectTab(PuntokFeed tab) {
    if (tab == ref.read(puntokFeedTabProvider)) return;

    ref.read(puntokFeedTabProvider.notifier).state = tab;
    setState(() {
      _index = 0;
      _paused = false;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
    _syncPlayers();
  }

  void _togglePlay() {
    final posts = ref.read(puntokFeedProvider);
    if (posts.isEmpty) return;

    final activeId = _activeId(posts);
    final player = activeId == null ? null : _players[activeId];
    if (player == null || !player.value.isInitialized) return;

    setState(() => _paused = !_paused);
    _paused ? player.pause() : player.play();
  }

  /// Holds players for the page in view and the next one, plays the first and
  /// pauses the rest, and lets go of everything else.
  Future<void> _syncPlayers() async {
    final posts = ref.read(puntokFeedProvider);
    final active = _activeId(posts);
    final keep = <String>{
      if (active != null) active,
      if (_index + 1 < posts.length) posts[_index + 1].id,
    };

    for (final id in _players.keys.toList()) {
      if (!keep.contains(id)) _players.remove(id)!.dispose();
    }
    for (final post in posts.where((post) => keep.contains(post.id))) {
      await _load(post);
      if (_disposed) return;
    }
    _resume(posts);
  }

  Future<void> _load(PuntokPost post) async {
    if (_players.containsKey(post.id)) return;

    final player = VideoPlayerController.asset(post.video);
    _players[post.id] = player;

    try {
      await player.initialize();
      await player.setLooping(true);
    } catch (_) {
      // A clip that will not decode keeps its poster rather than an error box.
      _players.remove(post.id);
      await player.dispose();
      return;
    }
    if (_disposed) {
      _players.remove(post.id);
      await player.dispose();
      return;
    }
    setState(() {});
  }

  void _resume(List<PuntokPost> posts) {
    final activeId = _activeId(posts);
    if (activeId == null) return;

    for (final entry in _players.entries) {
      if (entry.key == activeId && !_paused) {
        entry.value.play();
      } else {
        entry.value.pause();
      }
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

/// The Following tab with nothing in it.
class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            const Text(
              'ยังไม่มีคลิปจากคนที่คุณติดตาม',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
