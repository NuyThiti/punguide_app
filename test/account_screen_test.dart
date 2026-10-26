import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/profile/presentation/account_screen.dart';

import 'support/home_feed_fixtures.dart';

ProviderContainer _container({AuthSession? session = AuthSession.demo}) {
  final container = ProviderContainer(
    overrides: profileOverrides(session: session),
  );
  addTearDown(container.dispose);
  return container;
}

Widget _harness(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/profile/account',
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.home.name,
            builder: (_, __) => const Scaffold(body: Text('home-stub')),
          ),
          GoRoute(
            path: '/login',
            name: AppRoute.login.name,
            builder: (_, __) => const Scaffold(body: Text('login-stub')),
          ),
          GoRoute(
            path: '/trips/mine',
            name: AppRoute.myTrips.name,
            builder: (_, __) => const Scaffold(body: Text('my-trips-stub')),
          ),
          GoRoute(
            path: '/saved',
            name: AppRoute.savedTrips.name,
            builder: (_, __) => const Scaffold(body: Text('saved-stub')),
          ),
          GoRoute(
            path: '/profile',
            name: AppRoute.profile.name,
            builder: (_, __) => const Scaffold(body: Text('profile-stub')),
          ),
          GoRoute(
            path: '/profile/account',
            name: AppRoute.profileAccount.name,
            builder: (_, __) => const AccountScreen(),
          ),
        ],
      ),
    ),
  );
}

void _usePhone(WidgetTester tester, {double width = 393, double height = 852}) {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('every row from the reference is present, in order',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness(_container()));
    await tester.pumpAndSettle();

    expect(find.text('จัดการบัญชี'), findsOneWidget);

    const labels = [
      'Save Draft',
      'ทริปที่บันทึกไว้',
      'บุ๊คมาร์คสถานที่',
      'ตั้งค่าระบบ',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }

    final rendered = tester
        .widgetList<AccountRow>(find.byType(AccountRow))
        .map((row) => row.label)
        .toList();
    expect(rendered, labels);

    // Albums moved to the profile's own tab strip, so the row is gone.
    expect(find.text('อัลบั้มของฉัน'), findsNothing);
  });

  testWidgets('Save Draft opens the shelf that lists drafts', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness(_container()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Draft'));
    await tester.pumpAndSettle();

    expect(find.text('my-trips-stub'), findsOneWidget);
  });

  testWidgets('ทริปที่บันทึกไว้ opens the bookmarks shelf', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness(_container()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ทริปที่บันทึกไว้'));
    await tester.pumpAndSettle();

    expect(find.text('saved-stub'), findsOneWidget);
  });

  testWidgets('a row with nothing behind it reports instead of dead-ending',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness(_container()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('บุ๊คมาร์คสถานที่'));
    await tester.pump();

    expect(find.text('บุ๊คมาร์คสถานที่ยังไม่เปิดใช้งาน'), findsOneWidget);
  });

  testWidgets('signing out drops the session and leaves the page',
      (tester) async {
    _usePhone(tester);
    final container = _container();

    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AccountFooterButton, 'ออกจากระบบ'));
    await tester.pumpAndSettle();

    // The footer and the dialog share the label, so confirm via the dialog.
    expect(
      find.text('ทริปที่บันทึกไว้จะยังอยู่ในบัญชีของคุณ'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'ออกจากระบบ'));
    await tester.pumpAndSettle();

    expect(container.read(authSessionProvider), isNull);
    expect(find.text('home-stub'), findsOneWidget);
  });

  testWidgets('cancelling the dialog keeps the session', (tester) async {
    _usePhone(tester);
    final container = _container();

    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AccountFooterButton, 'ออกจากระบบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
    await tester.pumpAndSettle();

    expect(container.read(authSessionProvider), isNotNull);
    expect(find.byType(AccountScreen), findsOneWidget);
  });

  testWidgets('a guest gets a sign-in footer instead', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness(_container(session: null)));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AccountFooterButton, 'เข้าสู่ระบบ'),
        findsOneWidget);

    await tester.tap(find.widgetWithText(AccountFooterButton, 'เข้าสู่ระบบ'));
    await tester.pumpAndSettle();

    expect(find.text('login-stub'), findsOneWidget);
  });

  testWidgets('back falls through to the profile when there is no stack',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness(_container()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('profile-stub'), findsOneWidget);
  });

  testWidgets('account lays out on a narrow phone without overflow',
      (tester) async {
    _usePhone(tester, width: 320, height: 700);

    await tester.pumpWidget(_harness(_container()));
    await tester.pumpAndSettle();

    expect(find.byType(AccountRow), findsNWidgets(4));
  });
}
