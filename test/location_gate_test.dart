import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/location_access/data/location_permission_store.dart';
import 'package:pluno/features/location_access/domain/location_service.dart';
import 'package:pluno/features/location_access/presentation/location_access_screen.dart';
import 'package:pluno/features/location_access/presentation/location_picker_screen.dart';
import 'package:pluno/features/location_access/presentation/providers/location_providers.dart';
import 'package:pluno/features/paigun/presentation/paigun_screen.dart';

import 'support/home_feed_fixtures.dart';

/// The real [appRouter], so the gate under test is the one the app ships.
///
/// [answered] stands in for what `main` reads out of storage at startup.
Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  LocationPermissionStatus? answered,
}) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      ...homeOverrides(const []),
      storedLocationPermissionProvider.overrideWithValue(answered),
      locationPermissionStoreProvider
          .overrideWithValue(InMemoryLocationPermissionStore(answered)),
    ],
  );
  addTearDown(container.dispose);
  // The router is a global, so every test has to hand it back.
  addTearDown(() => appRouter.goNamed(AppRoute.home.name));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: appRouter),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('ไปกัน asks for location first while nobody has answered',
      (tester) async {
    await _pumpApp(tester);

    appRouter.goNamed(AppRoute.paigun.name);
    await tester.pumpAndSettle();

    expect(find.byType(LocationAccessScreen), findsOneWidget);
    expect(find.byType(PaigunScreen), findsNothing);
  });

  testWidgets('the picker is held behind the same gate', (tester) async {
    await _pumpApp(tester);

    appRouter.goNamed(AppRoute.locationPicker.name);
    await tester.pumpAndSettle();

    expect(find.byType(LocationAccessScreen), findsOneWidget);
    expect(find.byType(LocationPickerScreen), findsNothing);
  });

  testWidgets(
      'an answer kept from a previous run opens the board straight away',
      (tester) async {
    await _pumpApp(tester, answered: LocationPermissionStatus.denied);

    appRouter.goNamed(AppRoute.paigun.name);
    await tester.pumpAndSettle();

    // A refusal is an answer: asking again would put the board out of reach.
    expect(find.byType(PaigunScreen), findsOneWidget);
    expect(find.byType(LocationAccessScreen), findsNothing);
  });

  testWidgets('ไว้ทีหลังนะ carries on to where the traveller was heading',
      (tester) async {
    final container = await _pumpApp(tester);

    // Caught on the way to the picker, not to the board.
    appRouter.goNamed(AppRoute.locationPicker.name);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ไว้ทีหลังนะ'));
    await tester.pumpAndSettle();

    expect(find.byType(LocationPickerScreen), findsOneWidget);
    expect(
      container.read(locationPermissionProvider),
      LocationPermissionStatus.denied,
    );
  });

  testWidgets('อนุญาต goes on to the map, as the design has it',
      (tester) async {
    await _pumpApp(tester);

    appRouter.goNamed(AppRoute.paigun.name);
    await tester.pumpAndSettle();

    await tester.tap(find.text('อนุญาต'));
    await tester.pumpAndSettle();

    expect(find.byType(LocationPickerScreen), findsOneWidget);
  });
}
