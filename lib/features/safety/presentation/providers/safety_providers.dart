import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/reported_content_store.dart';

/// Where [contentFilterProvider] keeps the reported ids. Overridden in tests.
final reportedContentStoreProvider = Provider<ReportedContentStore>(
  (ref) => const PrefsReportedContentStore(),
);

/// What this device must not show the viewer, whatever a feed says.
///
/// Three sources, one test per row:
///
/// - **reported** — things the viewer reported. The server keeps them in
///   everyone's feed until enough people report them, so the reporter's own
///   copy is filtered here, and remembered across restarts.
/// - **gone** — things that answered 404 since they were listed (hidden after
///   reports, a block, deleted, made private). This run only.
/// - **blocks** — the viewer's own block ledger. `true` hides everything that
///   account wrote, the moment the block lands, without waiting for a
///   refetch; `false` records an unblock, so a profile read from before it
///   does not keep its stale `isBlocked: true`.
@immutable
class ContentFilter {
  const ContentFilter({
    this.reported = const <String>{},
    this.gone = const <String>{},
    this.blocks = const <String, bool>{},
  });

  final Set<String> reported;
  final Set<String> gone;
  final Map<String, bool> blocks;

  static String keyOf(ReportTargetType type, String id) => '${type.wire}:$id';

  bool get isEmpty =>
      reported.isEmpty && gone.isEmpty && !blocks.containsValue(true);

  /// The viewer's latest block decision about [userId], or null when this run
  /// has none — the caller then falls back to what the server said.
  bool? blockOf(String userId) => blocks[userId];

  bool isBlocked(String? userId) => userId != null && blocks[userId] == true;

  bool hides(ReportTargetType type, String id) {
    final key = keyOf(type, id);
    return reported.contains(key) || gone.contains(key);
  }

  bool hidesTrip(String id, {String? ownerId}) =>
      isBlocked(ownerId) || hides(ReportTargetType.trip, id);

  bool hidesComment(TripComment comment) =>
      isBlocked(comment.author?.id) ||
      hides(ReportTargetType.comment, comment.id);

  /// Feed rows minus everything this filter hides — the same instance back
  /// when nothing goes, so a `select` downstream sees no change.
  List<TripListItem> visibleTrips(List<TripListItem> rows) {
    if (isEmpty) return rows;
    final kept = [
      for (final row in rows)
        if (!hidesTrip(row.id, ownerId: row.creator?.id)) row,
    ];
    return kept.length == rows.length ? rows : kept;
  }

  ContentFilter copyWith({
    Set<String>? reported,
    Set<String>? gone,
    Map<String, bool>? blocks,
  }) =>
      ContentFilter(
        reported: reported ?? this.reported,
        gone: gone ?? this.gone,
        blocks: blocks ?? this.blocks,
      );
}

/// The one [ContentFilter] every feed, comment list and page reads.
///
/// Per account: it rebuilds empty when the signed-in user changes, then
/// restores that account's reported ids from the device. The blocked list is
/// pulled from `GET /users/me/blocks` by [ContentFilterNotifier.syncBlocks],
/// which the app shell calls once per sign-in.
final contentFilterProvider =
    NotifierProvider<ContentFilterNotifier, ContentFilter>(
  ContentFilterNotifier.new,
);

class ContentFilterNotifier extends Notifier<ContentFilter> {
  String? _userId;

  @override
  ContentFilter build() {
    _userId = ref.watch(authSessionProvider.select((s) => s?.userId));
    final userId = _userId;
    if (userId != null) _restore(userId);
    return const ContentFilter();
  }

  Future<void> _restore(String userId) async {
    final stored = await ref.read(reportedContentStoreProvider).read(userId);
    if (stored.isEmpty || _userId != userId) return;
    state = state.copyWith(reported: {...stored, ...state.reported});
  }

  /// Hides [id] for good on this device — called once a report is filed.
  void markReported(ReportTargetType type, String id) {
    if (type == ReportTargetType.user) return; // a user report hides nothing
    final key = ContentFilter.keyOf(type, id);
    if (state.reported.contains(key)) return;
    final next = {...state.reported, key};
    state = state.copyWith(reported: next);
    final userId = _userId;
    if (userId != null) {
      ref.read(reportedContentStoreProvider).write(userId, next);
    }
  }

  /// Hides [id] for the rest of this run — it answered 404.
  void markGone(ReportTargetType type, String id) {
    final key = ContentFilter.keyOf(type, id);
    if (state.gone.contains(key)) return;
    state = state.copyWith(gone: {...state.gone, key});
  }

  /// Records the viewer's own block / unblock of [userId].
  void recordBlock(String userId, {required bool blocked}) {
    if (state.blocks[userId] == blocked) return;
    state = state.copyWith(blocks: {...state.blocks, userId: blocked});
  }

  /// Reads every page of the blocked list into the ledger, so rows cached
  /// from before a block (on another device, say) are filtered too. Quiet on
  /// failure — the server filters the feeds anyway; this only covers caches.
  Future<void> syncBlocks() async {
    final userId = ref.read(authSessionProvider)?.userId;
    if (userId == null) return;
    try {
      final api = await ref.read(plunoApiProvider.future);
      final found = <String>{};
      var offset = 0;
      // A hard stop, in case `total` and the pages ever disagree.
      for (var page = 0; page < 20; page++) {
        final result = await api.safety.blocked(
          limit: SafetyApi.maxBlocksPageSize,
          offset: offset,
        );
        found.addAll(result.items.map((user) => user.id));
        if (!result.hasMore || result.items.isEmpty) break;
        offset += result.items.length;
      }
      if (ref.read(authSessionProvider)?.userId != userId) return;
      state = state.copyWith(blocks: {
        for (final id in found) id: true,
        // A tap made while the list was loading is newer than the list.
        ...state.blocks,
      });
    } catch (error) {
      debugPrint('ContentFilter.syncBlocks failed: $error');
    }
  }
}
