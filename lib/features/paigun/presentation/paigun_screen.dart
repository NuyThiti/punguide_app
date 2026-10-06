import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/create_sheet.dart';
import '../../home/presentation/widgets/home_assistant_fab.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/nearby_trip.dart';
import 'providers/paigun_providers.dart';
import 'widgets/paigun_filter_bar.dart';
import 'widgets/paigun_grid.dart';
import 'widgets/paigun_header.dart';

/// ไปกัน — trips read from where the traveller is standing.
///
/// Each wall is one `GET /trips` with the wizard's answers on the query string
/// (see [paigunFeedProvider]) — the server filters, sorts and measures, so a
/// chip is a request rather than a re-sort in memory.
class PaigunScreen extends ConsumerWidget {
  const PaigunScreen({super.key});

  /// How many cards a section shows while both are on screen. Tapping the
  /// section's own chip lifts the cap.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chip = ref.watch(paigunFilterProvider);
    final wizard = ref.watch(tripFilterProvider);
    final origin = ref.watch(paigunOriginProvider);
    final query = ref.watch(paigunQueryProvider);
    final rows = ref.watch(paigunTripsProvider);

    return AppFrame(
      background: AppColors.screen,
      child: Stack(
        children: [
          Column(
            children: [
              PaigunHeader(
                origin: origin,
                onBack: () => _close(context),
                onEditLocation: () =>
                    context.goNamed(AppRoute.locationPicker.name),
                query: query,
                onSearch: (text) =>
                    ref.read(paigunQueryProvider.notifier).state = text,
              ),
              // Pinned under the header: these chips re-sort the wall below,
              // so they have to stay reachable once the traveller is deep in
              // it. The header owns the status-bar inset, so the row never
              // lands under the clock.
              _StickyFilterBar(
                child: PaigunFilterBar(
                  selected: chip,
                  onSelected: (next) =>
                      ref.read(paigunFilterProvider.notifier).state = next,
                  // Pushed rather than swapped, so finishing the wizard — or
                  // backing out of it — drops the traveller back on the board
                  // they were reading.
                  onTune: () => context.pushNamed(AppRoute.paigunFilter.name),
                  filterCount: wizard.answeredCount,
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.loading,
                  onRefresh: () => refreshPaigunFeed(ref),
                  child: ListView(
                    padding: EdgeInsets.only(
                      bottom: AppBottomNav.heightOf(context) + 16,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: [
                      const SizedBox(height: 14),
                      // One wall under one row of chips: the chip in force is
                      // the heading, so the board does not repeat it.
                      _Section(
                        rows: rows,
                        emptyMessage: _emptyMessage(
                          chip: chip,
                          searching: query.trim().isNotEmpty,
                          filtered: !wizard.isEmpty,
                        ),
                        onOpen: (row) => _openTrip(context, row),
                        onSave: (row) => _toggleSaved(context, ref, row),
                        onRetry: () => refreshPaigunFeed(ref),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: HomeAssistantFab.bottomOffsetOf(context),
            child: HomeAssistantFab(
              onTap: () => context.goNamed(AppRoute.aiChat.name),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNav(
              active: AppRoute.paigun,
              onTap: (route) => context.goNamed(route.name),
              onCreate: () => openCreateSheet(
                context,
                onOwnPlan: () => context.goNamed(AppRoute.createTrip.name),
                onPost: () => context.goNamed(AppRoute.createPost.name),
                onUnavailable: (message) => _showMessage(context, message),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Why the wall is empty, in the traveller's own terms.
  ///
  /// A board narrowed to nothing is not the same as a board with nothing on
  /// it, and saying which is the difference between "try something else" and
  /// "come back later".
  static String _emptyMessage({
    required PaigunFilter chip,
    required bool searching,
    required bool filtered,
  }) {
    if (searching) return 'ไม่พบทริปในที่ที่ค้นหา';
    if (filtered) return 'ไม่มีทริปที่ตรงกับตัวกรอง';
    return switch (chip) {
      PaigunFilter.guide => 'ยังไม่มีคู่มือใกล้ตำแหน่งของคุณ',
      PaigunFilter.plan => 'ยังไม่มีแผนทริปใกล้ตำแหน่งของคุณ',
      PaigunFilter.topPunGuide => 'ยังไม่มีทริปปันไกด์',
      PaigunFilter.all => 'ยังไม่มีทริปใกล้ตำแหน่งของคุณ',
    };
  }

  /// Reached from the Home card as well as the nav tab, so there is not always
  /// something to pop back to.
  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.home.name);
    }
  }

  void _openTrip(BuildContext context, NearbyTrip row) {
    context.goNamed(
      AppRoute.tripDetail.name,
      params: {'tripId': row.trip.id},
    );
  }

  Future<void> _toggleSaved(
    BuildContext context,
    WidgetRef ref,
    NearbyTrip row,
  ) async {
    // Saving is the one thing on this board that needs an account; the feed
    // itself reads fine anonymously.
    if (!ref.read(isSignedInProvider)) {
      _promptSignIn(context);
      return;
    }

    try {
      await ref
          .read(paigunSavedProvider.notifier)
          .toggle(row.trip.id, wasSaved: row.isSaved);
    } on ApiException catch (failure) {
      if (!context.mounted) return;
      if (failure.isUnauthorized) {
        _promptSignIn(context);
        return;
      }
      _showMessage(
        context,
        failure.isNetworkFailure
            ? 'เชื่อมต่อไม่ได้ ลองใหม่อีกครั้ง'
            : 'บันทึกทริปไม่สำเร็จ: ${failure.message}',
      );
    }
  }

  void _promptSignIn(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('เข้าสู่ระบบก่อนเพื่อบันทึกทริป'),
        action: SnackBarAction(
          label: 'เข้าสู่ระบบ',
          onPressed: () => context.goNamed(AppRoute.login.name),
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// One heading's worth of cards, with the loading, empty and failed shapes the
/// feed can land in.
class _Section extends StatelessWidget {
  const _Section({
    required this.rows,
    required this.emptyMessage,
    required this.onOpen,
    required this.onSave,
    required this.onRetry,
  });

  final AsyncValue<List<NearbyTrip>> rows;
  final String emptyMessage;
  final ValueChanged<NearbyTrip> onOpen;
  final ValueChanged<NearbyTrip> onSave;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return rows.when(
      data: (all) {
        if (all.isEmpty) return _EmptyState(message: emptyMessage);
        return PaigunGrid(rows: all, onOpen: onOpen, onSave: onSave);
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _ErrorState(error: error, onRetry: onRetry),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.explore_off_outlined,
              size: 32, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = error is ApiException ? error as ApiException : null;
    final message = failure == null
        ? 'โหลดทริปไม่สำเร็จ'
        : failure.isNetworkFailure
            ? 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้'
            : 'โหลดทริปไม่สำเร็จ (${failure.statusCode})';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 34, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }
}

/// Opaque strip so the wall of cards scrolls *under* the chips rather than
/// showing through them.
class _StickyFilterBar extends StatelessWidget {
  const _StickyFilterBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.screen,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 15, bottom: 10),
        child: child,
      ),
    );
  }
}
