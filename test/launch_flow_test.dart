import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/login_screen.dart';
import 'package:pluno/features/home/presentation/home_screen.dart';
import 'package:pluno/features/location_access/data/location_permission_store.dart';
import 'package:pluno/features/location_access/domain/location_service.dart';
import 'package:pluno/features/location_access/presentation/location_access_screen.dart';
import 'package:pluno/features/location_access/presentation/providers/location_providers.dart';

import 'support/fake_api.dart';
import 'support/home_feed_fixtures.dart';

/// Opens the real [appRouter] on its launch route, with the session already
/// restored as [session] and the location question answered as [answered].
Future<void> _launch(
  WidgetTester tester, {
  AuthSession? session,
  LocationPermissionStatus? answered,
}) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // The router is a global, so every test has to hand it back.
  addTearDown(() => appRouter.goNamed(AppRoute.home.name));
  appRouter.goNamed(AppRoute.launch.name);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // No server: the local stand-in, which restores nothing.
        ...homeOverrides(const [], session: session),
        // A refusal while signed in clears the account's location.
        plunoApiProvider.overrideWith(
          (ref) async => fakeApi(FakeAdapter(<String, List<FakeReply>>{
            'DELETE /users/me/location': [const FakeReply(204, null)],
          })),
        ),
        storedLocationPermissionProvider.overrideWithValue(answered),
        locationPermissionStoreProvider
            .overrideWithValue(InMemoryLocationPermissionStore(answered)),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed out, the app opens on Login', (tester) async {
    await _launch(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('signing in carries on to Location Access', (tester) async {
    await _launch(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'somchai.jai');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('เข้าสู่ระบบ').last);
    await tester.pumpAndSettle();

    expect(find.byType(LocationAccessScreen), findsOneWidget);
  });

  testWidgets('signed in, the app skips Login for Location Access',
      (tester) async {
    await _launch(tester, session: AuthSession.demo);

    expect(find.byType(LocationAccessScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('ไว้ทีหลังนะ at launch lands on Home', (tester) async {
    await _launch(tester, session: AuthSession.demo);

    await tester.tap(find.text('ไว้ทีหลังนะ'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('signed in and already asked, the app opens on Home',
      (tester) async {
    await _launch(
      tester,
      session: AuthSession.demo,
      answered: LocationPermissionStatus.granted,
    );

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
