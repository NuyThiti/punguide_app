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
import 'package:pluno/features/create_post/presentation/widgets/post_title_field.dart';
import 'package:pluno/features/location_access/domain/location_service.dart';
import 'package:pluno/features/location_access/presentation/providers/location_providers.dart';

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

Widget _harness(
    {FakeAdapter? adapter, ApiTrip? initialTrip, List<Override> extra = const []}) {
  // Always a fake client: importing photos now talks to the API before it
  // draws anything, and an unstubbed route answers 500 rather than reaching
  // for plugins the test environment does not have.
  final client = adapter ?? FakeAdapter(<String, List<FakeReply>>{});
  return ProviderScope(
    overrides: [
      plunoApiProvider.overrideWith((ref) async => fakeApi(client)),
      ...extra,
    ],
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

/// Grants location, which is what gives `placePinOriginProvider` a point to
/// measure from — without it the composer has no idea where the traveller is
/// and never fills the place in.
final _located = [
  storedLocationPermissionProvider
      .overrideWithValue(LocationPermissionStatus.granted),
];

Future<void> _pumpComposer(WidgetTester tester,
    {FakeAdapter? adapter,
    ApiTrip? initialTrip,
    List<Override> extra = const []}) async {
  // Taller than a phone on purpose: a spot now carries a name, a location, the
  // story, the attachment row and three detail rows, so two of them do not fit
  // one screen — and a lazy list never builds what it cannot show, which would
  // hide the second spot from the finders rather than prove anything about it.
  tester.view.physicalSize = const Size(393 * 3, 1800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  // The เชื่อมกับแผนของฉัน step reads the traveller's plans. Without an answer
  // its spinner never stops, and pumpAndSettle would time out on every publish.
  final client = adapter ?? FakeAdapter(<String, List<FakeReply>>{});
  client.replies
      .putIfAbsent('GET /trips/mine', () => [const FakeReply(200, [])]);

  if (client.replies.containsKey('POST /trips')) {
    client.replies['GET /places/search'] = [
      const FakeReply(200, [
        {'id': 'place-1', 'mapId': 'map-1', 'name': 'เชียงใหม่'}
      ])
    ];
  }
  await tester.pumpWidget(
      _harness(adapter: client, initialTrip: initialTrip, extra: extra));
  await tester.pumpAndSettle();
}

/// The nearby lookup is a real request, so it leaves the framework and a plain
/// pump never sees its answer.
Future<void> _settleNearby(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)));
  }
  await tester.pumpAndSettle();
}

PostPlace? _cardPlace(WidgetTester tester) =>
    tester.widget<PostIdentityCard>(find.byType(PostIdentityCard)).place;

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

/// Turns the wheel for work that leaves the framework — uploads, the assistant
/// call, decoding a photo. Plain pumping never advances those, and the import
/// spinner keeps `pumpAndSettle` from ever settling on its own.
Future<void> _settleImport(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  }
  await tester.pump(const Duration(milliseconds: 50));
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

/// The bar's Next now leads through เชื่อมกับแผนของฉัน before anything is
/// published, so every publish in these tests confirms that step.
Future<void> _tapNext(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  // The sheet reads the plan list over the fake transport, which needs real
  // async turns — its spinner alone would never let pumpAndSettle finish.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  }
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
  // Publishing starts here and paints its own progress bar, so settle would
  // never return — turn the wheel a bounded number of times instead.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  }
}

/// Writes About trip through the Title sheet and confirms it.
Future<void> _fillAboutTrip(
  WidgetTester tester, {
  String overview = '',
  String budget = '',
}) async {
  await tester.tap(find.text('Title..'));
  await tester.pumpAndSettle();
  if (overview.isNotEmpty) {
    await tester.enterText(
        find.widgetWithText(TextField, 'ภาพรวมของทริป'), overview);
  }
  if (budget.isNotEmpty) {
    await tester.enterText(find.widgetWithText(TextField, '0.00'), budget);
  }
  tester.widget<FilledButton>(find.byKey(postTitleConfirmKey)).onPressed!();
  await tester.pumpAndSettle();
}

