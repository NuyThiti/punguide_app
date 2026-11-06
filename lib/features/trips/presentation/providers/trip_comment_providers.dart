import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The comment count each trip has reached since this session wrote to its
/// thread, by trip id — the twin of the like and save ledgers.
///
/// A trip can be on its own page and in a Puntok pager at once, each holding
/// its own copy of `commentCount`; posting or deleting in one sheet has to
/// move the 💬 everywhere, at once, without re-reading the trip. Screens show
/// `ledger[id] ?? row.commentCount`.
final tripCommentCountProvider =
    NotifierProvider<TripCommentCountNotifier, Map<String, int>>(
  TripCommentCountNotifier.new,
);

class TripCommentCountNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const <String, int>{};

  void record(String tripId, int count) {
    state = <String, int>{...state, tripId: count < 0 ? 0 : count};
  }
}
