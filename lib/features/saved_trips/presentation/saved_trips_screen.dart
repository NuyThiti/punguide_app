import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/trip_card.dart';
import 'saved_trips_notifier.dart';

class SavedTripsScreen extends ConsumerWidget {
  const SavedTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedTrips = ref.watch(savedTripsNotifierProvider);

    return AppFrame(
      background: AppColors.screen,
      child: Stack(
        children: [
          Column(
            children: [
              const _SavedHeader(),
              Expanded(
                child: savedTrips.when(
                  data: (trips) {
                    if (trips.isEmpty) {
                      return const _SavedEmptyState();
                    }

                    return ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        AppBottomNav.heightOf(context) + 16,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: trips.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final trip = trips[index];
                        return TripCard(
                          trip: trip,
                          onTap: () => context.goNamed(
                            AppRoute.tripDetail.name,
                            params: {'tripId': trip.id},
                          ),
                          onSave: () => ref
                              .read(savedTripsNotifierProvider.notifier)
                              .unsaveTrip(trip.id),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _SavedErrorState(message: error.toString()),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNav(
              active: AppRoute.savedTrips,
              onTap: (route) => context.goNamed(route.name),
              onCreate: () => context.goNamed(AppRoute.createTrip.name),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedHeader extends StatelessWidget {
  const _SavedHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 54, 20, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Saved Trips',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 28,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bookmark_border,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedEmptyState extends StatelessWidget {
  const _SavedEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppBottomNav.heightOf(context)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('🗺️', style: TextStyle(fontSize: 40)),
          SizedBox(height: 10),
          Text(
            'No trips found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 5),
          Text(
            'Start saving trips you love',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SavedErrorState extends StatelessWidget {
  const _SavedErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not load saved trips.\n$message',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
