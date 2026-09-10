import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/login_screen.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/profile/presentation/profile_screen.dart';
import 'package:pluno/shared/widgets/app_bottom_nav.dart';

Widget _harness() {
  return ProviderScope(
    overrides: [
      // These cases all start from a signed-in profile. The controller only
      // reaches the API when one is injected, so this session stays local.
      authSessionProvider
          .overrideWith((ref) => AuthController(AuthSession.demo)),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.profile.name,
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/login',
            name: AppRoute.login.name,
            builder: (_, __) => const LoginScreen(),
          ),
        ],
      ),
    ),
  );
}

/// Drags the list to its end so the auth row clears the bottom-nav overlay,
/// which otherwise swallows the tap.
Future<void> _scrollToAuthSection(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -1200));
  await tester.pumpAndSettle();
}

/// The hero is unbuilt while the list sits at its end, so come back up before
/// asserting on it.
Future<void> _scrollToHero(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, 1200));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('profile renders the shared bottom nav without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(find.text('Paigun'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Puntok'), findsOneWidget);
    // 'Home' and 'Profile' also appear in the nav; the old labels do not.
    expect(find.text('Discover'), findsNothing);
    expect(find.text('Saved'), findsNothing);

    // Brand-system copy replaced the old English strings.
    expect(find.text('โปรไฟล์'), findsOneWidget);
    expect(find.text('PunGuide Traveler'), findsOneWidget);
    expect(find.text('นักปันไกด์'), findsOneWidget);
    expect(find.text('สไตล์การเที่ยว'), findsOneWidget);
    expect(find.text('บัญชี'), findsOneWidget);
    expect(find.text('บันทึกไว้'), findsOneWidget);
    expect(find.text('Travel Style'), findsNothing);
  });

  testWidgets('profile shows the sign-out row while a session is active',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('การเข้าสู่ระบบ'), findsOneWidget);
    await _scrollToAuthSection(tester);

    expect(find.text('ออกจากระบบ'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsNothing);
  });

  testWidgets('signing out swaps the hero and the auth row to the guest state',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _scrollToAuthSection(tester);

    await tester.tap(find.text('ออกจากระบบ'));
    await tester.pumpAndSettle();

    // The dialog title and the row share the label, so confirm via the dialog.
    expect(
        find.text('ทริปที่บันทึกไว้จะยังอยู่ในเครื่องของคุณ'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'ออกจากระบบ'));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);

    await _scrollToHero(tester);
    expect(find.text('ผู้เยี่ยมชม'), findsOneWidget);
    expect(find.text('ยังไม่ได้เข้าสู่ระบบ'), findsOneWidget);
    expect(find.text('PunGuide Traveler'), findsNothing);
    expect(find.text('นักปันไกด์'), findsNothing);
  });

  testWidgets('cancelling the sign-out dialog keeps the session',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _scrollToAuthSection(tester);

    await tester.tap(find.text('ออกจากระบบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบ'), findsNothing);

    await _scrollToHero(tester);
    expect(find.text('PunGuide Traveler'), findsOneWidget);
  });

  testWidgets('the guest sign-in row opens the login page', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _scrollToAuthSection(tester);
    await tester.tap(find.text('ออกจากระบบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'ออกจากระบบ'));
    await tester.pumpAndSettle();

    await _scrollToAuthSection(tester);
    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
  });

  testWidgets('profile list reserves room for the bottom nav', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final listView = tester.widget<ListView>(find.byType(ListView));
    final padding = listView.padding! as EdgeInsets;
    expect(
      padding.bottom,
      greaterThanOrEqualTo(AppBottomNav.bumpHeight + AppBottomNav.barHeight),
    );
  });

  testWidgets('profile lays out on a narrow phone without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomNav), findsOneWidget);
  });
}
