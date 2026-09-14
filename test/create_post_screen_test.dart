import 'package:pluno/core/api/models/trip.dart';
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
      _UnreadablePhoto(paths.removeAt(0));
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

Widget _harness({FakeAdapter? adapter, ApiTrip? initialTrip}) {
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
            builder: (_, __) => CreatePostScreen(initialTrip: initialTrip),
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

Future<void> _pumpComposer(WidgetTester tester,
    {FakeAdapter? adapter, ApiTrip? initialTrip}) async {
  // Taller than a phone on purpose: a spot now carries a name, a location, the
  // story, the attachment row and three detail rows, so two of them do not fit
  // one screen — and a lazy list never builds what it cannot show, which would
  // hide the second spot from the finders rather than prove anything about it.
  tester.view.physicalSize = const Size(393 * 3, 1800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  if (adapter?.replies.containsKey('POST /trips') ?? false) {
    adapter!.replies['GET /places/search'] = [
      const FakeReply(200, [
        {'id': 'place-1', 'mapId': 'map-1', 'name': 'เชียงใหม่'}
      ])
    ];
  }
  await tester.pumpWidget(_harness(adapter: adapter, initialTrip: initialTrip));
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

/// Scrolls the composer until [target] is built and on screen. The page is a
/// lazy list, so `ensureVisible` alone throws on anything past the fold.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 300,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

/// The story field of a spot. The name field comes first in the tree now, so
/// "the first TextField in a PostBlock" is no longer the body.
Finder _bodyField() => find.byWidgetPredicate((widget) =>
    widget is TextField &&
    widget.decoration?.hintText == 'Tell us about your trip..');

const _a = 'aaaaaaaa-0000-4000-8000-000000000001';
const _b = 'bbbbbbbb-0000-4000-8000-000000000002';
Map<String, dynamic> _image(String id, String path) => {
      'mediaId': id,
      'urls': {'large': path, 'thumbnail': path}
    };
Future<void> _finishPublish(WidgetTester tester) async {
  for (var i = 0; i < 100 && find.text('home').evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'uncertain upload reconciles gallery without reuploading successful files',
      (tester) async {
    final previous = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _TripPicker(Future.value([
      _UnreadablePhoto('assets/images/puntok_osaka.jpg'),
      _UnreadablePhoto('assets/images/puntok_london.jpg')
    ]));
    addTearDown(() => ImagePickerPlatform.instance = previous);
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'POST /trips/trip-new/media': [
        FakeReply(201, _image(_a, 'https://example.com/a.jpg')),
        const FakeReply(500, {'message': 'unknown upload result'})
      ],
      'GET /trips/trip-new/media': [
        const FakeReply(200, {
          'tripId': 'trip-new',
          'total': 2,
          'page': 1,
          'limit': 100,
          'items': [
            {
              'id': _a,
              'urls': {
                'large': 'https://example.com/a.jpg',
                'thumbnail': 'https://example.com/a.jpg'
              },
              'caption': 'รูปแรก'
            },
            {
              'id': _b,
              'urls': {
                'large': 'https://example.com/b.jpg',
                'thumbnail': 'https://example.com/b.jpg'
              },
              'caption': 'รูปที่ตรวจพบ'
            },
          ]
        })
      ],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });
    await _pumpComposer(tester, adapter: adapter);
    await tester.tap(find.text('Creates post from Photos'));
    await tester.pumpAndSettle();
    tester.widget<PostBlock>(find.byType(PostBlock)).titleController.text =
        'วันหยุด';
    await _confirmPlace(tester);
    await tester.tap(find.text('Share PunGuide'));
    await _finishPublish(tester);
    expect(adapter.paths.where((p) => p == 'POST /trips/trip-new/media'),
        hasLength(2));
    expect(adapter.paths, isNot(contains('PATCH /trips/trip-new')));
    await tester.tap(find.text('Share PunGuide'));
    for (var i = 0;
        i < 10 && find.text('ตรวจรูปที่อัปโหลดไม่ทราบผล').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ตรวจรูปที่อัปโหลดไม่ทราบผล'), findsOneWidget);
    await tester.tap(find.text('รูปที่ตรวจพบ'));
    await _finishPublish(tester);
    expect(find.text('home'), findsOneWidget);
    expect(adapter.paths.where((p) => p == 'POST /trips/trip-new/media'),
        hasLength(2));
    expect(adapter.paths.where((p) => p == 'POST /trips'), hasLength(1));
    expect(adapter.bodyOf('PATCH /trips/trip-new')!['contents'][0]['mediaIds'],
        [_a, _b]);
  });

  testWidgets('draft creation retry reuses key and original creation payload',
      (tester) async {
    final adapter = FakeAdapter({
      'POST /trips': [
        const FakeReply(500, {'message': 'unknown create result'}),
        FakeReply(201, createdTripJson())
      ],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())]
    });
    await _pumpComposer(tester, adapter: adapter);
    await tester.enterText(find.byType(TextField).first, 'เรื่องแรก');
    await _confirmPlace(tester);
    await tester.tap(find.text('Share PunGuide'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'แก้ข้อความ');
    await tester.tap(find.text('Share PunGuide'));
    await _finishPublish(tester);
    final creates = adapter.requests
        .where((r) => r.method == 'POST' && r.path == '/trips')
        .toList();
    expect(creates, hasLength(2));
    expect(creates[0].headers['Idempotency-Key'],
        creates[1].headers['Idempotency-Key']);
    expect(creates[0].data, creates[1].data);
    expect(adapter.bodyOf('PATCH /trips/trip-new')!['title'], 'แก้ข้อความ');
  });

  testWidgets(
      'photo-only content publishes with user-entered trip fields and no cover',
      (tester) async {
    final previous = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _TripPicker(
        Future.value([_UnreadablePhoto('assets/images/puntok_osaka.jpg')]));
    addTearDown(() => ImagePickerPlatform.instance = previous);
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'POST /trips/trip-new/media': [
        FakeReply(201, _image(_a, 'https://example.com/a.jpg'))
      ],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });
    await _pumpComposer(tester, adapter: adapter);
    await tester.tap(find.text('Creates post from Photos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share PunGuide'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'ชื่อโพสต์'), 'วันหยุด');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'จุดหมาย (พิมพ์เองได้)'),
        'ระหว่างทาง');
    await tester.tap(find.widgetWithText(TextButton, 'บันทึก'));
    await _finishPublish(tester);
    expect(find.text('home'), findsOneWidget);
    expect(adapter.bodyOf('POST /trips'),
        {'type': 'content', 'title': 'วันหยุด', 'destination': 'ระหว่างทาง'});
    expect(
        adapter.requests
            .firstWhere((r) => r.method == 'POST')
            .headers['Idempotency-Key'],
        isNotEmpty);
    expect(adapter.bodyOf('PATCH /trips/trip-new')!['contents'], [
      {
        'content': '',
        'mediaIds': [_a],
        'location': {'status': 'none'}
      }
    ]);
    expect(adapter.paths, isNot(contains('PUT /trips/trip-new/cover')));
  });

  testWidgets(
      'owner edit preserves media order and only confirms suggestion on tap',
      (tester) async {
    final adapter = FakeAdapter({
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())]
    });
    final trip = ApiTrip.fromJson({
      ...createdTripJson(),
      'type': 'content',
      'contents': [
        {
          'content': '',
          'mediaIds': [_a, _b],
          'images': [
            _image(_a, 'assets/images/puntok_osaka.jpg'),
            _image(_b, 'assets/images/puntok_london.jpg')
          ],
          'location': {'status': 'suggested', 'name': 'ร้านที่แนะนำ'},
          'photoMetadata': [
            {'mediaId': _a, 'takenAt': '2026-09-01T10:00:00+07:00'}
          ]
        },
      ]
    });
    await _pumpComposer(tester, adapter: adapter, initialTrip: trip);
    expect(find.text('ร้านที่แนะนำ'), findsOneWidget);
    expect(find.text('สถานที่ที่แนะนำจากรูป'), findsOneWidget);
    tester
        .widget<PostBlock>(find.byType(PostBlock))
        .onConfirmLocationInItem!(0);
    await tester.pumpAndSettle();
    tester.widget<PostBlock>(find.byType(PostBlock)).onDropBeforeImage!(
        (0, 1), 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share PunGuide'));
    await _finishPublish(tester);
    expect(adapter.paths, ['PATCH /trips/trip-new']);
    final section =
        (adapter.bodyOf('PATCH /trips/trip-new')!['contents'] as List).single;
    expect(section['mediaIds'], [_b, _a]);
    expect(
        section['location'], {'status': 'confirmed', 'name': 'ร้านที่แนะนำ'});
    expect(section['photoMetadata'], [
      {'mediaId': _a, 'takenAt': '2026-09-01T10:00:00+07:00'}
    ]);
    expect(section.containsKey('images'), isFalse);
  });

  testWidgets('removed cover is dereferenced before deleting media',
      (tester) async {
    final adapter = FakeAdapter({
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
      'DELETE /trips/trip-new/media/$_a': [const FakeReply(204, null)]
    });
    final trip = ApiTrip.fromJson({
      ...createdTripJson(),
      'type': 'content',
      'coverImage': _image(_a, 'assets/images/puntok_osaka.jpg'),
      'contents': [
        {
          'content': '',
          'mediaIds': [_a, _b],
          'images': [
            _image(_a, 'assets/images/puntok_osaka.jpg'),
            _image(_b, 'assets/images/puntok_london.jpg')
          ]
        },
      ]
    });
    await _pumpComposer(tester, adapter: adapter, initialTrip: trip);
    tester.widget<PostBlock>(find.byType(PostBlock)).onRemoveImage!(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share PunGuide'));
    await _finishPublish(tester);
    expect(adapter.paths, [
      'PATCH /trips/trip-new',
      'DELETE /trips/trip-new/media/$_a',
      'PATCH /trips/trip-new'
    ]);
    expect(adapter.requests.first.data['contents'][0]['mediaIds'], [_b]);
    expect(adapter.requests.first.data.containsKey('visibility'), isFalse);
  });

  testWidgets('unavailable reference blocks publish until explicitly removed',
      (tester) async {
    final adapter = FakeAdapter({});
    final trip = ApiTrip.fromJson({
      ...createdTripJson(),
      'type': 'content',
      'contents': [
        {
          'content': '',
          'mediaIds': [_a],
          'images': [
            {'mediaId': _a, 'unavailable': true}
          ]
        }
      ]
    });
    await _pumpComposer(tester, adapter: adapter, initialTrip: trip);
    await tester.tap(find.text('Share PunGuide'));
    await tester.pumpAndSettle();
    expect(find.textContaining('มีรูปที่ไม่พร้อมใช้งาน'), findsOneWidget);
    expect(adapter.paths, isEmpty);
  });

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
    await tester.enterText(_bodyField().first, 'ข้อความเดิม');
    await tester.tap(find.text('Creates post from Photos'));
    await tester.pumpAndSettle();
    var blocks = tester.widgetList<PostBlock>(find.byType(PostBlock)).toList();
    expect(blocks, hasLength(2));
    expect(blocks.first.bodyController.text, 'ข้อความเดิม');
    expect(blocks.last.imagePaths, hasLength(2));
    expect(blocks.last.bodyController.text, isEmpty);
    expect(blocks.last.place, isNull);
    final secondBlock = blocks.last;
    blocks.first.onDropImage!((1, 0));
    await tester.pumpAndSettle();
    blocks = tester.widgetList<PostBlock>(find.byType(PostBlock)).toList();
    expect(blocks.first.imagePaths, ['assets/images/puntok_osaka.jpg']);
    expect(secondBlock.imagePaths, ['assets/images/puntok_london.jpg']);
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
    await tester.tap(find.text('Creates post from Photos'));
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
    await tester.tap(find.text('Creates post from Photos'));
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
      'photo-only draft asks for trip fields and can return without publishing',
      (tester) async {
    final adapter = FakeAdapter({});
    final previous = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _TripPicker(
        Future.value([_UnreadablePhoto('assets/images/puntok_osaka.jpg')]));
    addTearDown(() => ImagePickerPlatform.instance = previous);
    await _pumpComposer(tester, adapter: adapter);
    await tester.tap(find.text('Creates post from Photos'));
    await tester.pumpAndSettle();
    expect(tester.widget<PostBlock>(find.byType(PostBlock)).imagePaths,
        hasLength(1));
    await tester.tap(find.text('Share PunGuide'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('กลับไปแก้ไข'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
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
      await tester.tap(find.text('Creates post from Photos'));
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
          'mediaId': 'aaaaaaaa-0000-4000-8000-000000000001',
          'urls': {
            'large': 'https://example.com/one.jpg',
            'thumbnail': 'https://example.com/one.jpg'
          }
        }),
        const FakeReply(201, {
          'mediaId': 'bbbbbbbb-0000-4000-8000-000000000002',
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
      await tester.ensureVisible(find.widgetWithIcon(PostAddChip, Icons.photo_library_outlined));
      await tester.tap(find.widgetWithIcon(PostAddChip, Icons.photo_library_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เลือกจากคลังภาพ'));
      await tester.pumpAndSettle();
    }
    tester.widget<PostBlock>(find.byType(PostBlock)).titleController.text =
        'ทริปของฉัน';
    expect(find.text('รูปหน้าปก'), findsNothing);
    await tester.ensureVisible(find.text('ใช้เป็นหน้าปก').last);
    await tester.tap(find.text('ใช้เป็นหน้าปก').last);
    await tester.pumpAndSettle();
    expect(find.text('รูปหน้าปก'), findsOneWidget);
    expect(tester.widget<PostBlock>(find.byType(PostBlock)).coverPath,
        'assets/images/puntok_london.jpg');
    if (adapter.replies.containsKey('POST /trips')) await _confirmPlace(tester);
    await tester.tap(find.text('Share PunGuide'));
    for (var i = 0;
        i < 100 && !adapter.paths.contains('PATCH /trips/trip-new');
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    expect(adapter.paths, contains('PUT /trips/trip-new/cover'));
    await tester.pumpAndSettle();
    expect(adapter.bodyOf('PUT /trips/trip-new/cover'),
        {'mediaId': 'bbbbbbbb-0000-4000-8000-000000000002'});
    expect(adapter.paths.indexOf('PUT /trips/trip-new/cover'),
        lessThan(adapter.paths.indexOf('PATCH /trips/trip-new')));
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('removing the selected cover never chooses another automatically',
      (tester) async {
    final previousPicker = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _CoverImagePicker();
    addTearDown(() => ImagePickerPlatform.instance = previousPicker);
    await _pumpComposer(tester);
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.widgetWithIcon(PostAddChip, Icons.photo_library_outlined));
      await tester.tap(find.widgetWithIcon(PostAddChip, Icons.photo_library_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เลือกจากคลังภาพ'));
      await tester.pumpAndSettle();
    }
    var block = tester.widget<PostBlock>(find.byType(PostBlock));
    expect(block.coverPath, isNull);
    block.onSelectCover!('assets/images/puntok_osaka.jpg');
    block.onRemoveImage!(0);
    await tester.pumpAndSettle();
    block = tester.widget<PostBlock>(find.byType(PostBlock));
    expect(block.coverPath, isNull);
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
        _bodyField().first,
        'เรื่องราว');
    await tester.pumpAndSettle();
    if (adapter.replies.containsKey('POST /trips')) await _confirmPlace(tester);
    await tester.tap(find.text('Share PunGuide'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(adapter.bodyOf('POST /trips'), {
      'type': 'content',
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
        _bodyField().first,
        'เดินเล่น');
    await tester.pumpAndSettle();
    if (adapter.replies.containsKey('POST /trips')) await _confirmPlace(tester);
    await tester.tap(find.text('Share PunGuide'));
    await tester.pumpAndSettle();
    expect(adapter.paths.where((path) => path == 'POST /trips'), hasLength(1));
    expect(adapter.bodyOf('POST /trips'), {
      'type': 'content',
      'title': 'เดินเล่น',
      'destination': 'เชียงใหม่',
    });
    expect(adapter.bodyOf('PATCH /trips/trip-new')!['contents'], [
      {
        'content': 'เดินเล่น',
        'mediaIds': <String>[],
        'location': {'status': 'confirmed', 'name': 'เชียงใหม่'}
      },
    ]);
    expect(adapter.bodyOf('PATCH /trips/trip-new')!['visibility'], 'public');
    if (adapter.replies.containsKey('POST /trips')) await _confirmPlace(tester);
    await tester.tap(find.text('Share PunGuide'));
    await tester.pumpAndSettle();
    expect(adapter.paths.where((path) => path == 'POST /trips'), hasLength(1));
    expect(adapter.paths.where((path) => path == 'PATCH /trips/trip-new'),
        hasLength(2));
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('the composer lays out every part of the design', (tester) async {
    await _pumpComposer(tester);

    // The dark cap.
    expect(find.text('Create Post'), findsOneWidget);
    expect(find.text('Creates post from Photos'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);

    // The spot: a name, where it is, then the story.
    expect(find.text('ตั้งชื่อโพส..'), findsOneWidget);
    expect(find.text('Add Location'), findsOneWidget);
    expect(find.text('Tell us about your trip..'), findsOneWidget);

    // Attachments: camera, gallery, video, Trip Hack.
    expect(find.widgetWithIcon(PostAddChip, Icons.photo_camera_outlined),
        findsOneWidget);
    expect(find.widgetWithIcon(PostAddChip, Icons.photo_library_outlined),
        findsOneWidget);
    expect(find.widgetWithIcon(PostAddChip, Icons.videocam_outlined),
        findsOneWidget);
    expect(find.text('Trip Hack'), findsOneWidget);

    // The bar is pinned, so it is there before any scrolling.
    expect(find.text('Save Draft'), findsOneWidget);
    expect(find.text('Share PunGuide'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    for (final row in const [
      'Recommend Time',
      'Activity And Style',
      'How to Get Here',
    ]) {
      expect(find.text(row), findsOneWidget, reason: row);
    }
    expect(find.text('Every one can remix your trip'), findsOneWidget);
    expect(find.text('เพิ่มจุดต่อไป'), findsOneWidget);
  });

  testWidgets('เพิ่มจุดต่อไป appends a spot and the extra one goes away',
      (tester) async {
    await _pumpComposer(tester);

    expect(find.byType(PostBlock), findsOneWidget);
    // The first section keeps no remove, so a post always has one.
    expect(find.text('ลบจุดนี้'), findsNothing);

    await _scrollTo(tester, find.text('เพิ่มจุดต่อไป'));
    await tester.tap(find.text('เพิ่มจุดต่อไป'));
    await tester.pumpAndSettle();

    expect(find.byType(PostBlock), findsNWidgets(2));
    expect(find.text('ลบจุดนี้'), findsNWidgets(2));

    await tester.tap(find.text('ลบจุดนี้').last);
    await tester.pumpAndSettle();

    expect(find.byType(PostBlock), findsOneWidget);
  });

  testWidgets(
      'moving a section keeps its text and deleting removes only that section',
      (tester) async {
    await _pumpComposer(tester);
    await tester.enterText(
        _bodyField().first,
        'ส่วนแรก');
    await _scrollTo(tester, find.text('เพิ่มจุดต่อไป'));
    await tester.tap(find.text('เพิ่มจุดต่อไป'));
    await tester.pumpAndSettle();
    await tester.enterText(
        _bodyField().last,
        'ส่วนที่สอง');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('เลื่อนขึ้น').last);
    await tester.pumpAndSettle();
    final fields = tester.widgetList<TextField>(_bodyField()).toList();
    expect(fields.first.controller!.text, 'ส่วนที่สอง');
    expect(fields.last.controller!.text, 'ส่วนแรก');
    await tester.tap(find.text('ลบจุดนี้').last);
    await tester.pumpAndSettle();
    expect(find.text('ส่วนแรก'), findsNothing);
    expect(find.text('ส่วนที่สอง'), findsOneWidget);
  });

  testWidgets('the spot name is always on screen and the pencil focuses it',
      (tester) async {
    await _pumpComposer(tester);

    // No chip to summon it any more: the field is part of the spot.
    expect(find.text('ตั้งชื่อโพส..'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'คาเฟ่วิวภูเขา');
    await tester.pumpAndSettle();
    expect(
        tester.widget<PostBlock>(find.byType(PostBlock)).titleController.text,
        'คาเฟ่วิวภูเขา');

    await tester.tap(find.byTooltip('แก้ชื่อ'));
    await tester.pumpAndSettle();
    expect(tester.widget<PostBlock>(find.byType(PostBlock)).titleFocus.hasFocus,
        isTrue);
  });

  testWidgets('a titled section can publish multiple photo description sets',
      (tester) async {
    final previousPicker = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _CoverImagePicker();
    addTearDown(() => ImagePickerPlatform.instance = previousPicker);
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'POST /trips/trip-new/media': [
        FakeReply(201, _image(_a, 'https://example.com/a.jpg')),
        FakeReply(201, _image(_b, 'https://example.com/b.jpg')),
      ],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });
    await _pumpComposer(tester, adapter: adapter);

    var block = tester.widget<PostBlock>(find.byType(PostBlock));
    block.titleController.text = '1st Nagisa Park';
    block.bodyController.text = 'ทุ่งดอกไม้ริมทะเลสาบ';
    block.onPickImageInItem!(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('เลือกจากคลังภาพ'));
    await tester.pumpAndSettle();

    block = tester.widget<PostBlock>(find.byType(PostBlock));
    block.onAddItem!();
    await tester.pumpAndSettle();
    block = tester.widget<PostBlock>(find.byType(PostBlock));
    block.items![1].bodyController.text = 'มุมภูเขาและดอกทานตะวัน';
    block.onPickImageInItem!(1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('เลือกจากคลังภาพ'));
    await tester.pumpAndSettle();
    await _confirmPlace(tester);
    block = tester.widget<PostBlock>(find.byType(PostBlock));
    block.onPickPlaceInItem!(1);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'เชียงใหม่');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เชียงใหม่').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share PunGuide'));
    await _finishPublish(tester);

    expect(find.text('home'), findsOneWidget);
    expect(adapter.bodyOf('PATCH /trips/trip-new')!['contents'], [
      {
        'title': '1st Nagisa Park',
        'content': 'ทุ่งดอกไม้ริมทะเลสาบ',
        'mediaIds': [_a],
        'location': {'status': 'confirmed', 'name': 'เชียงใหม่'}
      },
      {
        'title': '1st Nagisa Park',
        'content': 'มุมภูเขาและดอกทานตะวัน',
        'mediaIds': [_b],
        'location': {'status': 'confirmed', 'name': 'เชียงใหม่'}
      },
    ]);
  });

  testWidgets('เผยแพร่ waits for something to post', (tester) async {
    await _pumpComposer(tester);

    final publish = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Share PunGuide'),
        matching: find.byType(FilledButton),
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

    final enabled = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Share PunGuide'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('the audience pill switches who sees the post', (tester) async {
    await _pumpComposer(tester);

    await tester.tap(find.text('Public'));
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
        .tap(find.text('Add Location').first);
    await tester.pumpAndSettle();

    // The sheet opens on its own header, and with no location answered yet it
    // offers to turn location services on instead of guessing a point.
    expect(find.text('Add Location'), findsWidgets);
    expect(find.text('Find places nearby'), findsOneWidget);
    expect(find.text('Turn on Location Services'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'akha');
    // Past the 350ms the picker collapses keystrokes over.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // A result row is the name over its address; with no origin there is no
    // distance in front of it.
    expect(find.text('Akha Ama Coffee'), findsOneWidget);
    expect(find.text('9/1 Mata Apartment, Chiang Mai 50200, Thailand'),
        findsOneWidget);

    await tester.tap(find.text('Akha Ama Coffee'));
    await tester.pumpAndSettle();

    // The spot's row now carries the same two lines.
    expect(find.text('Akha Ama Coffee'), findsOneWidget);
    expect(find.text('9/1 Mata Apartment, Chiang Mai 50200, Thailand'),
        findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    expect(adapter.paths, contains('GET /places/search'));

    // Taking the pin off happens back in the sheet, since the row itself
    // carries only a chevron now.
    await tester.tap(find.text('Akha Ama Coffee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบสถานที่ออกจากจุดนี้'));
    await tester.pumpAndSettle();

    expect(find.text('Akha Ama Coffee'), findsNothing);
    expect(find.text('Add Location'), findsOneWidget);
  });

  testWidgets('a chosen photo fills the width above its place row',
      (tester) async {
    // The picker is a platform channel, so the block is driven directly with
    // a bundled asset — what matters here is the layout it produces. A whole
    // spot is taller than a phone, and this one is not in a scroll view.
    tester.view.physicalSize = const Size(393 * 3, 1800 * 3);
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
            imagePath: 'assets/images/puntok_osaka.jpg',
            imagePaths: const [],
            place: const PostPlace(
              id: 'p1',
              name: 'Akha Ama Coffee',
              area: 'เชียงใหม่',
            ),
            onPickImage: () {},
            onClearImage: () {},
            onPickPlace: () {},
            onClearPlace: () {},
            onExtra: (_) {},
          ),
        ),
      ),
    ));
    await tester.pump();

    final photo = tester.getRect(find.byType(AspectRatio));
    expect(photo.width, 393 - 36);
    expect(photo.height, closeTo((393 - 36) / 1.6, 0.5));

    // The place now leads the spot: it sits above the story and the photo,
    // not beside or under them.
    final row = tester.getRect(find.text('Akha Ama Coffee'));
    expect(row.bottom, lessThan(photo.top));
  });

  testWidgets('the page lays out on a phone without overflow', (tester) async {
    await _pumpComposer(tester);

    await _scrollTo(tester, find.text('เพิ่มจุดต่อไป'));
    await tester.tap(find.text('เพิ่มจุดต่อไป'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
