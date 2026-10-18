import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/features/trip_detail/presentation/post_share_settings_screen.dart';

import 'support/fake_api.dart';

late FakeAdapter adapter;

Map<String, dynamic> _postJson({Map<String, dynamic>? linkedTrip}) =>
    <String, dynamic>{
      'id': 'trip-1',
      'ownerId': 'u1',
      'type': 'content',
      'title': 'เที่ยวย่านพระนคร 1 day trip',
      'destination': 'Phra Nakhon, Thai',
      'status': 'published',
      'schedule': const <String, dynamic>{},
      'totalBudget': 2000,
      'customer': const <String, dynamic>{
        'id': 'u1',
        'name': 'cattravel',
        'groupSize': 1,
      },
      'visibility': 'public',
      'isSaved': false,
      'isLiked': false,
      'likeCount': 0,
      'remixCount': 0,
      'days': const <Map<String, dynamic>>[],
      'contents': const <Map<String, dynamic>>[],
      'createdAt': '2026-09-09T00:00:00.000Z',
      'updatedAt': '2026-09-09T00:00:00.000Z',
      if (linkedTrip != null) 'linkedTrip': linkedTrip,
    };

Map<String, dynamic> _plan({
  required String id,
  required String title,
  int durationDays = 1,
  int placeCount = 11,
  String type = 'plan_trip',
}) =>
    <String, dynamic>{
      'id': id,
      'type': type,
      'title': title,
      'destination': 'กรุงเทพมหานคร',
      'status': 'draft',
      'schedule': {'durationDays': durationDays},
      'totalBudget': 0,
      'placeCount': placeCount,
      'tags': <String>[],
      'isSaved': false,
      'isLiked': false,
      'likeCount': 0,
      'remixCount': 0,
      'createdAt': '2026-09-09T00:00:00.000Z',
      'updatedAt': '2026-09-09T00:00:00.000Z',
    };

Widget _harness() => ProviderScope(
      overrides: [
        plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
      ],
      child: const MaterialApp(
        home: PostShareSettingsScreen(tripId: 'trip-1'),
      ),
    );

