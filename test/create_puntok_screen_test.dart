import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/create_puntok/presentation/create_puntok_screen.dart';
import 'package:pluno/features/puntok/presentation/providers/puntok_providers.dart';

/// `video_player` has no plugin under `flutter test`, so the editor's
/// `initialize()` throws and the clip's poster stands in — the chrome is what
/// these tests check, not playback.
Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = ProviderContainer();
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/puntok/create',
          routes: [
            GoRoute(
              path: '/puntok',
              name: AppRoute.puntok.name,
              builder: (_, __) => const Scaffold(body: Text('feed')),
            ),
            GoRoute(
              path: '/puntok/create',
              name: AppRoute.createPuntok.name,
              builder: (_, __) => const CreatePuntokScreen(),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Picks the first two clips and moves on to the editor.
Future<void> _toEditor(WidgetTester tester) async {
  await tester.tap(find.text('0:05').at(0));
  await tester.tap(find.text('0:05').at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ถัดไป'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the picker numbers clips in the order they were picked',
      (tester) async {
    await _pump(tester);

    expect(find.text('Puntok'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
    // Nothing picked, nothing to move on with.
    expect(find.text('ถัดไป'), findsNothing);

    await tester.tap(find.text('0:05').at(2));
    await tester.tap(find.text('0:05').at(0));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('ถัดไป'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('ถัดไป'), findsNothing);
  });

  testWidgets('the editor totals the cut and offers its tools',
      (tester) async {
    await _pump(tester);
    await _toEditor(tester);

    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Sub'), findsOneWidget);
    expect(find.text('0:10'), findsOneWidget);
    expect(find.text('Save Draft'), findsOneWidget);

    await tester.tap(find.text('Audio'));
    await tester.pump();
    expect(find.text('Audio — เร็วๆ นี้'), findsOneWidget);
  });

  testWidgets('back from the editor keeps what was picked', (tester) async {
    await _pump(tester);
    await _toEditor(tester);

    await tester.tap(find.bySemanticsLabel('ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('the composer lays out the design rows; remix opens its choices',
      (tester) async {
    await _pump(tester);
    await _toEditor(tester);
    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();

    expect(find.text('New Puntok'), findsOneWidget);
    expect(find.text('Add a caption...'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Edit cover'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Tag Friend'), findsOneWidget);
    expect(find.text('Add Location'), findsOneWidget);
    expect(find.text('Sync แผนทริปของฉัน'), findsOneWidget);
    expect(find.text('การมองเห็นโพส'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('เปิดให้ remix'), findsOneWidget);
    expect(find.text('ทุกคน'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('ทุกคน'), findsOneWidget);
    expect(find.text('คนที่ติดตาม'), findsOneWidget);
    expect(find.text('คนที่มีลิงก์'), findsOneWidget);
  });

  testWidgets('Activity puts the chosen chips under the caption',
      (tester) async {
    await _pump(tester);
    await _toEditor(tester);
    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('อาหาร'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();

    expect(find.text('อาหาร'), findsOneWidget);
  });

  testWidgets('Puntok publishes to the head of the feed and opens it',
      (tester) async {
    final container = await _pump(tester);
    await _toEditor(tester);
    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'เดินพระนคร 1 วัน');
    await tester.tap(find.widgetWithText(FilledButton, 'Puntok'));
    await tester.pumpAndSettle();

    expect(find.text('feed'), findsOneWidget);
    expect(find.text('โพสต์ Puntok แล้ว'), findsOneWidget);
    final head = container.read(puntokFeedProvider).first;
    expect(head.caption, 'เดินพระนคร 1 วัน');
    expect(head.video, 'assets/videos/puntok_osaka.mp4');
  });
}
