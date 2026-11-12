import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/ai_chat/presentation/providers/ai_chat_context.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/ai_chat/presentation/ai_chat_screen.dart';
import 'package:pluno/features/ai_chat/presentation/widgets/ai_chat_bubble.dart';
import 'package:pluno/features/ai_chat/presentation/widgets/ai_chat_empty_state.dart';

import 'support/fake_api.dart';

/// A turn that ends in a plan: a stage, a card, the words, then the envelope.
String _planStream({int revision = 1}) => ''
    'event: accepted\n'
    'data: {"conversationId":"room-1","messageId":"msg-2","userMessageId":"msg-1"}\n'
    '\n'
    'event: status\n'
    'data: {"stage":"drafting_itinerary"}\n'
    '\n'
    'event: text\n'
    'data: {"text":"จัดให้สามวันแบบไม่เดินเยอะครับ"}\n'
    '\n'
    'event: complete\n'
    'data: {"schemaVersion":1,"conversationId":"room-1","messageId":"msg-2",'
    '"status":"complete","text":"จัดให้สามวันแบบไม่เดินเยอะครับ",'
    '"blocks":[{"type":"itinerary_preview","draftId":"draft-7",'
    '"draftRevision":$revision,"title":"เชียงใหม่ 3 วัน","destination":"เชียงใหม่",'
    '"durationDays":3,"feasibilityUnverified":true,'
    '"days":[{"dayNumber":1,"stops":[{"name":"วัดพระสิงห์","startTime":"09:30"}]}]},'
    '{"type":"weather_forecast","outlook":"ฝนตก"}],'
    '"suggestedReplies":[],"warnings":["เวลาเดินทางเป็นค่าประมาณ"],'
    '"draftId":"draft-7","draftRevision":$revision,"error":null}\n';

/// A "find places" turn: §5.2 has the server fold published trips in above the
/// places, and the order is the server's to choose — never the model's.
const _placesTurn = ''
    'event: accepted\n'
    'data: {"conversationId":"room-1","messageId":"msg-2"}\n'
    '\n'
    'event: complete\n'
    'data: {"schemaVersion":1,"conversationId":"room-1","messageId":"msg-2",'
    '"status":"complete","text":"มีทริปที่คนอื่นแชร์ไว้ด้วยครับ","blocks":['
    '{"type":"trip_results","totalMatches":9,"trips":['
    '{"tripId":"t1","title":"เชียงใหม่ชิล ๆ","tripType":"plan_trip"},'
    '{"tripId":"t2","title":"คาเฟ่ฮอปปิ้งเชียงใหม่","tripType":"content",'
    '"distanceKm":2.3}]},'
    '{"type":"place_results","nearLabel":"นิมมานเหมินท์","totalMatches":6,'
    '"places":[{"placeId":"p1","name":"ร้านกาแฟริมคลอง"}]}],'
    '"suggestedReplies":[],"warnings":[],"error":null}\n';

FakeAdapter _adapter({String? stream, Map<String, List<FakeReply>>? extra}) =>
    FakeAdapter(<String, List<FakeReply>>{
      'POST /chat/conversations': [
        const FakeReply(201, <String, dynamic>{'id': 'room-1', 'locale': 'th'}),
      ],
      'POST /chat/conversations/room-1/messages': [
        FakeReply.text(200, stream ?? _planStream()),
      ],
      ...?extra,
    });

Future<void> _pumpChat(
  WidgetTester tester,
  FakeAdapter adapter, {
  bool signedIn = false,
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
        if (signedIn)
          authSessionProvider
              .overrideWith((ref) => AuthController(AuthSession.demo)),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();
}

/// The chat plus the pages its cards and its สร้างทริป button lead to, each a
/// bare marker — this suite asserts *where* a tap goes, not what is drawn
/// when it lands.
GoRouter _router() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          name: AppRoute.aiChat.name,
          builder: (_, __) => const AiChatScreen(),
        ),
        // Before the `:tripId` pattern, exactly as the real router orders
        // them: go_router matches in declaration order, and below the pattern
        // this would open a trip whose id is "mine".
        GoRoute(
          path: '/trips/mine',
          name: AppRoute.myTrips.name,
          builder: (_, __) => const _Marker('planner'),
        ),
        GoRoute(
          path: '/trips/:tripId/edit',
          name: AppRoute.editTrip.name,
          builder: (_, state) =>
              _Marker('edit:${state.params['tripId']}'),
        ),
        GoRoute(
          path: '/trips/:tripId',
          name: AppRoute.tripDetail.name,
          builder: (_, state) =>
              _Marker('detail:${state.params['tripId']}'),
        ),
      ],
    );

class _Marker extends StatelessWidget {
  const _Marker(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
        // An app bar purely so `pageBack()` has a back button to press.
        appBar: AppBar(),
        body: Center(child: Text(label)),
      );
}