/// Taps one of a spot's options. The row scrolls sideways now, so a chip past
/// the fold has to be brought on screen before it can be hit.
Future<void> _tapSpotOption(WidgetTester tester, Finder chip) async {
  await tester.ensureVisible(chip.first);
  await tester.pumpAndSettle();
  await tester.tap(chip.first);
  await tester.pumpAndSettle();
}

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
    await tester.tap(find.text('Create from Photos'));
    await _settleImport(tester);
    tester.widget<PostBlock>(find.byType(PostBlock)).titleController.text =
        'วันหยุด';
    await _confirmPlace(tester);
    // The import uploaded both and the second answered 500, so it is already
    // the uncertain one before anything is published.
    expect(adapter.paths.where((p) => p == 'POST /trips/trip-new/media'),
        hasLength(2));
    expect(adapter.paths, isNot(contains('PATCH /trips/trip-new')));
    await _tapNext(tester);
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

  testWidgets('the assistant drafts the post out of the uploaded photos',
      (tester) async {
    final previous = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _TripPicker(Future.value([
      _UnreadablePhoto('assets/images/puntok_osaka.jpg'),
      _UnreadablePhoto('assets/images/puntok_london.jpg'),
    ]));
    addTearDown(() => ImagePickerPlatform.instance = previous);

    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'POST /trips/trip-new/media': [
        FakeReply(201, _image(_a, 'https://example.com/a.jpg')),
        FakeReply(201, _image(_b, 'https://example.com/b.jpg')),
      ],
      'POST /trips/trip-new/contents/generate': [
        const FakeReply(200, {
          'title': 'สองวันช้า ๆ ในเชียงใหม่',
          'contents': [
            {
              'content': 'เช้าวันแรกเดินขึ้นไปดูเจดีย์เก่า',
              'mediaIds': [_a],
              'location': {
                'status': 'suggested',
                'name': 'วัดเจดีย์หลวง',
                'placeId': 'ChIJ-wat',
                'latitude': 18.787,
                'longitude': 98.9867,
              },
            },
            {
              'content': 'ตอนเย็นแวะร้านเล็ก ๆ ริมทาง',
              'mediaIds': [_b],
              'location': {'status': 'none'},
            },
          ],
          'locationOptions': [
            {
              'sectionIndex': 0,
              'confidence': 'high',
              'options': [
                {
                  'name': 'วัดเจดีย์หลวง',
                  'placeId': 'ChIJ-wat',
                  'category': 'attraction',
                  'latitude': 18.787,
                  'longitude': 98.9867,
                  'rating': 4.6,
                }
              ],
            },
            {'sectionIndex': 1, 'confidence': 'low', 'options': []},
          ],
          'warnings': ['รูปที่สองมืดเกินกว่าจะอธิบายได้'],
        })
      ],
    });

    await _pumpComposer(tester, adapter: adapter);
    await tester.tap(find.text('Create from Photos'));
    await _settleImport(tester);

    // A spot per section, each holding the photo it was written about.
    final blocks =
        tester.widgetList<PostBlock>(find.byType(PostBlock)).toList();
    expect(blocks, hasLength(2));
    expect(blocks.first.items!.first.bodyController.text,
        'เช้าวันแรกเดินขึ้นไปดูเจดีย์เก่า');
    expect(blocks.first.imagePaths, ['assets/images/puntok_osaka.jpg']);
    expect(blocks.last.imagePaths, ['assets/images/puntok_london.jpg']);

    // Its warnings have to be on screen, and its place stays unconfirmed.
    expect(find.text('• รูปที่สองมืดเกินกว่าจะอธิบายได้'), findsOneWidget);
    expect(find.text('วัดเจดีย์หลวง'), findsOneWidget);
    expect(find.text('สถานที่ที่แนะนำจากรูป'), findsOneWidget);

    // The photos went up in order, with the key that makes a replay free.
    final body = adapter.bodyOf('POST /trips/trip-new/contents/generate')!;
    expect(body['photos'], [
      {'mediaId': _a},
      {'mediaId': _b},
    ]);
    expect(body['language'], 'th');
    // Nothing was pinned by hand, so the assistant gets no name it may write.
    expect(body.containsKey('locationName'), isFalse);
    final request = adapter.requests
        .lastWhere((r) => r.path == '/trips/trip-new/contents/generate');
    expect(request.headers['Idempotency-Key'], isNotEmpty);
  });

  testWidgets('a place the traveller pinned is the one name the assistant gets',
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
      'POST /trips/trip-new/contents/generate': [
        const FakeReply(200, {
          'title': 'เชียงใหม่',
          'contents': [
            {
              'content': 'เดินเล่นในเมืองเก่า',
              'mediaIds': [_a],
              'location': {'status': 'none'},
            }
          ],
          'locationOptions': [],
          'warnings': [],
        })
      ],
    });

    await _pumpComposer(tester, adapter: adapter);
    await _confirmPlace(tester);
    await tester.tap(find.text('Create from Photos'));
    await _settleImport(tester);

    expect(
        adapter
            .bodyOf('POST /trips/trip-new/contents/generate')!['locationName'],
        'เชียงใหม่');
  });

  testWidgets('a photo the assistant skipped still gets its own card',
      (tester) async {
    final previous = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _TripPicker(Future.value([
      _UnreadablePhoto('assets/images/puntok_osaka.jpg'),
      _UnreadablePhoto('assets/images/puntok_london.jpg'),
    ]));
    addTearDown(() => ImagePickerPlatform.instance = previous);

    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'POST /trips/trip-new/media': [
        FakeReply(201, _image(_a, 'https://example.com/a.jpg')),
        FakeReply(201, _image(_b, 'https://example.com/b.jpg')),
      ],
      'POST /trips/trip-new/contents/generate': [
        const FakeReply(200, {
          'title': 'เชียงใหม่',
          'contents': [
            {
              'content': 'แดดเช้าตกลงมาบนอิฐเก่าพอดี',
              'mediaIds': [_a],
              'location': {'status': 'none'},
            },
            {
              'content': '',
              'mediaIds': [_b],
              'location': {'status': 'none'},
            },
          ],
          'locationOptions': [],
          'warnings': ['2 photos have no caption yet'],
        })
      ],
    });

    await _pumpComposer(tester, adapter: adapter);
    await tester.tap(find.text('Create from Photos'));
    await _settleImport(tester);

    // One card per photo, in the order they were sent, the wordless one kept
    // for the traveller to fill in rather than folded into its neighbour.
    final blocks =
        tester.widgetList<PostBlock>(find.byType(PostBlock)).toList();
    expect(blocks, hasLength(2));
    expect(blocks.first.imagePaths, ['assets/images/puntok_osaka.jpg']);
    expect(blocks.last.imagePaths, ['assets/images/puntok_london.jpg']);
    expect(blocks.last.items!.first.bodyController.text, isEmpty);
    expect(find.text('• 2 photos have no caption yet'), findsOneWidget);
  });

  testWidgets('a draft the assistant cannot write falls back to grouping',
      (tester) async {
    final previous = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _TripPicker(Future.value([
      _UnreadablePhoto('assets/images/puntok_osaka.jpg'),
      _UnreadablePhoto('assets/images/puntok_london.jpg'),
    ]));
    addTearDown(() => ImagePickerPlatform.instance = previous);

    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'POST /trips/trip-new/media': [
        FakeReply(201, _image(_a, 'https://example.com/a.jpg')),
        FakeReply(201, _image(_b, 'https://example.com/b.jpg')),
      ],
      'POST /trips/trip-new/contents/generate': [
        const FakeReply(503, {'message': 'assistant is off'})
      ],
    });

    await _pumpComposer(tester, adapter: adapter);
    await tester.tap(find.text('Create from Photos'));
    await _settleImport(tester);

    // No draft, but the photos are still laid out and the traveller is told.
    expect(find.byType(PostBlock), findsOneWidget);
    expect(tester.widget<PostBlock>(find.byType(PostBlock)).imagePaths,
        hasLength(2));
    expect(find.textContaining('ผู้ช่วยเขียนโพสต์ยังไม่เปิดใช้งาน'),
        findsOneWidget);
  });

  testWidgets('only a tap turns the assistant\'s place into a confirmed one',
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
      'POST /trips/trip-new/contents/generate': [
        const FakeReply(200, {
          'title': 'เชียงใหม่',
          'contents': [
            {
              'content': 'เดินเล่นในเมืองเก่า',
              'mediaIds': [_a],
              'location': {'status': 'suggested', 'name': 'วัดเจดีย์หลวง'},
            }
          ],
          'locationOptions': [
            {
              'sectionIndex': 0,
              'confidence': 'high',
              'options': [
                {
                  'name': 'วัดเจดีย์หลวง',
                  'placeId': 'ChIJ-wat',
                  'latitude': 18.787,
                  'longitude': 98.9867,
                }
              ],
            }
          ],
          'warnings': [],
        })
      ],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });

    await _pumpComposer(tester, adapter: adapter);
    await tester.tap(find.text('Create from Photos'));
    await _settleImport(tester);

    // The sheet leads with what the assistant suggested.
    await tester.tap(find.text('วัดเจดีย์หลวง'));
    await tester.pumpAndSettle();
    expect(find.text('สถานที่ที่ผู้ช่วยแนะนำ'), findsOneWidget);
    await tester.tap(find.text('วัดเจดีย์หลวง').last);
    await tester.pumpAndSettle();

    await _tapNext(tester);
    await _finishPublish(tester);

    // Confirmed only because a person tapped it, and it carries the id and
    // coordinates the suggestion came with.
    expect(
        adapter.bodyOf('PATCH /trips/trip-new')!['contents'][0]['location'], {
      'status': 'confirmed',
      'name': 'วัดเจดีย์หลวง',
      'placeId': 'ChIJ-wat',
      'latitude': 18.787,
      'longitude': 98.9867,
    });
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
    await _tapNext(tester);
    await tester.enterText(find.byType(TextField).first, 'แก้ข้อความ');
    await _tapNext(tester);
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
    await tester.tap(find.text('Create from Photos'));
    await _settleImport(tester);
    await _tapNext(tester);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'ชื่อโพสต์'), 'วันหยุด');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'จุดหมาย (พิมพ์เองได้)'),
        'ระหว่างทาง');
    await tester.tap(find.widgetWithText(TextButton, 'บันทึก'));
    await _finishPublish(tester);
    expect(find.text('home'), findsOneWidget);
    // The import created the draft before there was anything to name it with,
    // so the trip carries provisional fields until publish sends the real ones.
    expect(adapter.bodyOf('POST /trips'), {
      'type': 'content',
      'title': 'ร่างจากรูป',
      'destination': 'ยังไม่ระบุ'
    });
    final patched = adapter.bodyOf('PATCH /trips/trip-new')!;
    expect(patched['title'], 'วันหยุด');
    expect(patched['destination'], 'ระหว่างทาง');
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
    await _tapNext(tester);
    await _finishPublish(tester);
    expect(adapter.paths.where((p) => p != 'GET /trips/mine'),
        ['PATCH /trips/trip-new']);
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
    await _tapNext(tester);
    await _finishPublish(tester);
    expect(adapter.paths.where((p) => p != 'GET /trips/mine'), [
      'PATCH /trips/trip-new',
      'DELETE /trips/trip-new/media/$_a',
      'PATCH /trips/trip-new'
    ]);
    final firstWrite = adapter.requests
        .firstWhere((r) => r.path == '/trips/trip-new' && r.method == 'PATCH');
    expect(firstWrite.data['contents'][0]['mediaIds'], [_b]);
    expect(firstWrite.data.containsKey('visibility'), isFalse);
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
    await _tapNext(tester);
    expect(find.textContaining('มีรูปที่ไม่พร้อมใช้งาน'), findsOneWidget);
    // Nothing was written: the link step only reads the plan list.
    expect(adapter.paths.where((p) => p != 'GET /trips/mine'), isEmpty);
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
    await tester.tap(find.text('Create from Photos'));
    await _settleImport(tester);
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
    await tester.tap(find.text('Create from Photos'));
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
    await tester.tap(find.text('Create from Photos'));
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
    await tester.tap(find.text('Create from Photos'));
    await _settleImport(tester);
    expect(tester.widget<PostBlock>(find.byType(PostBlock)).imagePaths,
        hasLength(1));
    await _tapNext(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('กลับไปแก้ไข'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    // The import had to make the draft and upload the photo — that is the
    // assistant's price of entry. Backing out of publishing still writes
    // nothing to the trip itself.
    expect(adapter.paths, contains('POST /trips'));
    expect(adapter.paths, isNot(contains('PATCH /trips/trip-new')));
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
      await tester.tap(find.text('Create from Photos'));
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
      await tester.ensureVisible(
          find.widgetWithIcon(PostAddChip, Icons.add_photo_alternate_outlined));
      await tester.tap(
          find.widgetWithIcon(PostAddChip, Icons.add_photo_alternate_outlined));
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
    await _tapNext(tester);
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
      await tester.ensureVisible(
          find.widgetWithIcon(PostAddChip, Icons.add_photo_alternate_outlined));
      await tester.tap(
          find.widgetWithIcon(PostAddChip, Icons.add_photo_alternate_outlined));
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
    await tester.enterText(_bodyField().first, 'เรื่องราว');
    await tester.pumpAndSettle();
    if (adapter.replies.containsKey('POST /trips')) await _confirmPlace(tester);
    await _tapNext(tester);
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
    await tester.enterText(_bodyField().first, 'เดินเล่น');
    await tester.pumpAndSettle();
    if (adapter.replies.containsKey('POST /trips')) await _confirmPlace(tester);
    await _tapNext(tester);
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
    await _tapNext(tester);
    expect(adapter.paths.where((path) => path == 'POST /trips'), hasLength(1));
    expect(adapter.paths.where((path) => path == 'PATCH /trips/trip-new'),
        hasLength(2));
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('the composer lays out every part of the design', (tester) async {
    await _pumpComposer(tester);

    // The dark cap: back, title, and the cover action opposite it.
    expect(find.text('PunGuide'), findsOneWidget);
    expect(find.text('Create from Photos'), findsOneWidget);
    expect(find.byTooltip('รูปหน้าปก'), findsOneWidget);

    // One card says what the post is and who it is by. The plan link is not
    // on the page any more — it is the Next step's own screen.
    expect(find.text('Title..'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('เชื่อมแผนของฉัน'), findsNothing);
    expect(find.byType(PostIdentityCard), findsOneWidget);
    // The title row is the only way into the Title sheet; an add chip beside
    // it would be a second door onto the same thing.
    expect(find.text('Trip activity'), findsNothing);

    // Author then title, top to bottom inside that one card.
    final card = find.byType(PostIdentityCard);
    for (final part in ['Public', 'Title..']) {
      expect(
          find.descendant(of: card, matching: find.text(part)), findsOneWidget,
          reason: part);
    }
    expect(tester.getTopLeft(find.text('Public')).dy,
        lessThan(tester.getTopLeft(find.text('Title..')).dy));

    // The spot: a heading, where it is, then the story.
    // Optional parts offer themselves from the spot's options row rather than
    // sit open as blank fields.
    expect(find.text('ชื่อหัวข้อ'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    // About trip is written in the Title sheet, so it is not on the page.
    expect(find.text('About trip'), findsNothing);
    expect(find.text('ชื่อหัวข้อ  (เช่น รวมร้านอาหาร, จุดห้ามพลาด)'),
        findsNothing);
    expect(find.text('Add Location'), findsNothing);
    expect(find.text('Tell us about your trip..'), findsOneWidget);

    // Every option is on one line that scrolls, rather than wrapping onto a
    // second row and taking more height than the story itself.
    final options = find.descendant(
      of: find.byType(PostBlock),
      matching: find.byWidgetPredicate((w) =>
          w is SingleChildScrollView && w.scrollDirection == Axis.horizontal),
    );
    expect(options, findsOneWidget);
    for (final chip in ['ชื่อหัวข้อ', 'Location', 'Trip Hack']) {
      expect(find.descendant(of: options, matching: find.text(chip)),
          findsOneWidget,
          reason: chip);
    }

    // Attachments: a photo, the time, how you got there, and the hack.
    for (final icon in const [
      Icons.add_photo_alternate_outlined,
      Icons.schedule,
      Icons.directions_car_outlined,
      Icons.info_outline,
    ]) {
      expect(find.widgetWithIcon(PostAddChip, icon), findsOneWidget,
          reason: icon.toString());
    }
    expect(find.text('Trip Hack'), findsOneWidget);

    // The rows that used to sit under the chips are gone with this pass.
    expect(find.text('Recommend Time'), findsNothing);
    expect(find.text('Activity And Style'), findsNothing);
    expect(find.text('Every one can remix your trip'), findsNothing);

    // The bar is pinned, so it is there before any scrolling.
    expect(find.text('Save Draft'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('เพิ่มจุดต่อไป'), findsOneWidget);
  });

  testWidgets('the Title sheet names the post and picks its activities',
      (tester) async {
    await _pumpComposer(tester);

    await tester.tap(find.text('Title..'));
    await tester.pumpAndSettle();

    // The sheet offers the same activities the plan wizard does.
    expect(find.text('Trip Activity'), findsOneWidget);
    for (final label in const ['ทะเล', 'วัฒนธรรม', 'อาหาร', 'ผจญภัย']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    await tester.enterText(
        find.byType(TextField).first, 'เที่ยวย่านพระนคร 1 day trip');
    await tester.tap(find.text('วัฒนธรรม'));
    await tester.tap(find.text('อาหาร'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();

    // The name comes back to the field it was opened from.
    expect(find.text('เที่ยวย่านพระนคร 1 day trip'), findsOneWidget);
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
    await tester.enterText(_bodyField().first, 'ส่วนแรก');
    await _scrollTo(tester, find.text('เพิ่มจุดต่อไป'));
    await tester.tap(find.text('เพิ่มจุดต่อไป'));
    await tester.pumpAndSettle();
    await tester.enterText(_bodyField().last, 'ส่วนที่สอง');
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

  testWidgets('the spot heading is an add option until it is asked for',
      (tester) async {
    await _pumpComposer(tester);

    // Nothing to fill in yet — just the offer.
    expect(find.text('ชื่อหัวข้อ  (เช่น รวมร้านอาหาร, จุดห้ามพลาด)'),
        findsNothing);
    expect(find.text('ชื่อหัวข้อ'), findsOneWidget);

    await _tapSpotOption(tester, find.text('ชื่อหัวข้อ'));

    // Now the field is there, focused, ready to type into.
    expect(find.text('ชื่อหัวข้อ  (เช่น รวมร้านอาหาร, จุดห้ามพลาด)'),
        findsOneWidget);
    expect(tester.widget<PostBlock>(find.byType(PostBlock)).titleFocus.hasFocus,
        isTrue);

    await tester.enterText(find.byType(TextField).first, 'ร้านอาหารที่ต้องแวะ');
    await tester.pumpAndSettle();
    expect(
        tester.widget<PostBlock>(find.byType(PostBlock)).titleController.text,
        'ร้านอาหารที่ต้องแวะ');
  });

  testWidgets('a heading that has text stays put when focus moves on',
      (tester) async {
    await _pumpComposer(tester);
    await _tapSpotOption(tester, find.text('ชื่อหัวข้อ'));
    await tester.enterText(find.byType(TextField).first, 'ร้านอาหารที่ต้องแวะ');
    await tester.pumpAndSettle();

    // Tapping the story takes focus away; the heading must not vanish under
    // the writer's hands.
    await tester.tap(find.text('Tell us about your trip..'));
    await tester.pumpAndSettle();
    expect(find.text('ร้านอาหารที่ต้องแวะ'), findsOneWidget);
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

    await _tapNext(tester);
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
        of: find.text('Next'),
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
        of: find.text('Next'),
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

    await _tapSpotOption(tester, find.text('Location'));

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
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(adapter.paths, contains('GET /places/search'));

    // Taking the pin off happens back in the sheet, since the row itself
    // carries only a chevron now.
    await tester.tap(find.text('Akha Ama Coffee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบสถานที่ออกจากจุดนี้'));
    await tester.pumpAndSettle();

    expect(find.text('Akha Ama Coffee'), findsNothing);
    // With the pin gone the row goes with it; the options row offers it again.
    expect(find.text('Add Location'), findsNothing);
    expect(find.text('Location'), findsOneWidget);
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

  testWidgets('a blank post takes the place the traveller is standing in',
      (tester) async {
    final adapter = FakeAdapter({
      'GET /places/suggest': [
        const FakeReply(200, [
          {
            'id': 'near-1',
            'name': 'สนามหลวง',
            'address': 'ถนน ราชดำเนินกลาง, เขตพระนคร, กรุงเทพมหานคร, ประเทศไทย',
            'lat': 13.7563,
            'lng': 100.493,
          },
        ]),
      ],
    });
    await _pumpComposer(tester, adapter: adapter, extra: _located);
    await _settleNearby(tester);

    expect(_cardPlace(tester)?.name, 'สนามหลวง');
    expect(find.textContaining('สนามหลวง'), findsWidgets);
    // The old wording only told the traveller where they were, which is not
    // the same as the post having a place.
    expect(find.textContaining('ตอนนี้อยู่แถว'), findsNothing);
  });

  testWidgets('a Plus Code never becomes what the post says it was about',
      (tester) async {
    final adapter = FakeAdapter({
      'GET /places/suggest': [
        const FakeReply(200, [
          {
            'id': 'near-1',
            'name': 'สนามหลวง',
            // What Google answers for a place with no street number of its
            // own: the segment is led by an Open Location Code.
            // No commas anywhere, which is how Google writes a Thai
            // address, led by an Open Location Code because the place has no
            // street number of its own.
            'address':
                'QF4V+88R ถนน ราชดำเนินกลาง แขวงพระบรมมหาราชวัง เขตพระนคร กรุงเทพมหานคร 10200',
            'lat': 13.7563,
            'lng': 100.493,
          },
        ]),
      ],
    });
    await _pumpComposer(tester, adapter: adapter, extra: _located);
    await _settleNearby(tester);

    expect(_cardPlace(tester)?.area, 'กรุงเทพมหานคร');
    expect(find.textContaining('QF4V'), findsNothing);
  });

  testWidgets('a post opened for editing keeps its own place', (tester) async {
    final adapter = FakeAdapter({
      'GET /places/suggest': [
        const FakeReply(200, [
          {'id': 'near-1', 'name': 'สนามหลวง', 'lat': 13.7563, 'lng': 100.493},
        ]),
      ],
    });
    // Written up at home a week later: the destination it already carries is
    // the answer, and where the traveller is sitting now is not.
    await _pumpComposer(
      tester,
      adapter: adapter,
      extra: _located,
      initialTrip: ApiTrip.fromJson(
          {...createdTripJson(), 'destination': 'ดานัง, เวียดนาม'}),
    );
    await _settleNearby(tester);

    expect(_cardPlace(tester), isNull);
    expect(find.textContaining('สนามหลวง'), findsNothing);
  });

  testWidgets('the Title sheet sets where the post is about', (tester) async {
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });
    await _pumpComposer(tester, adapter: adapter);

    // The spot pins เชียงใหม่ from the harness's own stub …
    await tester.enterText(find.byType(TextField).first, 'เรื่องแรก');
    await _confirmPlace(tester);

    // … and the post's own place is somewhere else, so the assertion below
    // shows which of the two the destination comes from.
    // The locality is read off the address, not sent as its own field.
    adapter.replies['GET /places/search'] = [
      const FakeReply(200, [
        {
          'id': 'place-2',
          'name': 'พระนคร',
          // The locality is the segment before the country, postcode-free.
          'address': '161 ถ. ข้าวสาร, เขตพระนคร, '
              'กรุงเทพมหานคร 10200, ประเทศไทย',
        },
      ]),
    ];

    await tester.tap(find.text('Title..'));
    await tester.pumpAndSettle();
    expect(find.text('Add Location'), findsOneWidget);

    await tester.ensureVisible(find.text('Add Location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Location'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'พระนคร');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('พระนคร').last);
    await tester.pumpAndSettle();

    // The picker is gone and the Title sheet's row reads the chosen place.
    expect(find.text('Find places nearby'), findsNothing);
    expect(find.text('พระนคร'), findsOneWidget);

    // Pressed through its callback: the sheet's pinned footer is laid out on
    // screen but does not take a tap on this tall test viewport.
    tester.widget<FilledButton>(find.byKey(postTitleConfirmKey)).onPressed!();
    await tester.pumpAndSettle();

    // Back on the page, the card shows where the post is about.
    expect(
        find.descendant(
            of: find.byType(PostIdentityCard),
            matching: find.text('พระนคร · กรุงเทพมหานคร')),
        findsOneWidget);

    await _tapNext(tester);
    await _finishPublish(tester);

    // The locality of the post's own place, not the spot's pin.
    expect(adapter.bodyOf('PATCH /trips/trip-new')!['destination'],
        'กรุงเทพมหานคร');
  });

  testWidgets('About trip is written in the Title sheet', (tester) async {
    await _pumpComposer(tester);

    // Nothing of its own on the page — it rides along with the title and the
    // activities, which describe the post just as it does.
    expect(find.widgetWithText(PostAddOption, 'About trip'), findsNothing);

    await tester.tap(find.text('Title..'));
    await tester.pumpAndSettle();
    expect(find.text('About trip'), findsOneWidget);
    expect(find.text('ภาพรวมของทริป'), findsOneWidget);
    expect(find.text('ต่อคน'), findsOneWidget);
    expect(find.text('THB'), findsOneWidget);
  });
  testWidgets('a filled About trip reads back inside the card',
      (tester) async {
    await _pumpComposer(tester);
    await _fillAboutTrip(tester, overview: 'เดินเที่ยวย่านพระนคร');

    expect(
        find.descendant(
            of: find.byType(PostIdentityCard),
            matching: find.text('เดินเที่ยวย่านพระนคร')),
        findsOneWidget);
  });
  testWidgets('About trip reads back the overview and the budget',
      (tester) async {
    await _pumpComposer(tester);
    await _fillAboutTrip(tester,
        overview: 'เดินเที่ยวย่านพระนคร', budget: '2000');

    expect(find.text('เดินเที่ยวย่านพระนคร'), findsOneWidget);
    expect(find.text('฿2,000'), findsOneWidget);
  });
  testWidgets('dismissing the Title sheet keeps About trip as it was',
      (tester) async {
    await _pumpComposer(tester);
    await _fillAboutTrip(tester, overview: 'ที่เขียนไว้ก่อน');

    await tester.tap(find.text('ที่เขียนไว้ก่อน'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'ภาพรวมของทริป'), 'พิมพ์ไปแล้วเปลี่ยนใจ');
    // Out through the scrim rather than ตกลง.
    await tester.tapAt(const Offset(200, 30));
    await tester.pumpAndSettle();

    expect(find.text('พิมพ์ไปแล้วเปลี่ยนใจ'), findsNothing);
    expect(find.text('ที่เขียนไว้ก่อน'), findsOneWidget);
  });
  testWidgets('About trip goes up as description and budgetLimit',
      (tester) async {
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });
    await _pumpComposer(tester, adapter: adapter);

    await _fillAboutTrip(tester,
        overview: 'ทริปเดินกินย่านเมืองเก่า', budget: '2000');

    await tester.enterText(find.byType(TextField).first, 'เรื่องแรก');
    await _confirmPlace(tester);
    await _tapNext(tester);
    await _finishPublish(tester);

    final patched = adapter.bodyOf('PATCH /trips/trip-new')!;
    // The blurb is public, so it is `description` — never `specialNotes`,
    // which only the owner can read back.
    expect(patched['description'], 'ทริปเดินกินย่านเมืองเก่า');
    expect(patched.containsKey('specialNotes'), isFalse);
    expect(patched['budgetLimit'], 2000);
  });

  testWidgets('an empty About trip sends neither field', (tester) async {
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });
    await _pumpComposer(tester, adapter: adapter);

    await tester.enterText(find.byType(TextField).first, 'เรื่องแรก');
    await _confirmPlace(tester);
    await _tapNext(tester);
    await _finishPublish(tester);

    final patched = adapter.bodyOf('PATCH /trips/trip-new')!;
    expect(patched.containsKey('specialNotes'), isFalse);
    expect(patched.containsKey('budgetLimit'), isFalse);
  });

  testWidgets('Next opens เชื่อมกับแผนของฉัน before anything is written',
      (tester) async {
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
      'GET /trips/mine': [
        FakeReply(200, [
          {
            'id': 'plan-1',
            'title': 'เดินเล่นพระนคร',
            'destination': 'กรุงเทพมหานคร',
            'status': 'draft',
            'schedule': {
              'startDate': '2026-09-20',
              'endDate': '2026-09-20',
              'durationDays': 1,
            },
            'totalBudget': 0,
            'tags': <String>[],
            'isSaved': false,
            'isLiked': false,
            'likeCount': 0,
            'remixCount': 0,
            'createdAt': '2026-09-09T00:00:00.000Z',
            'updatedAt': '2026-09-09T00:00:00.000Z',
          }
        ])
      ],
    });
    await _pumpComposer(tester, adapter: adapter);
    await tester.enterText(find.byType(TextField).first, 'เรื่องแรก');
    await _confirmPlace(tester);

    await tester.tap(find.text('Next'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    await tester.pumpAndSettle();

    expect(find.text('เชื่อมกับแผนของฉัน'), findsOneWidget);
    expect(find.text('เดินเล่นพระนคร'), findsOneWidget);
    expect(find.text('20 Sep 2026 • 1 วัน'), findsOneWidget);
    // The step comes before the write, so nothing has been published yet.
    expect(adapter.paths, isNot(contains('PATCH /trips/trip-new')));
  });

  testWidgets('ยกเลิก on the plan step cancels the publish', (tester) async {
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });
    await _pumpComposer(tester, adapter: adapter);
    await tester.enterText(find.byType(TextField).first, 'เรื่องแรก');
    await _confirmPlace(tester);

    await tester.tap(find.text('Next'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'ยกเลิก'));
    await tester.pumpAndSettle();

    // Back on the composer with nothing written.
    expect(find.text('Next'), findsOneWidget);
    expect(adapter.paths, isNot(contains('PATCH /trips/trip-new')));
  });

  testWidgets('Trip Hack fills a row under the story', (tester) async {
    await _pumpComposer(tester);

    await _tapSpotOption(tester, find.text('Trip Hack'));

    expect(find.text('ทริคในการเที่ยวที่อยากแบ่งปันให้นักเดินทางคนอื่น'),
        findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'เช่น ไปเช้าคนน้อย ไม่ต้องรอคิว'),
        'ไปเช้าคนน้อยกว่า');
    await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
    await tester.pumpAndSettle();

    expect(find.text('ไปเช้าคนน้อยกว่า'), findsOneWidget);
  });

  testWidgets('การเดินทาง keeps the chosen modes and the fare', (tester) async {
    await _pumpComposer(tester);

    await _tapSpotOption(tester, find.byTooltip('การเดินทาง'));

    expect(find.text('รูปแบบการเดินทาง'), findsOneWidget);
    await tester.tap(find.text('MRT'));
    await tester.tap(find.text('เดิน'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '0'), '100');
    await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
    await tester.pumpAndSettle();

    // One chip carries both, in the order the modes were picked.
    expect(find.text('MRT · เดิน ฿100'), findsOneWidget);
  });

  testWidgets('Recommend Time writes the visit hour, then the opening hours',
      (tester) async {
    await _pumpComposer(tester);

    await _tapSpotOption(tester, find.byTooltip('เวลาที่แนะนำ'));

    expect(find.text('Recommend Time'), findsOneWidget);
    expect(find.text('เวลาที่ฉันไป'), findsOneWidget);
    // The wheel starts on 06:00, which is what the design shows.
    await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
    await tester.pumpAndSettle();
    expect(find.text('6:00 AM'), findsOneWidget);

    // Opening hours join the same chip once they are set.
    await tester.tap(find.text('6:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เวลาเปิด - ปิด'));
    await tester.pumpAndSettle();
    expect(find.text('เปิด'), findsOneWidget);
    expect(find.text('ปิด'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
    await tester.pumpAndSettle();

    // The visit time is what the chip shows; the hours live in its sheet.
    expect(find.text('6:00 AM'), findsOneWidget);
  });

  testWidgets('opening hours alone do not repeat their own label',
      (tester) async {
    await _pumpComposer(tester);

    await _tapSpotOption(tester, find.byTooltip('เวลาที่แนะนำ'));
    await tester.tap(find.text('เวลาเปิด - ปิด'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
    await tester.pumpAndSettle();

    // With no visit time the chip is the hours themselves.
    expect(find.text('06.00 - 14.30 น.'), findsOneWidget);
  });

  testWidgets('ยกเลิก on an extra leaves the spot as it was', (tester) async {
    await _pumpComposer(tester);

    await _tapSpotOption(tester, find.text('Trip Hack'));
    await tester.enterText(
        find.widgetWithText(TextField, 'เช่น ไปเช้าคนน้อย ไม่ต้องรอคิว'),
        'เปลี่ยนใจ');
    await tester.tap(find.widgetWithText(OutlinedButton, 'ยกเลิก'));
    await tester.pumpAndSettle();

    expect(find.text('เปลี่ยนใจ'), findsNothing);
  });

  testWidgets('the spot extras go up with their section', (tester) async {
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });
    await _pumpComposer(tester, adapter: adapter);

    await _tapSpotOption(tester, find.text('Trip Hack'));
    await tester.enterText(
        find.widgetWithText(TextField, 'เช่น ไปเช้าคนน้อย ไม่ต้องรอคิว'),
        'ไปเช้าคนน้อยกว่า');
    await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'เรื่องแรก');
    await _confirmPlace(tester);
    await _tapNext(tester);
    await _finishPublish(tester);

    final section =
        (adapter.bodyOf('PATCH /trips/trip-new')!['contents'] as List).single
            as Map;
    expect(section['tripHack'], 'ไปเช้าคนน้อยกว่า');
  });

  testWidgets('time and transport ride along on the same section',
      (tester) async {
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });
    await _pumpComposer(tester, adapter: adapter);

    await _tapSpotOption(tester, find.byTooltip('เวลาที่แนะนำ'));
    await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
    await tester.pumpAndSettle();

    await _tapSpotOption(tester, find.byTooltip('การเดินทาง'));
    await tester.tap(find.text('MRT'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '0'), '100');
    await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'เรื่องแรก');
    await _confirmPlace(tester);
    await _tapNext(tester);
    await _finishPublish(tester);

    final section =
        (adapter.bodyOf('PATCH /trips/trip-new')!['contents'] as List).single
            as Map;
    // Wall clock, not a timestamp — the post says "we went at six".
    expect(section['visitedAt'], '06:00');
    expect(section['transportModes'], ['MRT']);
    expect(section['transportCost'], 100);
    // A currency only travels with an amount.
    expect(section['transportCurrency'], 'THB');
  });

  testWidgets('ติดต่อ rides along on the section as one line', (tester) async {
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });
    await _pumpComposer(tester, adapter: adapter);

    await _tapSpotOption(tester, find.text('ติดต่อ'));
    expect(find.text('ชื่อผู้ติดต่อ เบอร์โทร เพจ หรือทั้งหมดรวมกัน'),
        findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'เช่น คุณบุญอนันต์ 081-234-5678'),
        'คุณบุญอนันต์ 081-234-5678');
    await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
    await tester.pumpAndSettle();

    expect(find.text('คุณบุญอนันต์ 081-234-5678'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'เรื่องแรก');
    await _confirmPlace(tester);
    await _tapNext(tester);
    await _finishPublish(tester);

    final section =
        (adapter.bodyOf('PATCH /trips/trip-new')!['contents'] as List).single
            as Map;
    // Stored as typed — a name and a number together, not split into fields.
    expect(section['contactInfo'], 'คุณบุญอนันต์ 081-234-5678');
  });

  testWidgets('a spot with no extras sends none of their keys', (tester) async {
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });
    await _pumpComposer(tester, adapter: adapter);
    await tester.enterText(find.byType(TextField).first, 'เรื่องแรก');
    await _confirmPlace(tester);
    await _tapNext(tester);
    await _finishPublish(tester);

    final section =
        (adapter.bodyOf('PATCH /trips/trip-new')!['contents'] as List).single
            as Map;
    for (final key in [
      'visitedAt',
      'opensAt',
      'closesAt',
      'transportModes',
      'transportCost',
      'transportCurrency',
      'tripHack',
      'contactInfo'
    ]) {
      expect(section.containsKey(key), isFalse, reason: key);
    }
  });

  testWidgets('a trip reopened from the server restores About trip and extras',
      (tester) async {
    final trip = ApiTrip.fromJson({
      ...createdTripJson(),
      'description': 'ทริปเดินกินย่านเมืองเก่า',
      'budgetLimit': 2000,
      'budgetCurrency': 'THB',
      'contents': [
        {
          'content': 'ตลาดเช้า',
          'visitedAt': '06:00',
          'opensAt': '06:00',
          'closesAt': '14:30',
          'transportModes': ['MRT', 'เดิน'],
          'transportCost': 100,
          'transportCurrency': 'THB',
          'tripHack': 'ไปเช้าคนน้อยกว่า',
        }
      ],
    });
    await _pumpComposer(tester, initialTrip: trip);

    expect(find.text('ทริปเดินกินย่านเมืองเก่า'), findsOneWidget);
    expect(find.text('฿2,000'), findsOneWidget);
    expect(find.text('6:00 AM'), findsOneWidget);
    expect(find.text('MRT · เดิน ฿100'), findsOneWidget);
    expect(find.text('ไปเช้าคนน้อยกว่า'), findsOneWidget);
  });

  testWidgets('a custom Trip Activity goes up as customStyles', (tester) async {
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });
    await _pumpComposer(tester, adapter: adapter);

    await tester.tap(find.text('Title..'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เพิ่ม'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'เช่น ดำน้ำ'), 'ดำน้ำ');
    await tester.tap(find.widgetWithText(TextButton, 'เพิ่ม'));
    await tester.pumpAndSettle();

    // The new activity joins the built-in ten as a removable chip.
    expect(find.text('ดำน้ำ'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'เรื่องแรก');
    await _confirmPlace(tester);
    await _tapNext(tester);
    await _finishPublish(tester);

    expect(adapter.bodyOf('PATCH /trips/trip-new')!['customStyles'], ['ดำน้ำ']);
  });

  testWidgets('the chosen plan is what goes up as linkedTripId',
      (tester) async {
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
      'GET /trips/plan-1': [
        FakeReply(200, {...createdTripJson(id: 'plan-1'), 'type': 'plan_trip'})
      ],
      'GET /trips/mine': [
        FakeReply(200, [
          {
            'id': 'plan-1',
            'title': 'เดินเล่นพระนคร',
            'destination': 'กรุงเทพมหานคร',
            'status': 'draft',
            'schedule': {'durationDays': 1},
            'totalBudget': 0,
            'placeCount': 11,
            'tags': <String>[],
            'isSaved': false,
            'isLiked': false,
            'likeCount': 0,
            'remixCount': 0,
            'createdAt': '2026-09-09T00:00:00.000Z',
            'updatedAt': '2026-09-09T00:00:00.000Z',
          }
        ])
      ],
    });
    await _pumpComposer(tester, adapter: adapter);
    await tester.enterText(find.byType(TextField).first, 'เรื่องแรก');
    await _confirmPlace(tester);

    await tester.tap(find.text('Next'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    await tester.pumpAndSettle();

    // The count comes from the list now, no request per row.
    expect(find.text('1 วัน • 11 สถานที่'), findsOneWidget);

    await tester.tap(find.text('เดินเล่นพระนคร'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ตกลง'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    await _finishPublish(tester);

    expect(adapter.bodyOf('PATCH /trips/trip-new')!['linkedTripId'], 'plan-1');
  });

  testWidgets('confirming with no plan chosen unlinks rather than staying put',
      (tester) async {
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });
    await _pumpComposer(tester, adapter: adapter);
    await tester.enterText(find.byType(TextField).first, 'เรื่องแรก');
    await _confirmPlace(tester);
    await _tapNext(tester);
    await _finishPublish(tester);

    final body = adapter.bodyOf('PATCH /trips/trip-new')!;
    // Explicitly null, not absent: the traveller answered "no plan".
    expect(body.containsKey('linkedTripId'), isTrue);
    expect(body['linkedTripId'], isNull);
  });

  testWidgets('a post reopened with a linked plan remembers it',
      (tester) async {
    final trip = ApiTrip.fromJson({
      ...createdTripJson(),
      'contents': [
        {
          'content': 'เรื่องแรก',
          'location': {'status': 'confirmed', 'name': 'เชียงใหม่'}
        }
      ],
      'linkedTrip': {
        'id': 'plan-1',
        'title': 'เดินเล่นพระนคร',
        'schedule': {'durationDays': 1},
        'placeCount': 11,
      },
    });
    final adapter = FakeAdapter({
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
      // The plan is not in this page of the list, and confirming must still
      // keep it rather than quietly unlinking.
      'GET /trips/mine': [const FakeReply(200, [])],
      'GET /trips/plan-1': [
        FakeReply(200, createdTripJson(id: 'plan-1')),
      ],
    });
    await _pumpComposer(tester, adapter: adapter, initialTrip: trip);

    // The Next step opens on the plan already chosen, so confirming keeps it.
    await _tapNext(tester);
    await _finishPublish(tester);

    expect(adapter.bodyOf('PATCH /trips/trip-new')!['linkedTripId'], 'plan-1');
  });
}
