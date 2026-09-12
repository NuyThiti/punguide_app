import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/create_post/domain/models/post_draft.dart';
import 'package:pluno/features/create_post/presentation/create_post_screen.dart';
import 'package:pluno/features/create_post/presentation/widgets/post_block.dart';

import 'support/fake_api.dart';

class _CoverImagePicker extends ImagePickerPlatform {
  final paths = [
    'assets/images/puntok_osaka.jpg',
    'assets/images/puntok_london.jpg'
  ];
  @override
  Future<XFile?> getImageFromSource(
          {required ImageSource source,
          ImagePickerOptions options = const ImagePickerOptions()}) async =>
      XFile(paths.removeAt(0));
}

class _UnreadablePhoto extends XFile {
  _UnreadablePhoto(super.path);
  @override
  Future<Uint8List> readAsBytes() async =>
      throw const FormatException('no metadata');
}

class _TripPicker extends ImagePickerPlatform {
  _TripPicker(this.result);
  final Future<List<XFile>> result;
  @override
  Future<List<XFile>> getMultiImageWithOptions(
          {MultiImagePickerOptions options =
              const MultiImagePickerOptions()}) =>
      result;
}

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

  if (adapter?.replies.containsKey('POST /trips') ?? false) {
    adapter!.replies['GET /places/search'] = [
      const FakeReply(200, [
        {'id': 'place-1', 'mapId': 'map-1', 'name': 'เชียงใหม่'}
      ])
    ];
  }
  await tester.pumpWidget(_harness(adapter: adapter));
  await tester.pumpAndSettle();
}

