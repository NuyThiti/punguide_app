import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/create_post/presentation/create_post_screen.dart';
import '../../features/create_trip/presentation/create_trip_screen.dart';
import '../../features/create_trip/presentation/edit_trip_brief_screen.dart';
import '../../features/create_trip/presentation/edit_trip_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/location_access/presentation/location_access_screen.dart';
import '../../features/location_access/presentation/location_picker_screen.dart';
import '../../features/location_access/presentation/providers/location_providers.dart';
import '../../features/paigun/presentation/paigun_filter_screen.dart';
import '../../features/paigun/presentation/paigun_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/puntok/presentation/puntok_screen.dart';
import '../../features/remix_trip/presentation/remix_trip_screen.dart';
import '../../features/saved_trips/presentation/saved_trips_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/trip_detail/presentation/trip_detail_screen.dart';

enum AppRoute {
  home,
  login,
  discover,
  paigun,
  paigunFilter,
  search,
  tripDetail,
  createTrip,
  createPost,
  editTrip,
  editTripBrief,
  savedTrips,
  remixTrip,
  puntok,
  profile,
  locationAccess,
  locationPicker,
}

/// Holds a location-led screen behind the Location Access page until the
/// traveller has answered it.
///
/// Returns null — carry on — the moment there is any answer at all, including
/// "ไว้ทีหลังนะ": a refusal is a decision, and re-asking on the next tap would
/// make the board unreachable.
///
/// The answer lives in memory, so the page comes back once per run of the app.
/// Once a real location plugin lands this should ask it for the OS's actual
/// status instead, which survives restarts and is the real source of truth —
/// see [LocationService].
String? _locationGate(BuildContext context, GoRouterState state) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(locationPermissionProvider) != null) return null;

  // Carry where they were heading, so answering puts them back on their way
  // instead of somewhere the app chose for them.
  return '/location?from=${Uri.encodeComponent(state.location)}';
}

/// Every route swaps instantly — no slide or fade. The bottom tabs are peers,
/// so a push animation would imply a hierarchy the app does not have.
Page<void> _instantPage(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: AppRoute.home.name,
      pageBuilder: (context, state) => _instantPage(state, const HomeScreen()),
    ),
    GoRoute(
      path: '/discover',
      name: AppRoute.discover.name,
      pageBuilder: (context, state) => _instantPage(
        state,
        const HomeScreen(activeRoute: AppRoute.discover),
      ),
    ),
    GoRoute(
      path: '/paigun',
      name: AppRoute.paigun.name,
      // The whole board is ordered by where the traveller is standing, so the
      // ask comes before it rather than after.
      redirect: _locationGate,
      pageBuilder: (context, state) =>
          _instantPage(state, const PaigunScreen()),
    ),
    GoRoute(
      path: '/paigun/filter',
      name: AppRoute.paigunFilter.name,
      // Not gated: the wizard asks about dates, heads, budget and style, none
      // of which need to know where the traveller is standing.
      pageBuilder: (context, state) =>
          _instantPage(state, const PaigunFilterScreen()),
    ),
    GoRoute(
      path: '/search',
      name: AppRoute.search.name,
      pageBuilder: (context, state) => _instantPage(
        state,
        SearchScreen(initialQuery: state.queryParams['q']),
      ),
    ),
    GoRoute(
      path: '/trips/:tripId',
      name: AppRoute.tripDetail.name,
      pageBuilder: (context, state) => _instantPage(
        state,
        TripDetailScreen(tripId: state.params['tripId']!),
      ),
    ),
    GoRoute(
      path: '/trips/:tripId/edit',
      name: AppRoute.editTrip.name,
      pageBuilder: (context, state) => _instantPage(
        state,
        EditTripScreen(tripId: state.params['tripId']!),
      ),
    ),
    GoRoute(
      path: '/trips/:tripId/edit/brief',
      name: AppRoute.editTripBrief.name,
      pageBuilder: (context, state) => _instantPage(
        state,
        EditTripBriefScreen(tripId: state.params['tripId']!),
      ),
    ),
    GoRoute(
      path: '/trips/:tripId/remix',
      name: AppRoute.remixTrip.name,
      pageBuilder: (context, state) => _instantPage(
        state,
        RemixTripScreen(tripId: state.params['tripId']!),
      ),
    ),
    GoRoute(
      path: '/create',
      name: AppRoute.createTrip.name,
      pageBuilder: (context, state) =>
          _instantPage(state, const CreateTripScreen()),
    ),
    GoRoute(
      path: '/posts/create',
      name: AppRoute.createPost.name,
      pageBuilder: (context, state) =>
          _instantPage(state, const CreatePostScreen()),
    ),
    GoRoute(
      path: '/saved',
      name: AppRoute.savedTrips.name,
      pageBuilder: (context, state) =>
          _instantPage(state, const SavedTripsScreen()),
    ),
    GoRoute(
      path: '/puntok',
      name: AppRoute.puntok.name,
      pageBuilder: (context, state) =>
          _instantPage(state, const PuntokScreen()),
    ),
    GoRoute(
      path: '/location',
      name: AppRoute.locationAccess.name,
      pageBuilder: (context, state) => _instantPage(
        state,
        LocationAccessScreen(from: state.queryParams['from']),
      ),
    ),
    GoRoute(
      path: '/location/pick',
      name: AppRoute.locationPicker.name,
      // Reachable on its own, from the ไปกัน header — so it needs the same
      // gate. Arriving from the Location Access page passes it, because that
      // page records the answer before it navigates.
      redirect: _locationGate,
      pageBuilder: (context, state) =>
          _instantPage(state, const LocationPickerScreen()),
    ),
    GoRoute(
      path: '/login',
      name: AppRoute.login.name,
      pageBuilder: (context, state) => _instantPage(state, const LoginScreen()),
    ),
    GoRoute(
      path: '/profile',
      name: AppRoute.profile.name,
      pageBuilder: (context, state) =>
          _instantPage(state, const ProfileScreen()),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Route not found')),
    body: Center(child: Text(state.error.toString())),
  ),
);
