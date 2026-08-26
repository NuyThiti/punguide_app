import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../trips/presentation/providers/trip_providers.dart';

class RemixTripScreen extends ConsumerWidget {
  const RemixTripScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(selectedTripProvider(tripId));

    return Scaffold(
      appBar: AppBar(title: const Text('Remix Trip')),
      body: trip.when(
        data: (trip) {
          if (trip == null) {
            return const Center(child: Text('Trip not found.'));
          }
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duplicate "${trip.title}" and edit it into your own plan.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CoverImage(
                    source: trip.coverImage,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () async {
                    final remix =
                        await ref.read(tripActionsProvider).remixTrip(trip);
                    if (!context.mounted) return;
                    context.goNamed(
                      AppRoute.editTrip.name,
                      params: {'tripId': remix.id},
                    );
                  },
                  icon: const Icon(Icons.call_split),
                  label: const Text('Create remix and edit'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}
