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
import 'providers/my_trips_providers.dart';
import 'widgets/my_trip_card.dart';

/// ทริปฉัน — everything the traveller has made, from `GET /trips/mine`.
///
/// The one list in the app that shows a trip before the world sees it: drafts
/// and private trips never reach the feed, so without this page a plan that
/// was closed halfway through is unreachable.
class MyTripsScreen extends ConsumerWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    final filter = ref.watch(myTripsFilterProvider);
    final rows = ref.watch(visibleMyTripsProvider);

    return AppFrame(
      background: AppColors.screen,
      child: Stack(
        children: [
          Column(
            children: [
              _MyTripsHeader(
                onBack: () => _close(context),
                count: ref.watch(myTripsProvider).valueOrNull?.length,
              ),
              _FilterRow(
                selected: filter,
                onSelected: (next) =>
                    ref.read(myTripsFilterProvider.notifier).state = next,
              ),
              Expanded(
                child: !signedIn
                    ? const _SignedOutState()
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(myTripsProvider.notifier).refresh(),
                        child: rows.when(
                          data: (trips) => trips.isEmpty
                              ? _EmptyState(filter: filter)
                              : _TripList(trips: trips),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) => _ErrorState(
                            error: error,
                            onRetry: () =>
                                ref.read(myTripsProvider.notifier).refresh(),
                          ),
                        ),
                      ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNav(
              // Reached from the profile menu, so the tab the traveller came
              // through stays lit rather than nothing at all.
              active: AppRoute.profile,
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

  /// Opened from the profile menu, but also reachable as a deep link, so there
  /// is not always something to pop back to.
  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.profile.name);
    }
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TripList extends ConsumerWidget {
  const _TripList({required this.trips});

  final List<TripListItem> trips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        AppBottomNav.heightOf(context) + 16,
      ),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: trips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final trip = trips[index];
        return MyTripCard(
          trip: trip,
          onTap: () => context.goNamed(
            AppRoute.tripDetail.name,
            params: {'tripId': trip.id},
          ),
          // The editor behind this is the plan editor; a post has no plan, so
          // the row offers nothing rather than opening an editor for days it
          // does not have.
          onEdit: trip.type == TripType.content
              ? null
              : () => context.goNamed(
                    AppRoute.editTrip.name,
                    params: {'tripId': trip.id},
                  ),
          onDelete: () => _confirmDelete(context, ref, trip),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TripListItem trip,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'ลบทริปนี้',
          style: TextStyle(
            color: AppColors.foreground,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '“${trip.title}” จะถูกลบพร้อมกับแผน รูป และค่าใช้จ่ายทั้งหมด '
          'และกู้คืนไม่ได้',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'ยกเลิก',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'ลบทริป',
              style: TextStyle(
                color: AppColors.brandOrangeDeep,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(myTripsProvider.notifier).delete(trip.id);
      messenger.showSnackBar(const SnackBar(content: Text('ลบทริปแล้ว')));
    } on ApiException catch (failure) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failure.isNetworkFailure
                ? 'เชื่อมต่อไม่ได้ ลองใหม่อีกครั้ง'
                : 'ลบทริปไม่สำเร็จ: ${failure.message}',
          ),
        ),
      );
    }
  }
}

/// Back button, title, and how many trips are on the shelf.
class _MyTripsHeader extends StatelessWidget {
  const _MyTripsHeader({required this.onBack, this.count});

  final VoidCallback onBack;

  /// Null until the first read lands, so the line does not flash "0 ทริป".
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 10,
        16,
        10,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.chipBorder),
              ),
              child: const Icon(Icons.arrow_back, size: 19),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ทริปฉัน',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (count != null)
                  Text(
                    '$count ทริปที่คุณสร้างไว้',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ทั้งหมด / แผนเที่ยว / โพสต์, the chip in force filled dark — the same
/// control the ไปกัน board uses, so the two shelves read as one family.
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelected});

  final MyTripsFilter selected;
  final ValueChanged<MyTripsFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    // Scrolls rather than wraps: a fourth chip, or a longer Thai label on a
    // 320pt phone, must push sideways instead of overflowing the row.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: MyTripsFilter.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = MyTripsFilter.values[index];
            return _Chip(
              label: filter.label,
              active: filter == selected,
              onTap: () => onSelected(filter),
            );
          },
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.paigunControl : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: active ? AppColors.paigunControl : AppColors.chipBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.foreground,
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// The shelf belongs to an account, so there is nothing to show — not even an
/// empty list — until there is one.
class _SignedOutState extends StatelessWidget {
  const _SignedOutState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppBottomNav.heightOf(context)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🧳', style: TextStyle(fontSize: 38)),
          const SizedBox(height: 10),
          const Text(
            'เข้าสู่ระบบเพื่อดูทริปของคุณ',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandOrange,
            ),
            onPressed: () => context.goNamed(AppRoute.login.name),
            child: const Text('เข้าสู่ระบบ'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final MyTripsFilter filter;

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      MyTripsFilter.all => 'ยังไม่มีทริปของคุณ เริ่มวางแผนทริปแรกได้เลย',
      MyTripsFilter.plans => 'ยังไม่มีแผนเที่ยวของคุณ',
      MyTripsFilter.posts => 'ยังไม่มีโพสต์ของคุณ',
    };

    // Scrollable so pull-to-refresh still works on an empty shelf.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.only(bottom: AppBottomNav.heightOf(context)),
      children: [
        const SizedBox(height: 90),
        const Center(child: Text('🗺️', style: TextStyle(fontSize: 38))),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.only(bottom: AppBottomNav.heightOf(context)),
      children: [
        const SizedBox(height: 80),
        const Center(
          child: Icon(Icons.cloud_off, size: 34, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('ลองใหม่'),
          ),
        ),
      ],
    );
  }
}
