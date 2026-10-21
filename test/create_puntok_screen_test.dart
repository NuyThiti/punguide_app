import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/create_puntok/domain/puntok_clip.dart';
import 'package:pluno/features/create_puntok/presentation/create_puntok_screen.dart';
import 'package:pluno/features/puntok/presentation/providers/puntok_providers.dart';

import 'support/fake_api.dart';

const _mediaA = '11111111-1111-4111-8111-111111111111';
const _mediaB = '22222222-2222-4222-8222-222222222222';

late Directory _dir;
late List<PuntokClip> _clips;

/// Small stand-in files: the uploads read them off disk for real, and
/// `video_player` has no plugin under `flutter test`, so nothing ever tries
/// to decode them — each clip shows its asset poster instead.
PuntokClip _clip(String name, String poster) {
  final file = File('${_dir.path}/$name.mp4')..writeAsBytesSync([0, 0, 0, 1]);
  return PuntokClip(
    id: name,
    path: file.path,
    duration: const Duration(seconds: 5),
    poster: poster,
  );
}

Map<String, dynamic> _video(String id) => <String, dynamic>{
      'mediaId': id,
      'source': 'user_upload',
      'mediaType': 'video',
      'mimeType': 'video/mp4',
      'durationSeconds': 5.2,
      'sizeBytes': 4,
      'urls': {
        'original': 'https://cdn.test/videos/$id.mp4',
        'large': 'https://cdn.test/videos/$id-large.webp',
        'thumbnail': 'https://cdn.test/videos/$id-thumb.webp',
      },
      'dimensions': {'width': 1080, 'height': 1920},
    };

Map<String, dynamic> _post() => <String, dynamic>{
      'id': 'post-1',
      'ownerId': 'u1',
      'type': 'content',
      'title': 'Puntok',
      'destination': 'ยังไม่ระบุ',
      'status': 'shared',
      'schedule': const <String, dynamic>{},
      'totalBudget': 0,
      'tags': const <String>[],
      'visibility': 'public',
      'isSaved': false,
      'isLiked': false,
      'likeCount': 0,
      'remixCount': 0,
      'createdAt': '2026-10-19T00:00:00.000Z',
      'updatedAt': '2026-10-19T00:00:00.000Z',
    };

