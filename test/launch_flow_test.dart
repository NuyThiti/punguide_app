import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/domain/google_authenticator.dart';
import 'package:pluno/features/auth/presentation/login_screen.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/home/presentation/home_screen.dart';
import 'package:pluno/features/location_access/data/location_permission_store.dart';
import 'package:pluno/features/location_access/domain/location_service.dart';
import 'package:pluno/features/location_access/presentation/location_access_screen.dart';
import 'package:pluno/features/location_access/presentation/providers/location_providers.dart';
import 'package:pluno/features/trip_style/data/trip_style_store.dart';
import 'package:pluno/features/trip_style/domain/trip_style_preference.dart';
import 'package:pluno/features/trip_style/presentation/providers/trip_style_providers.dart';
import 'package:pluno/features/trip_style/presentation/trip_style_screen.dart';

import 'support/fake_api.dart';
import 'support/home_feed_fixtures.dart';

/// Stands in for Firebase, so the launch flow can be driven without a device.
class _FakeGoogle implements GoogleAuthenticator {
  @override
  Future<String?> signIn() async => 'firebase-id-token';

  @override
  Future<void> signOut() async {}
}

/// Opens the real [appRouter] on its launch route, with the session already
/// restored as [session], the location question answered as [answered], and
/// สไตล์เที่ยวของฉัน answered as [styled].
///
/// Null for either question means it has never been put, which is what the
/// sequence keys off.
Future<void> _launch(
  WidgetTester tester, {
  AuthSession? session,
  LocationPermissionStatus? answered,
  TripStylePreference? styled,
  Map<String, dynamic>? accountAnswers,
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
            'PUT /users/me/preferences/location-access': [
              const FakeReply(200, <String, dynamic>{
                'locationAccess': <String, dynamic>{'status': 'later'},
                'travelStyle': null,
              }),
            ],
            'PUT /users/me/preferences/travel-style': [
              const FakeReply(200, <String, dynamic>{
                'locationAccess': null,
                'travelStyle': null,
              }),
            ],
            'GET /users/me/preferences': [
              FakeReply(
                200,
                accountAnswers ??
                    <String, dynamic>{
                      'locationAccess': null,
                      'travelStyle': null,
                    },
              ),
            ],
          })),
        ),
        googleAuthenticatorProvider.overrideWithValue(_FakeGoogle()),
        storedLocationPermissionProvider.overrideWithValue(answered),
        locationPermissionStoreProvider
            .overrideWithValue(InMemoryLocationPermissionStore(answered)),
        storedTripStyleProvider.overrideWithValue(styled),
        tripStyleStoreProvider
            .overrideWithValue(InMemoryTripStyleStore(styled)),
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

    await tester.tap(find.text('เข้าสู่ระบบด้วย Google'));
    await tester.pumpAndSettle();

    expect(find.byType(LocationAccessScreen), findsOneWidget);
  });

  testWidgets('signed in, the app skips Login for Location Access',
      (tester) async {
    await _launch(tester, session: AuthSession.demo);

    expect(find.byType(LocationAccessScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('ไว้ทีหลังนะ carries on to สไตล์เที่ยวของฉัน', (tester) async {
    await _launch(tester, session: AuthSession.demo);

    await tester.tap(find.text('ไว้ทีหลังนะ'));
    await tester.pumpAndSettle();

    // Refusing the location question does not skip the one after it.
    expect(find.byType(TripStyleScreen), findsOneWidget);
  });

  testWidgets('answering สไตล์เที่ยวของฉัน finishes the sequence on Home',
      (tester) async {
    await _launch(tester, session: AuthSession.demo);

    await tester.tap(find.text('ไว้ทีหลังนะ'));
    await tester.pumpAndSettle();
    // The style page has its own ข้ามไปก่อน; take it rather than the chips,
    // since the point here is where the sequence ends.
    await tester.tap(find.text('ข้ามไปก่อน'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('with location answered, the sequence opens on the style page',
      (tester) async {
    await _launch(
      tester,
      session: AuthSession.demo,
      answered: LocationPermissionStatus.granted,
    );

    expect(find.byType(TripStyleScreen), findsOneWidget);
    expect(find.byType(LocationAccessScreen), findsNothing);
  });

  testWidgets('answers given on another device skip both pages',
      (tester) async {
    // Nothing stored on this phone, but the account has been through the
    // sequence before — which is the whole reason it is kept there.
    await _launch(
      tester,
      session: AuthSession.demo,
      accountAnswers: <String, dynamic>{
        'locationAccess': <String, dynamic>{'status': 'granted'},
        'travelStyle': <String, dynamic>{
          'styles': ['nature'],
          'customStyles': <String>[],
          'constraints': <String>[],
          'customConstraints': <String>[],
        },
      },
    );

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LocationAccessScreen), findsNothing);
    expect(find.byType(TripStyleScreen), findsNothing);
  });

  testWidgets('an account half way through is asked only what is left',
      (tester) async {
    await _launch(
      tester,
      session: AuthSession.demo,
      accountAnswers: <String, dynamic>{
        'locationAccess': <String, dynamic>{'status': 'later'},
        'travelStyle': null,
      },
    );

    expect(find.byType(TripStyleScreen), findsOneWidget);
    expect(find.byType(LocationAccessScreen), findsNothing);
  });

  testWidgets('signed in with both answered, the app opens on Home',
      (tester) async {
    await _launch(
      tester,
      session: AuthSession.demo,
      answered: LocationPermissionStatus.granted,
      styled: TripStylePreference.skipped,
    );

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
