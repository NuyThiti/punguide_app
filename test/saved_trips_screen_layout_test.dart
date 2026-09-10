import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/saved_trips/presentation/saved_trips_notifier.dart';
import 'package:pluno/features/saved_trips/presentation/saved_trips_screen.dart';
import 'package:pluno/features/trips/data/mock_trips.dart';
import 'package:pluno/features/trips/domain/models/trip.dart';
import 'package:pluno/shared/widgets/app_bottom_nav.dart';

class _StubSavedTripsNotifier extends SavedTripsNotifier {
  _StubSavedTripsNotifier(this.trips);

  final List<Trip> trips;

  @override
  Future<List<Trip>> build() async => trips;
}

Widget _harness(List<Trip> trips) {
  return ProviderScope(
    overrides: [
      savedTripsNotifierProvider
          .overrideWith(() => _StubSavedTripsNotifier(trips)),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.savedTrips.name,
            builder: (_, __) => const SavedTripsScreen(),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('saved trips renders the shared bottom nav without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(mockTrips));
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Paigun'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Puntok'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    // The old private nav is gone, so none of its labels should remain.
    expect(find.text('Discover'), findsNothing);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('saved trips list reserves room for the bottom nav',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(mockTrips));
    await tester.pumpAndSettle();

    final listView = tester.widget<ListView>(find.byType(ListView));
    final padding = listView.padding! as EdgeInsets;
    expect(
      padding.bottom,
      greaterThanOrEqualTo(AppBottomNav.bumpHeight + AppBottomNav.barHeight),
    );
  });

  // TripCard's _InfoPill row (trip_card.dart:177) overflows horizontally
  // below ~325pt (by 4.3px at 320pt) — a pre-existing TripCard bug unrelated
  // to the bottom nav, so this stays at 360pt.
  testWidgets('saved trips lays out on a narrow phone without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(mockTrips));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgets('saved trips empty state clears the bottom nav', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(const []));
    await tester.pumpAndSettle();

    expect(find.text('No trips found'), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
  });
}
