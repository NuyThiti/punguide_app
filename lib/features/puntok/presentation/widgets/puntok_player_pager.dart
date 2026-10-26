import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/models/puntok_post.dart';
import 'puntok_post_view.dart';

/// The vertical pager of clips, and the player window that feeds it.
///
/// Holds a decoded player for the page in view and the one after it, plays the
/// first and pauses the rest, and lets go of everything else — so a feed of
/// fifty clips never holds fifty decoders. Shared by the Puntok feed and the
/// single-wall viewer, which differ only in their chrome.
class PuntokPlayerPager extends StatefulWidget {
  const PuntokPlayerPager({
    super.key,
    required this.posts,
    required this.bottomInset,
    required this.onLike,
    required this.onSave,
    required this.onComment,
    required this.onShare,
    required this.onCreator,
    required this.onFollow,
    required this.onOpenPlan,
    this.controller,
    this.initialIndex = 0,
    this.onIndexChanged,
  });

  final List<PuntokPost> posts;

  /// Room the bottom nav takes, so the rail and caption clear it.
  final double bottomInset;

  final ValueChanged<PuntokPost> onLike;
  final ValueChanged<PuntokPost> onSave;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onCreator;
  final VoidCallback onFollow;
  final ValueChanged<String> onOpenPlan;

  /// Supply one to drive the pager from outside — the feed jumps to the top
  /// when its tab changes.
  final PageController? controller;

  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;

  @override
  State<PuntokPlayerPager> createState() => _PuntokPlayerPagerState();
}

class _PuntokPlayerPagerState extends State<PuntokPlayerPager>
    with WidgetsBindingObserver {
  late final PageController _pageController =
      widget.controller ?? PageController(initialPage: widget.initialIndex);

  /// Players keyed by post id, so paging back reuses what is already decoded
  /// instead of fetching the clip again.
  final _players = <String, VideoPlayerController>{};

  late int _index = widget.initialIndex;
  bool _paused = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => syncPlayers());
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
    // Only ours to dispose; a controller passed in belongs to the caller.
    if (widget.controller == null) _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PuntokPlayerPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new page of rows, a tab switch or a fresh share can all move what is
    // under the current page — recompute the window, or a clip that is no
    // longer on screen keeps its audio running.
    if (_activeId(oldWidget.posts) != _activeId(widget.posts)) {
      syncPlayers();
    }
  }

  /// Nothing should keep playing behind a backgrounded app or another route.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncPlayers();
    } else {
      for (final player in _players.values) {
        player.pause();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts = widget.posts;
    // A list can be shorter than the page we were on, or empty.
    if (posts.isNotEmpty && _index >= posts.length) {
      _index = posts.length - 1;
    }

    return PageView.builder(
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
          bottomInset: widget.bottomInset,
          onTogglePlay: _togglePlay,
          onLike: () => widget.onLike(post),
          onSave: () => widget.onSave(post),
          onFollow: widget.onFollow,
          onOpenPlan: widget.onOpenPlan,
          onComment: widget.onComment,
          onShare: widget.onShare,
          onCreator: widget.onCreator,
        );
      },
    );
  }

  /// Recomputes the player window. Public so a screen can call it after the
  /// list under the pager has been replaced wholesale.
  Future<void> syncPlayers() async {
    final posts = widget.posts;
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

  /// Id of the post the current page lands on, or null if that list cannot
  /// fill the page.
  String? _activeId(List<PuntokPost> posts) {
    if (posts.isEmpty) return null;
    return posts[_index.clamp(0, posts.length - 1)].id;
  }

  void _onPageChanged(int index) {
    setState(() {
      _index = index;
      _paused = false;
    });
    widget.onIndexChanged?.call(index);
    syncPlayers();
  }

  void _togglePlay() {
    final activeId = _activeId(widget.posts);
    final player = activeId == null ? null : _players[activeId];
    if (player == null || !player.value.isInitialized) return;

    setState(() => _paused = !_paused);
    _paused ? player.pause() : player.play();
  }

  Future<void> _load(PuntokPost post) async {
    if (_players.containsKey(post.id)) return;

    // Clips stream from the server; a bundled asset path still plays, which
    // is what the widget tests hand in.
    final player = post.video.startsWith('http')
        ? VideoPlayerController.networkUrl(Uri.parse(post.video))
        : VideoPlayerController.asset(post.video);
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
}
