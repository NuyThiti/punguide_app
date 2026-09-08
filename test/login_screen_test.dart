import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/domain/google_authenticator.dart';
import 'package:pluno/features/auth/presentation/login_screen.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';

Widget _harness(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.home.name,
            builder: (_, __) => const Scaffold(body: Text('home-stub')),
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

ProviderContainer _container(
  WidgetTester tester, {
  AuthSession? session,
  GoogleAuthenticator? google,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith((ref) => AuthController(session)),
      if (google != null) googleAuthenticatorProvider.overrideWithValue(google),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Stands in for the Firebase SDKs, which the app does not depend on yet.
class _FakeGoogle implements GoogleAuthenticator {
  _FakeGoogle({this.token, this.error});

  final String? token;
  final Object? error;
  int signOutCount = 0;

  @override
  Future<String?> signIn() async {
    final failure = error;
    if (failure != null) throw failure;
    return token;
  }

  @override
  Future<void> signOut() async => signOutCount++;
}

void _phone(WidgetTester tester, {Size size = const Size(393, 852)}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _fillCredentials(
  WidgetTester tester, {
  required String username,
  required String password,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), username);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.pump();
}

/// Flips the screen from signing in to signing up via the bottom link.
Future<void> _switchToRegister(WidgetTester tester) async {
  await tester.ensureVisible(find.text('สมัครสมาชิก'));
  await tester.tap(find.text('สมัครสมาชิก'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login renders the brand header, both fields and every action',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_harness(_container(tester)));
    await tester.pumpAndSettle();

    expect(find.text('PunGuide'), findsOneWidget);
    expect(find.text('ชื่อผู้ใช้'), findsOneWidget);
    expect(find.text('อีเมล'), findsNothing);
    expect(find.text('รหัสผ่าน'), findsOneWidget);
    expect(find.text('จำฉันไว้'), findsOneWidget);
    expect(find.text('ลืมรหัสผ่าน?'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
    expect(find.text('ดำเนินการต่อด้วย Google'), findsOneWidget);
    expect(find.text('ดำเนินการต่อด้วย Apple'), findsOneWidget);
    expect(find.text('เข้าใช้แบบผู้เยี่ยมชม'), findsOneWidget);
    expect(find.text('สมัครสมาชิก'), findsOneWidget);
  });

  testWidgets('submitting an empty form reports both fields', (tester) async {
    _phone(tester);
    final container = _container(tester);
    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.pumpAndSettle();

    expect(find.text('กรอกชื่อผู้ใช้ของคุณ'), findsOneWidget);
    expect(find.text('กรอกรหัสผ่าน'), findsOneWidget);
    expect(container.read(authSessionProvider), isNull);
    expect(find.text('home-stub'), findsNothing);
  });

  testWidgets('an out-of-charset username and a short password each report',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_harness(_container(tester)));
    await tester.pumpAndSettle();

    // '@' and '-' are outside the API's [a-zA-Z0-9._] set.
    await _fillCredentials(tester, username: 'som-chai@x', password: '123');
    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.pumpAndSettle();

    expect(find.text('ใช้ได้เฉพาะ a-z 0-9 จุด และขีดล่าง'), findsOneWidget);
    expect(find.text('รหัสผ่านอย่างน้อย 8 ตัวอักษร'), findsOneWidget);
  });

  testWidgets('a username shorter than the API allows reports', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_harness(_container(tester)));
    await tester.pumpAndSettle();

    await _fillCredentials(tester, username: 'so', password: 'secret1234');
    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.pumpAndSettle();

    expect(find.text('ชื่อผู้ใช้ต้องยาว 3-30 ตัวอักษร'), findsOneWidget);
  });

  testWidgets('valid credentials open a session and land on home',
      (tester) async {
    _phone(tester);
    final container = _container(tester);
    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();

    await _fillCredentials(
      tester,
      username: 'somchai.jai',
      password: 'secret1234',
    );
    await tester.tap(find.text('เข้าสู่ระบบ'));

    // The pending state holds while the credential exchange runs.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    final session = container.read(authSessionProvider);
    expect(session, isNotNull);
    expect(session!.handle, '@somchai.jai');
    expect(session.displayName, 'Somchai Jai');
    // A username/password account has no email until it signs in with Google.
    expect(session.email, isEmpty);
    expect(find.text('home-stub'), findsOneWidget);
  });

  testWidgets('the bottom link flips the screen into sign-up', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_harness(_container(tester)));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีบัญชี?'), findsOneWidget);
    await _switchToRegister(tester);

    expect(find.text('มีบัญชีอยู่แล้ว?'), findsOneWidget);
    expect(find.text('ยังไม่มีบัญชี?'), findsNothing);
    // Remember-me belongs to signing in; the password rule replaces it here.
    expect(find.text('จำฉันไว้'), findsNothing);
    expect(
      find.text('ตั้งรหัสผ่าน 8-72 ตัวอักษร และชื่อผู้ใช้จะเปลี่ยนภายหลังไม่ได้'),
      findsOneWidget,
    );
  });

  testWidgets('signing up opens a session and lands on home', (tester) async {
    _phone(tester);
    final container = _container(tester);
    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();
    await _switchToRegister(tester);

    await _fillCredentials(
      tester,
      username: 'new.traveller',
      password: 'secret1234',
    );
    // In sign-up mode the label is the primary button, not the bottom link.
    await tester.tap(find.widgetWithText(GestureDetector, 'สมัครสมาชิก').first);
    await tester.pumpAndSettle();

    expect(container.read(authSessionProvider)?.handle, '@new.traveller');
    expect(find.text('home-stub'), findsOneWidget);
  });

  testWidgets('switching modes keeps what was typed but clears stale errors',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_harness(_container(tester)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.pumpAndSettle();
    expect(find.text('กรอกชื่อผู้ใช้ของคุณ'), findsOneWidget);

    await _fillCredentials(tester, username: 'somchai', password: 'secret1234');
    await _switchToRegister(tester);

    expect(find.text('กรอกชื่อผู้ใช้ของคุณ'), findsNothing);
    // Read the field itself: 'somchai' is also the hint, so find.text is
    // ambiguous here.
    final username = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(TextFormField).at(0),
        matching: find.byType(EditableText),
      ),
    );
    expect(username.controller.text, 'somchai');
  });

  testWidgets('the eye toggle reveals and re-hides the password',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_harness(_container(tester)));
    await tester.pumpAndSettle();

    EditableText passwordField() => tester.widget<EditableText>(
          find.descendant(
            of: find.byType(TextFormField).at(1),
            matching: find.byType(EditableText),
          ),
        );

    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    expect(passwordField().obscureText, isFalse);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();
    expect(passwordField().obscureText, isTrue);
  });

  testWidgets('the guest action drops any session and goes home',
      (tester) async {
    _phone(tester);
    final container = _container(tester, session: AuthSession.demo);
    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('เข้าใช้แบบผู้เยี่ยมชม'));
    await tester.tap(find.text('เข้าใช้แบบผู้เยี่ยมชม'));
    await tester.pumpAndSettle();

    expect(container.read(authSessionProvider), isNull);
    expect(find.text('home-stub'), findsOneWidget);
  });

  testWidgets('the remember-me box toggles', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_harness(_container(tester)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.text('จำฉันไว้'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('the Google button exchanges an ID token for a session',
      (tester) async {
    _phone(tester);
    final container = _container(
      tester,
      google: _FakeGoogle(token: 'firebase-id-token'),
    );
    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('ดำเนินการต่อด้วย Google'));
    await tester.tap(find.text('ดำเนินการต่อด้วย Google'));
    await tester.pumpAndSettle();

    expect(container.read(authSessionProvider), isNotNull);
    expect(find.text('home-stub'), findsOneWidget);
  });

  testWidgets('backing out of the Google picker changes nothing',
      (tester) async {
    _phone(tester);
    // A null token is a cancel, not a failure.
    final container = _container(tester, google: _FakeGoogle());
    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('ดำเนินการต่อด้วย Google'));
    await tester.tap(find.text('ดำเนินการต่อด้วย Google'));
    await tester.pumpAndSettle();

    expect(container.read(authSessionProvider), isNull);
    expect(find.text('home-stub'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // No snackbar: cancelling is not worth reporting.
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('an unconfigured Google flow explains itself', (tester) async {
    _phone(tester);
    final container = _container(
      tester,
      google: _FakeGoogle(
        error: const GoogleSignInUnavailable('ยังตั้งค่า Firebase ไม่เสร็จ'),
      ),
    );
    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('ดำเนินการต่อด้วย Google'));
    await tester.tap(find.text('ดำเนินการต่อด้วย Google'));
    await tester.pumpAndSettle();

    expect(find.text('ยังตั้งค่า Firebase ไม่เสร็จ'), findsOneWidget);
    expect(container.read(authSessionProvider), isNull);
  });

  testWidgets('the shipped build reports Google sign-in as unavailable',
      (tester) async {
    _phone(tester);
    // No override: whatever the app actually ships with answers here.
    final container = _container(tester);
    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('ดำเนินการต่อด้วย Google'));
    await tester.tap(find.text('ดำเนินการต่อด้วย Google'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(container.read(authSessionProvider), isNull);
    expect(find.text('home-stub'), findsNothing);
  });

  testWidgets('login lays out on a narrow phone without overflow',
      (tester) async {
    _phone(tester, size: const Size(320, 640));
    await tester.pumpWidget(_harness(_container(tester)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีบัญชี?'), findsOneWidget);
  });
}
