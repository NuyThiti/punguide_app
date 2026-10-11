import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/features/remix_trip/presentation/post_done_screen.dart';

void main() {
  testWidgets('lays out on a phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: PostDoneScreen(tripId: 'trip-1'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('PunGuide Done!'), findsOneWidget);
    // Default reason: a post's own first publish, not a remix.
    expect(find.text('บันทึกโพสต์เรียบร้อยแล้ว'), findsOneWidget);
    expect(find.text('คัดลอกลิงก์'), findsOneWidget);
    expect(find.text('LINE'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('อื่น ๆ'), findsOneWidget);
    expect(find.text('อยู่ต่อ'), findsOneWidget);
    expect(find.text('ดูทริปของฉัน'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the remix reason shows its own subtitle', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PostDoneScreen(tripId: 'trip-1', reason: PostDoneReason.remix),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Remix ลงทริปของคุณสำเร็จแล้ว'), findsOneWidget);
    expect(find.text('บันทึกโพสต์เรียบร้อยแล้ว'), findsNothing);
  });

  testWidgets('each share chip opens its own stub message', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PostDoneScreen(tripId: 'trip-1'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byWidgetPredicate((w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == 'assets/images/share_line.png'));
    await tester.pumpAndSettle();
    expect(find.text('แชร์ผ่าน LINE ยังไม่เปิดใช้งาน'), findsOneWidget);
  });
}
