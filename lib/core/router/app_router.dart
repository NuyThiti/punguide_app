import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/create_post/presentation/create_post_screen.dart';
import '../../features/create_trip/presentation/create_trip_screen.dart';
import '../../features/create_trip/presentation/edit_trip_brief_screen.dart';
import '../../features/create_trip/presentation/edit_trip_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/location_access/presentation/location_access_screen.dart';
import '../../features/location_access/presentation/location_picker_screen.dart';
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
      pageBuilder: (context, state) =>
          _instantPage(state, const PaigunScreen()),
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
      pageBuilder: (context, state) =>
          _instantPage(state, const LocationAccessScreen()),
    ),
    GoRoute(
      path: '/location/pick',
      name: AppRoute.locationPicker.name,
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
