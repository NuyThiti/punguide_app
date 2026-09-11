import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/home/presentation/home_screen.dart';
import 'package:pluno/shared/widgets/create_sheet.dart';

import 'support/home_feed_fixtures.dart';

/// A button that opens the sheet and records what came back.
Widget _opener(void Function(CreateAction?) onResult) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async => onResult(await showCreateSheet(context)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the sheet lists every create option', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_opener((_) {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Create'), findsOneWidget);
    expect(find.text('PunGuide'), findsOneWidget);
    expect(find.text('สร้างแพลนเอง'), findsOneWidget);
    expect(find.text('Post'), findsOneWidget);
    expect(find.text('Puntok'), findsOneWidget);
    expect(find.text('ตกลง'), findsOneWidget);
  });

  testWidgets('picking an option returns it to the caller', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    CreateAction? picked;
    var called = false;
    await tester.pumpWidget(_opener((value) {
      picked = value;
      called = true;
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('สร้างแพลนเอง'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(picked, CreateAction.ownPlan);
  });

  testWidgets('ตกลง closes the sheet without choosing', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    CreateAction? picked;
    var called = false;
    await tester.pumpWidget(_opener((value) {
      picked = value;
      called = true;
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(picked, isNull);
    expect(find.text('PunGuide'), findsNothing);
  });

  testWidgets('the ไปกัน card on Home opens the same sheet', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: homeOverrides([feedTrip(id: 'lpq')]),
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                name: AppRoute.home.name,
                builder: (_, __) => const HomeScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ไปกัน'));
    await tester.pumpAndSettle();

    expect(find.text('สร้างแพลนเอง'), findsOneWidget);
    expect(find.text('ตกลง'), findsOneWidget);
  });

  testWidgets('an unbuilt option reports itself instead of going nowhere',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: homeOverrides([feedTrip(id: 'lpq')]),
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                name: AppRoute.home.name,
                builder: (_, __) => const HomeScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ไปกัน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(find.text('สร้างโพสยังไม่เปิดใช้งาน'), findsOneWidget);
  });
}
