import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/api_providers.dart';
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

Future<void> _pumpChat(WidgetTester tester, FakeAdapter adapter) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
      ],
      child: const MaterialApp(home: AiChatScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

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

  testWidgets('the room is opened lazily, on the first message', (tester) async {
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

  testWidgets('saving sends the revision on screen, once', (tester) async {
    final adapter = _adapter(
      stream: _planStream(revision: 2),
      extra: <String, List<FakeReply>>{
        'POST /chat/conversations/room-1/drafts/draft-7/save': [
          const FakeReply(201, <String, dynamic>{
            'tripId': 'trip-3',
            'alreadySaved': false,
          }),
        ],
      },
    );
    await _pumpChat(tester, adapter);
    await _send(tester, 'จัดแผนเชียงใหม่ 3 วัน');

    await tester.tap(find.text('บันทึกลง Trip Planner'));
    await tester.pumpAndSettle();

    expect(
      adapter.bodyOf('POST /chat/conversations/room-1/drafts/draft-7/save'),
      <String, dynamic>{'revision': 2},
    );
    // The button latches, so a second tap cannot write a second trip.
    expect(find.text('บันทึกแล้ว'), findsOneWidget);
    expect(find.text('บันทึกลง Trip Planner'), findsNothing);
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
}
