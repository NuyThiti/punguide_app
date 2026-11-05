import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../follow/presentation/providers/follow_providers.dart';
import '../../../paigun/presentation/providers/paigun_providers.dart';
import '../../../trips/presentation/providers/trip_like_providers.dart';
import '../../domain/models/puntok_post.dart';

/// The tab in force above the feed.
final puntokFeedTabProvider =
    StateProvider<PuntokFeed>((ref) => PuntokFeed.forYou);

/// How many rows one page of the feed asks for. Photo posts come back in the
/// same list and are dropped, so this is more than the clips it yields.
const puntokFeedPageSize = 50;

/// The clips for [puntokFeedTabProvider], from `GET /trips`.
///
/// A Puntok is a [puntokTripType] post whose cover is a video, so each tab
/// asks for that type and keeps the ones with a playable cover: Top Punguide by
/// `sort=popular`, For you by `sort=recent`. Following stays empty — the API
/// has no way to ask for the people the traveller follows yet.
///
/// Re-read when the session changes: `isLiked`/`isSaved` are per viewer.
final puntokFeedProvider =
    AsyncNotifierProvider<PuntokFeedNotifier, List<PuntokPost>>(
  PuntokFeedNotifier.new,
);

class PuntokFeedNotifier extends AsyncNotifier<List<PuntokPost>> {
  /// Clips shared this session, kept at the head of For you so a fresh post
  /// shows straight away even if the list has not caught up with it.
  /// Survives a tab switch: Riverpod re-runs [build] on the same notifier.
  final _shared = <PuntokPost>[];

  @override
  Future<List<PuntokPost>> build() async {
    ref.watch(authSessionProvider);
    final tab = ref.watch(puntokFeedTabProvider);
    if (tab == PuntokFeed.following) return const [];

    final api = await ref.watch(plunoApiProvider.future);
    final rows = await api.trips.feed(TripFeedQuery(
      type: puntokTripType,
      sort: tab == PuntokFeed.topPunGuide ? FeedSort.popular : FeedSort.recent,
      limit: puntokFeedPageSize,
    ));
    final clips = rows
        .map(PuntokPost.fromListItem)
        .whereType<PuntokPost>()
        .toList(growable: false);
    return _withShared(clips, tab);
  }

  List<PuntokPost> _withShared(List<PuntokPost> clips, PuntokFeed tab) {
    if (tab != PuntokFeed.forYou || _shared.isEmpty) return clips;
    final listed = {for (final clip in clips) clip.id};
    return [
      ..._shared.where((post) => !listed.contains(post.id)),
      ...clips,
    ];
  }

  /// Puts a clip the traveller just shared at the head of For you.
  void publish(PuntokPost post) {
    _shared
      ..removeWhere((existing) => existing.id == post.id)
      ..insert(0, post);
    final current = state.valueOrNull;
    if (current == null ||
        ref.read(puntokFeedTabProvider) != PuntokFeed.forYou) {
      return;
    }
    state = AsyncData([
      post,
      ...current.where((existing) => existing.id != post.id),
    ]);
  }

  /// Likes or unlikes, flipping the page first so the tap feels instant and
  /// putting it back if the server refuses. Throws the [ApiException] so the
  /// screen can tell "sign in first" (401) from anything else.
  Future<void> toggleLike(String id) async {
    final post = _find(id);
    if (post == null) return;
    final liked = !post.liked;
    _replace(post.copyWith(
      liked: liked,
      likes: post.likes + (liked ? 1 : -1),
    ));
    try {
      final api = await ref.read(plunoApiProvider.future);
      liked ? await api.trips.like(id) : await api.trips.unlike(id);
    } catch (_) {
      _replace(post);
      rethrow;
    }
    // A clip is a trip like any other, so a heart tapped here has to show on
    // the card the same post wears over on a wall.
    ref.read(tripLikedProvider.notifier).record(id, liked: liked);
  }

  /// Same shape as [toggleLike], for the bookmark.
  Future<void> toggleSave(String id) async {
    final post = _find(id);
    if (post == null) return;
    final saved = !post.saved;
    _replace(post.copyWith(saved: saved));
    try {
      final api = await ref.read(plunoApiProvider.future);
      saved ? await api.trips.save(id) : await api.trips.unsave(id);
    } catch (_) {
      _replace(post);
      rethrow;
    }
    ref.read(paigunSavedProvider.notifier).record(id, saved: saved);
  }

  PuntokPost? _find(String id) {
    for (final post in state.valueOrNull ?? const <PuntokPost>[]) {
      if (post.id == id) return post;
    }
    return null;
  }

  void _replace(PuntokPost post) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final existing in current) existing.id == post.id ? post : existing,
    ]);
    final index = _shared.indexWhere((existing) => existing.id == post.id);
    if (index >= 0) _shared[index] = post;
  }
}

/// The clips with each creator's follow badge set from the viewer's own taps,
/// and with no follow control at all on the viewer's own clips ([myId]).
///
/// The list endpoint says nothing about follows, so a clip starts unfollowed
/// and only the ledger moves it. Untouched rows come back as the same objects.
List<PuntokPost> withFollowState(
  List<PuntokPost> posts,
  FollowLedger ledger, {
  String? myId,
}) {
  if (ledger.following.isEmpty && myId == null) return posts;
  return [
    for (final post in posts)
      if (myId != null && post.authorId == myId)
        post.followable ? post.copyWith(followable: false) : post
      else
        switch (ledger.isFollowing(post.authorId ?? '')) {
          final bool following when following != post.following =>
            post.copyWith(following: following),
          _ => post,
        },
  ];
}
