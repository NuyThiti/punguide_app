import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/profile/presentation/edit_profile_screen.dart';

import 'support/fake_api.dart';

Map<String, dynamic> _user({String name = 'Thitichaya Butsala'}) =>
    <String, dynamic>{
      'id': 'u1',
      'username': 'thitichaya.but',
      'name': name,
      'email': 'thitichaya.but@fullteam.tech',
      'avatarUrl': 'https://cdn.test/avatar.jpg',
    };

FakeAdapter _adapter({
  Map<String, List<FakeReply>> extra = const <String, List<FakeReply>>{},
}) =>
    FakeAdapter(<String, List<FakeReply>>{
      // The location row reads the account's stored place.
      'GET /users/me/location': <FakeReply>[
        FakeReply(200, <String, dynamic>{
          'location': <String, dynamic>{
            'id': 'place-1',
            'name': 'เขตพระนคร',
            'lat': 13.7563,
            'lng': 100.4930,
          },
        }),
      ],
      ...extra,
    });

/// Distinguishes "left out" from "deliberately signed out" — `?? demo` would
/// quietly turn the signed-out case back into a signed-in one.
const _noSession = AuthSession(
  displayName: '',
  handle: '',
  email: '',
);

Widget _harness(
  FakeAdapter adapter, {
  AuthSession? session = _noSession,
}) {
  return ProviderScope(
    overrides: <Override>[
      plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
      authSessionProvider.overrideWith(
        (ref) => AuthController(
          identical(session, _noSession) ? AuthSession.demo : session,
        ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.profileEdit.name,
            builder: (_, __) => const EditProfileScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: AppRoute.profile.name,
            builder: (_, __) => const Scaffold(body: Text('profile-stub')),
          ),
          GoRoute(
            path: '/location/pick',
            name: AppRoute.locationPicker.name,
            builder: (_, __) => const Scaffold(body: Text('picker-stub')),
          ),
        ],
      ),
    ),
  );
}

/// An account that has set a display name, unlike [AuthSession.demo].
const _named = AuthSession(
  displayName: 'Thitichaya Butsala',
  name: 'Thitichaya Butsala',
  handle: '@thitichaya.but',
  email: 'thitichaya.but@fullteam.tech',
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('prints the account, and only the editable parts as fields',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_adapter()));
    await tester.pumpAndSettle();

    expect(find.text('จัดการโปรไฟล์'), findsOneWidget);
    // Pre-filled from the account's *raw* name.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      AuthSession.demo.name ?? '',
    );
    // Username and email have no endpoint, so they are printed, not offered.
    expect(find.text(AuthSession.demo.handle), findsOneWidget);
    expect(find.text(AuthSession.demo.email), findsOneWidget);
  });

  testWidgets('the saved place fills the location row', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_adapter()));
    await tester.pumpAndSettle();

    expect(find.text('เขตพระนคร'), findsOneWidget);
  });

  testWidgets('an account with no place says so', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(FakeAdapter(<String, List<FakeReply>>{
      'GET /users/me/location': <FakeReply>[
        const FakeReply(200, <String, dynamic>{'location': null}),
      ],
    })));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่ได้ตั้งตำแหน่ง'), findsOneWidget);
  });

  testWidgets('Save stays off until the name actually changes', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_adapter(), session: _named));
    await tester.pumpAndSettle();

    Widget save() => tester.widget(find.ancestor(
          of: find.text('บันทึก'),
          matching: find.byType(InkWell),
        ));
    expect((save() as InkWell).onTap, isNull);

    // Retyping the same name is not a change.
    await tester.enterText(
      find.byType(TextField),
      _named.name!,
    );
    await tester.pump();
    expect((save() as InkWell).onTap, isNull);

    await tester.enterText(find.byType(TextField), 'ชื่อใหม่');
    await tester.pump();
    expect((save() as InkWell).onTap, isNotNull);

    // An empty name cannot be saved either.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect((save() as InkWell).onTap, isNull);
  });

  testWidgets(
      'an account that never set a name starts empty, not on its username',
      (tester) async {
    _phone(tester);

    // The API answers `name: null` for every username registration until the
    // traveller sets one; displayName falls back to the username for display.
    const unnamed = AuthSession(
      displayName: 'thitichaya.but',
      handle: '@thitichaya.but',
      email: '',
    );

    await tester.pumpWidget(_harness(_adapter(), session: unnamed));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    // Saving unchanged would have set the username as the name.
    expect(
      tester
          .widget<InkWell>(find.ancestor(
            of: find.text('บันทึก'),
            matching: find.byType(InkWell),
          ))
          .onTap,
      isNull,
    );
  });

  testWidgets('saving sends the new name and keeps it', (tester) async {
    _phone(tester);
    final adapter = _adapter(extra: <String, List<FakeReply>>{
      'PATCH /users/me': <FakeReply>[FakeReply(200, _user(name: 'ชื่อใหม่'))],
      'PUT /users/me': <FakeReply>[FakeReply(200, _user(name: 'ชื่อใหม่'))],
    });

    await tester.pumpWidget(_harness(adapter));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ชื่อใหม่');
    await tester.pump();
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    expect(find.text('บันทึกชื่อแล้ว'), findsOneWidget);
  });

  testWidgets('the location row opens the picker', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_adapter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('เขตพระนคร'));
    await tester.pumpAndSettle();

    expect(find.text('picker-stub'), findsOneWidget);
  });

  testWidgets('signed out, it asks for an account instead of a form',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_adapter(), session: null));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบเพื่อแก้ไขโปรไฟล์'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