/// What `GET /users/me/location` answers once a place has been stored.
Map<String, List<FakeReply>> _storedPlace({
  String address = 'เทศบาลนครเชียงใหม่ อำเภอเมืองเชียงใหม่ เชียงใหม่',
}) =>
    <String, List<FakeReply>>{
      'GET /users/me/location': [
        FakeReply(200, <String, dynamic>{
          'location': <String, dynamic>{
            'id': 'place-1',
            'name': 'ร้านกาแฟริมคลอง',
            'address': address,
            'lat': 18.7961,
            'lng': 98.9673,
          },
        }),
      ],
    };

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byIcon(Icons.near_me));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the empty state, under the header and its badge',
      (tester) async {
    await _pumpChat(tester, _adapter());

    expect(find.byType(AiChatEmptyState), findsOneWidget);
    expect(find.text('ไปกัน'), findsOneWidget);
    expect(find.text('Ai Chat'), findsOneWidget);
    expect(find.byType(AiChatBubble), findsNothing);
    expect(find.text('สถานที่ใกล้ฉัน'), findsOneWidget);
  });

  testWidgets('the room is opened lazily, on the first message',
      (tester) async {
    final adapter = _adapter();
    await _pumpChat(tester, adapter);

    // Merely looking at the page must not create a room.
    expect(adapter.paths, isNot(contains('POST /chat/conversations')));

    await _send(tester, 'จัดแผนเชียงใหม่ 3 วัน');
    expect(adapter.paths, contains('POST /chat/conversations'));
    expect(
      adapter.bodyOf('POST /chat/conversations/room-1/messages')!['text'],
      'จัดแผนเชียงใหม่ 3 วัน',
    );
  });

  testWidgets('a streamed turn becomes bubbles, a plan card and its caveats',
      (tester) async {
    await _pumpChat(tester, _adapter());
    await _send(tester, 'จัดแผนเชียงใหม่ 3 วัน');

    expect(find.byType(AiChatEmptyState), findsNothing);
    expect(find.text('จัดแผนเชียงใหม่ 3 วัน'), findsOneWidget);
    expect(find.text('จัดให้สามวันแบบไม่เดินเยอะครับ'), findsOneWidget);

    // The plan reads as a draft, and says what has not been checked.
    expect(find.text('เชียงใหม่ 3 วัน'), findsOneWidget);
    expect(find.text('ร่างแผนจากผู้ช่วย'), findsOneWidget);
    expect(find.text('ยังไม่ได้บันทึก'), findsOneWidget);
    expect(
      find.text('เวลาเดินทางและเวลาเปิด-ปิดยังไม่ได้ตรวจครบทุกช่วง'),
      findsOneWidget,
    );
    expect(find.text('เวลาเดินทางเป็นค่าประมาณ'), findsOneWidget);
    expect(find.text('วัดพระสิงห์'), findsOneWidget);
  });

  testWidgets('a block kind the app does not know is skipped, not fatal',
      (tester) async {
    await _pumpChat(tester, _adapter());
    await _send(tester, 'จัดแผนเชียงใหม่ 3 วัน');

    // The turn carried a weather_forecast block alongside the plan.
    expect(tester.takeException(), isNull);
    expect(find.text('ฝนตก'), findsNothing);
    expect(find.text('เชียงใหม่ 3 วัน'), findsOneWidget);
  });

  FakeAdapter _saveAdapter({bool alreadySaved = false}) => _adapter(
        stream: _planStream(revision: 2),
        extra: <String, List<FakeReply>>{
          'POST /chat/conversations/room-1/drafts/draft-7/save': [
            FakeReply(201, <String, dynamic>{
              'tripId': 'trip-3',
              'alreadySaved': alreadySaved,
            }),
          ],
        },
      );

  testWidgets('สร้างทริป writes the revision on screen and opens the editor',
      (tester) async {
    final adapter = _saveAdapter();
    await _pumpChat(tester, adapter);
    await _send(tester, 'จัดแผนเชียงใหม่ 3 วัน');

    await tester.tap(find.text('สร้างทริป'));
    await tester.pumpAndSettle();

    expect(
      adapter.bodyOf('POST /chat/conversations/room-1/drafts/draft-7/save'),
      <String, dynamic>{'revision': 2},
    );
    // Straight into the editor, the way the create-trip wizard hands off.
    expect(find.text('edit:trip-3'), findsOneWidget);
  });

  testWidgets('a revision already turned into a trip opens the same one',
      (tester) async {
    // alreadySaved is a success, not a conflict — the road is the same.
    await _pumpChat(tester, _saveAdapter(alreadySaved: true));
    await _send(tester, 'จัดแผนเชียงใหม่ 3 วัน');

    await tester.tap(find.text('สร้างทริป'));
    await tester.pumpAndSettle();

    expect(find.text('edit:trip-3'), findsOneWidget);
  });

  testWidgets('once created, the button leads back instead of going dead',
      (tester) async {
    final adapter = _saveAdapter();
    await _pumpChat(tester, adapter);
    await _send(tester, 'จัดแผนเชียงใหม่ 3 วัน');

    await tester.tap(find.text('สร้างทริป'));
    await tester.pumpAndSettle();

    // Back out of the editor, onto the card that made it.
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('สร้างทริป'), findsNothing);
    expect(find.text('เปิดทริปที่สร้างไว้'), findsOneWidget);

    await tester.tap(find.text('เปิดทริปที่สร้างไว้'));
    await tester.pumpAndSettle();
    expect(find.text('detail:trip-3'), findsOneWidget);

    // And no second trip was written along the way.
    expect(
      adapter.paths
          .where((p) => p.endsWith('/drafts/draft-7/save')),
      hasLength(1),
    );
  });

  testWidgets('a failed turn offers a retry under the same request id',
      (tester) async {
    final failure = ''
        'event: accepted\n'
        'data: {"conversationId":"room-1","messageId":"msg-2"}\n'
        '\n'
        'event: error\n'
        'data: {"schemaVersion":1,"conversationId":"room-1","messageId":"msg-2",'
        '"status":"failed","text":null,"blocks":[],'
        '"error":{"code":"provider_unavailable","message":"ไม่ว่าง",'
        '"retryable":true}}\n';

    final adapter = _adapter(stream: failure);
    await _pumpChat(tester, adapter);
    await _send(tester, 'จัดแผนเชียงใหม่');

    expect(find.text('ลองใหม่'), findsOneWidget);

    await tester.tap(find.text('ลองใหม่'));
    await tester.pumpAndSettle();

    final sends = adapter.requests
        .where((r) => r.path == '/chat/conversations/room-1/messages')
        .toList();
    expect(sends, hasLength(2));
    // Same id — the server replays the answer instead of charging for a
    // second turn, and the room does not grow a duplicate question.
    expect(sends.first.data['requestId'], sends.last.data['requestId']);
    // And the room is reused rather than reopened.
    expect(
      adapter.paths.where((p) => p == 'POST /chat/conversations'),
      hasLength(1),
    );
  });

  testWidgets('published trips sit above places, in the order the server sent',
      (tester) async {
    await _pumpChat(tester, _adapter(stream: _placesTurn));
    await _send(tester, 'หาคาเฟ่ใกล้ ๆ หน่อย');

    final trips = find.text('ทริปที่คนอื่นแชร์ไว้');
    final places = find.text('ใกล้ นิมมานเหมินท์');
    expect(trips, findsOneWidget);
    expect(places, findsOneWidget);

    // Ordering is the server's contract — the app must not re-sort.
    expect(
      tester.getTopLeft(trips).dy,
      lessThan(tester.getTopLeft(places).dy),
    );

    // Only a slice was sent, and the card says so rather than implying it is
    // the whole answer.
    expect(find.text('2 จาก 9'), findsOneWidget);
    expect(find.text('เชียงใหม่ชิล ๆ'), findsOneWidget);
    expect(find.text('ร้านกาแฟริมคลอง'), findsOneWidget);
  });

  testWidgets('a nearby trip is badged by kind and shows how far it is',
      (tester) async {
    await _pumpChat(tester, _adapter(stream: _placesTurn));
    await _send(tester, 'หาคาเฟ่ใกล้ ๆ หน่อย');

    // The two kinds of published thing, named the way the rest of the app
    // names them.
    expect(find.text('แผนทริป'), findsOneWidget);
    expect(find.text('คู่มือ'), findsOneWidget);

    // Straight-line, and captioned as such. Only the trip that carried a
    // distance shows one — the other has nothing to measure from.
    expect(find.text('2.3 กม. (ตรง)'), findsOneWidget);
  });

  testWidgets('a card follows the destination the server named', (tester) async {
    await _pumpChat(tester, _adapter(stream: _placesTurn));
    await _send(tester, 'หาคาเฟ่ใกล้ ๆ หน่อย');

    await tester.tap(find.text('เชียงใหม่ชิล ๆ'));
    await tester.pumpAndSettle();

    expect(find.text('detail:t1'), findsOneWidget);
  });

  testWidgets('an open_trip_planner action lands on ทริปฉัน', (tester) async {
    const plannerTurn = ''
        'event: complete\n'
        'data: {"schemaVersion":1,"conversationId":"room-1","messageId":"msg-2",'
        '"status":"complete","text":"ดูได้ที่ทริปของคุณเลยครับ","blocks":['
        '{"type":"trip_results","trips":[{"tripId":"t9","title":"ทริปของฉัน",'
        '"action":{"type":"open_trip_planner"}}]}],'
        '"suggestedReplies":[],"warnings":[],"error":null}\n';

    await _pumpChat(tester, _adapter(stream: plannerTurn));
    await _send(tester, 'ทริปที่ฉันเก็บไว้');

    await tester.tap(find.text('ทริปของฉัน'));
    await tester.pumpAndSettle();

    // Routed rather than silently swallowed, even though no card type sends
    // this one today.
    expect(find.text('planner'), findsOneWidget);
  });

  testWidgets('a trips turn that found nothing shows no empty rail',
      (tester) async {
    const emptyTrips = ''
        'event: complete\n'
        'data: {"schemaVersion":1,"conversationId":"room-1","messageId":"msg-2",'
        '"status":"complete","text":"ยังไม่มีใครแชร์ทริปน่านไว้เลยครับ",'
        '"blocks":[{"type":"trip_results","totalMatches":0,"trips":[]}],'
        '"suggestedReplies":[],"warnings":[],"error":null}\n';

    await _pumpChat(tester, _adapter(stream: emptyTrips));
    await _send(tester, 'ทริปน่าน');

    expect(find.text('ยังไม่มีใครแชร์ทริปน่านไว้เลยครับ'), findsOneWidget);
    expect(find.text('ทริปที่คนอื่นแชร์ไว้'), findsNothing);
  });

  group('knowing where the traveller is', () {
    testWidgets('names the area and offers openers that use it',
        (tester) async {
      await _pumpChat(
        tester,
        _adapter(extra: _storedPlace()),
        signedIn: true,
      );

      // The page says what it is working from, in the traveller's own words.
      expect(find.text('กำลังดูแถว เชียงใหม่'), findsOneWidget);
      expect(find.text('เปลี่ยน'), findsOneWidget);

      // And the openers are worth one tap each, rather than the generic one.
      expect(find.text('ที่เที่ยวในเชียงใหม่'), findsOneWidget);
      expect(find.text('ร้านอาหารใกล้ฉัน'), findsOneWidget);
      expect(find.text('สถานที่ใกล้ฉัน'), findsNothing);
    });

    testWidgets('sends the stored place as the turn origin', (tester) async {
      final adapter = _adapter(extra: _storedPlace());
      await _pumpChat(tester, adapter, signedIn: true);

      await tester.tap(find.text('ร้านอาหารใกล้ฉัน'));
      await tester.pumpAndSettle();

      final body = adapter.bodyOf('POST /chat/conversations/room-1/messages')!;
      expect(body['text'], 'ร้านอาหารใกล้ฉัน');
      expect(body['origin'], <String, dynamic>{
        'lat': 18.7961,
        'lng': 98.9673,
        // The province, not the cafe across the road — a landmark is not
        // where the traveller is.
        'label': 'เชียงใหม่',
      });
    });

    testWidgets('falls back to the place name when the address has no province',
        (tester) async {
      await _pumpChat(
        tester,
        _adapter(extra: _storedPlace(address: '')),
        signedIn: true,
      );

      expect(find.text('กำลังดูแถว ร้านกาแฟริมคลอง'), findsOneWidget);
    });

    testWidgets('signed out, it claims nothing and sends no origin',
        (tester) async {
      // Stubbed, but the route is behind the auth guard so it is never asked.
      final adapter = _adapter(extra: _storedPlace());
      await _pumpChat(tester, adapter);

      expect(find.textContaining('กำลังดูแถว'), findsNothing);
      expect(find.text('สถานที่ใกล้ฉัน'), findsOneWidget);
      expect(adapter.paths, isNot(contains('GET /users/me/location')));

      await _send(tester, 'หาที่เที่ยวหน่อย');
      final body = adapter.bodyOf('POST /chat/conversations/room-1/messages')!;
      expect(body.containsKey('origin'), isFalse);
    });

    testWidgets('a location the page could not read is simply not claimed',
        (tester) async {
      final adapter = _adapter(
        extra: <String, List<FakeReply>>{
          'GET /users/me/location': [const FakeReply(500, null)],
        },
      );
      await _pumpChat(tester, adapter, signedIn: true);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('กำลังดูแถว'), findsNothing);
      expect(find.text('สถานที่ใกล้ฉัน'), findsOneWidget);
    });

    test('the openers only name an area when there is one', () {
      expect(chatOpeners(null), <String>['สถานที่ใกล้ฉัน']);
      expect(
        chatOpeners(const AiChatContext(
          latitude: 1,
          longitude: 2,
          placeName: 'ร้านกาแฟ',
          area: 'น่าน',
        )),
        contains('ที่เที่ยวในน่าน'),
      );
    });
  });
}
