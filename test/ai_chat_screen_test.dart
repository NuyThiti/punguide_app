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

    // The empty state's question leads, so the traveller's line still has the
    // prompt it answered above it.
    final bubbles = tester
        .widgetList<AiChatBubble>(find.byType(AiChatBubble))
        .toList();
    expect(bubbles, hasLength(3));
    expect(bubbles[0].message.author, ChatAuthor.assistant);
    expect(bubbles[0].message.text, 'What are you looking for today?');
    expect(bubbles[1].message.author, ChatAuthor.traveller);
    expect(bubbles[1].message.text, 'ที่เที่ยวใกล้ ๆ ฉันตอนนี้');
    expect(bubbles[2].message.author, ChatAuthor.assistant);

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);

    // The opener stays where the design leaves it.
    expect(find.text('สถานที่ใกล้ฉัน'), findsOneWidget);
  });

  testWidgets('the greeting only leads once, however many turns follow',
      (tester) async {
    await _pumpChat(tester);

    for (final line in ['ทะเลใกล้ ๆ', 'คาเฟ่ด้วย']) {
      await tester.enterText(find.byType(TextField), line);
      await tester.tap(find.byIcon(Icons.near_me));
      await tester.pumpAndSettle();
    }

    final bubbles = tester
        .widgetList<AiChatBubble>(find.byType(AiChatBubble))
        .toList();
    expect(bubbles, hasLength(5));
    expect(
      bubbles.where((b) => b.message.text == 'What are you looking for today?'),
      hasLength(1),
    );
  });

  testWidgets('the opener sends itself, and blank input sends nothing',
      (tester) async {
    await _pumpChat(tester);

    await tester.tap(find.byIcon(Icons.near_me));
    await tester.pumpAndSettle();
    expect(find.byType(AiChatBubble), findsNothing);

    await tester.tap(find.text('สถานที่ใกล้ฉัน'));
    await tester.pumpAndSettle();

    final bubbles = tester
        .widgetList<AiChatBubble>(find.byType(AiChatBubble))
        .toList();
    expect(bubbles[1].message.author, ChatAuthor.traveller);
    expect(bubbles[1].message.text, 'สถานที่ใกล้ฉัน');
  });
}
