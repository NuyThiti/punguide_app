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

void main() {
  testWidgets('login shows the welcome artwork and both providers',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_harness(_container(tester)));
    await tester.pumpAndSettle();

    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วย Apple'), findsOneWidget);
    expect(find.text('ยังไม่มีบัญชี?'), findsOneWidget);
    expect(find.text('สมัครสมาชิก'), findsOneWidget);
    // The old light header is gone with the redesign.
    expect(find.text('บัญชีผู้ใช้'), findsNothing);
  });

  testWidgets('Apple sign-in says it is not available yet', (tester) async {
    _phone(tester);
    final container = _container(tester);
    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('เข้าสู่ระบบด้วย Apple'));
    await tester.pumpAndSettle();

    expect(
      find.text('เข้าสู่ระบบด้วย Apple ยังไม่เปิดให้ใช้งาน'),
      findsOneWidget,
    );
    expect(container.read(authSessionProvider), isNull);
  });

  testWidgets('สมัครสมาชิก runs the same Google flow', (tester) async {
    _phone(tester);
    final container = _container(
      tester,
      google: _FakeGoogle(token: 'firebase-id-token'),
    );
    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('สมัครสมาชิก'));
    await tester.pumpAndSettle();

    expect(container.read(authSessionProvider), isNotNull);
  });

  testWidgets('the username and password form is gone', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_harness(_container(tester)));
    await tester.pumpAndSettle();

    // No text entry at all: nothing is left to type into.
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(Form), findsNothing);
    expect(find.text('อีเมลหรือชื่อผู้ใช้'), findsNothing);
    expect(find.text('รหัสผ่าน'), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
  });

  testWidgets('secondary actions omitted by the new design stay hidden',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_harness(_container(tester)));
    await tester.pumpAndSettle();

    expect(find.text('จำฉันไว้'), findsNothing);
    expect(find.text('เข้าใช้แบบผู้เยี่ยมชม'), findsNothing);
    expect(find.text('ลืมรหัสผ่าน?'), findsNothing);
    expect(find.text('หรือดำเนินการต่อด้วย'), findsNothing);
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

    await tester.ensureVisible(find.text('เข้าสู่ระบบด้วย Google'));
    await tester.tap(find.text('เข้าสู่ระบบด้วย Google'));
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

    await tester.ensureVisible(find.text('เข้าสู่ระบบด้วย Google'));
    await tester.tap(find.text('เข้าสู่ระบบด้วย Google'));
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

    await tester.ensureVisible(find.text('เข้าสู่ระบบด้วย Google'));
    await tester.tap(find.text('เข้าสู่ระบบด้วย Google'));
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

    await tester.ensureVisible(find.text('เข้าสู่ระบบด้วย Google'));
    await tester.tap(find.text('เข้าสู่ระบบด้วย Google'));
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

    expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
    expect(find.text('Welcome!'), findsOneWidget);
  });
}
