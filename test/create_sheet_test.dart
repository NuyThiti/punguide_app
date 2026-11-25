import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/create_post/domain/services/photo_library_source.dart';
import 'package:pluno/features/create_post/presentation/create_post_screen.dart';
import 'package:pluno/features/create_post/presentation/providers/photo_library_providers.dart';
import 'package:pluno/features/create_puntok/presentation/create_puntok_screen.dart';
import 'package:pluno/features/home/presentation/home_screen.dart';
import 'package:pluno/shared/widgets/create_sheet.dart';

import 'support/home_feed_fixtures.dart';

/// One fixed photo — no EXIF, no network round trip. The review screen tries
/// to read its GPS anyway, and this just answers with nothing rather than
/// needing a `/places/suggest` stub for every test that reaches it.
class _FakeGalleryAsset implements GalleryAsset {
  _FakeGalleryAsset(this.id);

  @override
  final String id;

  @override
  Future<Uint8List?> thumbnail() async => null;

  @override
  Future<XFile?> toXFile() async => _FakeXFile('$id.jpg');
}

class _FakeXFile extends XFile {
  _FakeXFile(super.path);
  @override
  Future<Uint8List> readAsBytes() async =>
      throw const FormatException('no metadata');
}

/// Hands the photo-first entry's picker a fixed device library — [photos],
/// or none at all for the "nothing to pick" case.
class _FixedLibrarySource implements PhotoLibrarySource {
  _FixedLibrarySource(this.photos);
  final List<GalleryAsset> photos;

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<List<GalleryAsset>> recentPhotos({int limit = 120}) async => photos;
}

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

/// Settles the push into the composer without ever calling `pumpAndSettle`
/// — the AI run behind it is backed by a `Completer` that never resolves in
/// these tests, so waiting for "no more frames scheduled" would hang. A
/// handful of timed pumps is enough for the route transition and the
/// microtask chain between the review screen's pop and `goNamed` to settle.
Future<void> _pumpIntoComposer(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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

  testWidgets('the ปันไกด์ card on Home opens the same sheet', (tester) async {
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

    await tester.tap(find.text('ปันไกด์'));
    await tester.pumpAndSettle();

    expect(find.text('สร้างแพลนเอง'), findsOneWidget);
    expect(find.text('ตกลง'), findsOneWidget);
  });

  testWidgets('Puntok opens the clip creator', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.text('ปันไกด์'));
    await tester.pumpAndSettle();
    // "Puntok" is also a nav-bar label; the sheet's row is the later one.
    await tester.tap(find.text('Puntok').last);
    await tester.pumpAndSettle();

    expect(find.byType(CreatePuntokScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets(
      'PunGuide opens our own picker, then the review screen, before the composer',
      (tester) async {
    await _pumpHome(tester, extraOverrides: [
      photoLibrarySourceProvider
          .overrideWithValue(_FixedLibrarySource([_FakeGalleryAsset('a')])),
    ]);

    await tester.tap(find.text('ปันไกด์'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PunGuide'));
    await tester.pumpAndSettle();

    // Our own picker is up first — not straight into the composer, nor the
    // review screen yet.
    expect(find.text('New PunGuide'), findsOneWidget);
    expect(find.text('ต่อไป'), findsOneWidget);
    expect(find.byType(CreatePostScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('photo-picker-tile-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ต่อไป'));
    await tester.pumpAndSettle();

    // Now the review screen, with the same photo carried over.
    expect(find.text('ฉันสร้างโพสเอง'), findsOneWidget);

    await tester.tap(find.text('ฉันสร้างโพสเอง'));
    await tester.pumpAndSettle();

    // Assert the destination, not its copy: the composer's heading is built
    // at runtime and has changed once already.
    expect(find.byType(CreatePostScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('the review screen\'s AI button also reaches the composer',
      (tester) async {
    // Never answers, so the overlay's own showing/hiding is asserted against
    // the composer's state rather than racing a real (or fast-failing) API
    // call — cancelling is what ends the run in this test.
    await _pumpHome(tester, extraOverrides: [
      photoLibrarySourceProvider
          .overrideWithValue(_FixedLibrarySource([_FakeGalleryAsset('a')])),
      plunoApiProvider.overrideWith((ref) => Completer<PlunoApi>().future),
    ]);

    await tester.tap(find.text('ปันไกด์'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PunGuide'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('photo-picker-tile-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ต่อไป'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ให้ AI สร้างโพสจากรูป'));
    await _pumpIntoComposer(tester);

    // The composer is up, but the "AI กำลังสร้างโพส" step covers it while
    // the assistant is still drafting.
    expect(find.byType(CreatePostScreen), findsOneWidget);
    expect(find.text('AI กำลังสร้างโพส'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    // Cancel rather than leaving the overlay's own animation ticking past
    // the end of the test.
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
  });

  testWidgets('ยกเลิก on the AI step hands the composer back early',
      (tester) async {
    await _pumpHome(tester, extraOverrides: [
      photoLibrarySourceProvider
          .overrideWithValue(_FixedLibrarySource([_FakeGalleryAsset('a')])),
      plunoApiProvider.overrideWith((ref) => Completer<PlunoApi>().future),
    ]);

    await tester.tap(find.text('ปันไกด์'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PunGuide'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('photo-picker-tile-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ต่อไป'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ให้ AI สร้างโพสจากรูป'));
    await _pumpIntoComposer(tester);
    expect(find.text('AI กำลังสร้างโพส'), findsOneWidget);

    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();

    expect(find.text('AI กำลังสร้างโพส'), findsNothing);
    expect(find.byType(CreatePostScreen), findsOneWidget);
  });

  testWidgets('backing out of our own picker leaves Home exactly as it was',
      (tester) async {
    await _pumpHome(tester, extraOverrides: [
      photoLibrarySourceProvider
          .overrideWithValue(_FixedLibrarySource([_FakeGalleryAsset('a')])),
    ]);

    await tester.tap(find.text('ปันไกด์'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PunGuide'));
    await tester.pumpAndSettle();

    expect(find.text('New PunGuide'), findsOneWidget);
    await tester.tap(find.byTooltip('ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('New PunGuide'), findsNothing);
    expect(find.byType(CreatePostScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}

/// Home on a phone viewport, with the routes the create sheet can reach.
Future<void> _pumpHome(WidgetTester tester,
    {List<Override> extraOverrides = const []}) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [...homeOverrides([feedTrip(id: 'lpq')]), ...extraOverrides],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              name: AppRoute.home.name,
              builder: (_, __) => const HomeScreen(),
            ),
            GoRoute(
              path: '/posts/create',
              name: AppRoute.createPost.name,
              builder: (_, state) {
                final args = state.extra;
                return CreatePostScreen(
                  initialAiImport:
                      args is CreatePostRouteArgs ? args.aiImport : null,
                  initialManualImport:
                      args is CreatePostRouteArgs ? args.manualImport : null,
                );
              },
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
}