Future<void> _pumpScreen(WidgetTester tester,
    {Map<String, dynamic>? trip, List<Map<String, dynamic>>? plans}) async {
  adapter = FakeAdapter({
    'GET /trips/trip-1': [FakeReply(200, trip ?? _postJson())],
    'GET /trips/mine': [FakeReply(200, plans ?? const <Map<String, dynamic>>[])],
    'PUT /trips/posts/trip-1': [FakeReply(200, _postJson())],
  });
  await tester.pumpWidget(_harness());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no plan connected shows the empty connect-plan row',
      (tester) async {
    await _pumpScreen(tester);

    expect(find.text('เชื่อมแพลนของฉัน'), findsOneWidget);
    expect(find.text('เชื่อมโพสต์นี้กับแพลนท่องเที่ยวของคุณ'), findsOneWidget);
  });

  testWidgets('shows the second-of-two step indicator above the bar',
      (tester) async {
    await _pumpScreen(tester);

    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets(
      'a draft that has never been shared defaults to Public, '
      'regardless of the server\'s own private fallback', (tester) async {
    await _pumpScreen(tester, trip: {
      ..._postJson(),
      'status': 'draft',
      'visibility': 'private',
      'publishedAt': null,
    });

    expect(find.text('Public'), findsOneWidget);
    expect(find.text('Only me'), findsNothing);
  });

  testWidgets('a post already shared as Only me keeps that on reopen',
      (tester) async {
    await _pumpScreen(tester, trip: {
      ..._postJson(),
      'visibility': 'private',
      'publishedAt': '2026-09-09T00:00:00.000Z',
    });

    expect(find.text('Only me'), findsOneWidget);
    expect(find.text('Public'), findsNothing);
  });

  testWidgets('a post shared to Followers reopens and re-shares as Followers',
      (tester) async {
    await _pumpScreen(tester, trip: {
      ..._postJson(),
      'visibility': 'followers',
      'publishedAt': '2026-09-09T00:00:00.000Z',
    });

    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('Public'), findsNothing);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(adapter.bodyOf('PUT /trips/posts/trip-1')!['visibility'],
        'followers');
  });

  testWidgets('a draft saved with Followers shows Followers, not private',
      (tester) async {
    await _pumpScreen(tester, trip: {
      ..._postJson(),
      'status': 'draft',
      'visibility': 'private',
      'draftVisibility': 'followers',
      'publishedAt': null,
    });

    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('Only me'), findsNothing);
  });

  testWidgets(
      'a shared post taken down by Save Draft shows the dropdown it was '
      'saved as, not the visibility the takedown forced',
      (tester) async {
    await _pumpScreen(tester, trip: {
      ..._postJson(),
      // Save Draft forces this to private server-side — `draftVisibility`
      // is what actually remembers the dropdown's own last value.
      'visibility': 'private',
      'draftVisibility': 'public',
      'publishedAt': '2026-09-09T00:00:00.000Z',
    });

    expect(find.text('Public'), findsOneWidget);
    expect(find.text('Only me'), findsNothing);
  });

  testWidgets(
      "/trips/mine's own other posts never show up as a plan to connect",
      (tester) async {
    await _pumpScreen(tester, plans: [
      _plan(id: 'plan-1', title: 'เดินเล่นพระนคร'),
      _plan(id: 'post-1', title: 'ของกินย่านพระนคร', type: 'content'),
    ]);

    await tester.tap(find.text('เชื่อมแพลนของฉัน'));
    await tester.pumpAndSettle();

    expect(find.text('เดินเล่นพระนคร'), findsOneWidget);
    expect(find.text('ของกินย่านพระนคร'), findsNothing);
  });

  testWidgets('picking a plan connects it and shows its facts',
      (tester) async {
    await _pumpScreen(tester, plans: [
      _plan(id: 'plan-1', title: 'เดินเล่นพระนคร', durationDays: 1, placeCount: 11),
    ]);

    await tester.tap(find.text('เชื่อมแพลนของฉัน'));
    await tester.pumpAndSettle();
    expect(find.text('เชื่อมกับแผนของฉัน'), findsOneWidget);
    expect(find.text('เดินเล่นพระนคร'), findsOneWidget);

    await tester.tap(find.text('เดินเล่นพระนคร'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();

    expect(find.text('เชื่อมแพลนเดินเล่นพระนคร'), findsOneWidget);
    expect(find.text('1 วัน • 11 สถานที่'), findsOneWidget);
    expect(find.text('เชื่อมแพลนของฉัน'), findsNothing);
  });

  testWidgets('reopening the picker preselects the connected plan',
      (tester) async {
    await _pumpScreen(
      tester,
      trip: _postJson(linkedTrip: {
        'id': 'plan-1',
        'title': 'เดินเล่นพระนคร',
        'schedule': {'durationDays': 1},
        'placeCount': 11,
      }),
      plans: [
        _plan(id: 'plan-1', title: 'เดินเล่นพระนคร'),
        _plan(id: 'plan-2', title: 'ทริปทะเล'),
      ],
    );

    expect(find.text('เชื่อมแพลนเดินเล่นพระนคร'), findsOneWidget);

    await tester.tap(find.text('เชื่อมแพลนเดินเล่นพระนคร'));
    await tester.pumpAndSettle();
    // The already-connected plan shows a filled checkmark — switch to the
    // other one and confirm.
    await tester.tap(find.text('ทริปทะเล'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();

    expect(find.text('เชื่อมแพลนทริปทะเล'), findsOneWidget);
  });

  testWidgets('cancel discards a pending pick', (tester) async {
    await _pumpScreen(
      tester,
      trip: _postJson(linkedTrip: {
        'id': 'plan-1',
        'title': 'เดินเล่นพระนคร',
        'schedule': {'durationDays': 1},
        'placeCount': 11,
      }),
      plans: [
        _plan(id: 'plan-1', title: 'เดินเล่นพระนคร'),
        _plan(id: 'plan-2', title: 'ทริปทะเล'),
      ],
    );

    await tester.tap(find.text('เชื่อมแพลนเดินเล่นพระนคร'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทริปทะเล'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();

    // Still the original plan — nothing was committed.
    expect(find.text('เชื่อมแพลนเดินเล่นพระนคร'), findsOneWidget);
    expect(find.text('เชื่อมแพลนทริปทะเล'), findsNothing);
  });

  testWidgets('tapping the selected plan again removes the connection',
      (tester) async {
    await _pumpScreen(
      tester,
      trip: _postJson(linkedTrip: {
        'id': 'plan-1',
        'title': 'เดินเล่นพระนคร',
        'schedule': {'durationDays': 1},
        'placeCount': 11,
      }),
      plans: [_plan(id: 'plan-1', title: 'เดินเล่นพระนคร')],
    );

    await tester.tap(find.text('เชื่อมแพลนเดินเล่นพระนคร'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เดินเล่นพระนคร')); // deselect
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();

    expect(find.text('เชื่อมแพลนของฉัน'), findsOneWidget);
    expect(find.text('เชื่อมแพลนเดินเล่นพระนคร'), findsNothing);
  });

  testWidgets('no plans to connect shows the empty sheet state',
      (tester) async {
    await _pumpScreen(tester, plans: const []);

    await tester.tap(find.text('เชื่อมแพลนของฉัน'));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีแผนให้เชื่อม สร้างแพลนก่อนได้เลย'), findsOneWidget);
  });

  testWidgets(
      'shows the remix toggle, and the audience options once it is on',
      (tester) async {
    await _pumpScreen(tester, trip: {..._postJson(), 'remixEnabled': false});

    expect(find.text('เปิดให้ remix'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    // Off, so the audience choice (which only matters once remix is on)
    // stays off screen rather than showing a choice that does nothing yet.
    expect(find.text('ทุกคน'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('ทุกคน'), findsOneWidget);
    expect(find.text('คนที่ติดตาม'), findsOneWidget);
    expect(find.text('คนที่มีลิงก์'), findsOneWidget);
  });

  testWidgets(
      'a trip missing the remix fields defaults to on and everyone — the '
      "server's own backfill for every trip older than this feature",
      (tester) async {
    await _pumpScreen(tester);

    expect(find.text('ทุกคน'), findsOneWidget);
  });

  testWidgets(
      'sharing sends the connected plan, the remix toggle and its audience',
      (tester) async {
    // Taller than the default test surface: with a connected plan's card
    // above it, the audience list otherwise lands right on the viewport's
    // own edge once scrolled into view.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pumpScreen(
      tester,
      trip: {..._postJson(), 'remixEnabled': false},
      plans: [_plan(id: 'plan-1', title: 'เดินเล่นพระนคร')],
    );

    await tester.tap(find.text('เชื่อมแพลนของฉัน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เดินเล่นพระนคร'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('คนที่ติดตาม'));
    await tester.tap(find.text('คนที่ติดตาม'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    final body = adapter.bodyOf('PUT /trips/posts/trip-1')!;
    expect(body['linkedTripId'], 'plan-1');
    expect(body['remixEnabled'], true);
    expect(body['remixAudience'], 'followers');
    expect(body['visibility'], 'public');
  });

  testWidgets('sharing without connecting a plan clears any link',
      (tester) async {
    await _pumpScreen(tester, plans: const []);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    final body = adapter.bodyOf('PUT /trips/posts/trip-1')!;
    expect(body['linkedTripId'], isNull);
    expect(body.containsKey('linkedTripId'), isTrue);
  });
}
