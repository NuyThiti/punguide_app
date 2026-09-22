import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/features/ai_chat/domain/chat_message.dart';
import 'package:pluno/features/ai_chat/presentation/ai_chat_screen.dart';
import 'package:pluno/features/ai_chat/presentation/widgets/ai_chat_bubble.dart';
import 'package:pluno/features/ai_chat/presentation/widgets/ai_chat_empty_state.dart';

Future<void> _pumpChat(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: AiChatScreen()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the empty state, under the header and its badge',
      (tester) async {
    await _pumpChat(tester);

    expect(find.byType(AiChatEmptyState), findsOneWidget);
    expect(find.text('ไปกัน'), findsOneWidget);
    expect(find.text('Ai Chat'), findsOneWidget);
    expect(find.byType(AiChatBubble), findsNothing);

    // The opener the design prints above the composer.
    expect(find.text('สถานที่ใกล้ฉัน'), findsOneWidget);
  });

  testWidgets('sending swaps the empty state for the transcript',
      (tester) async {
    await _pumpChat(tester);

    await tester.enterText(find.byType(TextField), 'ที่เที่ยวใกล้ ๆ ฉันตอนนี้');
    await tester.tap(find.byIcon(Icons.near_me));
    await tester.pumpAndSettle();

    expect(find.byType(AiChatEmptyState), findsNothing);

    // The traveller's line, then the assistant's answer to it.
    final bubbles = tester
        .widgetList<AiChatBubble>(find.byType(AiChatBubble))
        .toList();
    expect(bubbles, hasLength(2));
    expect(bubbles.first.message.author, ChatAuthor.traveller);
    expect(bubbles.first.message.text, 'ที่เที่ยวใกล้ ๆ ฉันตอนนี้');
    expect(bubbles.last.message.author, ChatAuthor.assistant);

    // The field is emptied, and the opener has done its job.
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(find.text('สถานที่ใกล้ฉัน'), findsNothing);
  });

  testWidgets('the opener sends itself, and blank input sends nothing',
      (tester) async {
    await _pumpChat(tester);

    await tester.tap(find.byIcon(Icons.near_me));
    await tester.pumpAndSettle();
    expect(find.byType(AiChatBubble), findsNothing);

    await tester.tap(find.text('สถานที่ใกล้ฉัน'));
    await tester.pumpAndSettle();

    final first = tester.widgetList<AiChatBubble>(find.byType(AiChatBubble));
    expect(first.first.message.text, 'สถานที่ใกล้ฉัน');
  });
}
