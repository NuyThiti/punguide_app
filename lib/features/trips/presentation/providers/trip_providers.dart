import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart' as api;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/isar_service.dart';
import '../../data/datasources/isar_trip_local_data_source.dart';
import '../../data/datasources/trip_local_data_source.dart';
import '../../data/mock_trips.dart';
import '../../data/repositories/isar_trip_repository.dart';
import '../../domain/models/trip.dart';
import '../../domain/repositories/trip_repository.dart';

final isarProvider = FutureProvider<Isar>((ref) => IsarService.open());

final tripLocalDataSourceProvider = FutureProvider<TripLocalDataSource>((ref) async {
  final isar = await ref.watch(isarProvider.future);
  final dataSource = IsarTripLocalDataSource(isar);

  // Seed the offline cache so the app is useful before a backend exists.
  if (await dataSource.isEmpty()) {
    for (final trip in mockTrips) {
      await dataSource.upsertTrip(trip);
    }
  }

  return dataSource;
});

final tripRepositoryProvider = FutureProvider<TripRepository>((ref) async {
  final dataSource = await ref.watch(tripLocalDataSourceProvider.future);
  return IsarTripRepository(dataSource);
});

final tripListProvider = FutureProvider<List<Trip>>((ref) async {
  final repository = await ref.watch(tripRepositoryProvider.future);
  return repository.getTrips();
});

final savedTripsProvider = FutureProvider<List<Trip>>((ref) async {
  final repository = await ref.watch(tripRepositoryProvider.future);
  return repository.getSavedTrips();
});

/// A trip for the detail screen, local cache first.
///
/// Feed rows come from the server and were never written to Isar, so a miss
/// falls back to `GET /trips/:id` rather than showing "not found".
final selectedTripProvider =
    FutureProvider.family<Trip?, String>((ref, tripId) async {
  final repository = await ref.watch(tripRepositoryProvider.future);
  final local = await repository.getTrip(tripId);
  if (local != null) return local;

  try {
    final client = await ref.watch(plunoApiProvider.future);
    return _tripFromApi(await client.trips.byId(tripId));
  } on api.ApiException catch (failure) {
    if (failure.isNotFound || failure.isForbidden) return null;
    rethrow;
  }
});

/// Flattens the API trip onto the local model the detail screen renders.
///
/// The itinerary is dropped on purpose — the local [Trip] has no days, so the
/// screen shows the header facts until it is ported to [api.ApiTrip].
Trip _tripFromApi(api.ApiTrip trip) => Trip(
      id: trip.id,
      title: trip.title,
      destination: trip.destination,
      coverImage:
          trip.coverImage?.urls.large ?? AppConstants.defaultCoverImage,
      budget: trip.totalBudget,
      duration: trip.schedule.durationDays ?? 0,
      description: _briefLine(trip.brief),
      createdAt: trip.createdAt,
      updatedAt: trip.updatedAt,
      isSaved: trip.isSaved,
    );

/// The planner's style tags as one line; empty when they filled in nothing.
String _briefLine(api.TripPlanBrief? brief) {
  if (brief == null) return '';
  return <String>[
    ...brief.styles.map((style) => style.name),
    ...brief.customStyles,
  ].join(' · ');
}

final tripActionsProvider = Provider<TripActions>((ref) => TripActions(ref));

class TripActions {
  const TripActions(this._ref);

  final Ref _ref;

  Future<void> saveTrip(Trip trip) async {
    final repository = await _ref.read(tripRepositoryProvider.future);
    await repository.saveTrip(trip);
    _ref.invalidate(tripListProvider);
    _ref.invalidate(savedTripsProvider);
    _ref.invalidate(selectedTripProvider(trip.id));
  }

  Future<void> removeTrip(String id) async {
    final repository = await _ref.read(tripRepositoryProvider.future);
    await repository.unsaveTrip(id);
    _ref.invalidate(tripListProvider);
    _ref.invalidate(savedTripsProvider);
    _ref.invalidate(selectedTripProvider(id));
  }

  Future<Trip> createTrip({
    required String title,
    required String destination,
    required String coverImage,
    required double budget,
    required int duration,
    required String description,
  }) async {
    final now = DateTime.now();
    final trip = Trip(
      id: '${destination.toLowerCase().replaceAll(' ', '-')}-${now.millisecondsSinceEpoch}',
      title: title,
      destination: destination,
      coverImage: coverImage,
      budget: budget,
      duration: duration,
      description: description,
      createdAt: now,
      updatedAt: now,
      isSaved: true,
    );
    debugPrint('Creating trip: $trip');
    try {
      await saveTrip(trip);
      debugPrint('Created trip saved: ${trip.id}');
    } catch (error, stackTrace) {
      debugPrint('Create trip save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
    return trip;
  }

  Future<Trip> remixTrip(Trip source) async {
    final now = DateTime.now();
    final remix = source.copyWith(
      id: '${source.id}-remix-${now.millisecondsSinceEpoch}',
      title: '${source.title} Remix',
      createdAt: now,
      updatedAt: now,
      isSaved: true,
    );
    await saveTrip(remix);
    return remix;
  }
}
