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
import '../../home/presentation/providers/home_feed_providers.dart';
import '../domain/nearby_trip.dart';
import 'providers/paigun_providers.dart';
import 'widgets/paigun_filter_bar.dart';
import 'widgets/paigun_grid.dart';
import 'widgets/paigun_header.dart';

/// ไปกัน — trips read from where the traveller is standing.
///
/// The corpus is the public feed Home already holds (see [paigunTripsProvider]),
/// so switching chips re-orders a list in memory rather than calling the API.
class PaigunScreen extends ConsumerWidget {
  const PaigunScreen({super.key});

  /// How many cards a section shows while both are on screen. Tapping the
  /// section's own chip lifts the cap.
  static const int _previewCount = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(paigunFilterProvider);
    final origin = ref.watch(paigunOriginProvider);
    final nearMe = ref.watch(nearMeTripsProvider);
    final topPunGuide = ref.watch(topPunGuideTripsProvider);

    final showNearMe = filter != PaigunFilter.topPunGuide;
    final showTop = filter != PaigunFilter.nearMe;
    final capped = filter == PaigunFilter.all;

    return AppFrame(
      background: AppColors.screen,
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => ref.read(homeFeedProvider.notifier).refresh(),
            child: ListView(
              padding:
                  EdgeInsets.only(bottom: AppBottomNav.heightOf(context) + 16),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                PaigunHeader(
                  origin: origin,
                  onBack: () => _close(context),
                  onTune: () => context.goNamed(AppRoute.search.name),
                ),
                const SizedBox(height: 18),
                PaigunFilterBar(
                  selected: filter,
                  onSelected: (next) =>
                      ref.read(paigunFilterProvider.notifier).state = next,
                ),
                if (showNearMe) ...[
                  const SizedBox(height: 18),
                  const PaigunSectionHeader(title: 'Near Me'),
                  const SizedBox(height: 12),
                  _Section(
                    rows: nearMe,
                    limit: capped ? _previewCount : null,
                    emptyMessage: 'ยังไม่มีทริปใกล้ตำแหน่งของคุณ',
                    onOpen: (row) => _openTrip(context, row),
                    onSave: (row) => _toggleSaved(context, ref, row),
                    onRetry: () => ref.read(homeFeedProvider.notifier).refresh(),
                  ),
                ],
                if (showTop) ...[
                  const SizedBox(height: 10),
                  const PaigunSectionHeader(title: 'Top PunGuide'),
                  const SizedBox(height: 12),
                  _Section(
                    rows: topPunGuide,
                    limit: capped ? _previewCount : null,
                    emptyMessage: 'ยังไม่มีทริปปันไกด์',
                    onOpen: (row) => _openTrip(context, row),
                    onSave: (row) => _toggleSaved(context, ref, row),
                    onRetry: () => ref.read(homeFeedProvider.notifier).refresh(),
                  ),
                ],
              ],
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
      await ref.read(homeFeedProvider.notifier).toggleSaved(row.trip.id);
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
    required this.limit,
    required this.emptyMessage,
    required this.onOpen,
    required this.onSave,
    required this.onRetry,
  });

  final AsyncValue<List<NearbyTrip>> rows;

  /// Null shows everything.
  final int? limit;
  final String emptyMessage;
  final ValueChanged<NearbyTrip> onOpen;
  final ValueChanged<NearbyTrip> onSave;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return rows.when(
      data: (all) {
        if (all.isEmpty) return _EmptyState(message: emptyMessage);
        final shown = limit == null ? all : all.take(limit!).toList();
        return PaigunGrid(rows: shown, onOpen: onOpen, onSave: onSave);
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
