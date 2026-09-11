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

Widget _harness({AuthSession? session = AuthSession.demo}) {
  return ProviderScope(
    overrides: [
      // The controller only reaches the API when one is injected, so these
      // sessions stay local.
      authSessionProvider.overrideWith((ref) => AuthController(session)),
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
          // Stubbed: the real screen waits on the API and never settles.
          GoRoute(
            path: '/saved',
            name: AppRoute.savedTrips.name,
            builder: (_, __) => const Scaffold(body: Text('saved-stub')),
          ),
        ],
      ),
    ),
  );
}

/// Drags the list to its end so the session row clears the bottom-nav
/// overlay, which otherwise swallows the tap.
Future<void> _scrollToSessionRow(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -1200));
  await tester.pumpAndSettle();
}

/// The hero is unbuilt while the list sits at its end, so come back up before
/// asserting on it.
Future<void> _scrollToHero(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, 1200));
  await tester.pumpAndSettle();
}

void _usePhone(WidgetTester tester, {double width = 393, double height = 852}) {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the hero shows the account and the counts strip',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text(AuthSession.demo.displayName), findsOneWidget);
    expect(find.text(AuthSession.demo.handle), findsOneWidget);

    for (final (value, label) in ProfileStatsStrip.stats) {
      expect(find.text(value), findsOneWidget);
      expect(find.text(label), findsOneWidget);
    }

    // The old brand-restyle header and sections are gone.
    expect(find.text('โปรไฟล์'), findsNothing);
    expect(find.text('สไตล์การเที่ยว'), findsNothing);
    expect(find.text('บัญชี'), findsNothing);
  });

  testWidgets('every menu row from the reference is present in order',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    const labels = [
      'ทริปของฉัน',
      'โพสต์ของฉัน',
      'รีมิกซ์ของฉัน',
      'บุ๊กมาร์คสถานที่',
      'ตั้งค่าระบบ',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }

    final rendered = tester
        .widgetList<ProfileMenuRow>(find.byType(ProfileMenuRow))
        .map((row) => row.label)
        .toList();
    expect(rendered.take(labels.length), labels);
  });

  testWidgets('ทริปของฉัน opens the saved trips page', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('ทริปของฉัน'));
    await tester.pumpAndSettle();

    expect(find.text('saved-stub'), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
  });

  testWidgets('a row with nothing behind it reports instead of dead-ending',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('โพสต์ของฉัน'));
    await tester.pump();

    expect(find.text('โพสต์ของฉันยังไม่เปิดใช้งาน'), findsOneWidget);
  });

  testWidgets('the guest hero drops the counts strip and the edit badge',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness(session: null));
    await tester.pumpAndSettle();

    expect(find.text('ผู้เยี่ยมชม'), findsOneWidget);
    expect(find.text('ยังไม่ได้เข้าสู่ระบบ'), findsOneWidget);
    expect(find.byType(ProfileStatsStrip), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.text(AuthSession.demo.displayName), findsNothing);
  });

  testWidgets('signing out swaps the session row and the hero to guest',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _scrollToSessionRow(tester);

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
  });

  testWidgets('cancelling the sign-out dialog keeps the session',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _scrollToSessionRow(tester);

    await tester.tap(find.text('ออกจากระบบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบ'), findsNothing);

    await _scrollToHero(tester);
    expect(find.text(AuthSession.demo.displayName), findsOneWidget);
  });

  testWidgets('the guest sign-in row opens the login page', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness(session: null));
    await tester.pumpAndSettle();
    await _scrollToSessionRow(tester);

    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
  });

  testWidgets('profile keeps the shared bottom nav and reserves room for it',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(find.text('Paigun'), findsOneWidget);
    expect(find.text('Puntok'), findsOneWidget);

    final listView = tester.widget<ListView>(find.byType(ListView));
    final padding = listView.padding! as EdgeInsets;
    expect(
      padding.bottom,
      greaterThanOrEqualTo(AppBottomNav.bumpHeight + AppBottomNav.barHeight),
    );
  });

  testWidgets('profile lays out on a narrow phone without overflow',
      (tester) async {
    _usePhone(tester, width: 320, height: 700);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomNav), findsOneWidget);
  });
}