FakeAdapter _savingApi({int uploadStatus = 201}) => FakeAdapter({
      'POST /media': [
        FakeReply(uploadStatus,
            uploadStatus == 201 ? _video(_mediaA) : {'message': 'too long'}),
        FakeReply(201, _video(_mediaB)),
      ],
      'POST /trips/posts': [FakeReply(201, _post())],
      // The feed the shared clip lands on; the list has not caught up yet.
      'GET /trips': [const FakeReply(200, <Object>[])],
      'DELETE /media/$_mediaA': [const FakeReply(204, null)],
      'DELETE /media/$_mediaB': [const FakeReply(204, null)],
    });

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  FakeAdapter? adapter,
  bool signedIn = true,
  List<XFile> picks = const [],
}) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: [
    plunoApiProvider
        .overrideWith((ref) async => fakeApi(adapter ?? FakeAdapter({}))),
    if (signedIn)
      authSessionProvider
          .overrideWith((ref) => AuthController(AuthSession.demo)),
  ]);
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
              path: '/trips/mine',
              name: AppRoute.myTrips.name,
              builder: (_, __) => const Scaffold(body: Text('my trips')),
            ),
            GoRoute(
              path: '/puntok/create',
              name: AppRoute.createPuntok.name,
              builder: (_, __) => CreatePuntokScreen(
                clips: _clips,
                pickVideos: () async => picks,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Turns the wheel for work that leaves the framework — reading files and
/// the fake network. Plain pumping never advances those.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  }
  await tester.pumpAndSettle();
}

/// Picks the first two clips and moves on to the editor.
Future<void> _toEditor(WidgetTester tester) async {
  await tester.tap(find.text('0:05').at(0));
  await tester.tap(find.text('0:05').at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ถัดไป'));
  await tester.pumpAndSettle();
}

Future<void> _toComposer(WidgetTester tester) async {
  await _toEditor(tester);
  await tester.tap(find.text('ถัดไป'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    _dir = Directory.systemTemp.createTempSync('puntok_test');
    _clips = [
      _clip('osaka', 'assets/images/puntok_osaka.jpg'),
      _clip('seoul', 'assets/images/puntok_seoul.jpg'),
      _clip('london', 'assets/images/puntok_london.jpg'),
    ];
  });
  tearDown(() => _dir.deleteSync(recursive: true));

  testWidgets('the picker numbers clips in the order they were picked',
      (tester) async {
    await _pump(tester);

    expect(find.text('Puntok'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('เพิ่มวิดีโอ'), findsOneWidget);
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

  testWidgets('เพิ่มวิดีโอ brings videos in, picked, and skips the rest',
      (tester) async {
    _clips = [];
    final video = File('${_dir.path}/trip.mov')..writeAsBytesSync([1, 2, 3]);
    final photo = File('${_dir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
    await _pump(tester, picks: [XFile(video.path), XFile(photo.path)]);

    await tester.tap(find.text('เพิ่มวิดีโอ'));
    await _settle(tester);

    // The video is in the grid and already in the cut.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('ถัดไป'), findsOneWidget);
    expect(find.textContaining('ไม่ใช่วิดีโอ'), findsOneWidget);
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
    await _toComposer(tester);

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
    await _toComposer(tester);

    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('อาหาร'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();

    expect(find.text('อาหาร'), findsOneWidget);
  });

  testWidgets('signed out, Puntok asks to sign in and sends nothing',
      (tester) async {
    final adapter = _savingApi();
    await _pump(tester, adapter: adapter, signedIn: false);
    await _toComposer(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Puntok'));
    await _settle(tester);

    expect(find.textContaining('เข้าสู่ระบบก่อน'), findsOneWidget);
    expect(adapter.paths, isEmpty);
  });

  testWidgets(
      'Puntok uploads each clip, shares one post carrying them in cut order, '
      'and opens it at the head of the feed', (tester) async {
    final adapter = _savingApi();
    final container = await _pump(tester, adapter: adapter);
    await _toComposer(tester);

    await tester.enterText(
        find.byType(TextField), 'เดินพระนคร 1 วัน\nกินข้าวต้มเช้า');
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('อาหาร'));
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Public'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Followers'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('คนที่มีลิงก์'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Puntok'));
    await _settle(tester);

    // The save itself; the feed it lands on loads its own rows after.
    expect(
      adapter.paths.where((path) => path != 'GET /trips'),
      ['POST /media', 'POST /media', 'POST /trips/posts'],
    );
    final body = adapter.bodyOf('POST /trips/posts')!;
    expect(body['action'], 'share');
    expect(body['visibility'], 'followers');
    expect(body['title'], 'เดินพระนคร 1 วัน');
    expect(body['description'], 'เดินพระนคร 1 วัน\nกินข้าวต้มเช้า');
    expect(body['coverMediaId'], _mediaA);
    expect(body['contents'], [
      {
        'content': 'เดินพระนคร 1 วัน\nกินข้าวต้มเช้า',
        'mediaIds': [_mediaA, _mediaB],
        'location': {'status': 'none'},
      },
    ]);
    expect(body['travelStyles'], ['food']);
    expect(body['remixEnabled'], true);
    expect(body['remixAudience'], 'link');
    expect(body.containsKey('linkedTripId'), isFalse);

    expect(find.text('feed'), findsOneWidget);
    expect(find.text('โพสต์ Puntok แล้ว'), findsOneWidget);
    final feed =
        await tester.runAsync(() => container.read(puntokFeedProvider.future));
    final head = feed!.first;
    expect(head.id, 'post-1');
    expect(head.video, 'https://cdn.test/videos/$_mediaA.mp4');
    expect(head.poster, 'https://cdn.test/videos/$_mediaA-large.webp');
  });

  testWidgets('Save Draft saves as a draft and lands on ทริปฉัน',
      (tester) async {
    final adapter = _savingApi();
    await _pump(tester, adapter: adapter);
    await _toComposer(tester);

    await tester.tap(find.text('Save Draft'));
    await _settle(tester);

    expect(adapter.bodyOf('POST /trips/posts')!['action'], 'draft');
    expect(find.text('my trips'), findsOneWidget);
  });

  testWidgets('a rejected upload says why and stays on the composer',
      (tester) async {
    final adapter = _savingApi(uploadStatus: 400);
    await _pump(tester, adapter: adapter);
    await _toComposer(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Puntok'));
    await _settle(tester);

    expect(find.textContaining('ยาวไม่เกิน 60 วินาที'), findsOneWidget);
    expect(find.text('New Puntok'), findsOneWidget);
    expect(adapter.paths, isNot(contains('POST /trips/posts')));
  });
}
