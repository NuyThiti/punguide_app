import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../saved_trips/presentation/saved_trips_notifier.dart';
import '../../trips/domain/models/trip.dart';
import '../../trips/presentation/providers/trip_providers.dart';
import '../data/mock_destinations.dart';
import 'widgets/destination_card.dart';
import 'widgets/home_filter_bar.dart';
import 'widgets/home_hero.dart';
import 'widgets/pun_guide_card.dart';

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
  static const _avatarImage =
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?crop=faces&cs=tinysrgb&fit=crop&fm=jpg&q=80&w=160&h=160';

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(tripListProvider);
    final showDestinations = _categoryIndex != 2;
    final showPunGuide = _categoryIndex != 1;

    return AppFrame(
      background: AppColors.screen,
      child: Stack(
        children: [
          ListView(
            padding:
                EdgeInsets.only(bottom: AppBottomNav.heightOf(context) + 16),
            physics: const BouncingScrollPhysics(),
            children: [
              HomeHero(
                coverImage: _heroImage,
                avatarImage: _avatarImage,
                onProfile: () => context.goNamed(AppRoute.profile.name),
                onFindTrip: () => context.goNamed(AppRoute.discover.name),
                onShareTrip: () => context.goNamed(AppRoute.createTrip.name),
              ),
              const SizedBox(height: 18),
              HomeFilterBar(
                categories: _categories,
                activeIndex: _categoryIndex,
                onSelected: (index) => setState(() => _categoryIndex = index),
                onSearch: () => context.goNamed(AppRoute.discover.name),
              ),
              if (showDestinations) ...[
                const SizedBox(height: 22),
                HomeSectionHeader(
                  title: 'Top Destination',
                  onSeeAll: () => context.goNamed(AppRoute.discover.name),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: DestinationCard.height,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: mockDestinations.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => DestinationCard(
                      destination: mockDestinations[index],
                      onTap: () => context.goNamed(AppRoute.discover.name),
                    ),
                  ),
                ),
              ],
              if (showPunGuide) ...[
                const SizedBox(height: 24),
                HomeSectionHeader(
                  title: 'Top PunGuide',
                  onSeeAll: () => context.goNamed(AppRoute.discover.name),
                ),
                const SizedBox(height: 12),
                trips.when(
                  data: _buildPunGuideGrid,
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => _ErrorState(message: error.toString()),
                ),
              ],
            ],
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

  Widget _buildPunGuideGrid(List<Trip> items) {
    if (items.isEmpty) {
      return const _EmptyState(
        title: 'ยังไม่มีทริป',
        subtitle: 'เริ่มปันไกด์ทริปแรกของคุณได้เลย',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // The text block under the cover is a fixed height, so size each tile
        // from the cover's own aspect ratio instead of a single ratio that
        // only fits one screen width.
        final tileWidth = (constraints.maxWidth - 32 - 12) / 2;
        final extent = PunGuideCard.tileExtentFor(tileWidth);

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
            mainAxisExtent: extent,
          ),
          itemBuilder: (context, index) {
            final trip = items[index];
            return PunGuideCard(
              trip: trip,
              onTap: () => context.goNamed(
                AppRoute.tripDetail.name,
                params: {'tripId': trip.id},
              ),
              onSave: () => _toggleSaved(trip),
            );
          },
        );
      },
    );
  }

  void _toggleSaved(Trip trip) {
    final notifier = ref.read(savedTripsNotifierProvider.notifier);
    if (trip.isSaved) {
      notifier.unsaveTrip(trip.id);
    } else {
      notifier.saveTrip(trip);
    }
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
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Could not load trips.\n$message',
        textAlign: TextAlign.center,
      ),
    );
  }
}
