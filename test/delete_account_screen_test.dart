import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/profile/presentation/delete_account_screen.dart';

import 'support/fake_api.dart';

/// Registered with a username and password: no email, so a password is
/// certain.
const _passworded = AuthSession(
  displayName: 'Thitichaya Butsala',
  name: 'Thitichaya Butsala',
  handle: '@thitichaya.but',
  email: '',
);

/// Signed in through Google: may have no password at all.
const _google = AuthSession(
  displayName: 'Thitichaya Butsala',
  name: 'Thitichaya Butsala',
  handle: '@thitichaya.but',
  email: 'thitichaya.but@fullteam.tech',
);

FakeAdapter _adapter({List<FakeReply>? replies}) =>
    FakeAdapter(<String, List<FakeReply>>{
      'DELETE /users/me': replies ?? <FakeReply>[const FakeReply(204, null)],
    });

ProviderContainer _container(FakeAdapter adapter, AuthSession? session) {
  final container = ProviderContainer(
    overrides: <Override>[
      plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
      // The controller takes its API by constructor, so the provider
      // override alone would leave it with none and nothing would be sent.
      authSessionProvider.overrideWith(
        (ref) => AuthController(session, ref.watch(plunoApiProvider.future)),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _harness(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.profileDelete.name,
            builder: (_, __) => const DeleteAccountScreen(),
          ),
          GoRoute(
            path: '/profile/account',
            name: AppRoute.profileAccount.name,
            builder: (_, __) => const Scaffold(body: Text('account-stub')),
          ),
          GoRoute(
            path: '/login',
            name: AppRoute.login.name,
            builder: (_, __) => const Scaffold(body: Text('login-stub')),
          ),
        ],
      ),
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

InkWell _button(WidgetTester tester) => tester.widget<InkWell>(
      find.ancestor(
        of: find.text('ลบบัญชีถาวร'),
        matching: find.byType(InkWell),
      ),
    );

Finder _confirmField() => find.byType(TextField).first;
Finder _passwordField() => find.byType(TextField).last;

void main() {
  testWidgets('spells out what would be lost before asking to confirm',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_container(_adapter(), _passworded)));
    await tester.pumpAndSettle();

    expect(find.text('แผนทริปและโพสต์ทั้งหมดของคุณ'), findsOneWidget);
    expect(find.text('คลิป Puntok และรูปที่อัปโหลดไว้'), findsOneWidget);
    expect(find.text('ทริปที่บันทึกไว้และตำแหน่งที่ตั้ง'), findsOneWidget);
    expect(find.textContaining('กู้คืนไม่ได้'), findsOneWidget);
    expect(find.text('พิมพ์ "thitichaya.but" เพื่อยืนยัน'), findsOneWidget);
  });

  testWidgets('a wrong username never arms the button', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_container(_adapter(), _passworded)));
    await tester.pumpAndSettle();

    for (final typed in <String>['', ' ', '@thitichaya.but', 'thitichaya']) {
      await tester.enterText(_confirmField(), typed);
      await tester.pump();
      expect(_button(tester).onTap, isNull, reason: 'typed "$typed"');
    }
  });

  testWidgets('an account with no email must give its password',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_container(_adapter(), _passworded)));
    await tester.pumpAndSettle();

    // No email means it never came from Google, so it has a password.
    expect(find.text('รหัสผ่าน'), findsOneWidget);

    await tester.enterText(_confirmField(), 'thitichaya.but');
    await tester.pump();
    // Username alone is not enough here.
    expect(_button(tester).onTap, isNull);

    await tester.enterText(_passwordField(), 'hunter2');
    await tester.pump();
    expect(_button(tester).onTap, isNotNull);
  });

  testWidgets('a Google account is not asked for a password up front',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_container(_adapter(), _google)));
    await tester.pumpAndSettle();

    expect(find.text('รหัสผ่าน'), findsNothing);

    await tester.enterText(_confirmField(), 'thitichaya.but');
    await tester.pump();
    expect(_button(tester).onTap, isNotNull);
  });

  testWidgets('deleting sends the password and signs the traveller out',
      (tester) async {
    _phone(tester);
    final adapter = _adapter();
    final container = _container(adapter, _passworded);

    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();

    await tester.enterText(_confirmField(), 'thitichaya.but');
    await tester.enterText(_passwordField(), 'hunter2');
    await tester.pump();
    await tester.tap(find.text('ลบบัญชีถาวร'));
    await tester.pumpAndSettle();

    final sent = adapter.requests.last;
    expect('${sent.method} ${sent.path}', 'DELETE /users/me');
    expect(sent.data, <String, dynamic>{'password': 'hunter2'});

    expect(container.read(authSessionProvider), isNull);
    expect(find.text('login-stub'), findsOneWidget);
  });

  testWidgets('a Google account sends no body at all', (tester) async {
    _phone(tester);
    final adapter = _adapter();

    await tester.pumpWidget(_harness(_container(adapter, _google)));
    await tester.pumpAndSettle();

    await tester.enterText(_confirmField(), 'thitichaya.but');
    await tester.pump();
    await tester.tap(find.text('ลบบัญชีถาวร'));
    await tester.pumpAndSettle();

    expect(adapter.requests.last.data, isNull);
  });

  testWidgets('400 means the account has a password — ask for it, stay put',
      (tester) async {
    _phone(tester);
    final container = _container(
      _adapter(replies: <FakeReply>[
        const FakeReply(400, <String, dynamic>{
          'statusCode': 400,
          'message': 'password required',
        }),
      ]),
      _google,
    );

    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();

    expect(find.text('รหัสผ่าน'), findsNothing);
    await tester.enterText(_confirmField(), 'thitichaya.but');
    await tester.pump();
    await tester.tap(find.text('ลบบัญชีถาวร'));
    await tester.pumpAndSettle();

    // The field appears, the account survives, and nobody is signed out.
    expect(find.text('รหัสผ่าน'), findsOneWidget);
    expect(find.text('บัญชีนี้ตั้งรหัสผ่านไว้ กรอกรหัสผ่านเพื่อยืนยัน'),
        findsOneWidget);
    expect(container.read(authSessionProvider), isNotNull);
    expect(find.text('login-stub'), findsNothing);
  });

  testWidgets('403 is a wrong password, not an expired session',
      (tester) async {
    _phone(tester);
    final container = _container(
      _adapter(replies: <FakeReply>[
        const FakeReply(403, <String, dynamic>{
          'statusCode': 403,
          'message': 'wrong password',
        }),
      ]),
      _passworded,
    );

    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();

    await tester.enterText(_confirmField(), 'thitichaya.but');
    await tester.enterText(_passwordField(), 'wrong');
    await tester.pump();
    await tester.tap(find.text('ลบบัญชีถาวร'));
    await tester.pumpAndSettle();

    expect(find.text('รหัสผ่านไม่ถูกต้อง'), findsOneWidget);
    // Still signed in: a refused delete must never read as a successful one.
    expect(container.read(authSessionProvider), isNotNull);
    expect(find.text('login-stub'), findsNothing);
  });

  testWidgets('signed out, there is no form at all', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_container(_adapter(), null)));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบก่อน จึงจะลบบัญชีได้'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('back falls through to จัดการบัญชี', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_container(_adapter(), _passworded)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('account-stub'), findsOneWidget);
  });
}
