import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/create_post/domain/models/post_draft.dart';
import 'package:pluno/features/create_post/presentation/create_post_screen.dart';
import 'package:pluno/features/create_post/presentation/widgets/post_block.dart';

import 'support/fake_api.dart';

Widget _harness({FakeAdapter? adapter}) {
  return ProviderScope(
    overrides: adapter == null
        ? const []
        : [plunoApiProvider.overrideWith((ref) async => fakeApi(adapter))],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/posts/create',
        routes: [
          GoRoute(
            path: '/posts/create',
            name: AppRoute.createPost.name,
            builder: (_, __) => const CreatePostScreen(),
          ),
          GoRoute(
            path: '/',
            name: AppRoute.home.name,
            builder: (_, __) => const Scaffold(body: Text('home')),
          ),
        ],
      ),
    ),
  );
}

Future<void> _pumpComposer(WidgetTester tester, {FakeAdapter? adapter}) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_harness(adapter: adapter));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the composer lays out every part of the design', (tester) async {
    await _pumpComposer(tester);

    expect(find.text('สร้างโพสต์'), findsOneWidget);
    expect(find.text('เผยแพร่'), findsOneWidget);
    expect(find.text('สาธารณะ'), findsOneWidget);
    // The body leads, unlabelled; the optional parts are offered as chips.
    expect(find.text('เล่าเรื่องราวของทริปนี้…'), findsOneWidget);
    expect(find.widgetWithText(PostAddChip, 'หัวข้อ'), findsOneWidget);
    expect(find.widgetWithText(PostAddChip, 'รูปภาพ'), findsOneWidget);
    expect(find.widgetWithText(PostAddChip, 'สถานที่'), findsOneWidget);
    // Each chip wears the glyph of what it adds: a gallery and a map.
    expect(
      find.widgetWithIcon(PostAddChip, Icons.photo_library_outlined),
      findsOneWidget,
    );
    expect(
      find.widgetWithIcon(PostAddChip, Icons.map_outlined),
      findsOneWidget,
    );
    expect(find.text('ไม่บังคับ'), findsOneWidget);
    expect(find.text('เพิ่มเนื้อหา'), findsOneWidget);
    expect(find.text('เพิ่มเรื่องราวส่วนถัดไป'), findsOneWidget);
    expect(find.textContaining('เชื่อมกับทริป'), findsOneWidget);
  });

  testWidgets('เพิ่มเนื้อหา appends a section and the extra one goes away',
      (tester) async {
    await _pumpComposer(tester);

    expect(find.byType(PostBlock), findsOneWidget);
    // The first section keeps no remove, so a post always has one.
    expect(find.text('ลบเนื้อหานี้'), findsNothing);

    await tester.tap(find.text('เพิ่มเนื้อหา'));
    await tester.pumpAndSettle();

    expect(find.byType(PostBlock), findsNWidgets(2));
    expect(find.text('ลบเนื้อหานี้'), findsOneWidget);

    await tester.tap(find.text('ลบเนื้อหานี้'));
    await tester.pumpAndSettle();

    expect(find.byType(PostBlock), findsOneWidget);
  });

  testWidgets('หัวข้อ adds a heading field, and its ✕ takes it back off',
      (tester) async {
    await _pumpComposer(tester);

    expect(find.text('หัวข้อ'), findsOneWidget); // the chip only

    await tester.tap(find.widgetWithText(PostAddChip, 'หัวข้อ'));
    await tester.pumpAndSettle();

    // The chip is spent, and the field it added carries the hint instead.
    expect(find.widgetWithText(PostAddChip, 'หัวข้อ'), findsNothing);
    expect(find.text('หัวข้อ'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'คาเฟ่วิวภูเขา');
    await tester.pumpAndSettle();
    expect(find.text('คาเฟ่วิวภูเขา'), findsOneWidget);

    await tester.tap(find.byTooltip('ลบหัวข้อ'));
    await tester.pumpAndSettle();

    expect(find.text('คาเฟ่วิวภูเขา'), findsNothing);
    expect(find.widgetWithText(PostAddChip, 'หัวข้อ'), findsOneWidget);
  });

  testWidgets('เผยแพร่ waits for something to post', (tester) async {
    await _pumpComposer(tester);

    final publish = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('เผยแพร่'),
        matching: find.byType(TextButton),
      ),
    );
    expect(publish.onPressed, isNull);

    await tester.enterText(
      find.byType(TextField).first,
      'บรรยากาศดีมาก นั่งจิบกาแฟชมวิวภูเขา',
    );
    await tester.pumpAndSettle();

    final enabled = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('เผยแพร่'),
        matching: find.byType(TextButton),
      ),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('the audience pill switches who sees the post', (tester) async {
    await _pumpComposer(tester);

    await tester.tap(find.text('สาธารณะ'));
    await tester.pumpAndSettle();

    expect(find.text('ใครเห็นโพสต์นี้'), findsOneWidget);
    await tester.tap(find.text(PostAudience.onlyMe.label));
    await tester.pumpAndSettle();

    expect(find.text(PostAudience.onlyMe.label), findsOneWidget);
    expect(find.text(PostAudience.public.label), findsNothing);
  });

  testWidgets('the place pin searches /places/search and fills the row',
      (tester) async {
    final adapter = FakeAdapter(<String, List<FakeReply>>{
      'GET /places/search': [
        const FakeReply(200, [
          {
            'id': 'place-1',
            'name': 'Akha Ama Coffee',
            'address': '9/1 Mata Apartment, Chiang Mai 50200, Thailand',
          },
        ]),
      ],
    });

    await _pumpComposer(tester, adapter: adapter);

    await tester.tap(find.widgetWithText(PostAddChip, 'สถานที่'));
    await tester.pumpAndSettle();

    expect(find.text('สถานที่ของหัวข้อนี้'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'akha');
    // Past the 350ms the picker collapses keystrokes over.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Akha Ama Coffee'), findsOneWidget);
    // The postcode and the country are trimmed off the address.
    expect(find.text('Chiang Mai'), findsOneWidget);

    await tester.tap(find.text('Akha Ama Coffee'));
    await tester.pumpAndSettle();

    // The pinned place becomes its own row, removable on the spot.
    expect(find.text('Akha Ama Coffee, Chiang Mai'), findsOneWidget);
    expect(find.byIcon(Icons.map), findsOneWidget);
    expect(find.byTooltip('ลบสถานที่'), findsOneWidget);
    expect(adapter.paths, contains('GET /places/search'));

    await tester.tap(find.byTooltip('ลบสถานที่'));
    await tester.pumpAndSettle();

    expect(find.text('Akha Ama Coffee, Chiang Mai'), findsNothing);
  });

  testWidgets('a chosen photo fills the width above its place row',
      (tester) async {
    // The picker is a platform channel, so the block is driven directly with
    // a bundled asset — what matters here is the layout it produces.
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final title = TextEditingController();
    final body = TextEditingController();
    final focus = FocusNode();
    addTearDown(() {
      title.dispose();
      body.dispose();
      focus.dispose();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: PostBlock(
            titleController: title,
            titleFocus: focus,
            bodyController: body,
            showTitle: false,
            imagePath: 'assets/images/puntok_osaka.jpg',
            place: const PostPlace(
              id: 'p1',
              name: 'Akha Ama Coffee',
              area: 'เชียงใหม่',
            ),
            onAddTitle: () {},
            onClearTitle: () {},
            onPickImage: () {},
            onClearImage: () {},
            onPickPlace: () {},
            onClearPlace: () {},
          ),
        ),
      ),
    ));
    await tester.pump();

    final photo = tester.getRect(find.byType(AspectRatio));
    expect(photo.width, 393 - 36);
    expect(photo.height, closeTo((393 - 36) / 1.6, 0.5));

    // The place row sits under the photo, not beside it.
    final row = tester.getRect(find.text('Akha Ama Coffee, เชียงใหม่'));
    expect(row.top, greaterThan(photo.bottom));
  });

  testWidgets('the page lays out on a phone without overflow', (tester) async {
    await _pumpComposer(tester);

    await tester.tap(find.text('เพิ่มเนื้อหา'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

