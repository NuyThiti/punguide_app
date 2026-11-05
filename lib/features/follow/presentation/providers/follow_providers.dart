import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// What this run of the app has learnt from the viewer's own follow taps,
/// keyed by the other account's id.
///
/// The server is the truth, but each screen reads it separately — the trip
/// page's author chip, a Puntok clip, someone's profile, a list row — so a
/// tap on one would leave the others stale until they re-read. Every screen
/// therefore resolves "do I follow them" as *ledger first, then whatever its
/// own response said*, and they all agree the moment the tap lands.
@immutable
class FollowLedger {
  const FollowLedger({
    this.following = const <String, bool>{},
    this.summaries = const <String, FollowSummary>{},
  });

  /// The viewer's latest intent per account — set optimistically on tap.
  final Map<String, bool> following;

  /// The followee's counts as follow / unfollow last answered them.
  final Map<String, FollowSummary> summaries;

  bool? isFollowing(String userId) => following[userId];

  FollowLedger _withFollowing(String userId, bool? value) {
    final next = Map<String, bool>.of(following);
    value == null ? next.remove(userId) : next[userId] = value;
    return FollowLedger(following: next, summaries: summaries);
  }

  FollowLedger _withSummary(String userId, FollowSummary summary) =>
      FollowLedger(
        following: {...following, userId: summary.isFollowing},
        summaries: {...summaries, userId: summary},
      );
}

/// Resets whenever the session changes: who "I" am is part of every answer.
final followLedgerProvider =
    StateNotifierProvider<FollowLedgerController, FollowLedger>((ref) {
  ref.watch(authSessionProvider);
  return FollowLedgerController(ref);
});

class FollowLedgerController extends StateNotifier<FollowLedger> {
  FollowLedgerController(this._ref) : super(const FollowLedger());

  final Ref _ref;

  /// Follows or unfollows [userId]. The button flips before the request and
  /// flips back if the server refuses; the error is rethrown for the caller
  /// to say so.
  Future<FollowSummary> setFollowing(String userId, bool follow) async {
    final before = state.isFollowing(userId);
    state = state._withFollowing(userId, follow);
    try {
      final api = await _ref.read(plunoApiProvider.future);
      final summary = follow
          ? await api.follows.follow(userId)
          : await api.follows.unfollow(userId);
      if (mounted) state = state._withSummary(userId, summary);
      // The viewer's own "Following" count moved too.
      _ref.invalidate(myFollowSummaryProvider);
      return summary;
    } catch (_) {
      if (mounted) state = state._withFollowing(userId, before);
      rethrow;
    }
  }

  /// Takes [userId] off the viewer's followers. Not a block — they can follow
  /// again. Returns the viewer's own new counts.
  Future<FollowSummary> removeFollower(String userId) async {
    final api = await _ref.read(plunoApiProvider.future);
    final mine = await api.follows.removeFollower(userId);
    _ref.invalidate(myFollowSummaryProvider);
    return mine;
  }
}

/// Someone's public profile — `GET /users/:userId`. `isFollowing`,
/// `followsYou` and `isMe` are about the viewer.
///
/// Not keyed on the session: it is auto-disposed, so every visit reads it
/// fresh, and the follow ledger — which does reset on sign-out — overrides
/// `isFollowing` wherever it is shown.
final userProfileProvider = FutureProvider.autoDispose
    .family<PublicUserProfile, String>((ref, userId) async {
  final api = await ref.watch(plunoApiProvider.future);
  return api.follows.profile(userId);
});

/// The signed-in account's id and its own follower / following counts.
///
/// `GET /users/me` is not a profile (it is a 400), so the counts come from
/// `follow-summary` under the account's real id. Null when signed out or
/// when the session cannot be read — the counts then show as a dash rather
/// than an error over the profile.
final myFollowSummaryProvider =
    FutureProvider.autoDispose<({String userId, FollowSummary summary})?>(
        (ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return null;
  try {
    final myId =
        session.userId ?? (await ref.watch(currentUserProvider.future))?.id;
    if (myId == null) return null;
    final api = await ref.watch(plunoApiProvider.future);
    return (userId: myId, summary: await api.follows.summary(myId));
  } catch (_) {
    return null;
  }
});

/// How many rows one page of a follow list asks for.
const followListPageSize = 20;

typedef FollowListArgs = ({String userId, FollowListKind kind});

/// One account's followers or followings, walked a page at a time.
final followListProvider = AsyncNotifierProvider.autoDispose
    .family<FollowListNotifier, List<FollowUser>, FollowListArgs>(
  FollowListNotifier.new,
);

class FollowListNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<FollowUser>, FollowListArgs> {
  /// The endpoint sends no total: a page shorter than asked for is the end.
  bool _exhausted = false;
  bool get hasMore => !_exhausted;

  @override
  Future<List<FollowUser>> build(FollowListArgs arg) async {
    _exhausted = false;
    // Each row's isFollowing is about the viewer.
    ref.watch(authSessionProvider);
    final api = await ref.watch(plunoApiProvider.future);
    return _page(api, offset: 0);
  }

  /// Appends the next page; a no-op while one is in flight or the list is
  /// spent, so a scroll that fires twice cannot double-read.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || _exhausted || state.isLoading) return;

    state = AsyncLoading<List<FollowUser>>()
        .copyWithPrevious(AsyncData<List<FollowUser>>(current));
    state = await AsyncValue.guard(() async {
      final api = await ref.read(plunoApiProvider.future);
      final page = await _page(api, offset: current.length);
      // Someone following mid-walk shifts the window; never print a row twice.
      final seen = {for (final user in current) user.id};
      return <FollowUser>[
        ...current,
        ...page.where((user) => !seen.contains(user.id)),
      ];
    });
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final api = await ref.read(plunoApiProvider.future);
      return _page(api, offset: 0);
    });
  }

  /// Takes a row out without a re-read — after removing a follower.
  void drop(String userId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData<List<FollowUser>>(
      List<FollowUser>.unmodifiable(current.where((u) => u.id != userId)),
    );
  }

  Future<List<FollowUser>> _page(PlunoApi api, {required int offset}) async {
    final page = await api.follows.list(
      arg.userId,
      arg.kind,
      limit: followListPageSize,
      offset: offset,
    );
    _exhausted = page.length < followListPageSize;
    return page;
  }
}
