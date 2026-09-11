import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/puntok_mock_posts.dart';
import '../../domain/models/puntok_post.dart';

/// The tab in force above the feed.
final puntokFeedTabProvider =
    StateProvider<PuntokFeed>((ref) => PuntokFeed.forYou);

/// The clips for [puntokFeedTabProvider], plus this session's toggles.
///
/// Puntok has no endpoint yet. One notifier holds the whole mock corpus and
/// hands out a slice of it, so a like survives switching tabs and back:
/// `following` keeps the creators the traveller follows, `topPunGuide` orders
/// by likes, `forYou` is feed order.
final puntokFeedProvider =
    NotifierProvider<PuntokFeedNotifier, List<PuntokPost>>(
  PuntokFeedNotifier.new,
);

class PuntokFeedNotifier extends Notifier<List<PuntokPost>> {
  /// Survives a rebuild — Riverpod re-runs [build] on the same notifier when
  /// the tab changes, so the toggles are not reset by a tab switch.
  List<PuntokPost> _all = puntokMockPosts;

  @override
  List<PuntokPost> build() => _slice(ref.watch(puntokFeedTabProvider));

  List<PuntokPost> _slice(PuntokFeed tab) {
    switch (tab) {
      case PuntokFeed.forYou:
        return _all;
      case PuntokFeed.following:
        return _all.where((post) => post.following).toList(growable: false);
      case PuntokFeed.topPunGuide:
        return ([..._all]..sort((a, b) => b.likes.compareTo(a.likes)))
            .toList(growable: false);
    }
  }

  void toggleLike(String id) => _update(
        id,
        (post) => post.copyWith(
          liked: !post.liked,
          likes: post.liked ? post.likes - 1 : post.likes + 1,
        ),
      );

  void toggleSave(String id) => _update(
        id,
        (post) => post.copyWith(
          saved: !post.saved,
          saves: post.saved ? post.saves - 1 : post.saves + 1,
        ),
      );

  void toggleFollow(String id) =>
      _update(id, (post) => post.copyWith(following: !post.following));

  void _update(String id, PuntokPost Function(PuntokPost) change) {
    _all = _all
        .map((post) => post.id == id ? change(post) : post)
        .toList(growable: false);
    state = _slice(ref.read(puntokFeedTabProvider));
  }
}