Future<void> _confirmPlace(WidgetTester tester) async {
  if (tester.widget<PostBlock>(find.byType(PostBlock).first).place != null)
    return;
  tester.widget<PostBlock>(find.byType(PostBlock).first).onPickPlace();
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, 'เชียงใหม่');
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.tap(find.text('เชียงใหม่').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'trip photos append without overwriting text, move, and remain optional',
      (tester) async {
    final previous = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _TripPicker(Future.value([
      _UnreadablePhoto('assets/images/puntok_osaka.jpg'),
      _UnreadablePhoto('assets/images/puntok_london.jpg'),
    ]));
    addTearDown(() => ImagePickerPlatform.instance = previous);
    await _pumpComposer(tester);
    await tester.enterText(find.byType(TextField).first, 'ข้อความเดิม');
    await tester.tap(find.text('สร้างจากรูปทริป'));
    await tester.pumpAndSettle();
    var blocks = tester.widgetList<PostBlock>(find.byType(PostBlock)).toList();
    expect(blocks, hasLength(2));
    expect(blocks.first.bodyController.text, 'ข้อความเดิม');
    expect(blocks.last.imagePaths, hasLength(2));
    expect(blocks.last.bodyController.text, isEmpty);
    expect(blocks.last.place, isNull);
    blocks.first.onDropImage!((1, 0));
    await tester.pumpAndSettle();
    blocks = tester.widgetList<PostBlock>(find.byType(PostBlock)).toList();
    expect(blocks.first.imagePaths, ['assets/images/puntok_osaka.jpg']);
    expect(blocks.last.imagePaths, ['assets/images/puntok_london.jpg']);
    blocks.first.onDropBeforeImage!((1, 0), 0);
    await tester.pumpAndSettle();
    expect(tester.widget<PostBlock>(find.byType(PostBlock).first).imagePaths,
        ['assets/images/puntok_london.jpg', 'assets/images/puntok_osaka.jpg']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel ignores a late picker result and preserves writing',
      (tester) async {
    final pending = Completer<List<XFile>>();
    final previous = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _TripPicker(pending.future);
    addTearDown(() => ImagePickerPlatform.instance = previous);
    await _pumpComposer(tester);
    await tester.enterText(find.byType(TextField).first, 'ยังอยู่');
    await tester.tap(find.text('สร้างจากรูปทริป'));
    await tester.pump();
    expect(find.text('กำลังจัดรูปเป็นเรื่องราว…'), findsOneWidget);
    await tester.tap(find.text('ยกเลิก'));
    pending.complete([_UnreadablePhoto('late.jpg')]);
    await tester.pumpAndSettle();
    expect(find.text('ยังอยู่'), findsOneWidget);
    expect(
        tester.widget<PostBlock>(find.byType(PostBlock)).imagePaths, isEmpty);
  });

  testWidgets('closing during import keeps the draft when reopening',
      (tester) async {
    final pending = Completer<List<XFile>>();
    final previous = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _TripPicker(pending.future);
    addTearDown(() => ImagePickerPlatform.instance = previous);
    await _pumpComposer(tester);
    await tester.enterText(find.byType(TextField).first, 'ร่างที่เก็บไว้');
    final router = GoRouter.of(tester.element(find.byType(CreatePostScreen)));
    await tester.tap(find.text('สร้างจากรูปทริป'));
    await tester.pump();
    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    pending.complete([_UnreadablePhoto('late.jpg')]);
    await tester.pumpAndSettle();
    router.go('/posts/create');
    await tester.pumpAndSettle();
    expect(find.text('ร่างที่เก็บไว้'), findsOneWidget);
    expect(
        tester.widget<PostBlock>(find.byType(PostBlock)).imagePaths, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'photo-only draft shows API limitation without fabricated payload',
      (tester) async {
    final adapter = FakeAdapter({});
    final previous = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _TripPicker(
        Future.value([_UnreadablePhoto('assets/images/puntok_osaka.jpg')]));
    addTearDown(() => ImagePickerPlatform.instance = previous);
    await _pumpComposer(tester, adapter: adapter);
    await tester.tap(find.text('สร้างจากรูปทริป'));
    await tester.pumpAndSettle();
    expect(tester.widget<PostBlock>(find.byType(PostBlock)).imagePaths,
        hasLength(1));
    await tester.tap(find.text('ปันไกด์'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Trip API ปัจจุบัน'), findsOneWidget);
    expect(adapter.paths, isEmpty);
  });

  for (final denied in [false, true]) {
    testWidgets(
        denied
            ? 'picker permission failure retains draft'
            : 'empty selection retains draft', (tester) async {
      final pending = Completer<List<XFile>>();
      final previous = ImagePickerPlatform.instance;
      ImagePickerPlatform.instance = _TripPicker(pending.future);
      addTearDown(() => ImagePickerPlatform.instance = previous);
      await _pumpComposer(tester);
      await tester.enterText(find.byType(TextField).first, 'ร่างเดิม');
      await tester.tap(find.text('สร้างจากรูปทริป'));
      await tester.pump();
      if (denied) {
        pending.completeError(Exception('permission denied'));
      } else {
        pending.complete([]);
      }
      await tester.pumpAndSettle();
      expect(find.text('ร่างเดิม'), findsOneWidget);
      expect(find.text('กำลังจัดรูปเป็นเรื่องราว…'), findsNothing);
      expect(
          tester.widget<PostBlock>(find.byType(PostBlock)).imagePaths, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('one cover is selected and uploaded media ID is saved',
      (tester) async {
    final previousPicker = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _CoverImagePicker();
    addTearDown(() => ImagePickerPlatform.instance = previousPicker);
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'POST /trips/trip-new/media': [
        const FakeReply(201, {
          'mediaId': 'photo-one',
          'urls': {
            'large': 'https://example.com/one.jpg',
            'thumbnail': 'https://example.com/one.jpg'
          }
        }),
        const FakeReply(201, {
          'mediaId': 'photo-two',
          'urls': {
            'large': 'https://example.com/two.jpg',
            'thumbnail': 'https://example.com/two.jpg'
          }
        }),
      ],
      'PUT /trips/trip-new/cover': [FakeReply(200, createdTripJson())],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });
    await _pumpComposer(tester, adapter: adapter);
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.widgetWithText(PostAddChip, 'รูปภาพ'));
      await tester.tap(find.widgetWithText(PostAddChip, 'รูปภาพ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เลือกจากคลังภาพ'));
      await tester.pumpAndSettle();
    }
    tester.widget<PostBlock>(find.byType(PostBlock)).titleController.text =
        'ทริปของฉัน';
    expect(find.text('รูปหน้าปก'), findsOneWidget);
    await tester.ensureVisible(find.text('ใช้เป็นหน้าปก'));
    await tester.tap(find.text('ใช้เป็นหน้าปก'));
    await tester.pumpAndSettle();
    expect(find.text('รูปหน้าปก'), findsOneWidget);
    expect(tester.widget<PostBlock>(find.byType(PostBlock)).coverPath,
        'assets/images/puntok_london.jpg');
    if (adapter.replies.containsKey('POST /trips')) await _confirmPlace(tester);
    await tester.tap(find.text('ปันไกด์'));
    for (var i = 0;
        i < 100 && !adapter.paths.contains('PATCH /trips/trip-new');
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    expect(adapter.paths, contains('PUT /trips/trip-new/cover'));
    await tester.pumpAndSettle();
    expect(
        adapter.bodyOf('PUT /trips/trip-new/cover'), {'mediaId': 'photo-two'});
    expect(adapter.paths.indexOf('PUT /trips/trip-new/cover'),
        lessThan(adapter.paths.indexOf('PATCH /trips/trip-new')));
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('removing the cover selects a remaining photo then clears it',
      (tester) async {
    final previousPicker = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _CoverImagePicker();
    addTearDown(() => ImagePickerPlatform.instance = previousPicker);
    await _pumpComposer(tester);
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.widgetWithText(PostAddChip, 'รูปภาพ'));
      await tester.tap(find.widgetWithText(PostAddChip, 'รูปภาพ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เลือกจากคลังภาพ'));
      await tester.pumpAndSettle();
    }
    var block = tester.widget<PostBlock>(find.byType(PostBlock));
    expect(block.coverPath, 'assets/images/puntok_osaka.jpg');
    block.onRemoveImage!(0);
    await tester.pumpAndSettle();
    block = tester.widget<PostBlock>(find.byType(PostBlock));
    expect(block.coverPath, 'assets/images/puntok_london.jpg');
    block.onRemoveImage!(0);
    await tester.pumpAndSettle();
    expect(tester.widget<PostBlock>(find.byType(PostBlock)).coverPath, isNull);
    expect(find.text('รูปหน้าปก'), findsNothing);
  });

  testWidgets('publishing generates trip info without a popup', (tester) async {
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });
    await _pumpComposer(tester, adapter: adapter);
    await tester.enterText(
        find
            .descendant(
                of: find.byType(PostBlock), matching: find.byType(TextField))
            .first,
        'เรื่องราว');
    await tester.pumpAndSettle();
    if (adapter.replies.containsKey('POST /trips')) await _confirmPlace(tester);
    await tester.tap(find.text('ปันไกด์'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(adapter.bodyOf('POST /trips'), {
      'title': 'เรื่องราว',
      'destination': 'เชียงใหม่',
    });
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('publish retries PATCH on the same draft after failure',
      (tester) async {
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'PATCH /trips/trip-new': [
        const FakeReply(500, {'message': 'ลองอีกครั้ง'}),
        FakeReply(200, createdTripJson()),
      ],
    });
    await _pumpComposer(tester, adapter: adapter);
    await tester.enterText(
        find
            .descendant(
                of: find.byType(PostBlock), matching: find.byType(TextField))
            .first,
        'เดินเล่น');
    await tester.pumpAndSettle();
    if (adapter.replies.containsKey('POST /trips')) await _confirmPlace(tester);
    await tester.tap(find.text('ปันไกด์'));
    await tester.pumpAndSettle();
    expect(adapter.paths.where((path) => path == 'POST /trips'), hasLength(1));
    expect(adapter.bodyOf('POST /trips'), {
      'title': 'เดินเล่น',
      'destination': 'เชียงใหม่',
    });
    expect(adapter.bodyOf('PATCH /trips/trip-new')!['contents'], [
      {
        'title': '',
        'content': 'เดินเล่น',
        'imageUrls': <String>[],
        'mapId': 'map-1'
      },
    ]);
    expect(adapter.bodyOf('PATCH /trips/trip-new')!['visibility'], 'public');
    if (adapter.replies.containsKey('POST /trips')) await _confirmPlace(tester);
    await tester.tap(find.text('ปันไกด์'));
    await tester.pumpAndSettle();
    expect(adapter.paths.where((path) => path == 'POST /trips'), hasLength(1));
    expect(adapter.paths.where((path) => path == 'PATCH /trips/trip-new'),
        hasLength(2));
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('the composer lays out every part of the design', (tester) async {
    await _pumpComposer(tester);

    expect(find.text('สร้างโพสต์'), findsOneWidget);
    expect(find.text('ปันไกด์'), findsOneWidget);
    expect(find.text('สาธารณะ'), findsOneWidget);
    expect(find.text('ชื่อโพสต์'), findsNothing);
    expect(find.text('จุดหมาย'), findsNothing);
    // The body leads, unlabelled; the optional parts are offered as chips.
    expect(find.text('เล่าเรื่องราวของทริปนี้…'), findsOneWidget);
    expect(find.widgetWithText(PostAddChip, 'หัวข้อ'), findsOneWidget);
    expect(find.widgetWithText(PostAddChip, 'รูปภาพ'), findsOneWidget);
    expect(find.widgetWithText(PostAddChip, 'เพิ่มสถานที่ (ไม่บังคับ)'),
        findsOneWidget);
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
    expect(find.textContaining('ใช้ข้อมูลจากทริป'), findsOneWidget);
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
    expect(find.text('ลบเนื้อหานี้'), findsNWidgets(2));

    await tester.tap(find.text('ลบเนื้อหานี้').last);
    await tester.pumpAndSettle();

    expect(find.byType(PostBlock), findsOneWidget);
  });

  testWidgets(
      'moving a section keeps its text and deleting removes only that section',
      (tester) async {
    await _pumpComposer(tester);
    await tester.enterText(
        find
            .descendant(
                of: find.byType(PostBlock), matching: find.byType(TextField))
            .first,
        'ส่วนแรก');
    await tester.tap(find.text('เพิ่มเนื้อหา'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find
            .descendant(
                of: find.byType(PostBlock), matching: find.byType(TextField))
            .last,
        'ส่วนที่สอง');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('เลื่อนขึ้น').last);
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextField>(find.descendant(
            of: find.byType(PostBlock), matching: find.byType(TextField)))
        .toList();
    expect(fields.first.controller!.text, 'ส่วนที่สอง');
    expect(fields.last.controller!.text, 'ส่วนแรก');
    await tester.tap(find.text('ลบเนื้อหานี้').last);
    await tester.pumpAndSettle();
    expect(find.text('ส่วนแรก'), findsNothing);
    expect(find.text('ส่วนที่สอง'), findsOneWidget);
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
    await tester.enterText(
        find
            .descendant(
                of: find.byType(PostBlock), matching: find.byType(TextField))
            .first,
        'คาเฟ่วิวภูเขา');
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
        of: find.text('ปันไกด์'),
        matching: find.byType(TextButton),
      ),
    );
    expect(publish.onPressed, isNull);

    await tester.enterText(
      find
          .descendant(
              of: find.byType(PostBlock), matching: find.byType(TextField))
          .first,
      'บรรยากาศดีมาก นั่งจิบกาแฟชมวิวภูเขา',
    );
    await tester.pumpAndSettle();

    final enabled = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('ปันไกด์'),
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

    await tester
        .tap(find.widgetWithText(PostAddChip, 'เพิ่มสถานที่ (ไม่บังคับ)'));
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
