import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import 'providers/home_feed_providers.dart';
import 'widgets/destination_card.dart';
import 'widgets/home_filter_bar.dart';
import 'widgets/home_hero.dart';
import 'widgets/pun_guide_grid.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.activeRoute = AppRoute.home});

  final AppRoute activeRoute;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _categoryIndex = 0;

  static const _categories = <String>['All', 'Top Destination', 'Top PunGuide'];

  static const _heroImage = 'assets/images/home_hero.jpg';

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(homeFeedProvider);
    final destinations = ref.watch(topDestinationsProvider);
    final session = ref.watch(authSessionProvider);
    final showDestinations = _categoryIndex != 2;
    final showPunGuide = _categoryIndex != 1;

    return AppFrame(
      background: AppColors.screen,
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () =>
                ref.read(homeFeedProvider.notifier).refresh(),
            child: ListView(
              padding:
                  EdgeInsets.only(bottom: AppBottomNav.heightOf(context) + 16),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                HomeHero(
                  coverImage: _heroImage,
                  avatarImage: session?.avatarImage,
                  onProfile: () => context.goNamed(AppRoute.profile.name),
                  onFindTrip: _openSearch,
                  onShareTrip: () => context.goNamed(AppRoute.createTrip.name),
                ),
                const SizedBox(height: 18),
                HomeFilterBar(
                  categories: _categories,
                  activeIndex: _categoryIndex,
                  onSelected: (index) => setState(() => _categoryIndex = index),
                  onSearch: _openSearch,
                ),
                if (showDestinations && destinations.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  HomeSectionHeader(
                    title: 'Top Destination',
                    onSeeAll: _openSearch,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: DestinationCard.height,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: destinations.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) => DestinationCard(
                        destination: destinations[index],
                        onTap: () => _openSearch(destinations[index].name),
                      ),
                    ),
                  ),
                ],
                if (showPunGuide) ...[
                  const SizedBox(height: 24),
                  HomeSectionHeader(
                    title: 'Top PunGuide',
                    onSeeAll: _openSearch,
                  ),
                  const SizedBox(height: 12),
                  feed.when(
                    data: _buildPunGuideGrid,
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => _ErrorState(
                      error: error,
                      onRetry: () =>
                          ref.read(homeFeedProvider.notifier).refresh(),
                    ),
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
              active: widget.activeRoute,
              onTap: (route) => context.goNamed(route.name),
              onCreate: () => context.goNamed(AppRoute.createTrip.name),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens search, optionally seeded with a destination the traveller tapped.
  void _openSearch([String? query]) {
    context.goNamed(
      AppRoute.search.name,
      queryParams: query == null ? const {} : {'q': query},
    );
  }

  Widget _buildPunGuideGrid(List<TripListItem> items) {
    if (items.isEmpty) {
      return const _EmptyState(
        title: 'ยังไม่มีทริป',
        subtitle: 'เริ่มปันไกด์ทริปแรกของคุณได้เลย',
      );
    }

    return PunGuideGrid(
      trips: items,
      onOpen: (trip) => context.goNamed(
        AppRoute.tripDetail.name,
        params: {'tripId': trip.id},
      ),
      onSave: _toggleSaved,
    );
  }

  Future<void> _toggleSaved(TripListItem trip) async {
    // Saving is the one thing on this screen that needs an account; the feed
    // itself reads fine anonymously.
    if (!ref.read(isSignedInProvider)) {
      _promptSignIn();
      return;
    }

    try {
      await ref.read(homeFeedProvider.notifier).toggleSaved(trip.id);
    } on ApiException catch (failure) {
      if (!mounted) return;
      if (failure.isUnauthorized) {
        _promptSignIn();
        return;
      }
      _showMessage(
        failure.isNetworkFailure
            ? 'เชื่อมต่อไม่ได้ ลองใหม่อีกครั้ง'
            : 'บันทึกทริปไม่สำเร็จ: ${failure.message}',
      );
    }
  }

  void _promptSignIn() {
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Text('🗺️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 34, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            failure?.message ?? error.toString(),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }
}
