import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../trips/presentation/providers/trip_providers.dart';
import 'create_trip_screen.dart';

class EditTripScreen extends ConsumerWidget {
  const EditTripScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(selectedTripProvider(tripId));
    return trip.when(
      data: (trip) {
        if (trip == null) {
          return const Scaffold(body: Center(child: Text('Trip not found.')));
        }
        return CreateTripScreen(trip: trip);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Scaffold(body: Center(child: Text(error.toString()))),
    );
  }
}
