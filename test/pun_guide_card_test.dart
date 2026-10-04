import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/theme/app_colors.dart';
import 'package:pluno/features/home/presentation/widgets/pun_guide_card.dart';

import 'support/home_feed_fixtures.dart';

/// The colour of the pill wrapped round [label].
Color chipColourOf(WidgetTester tester, String label) {
  final box = tester.widget<Container>(
    find
        .ancestor(of: find.text(label), matching: find.byType(Container))
        .first,
  );
  return (box.decoration! as BoxDecoration).color!;
}

Widget _card(
  TripListItem trip, {
  String? distanceLabel,
  bool featured = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 180,
          child: PunGuideCard(
            trip: trip,
            distanceLabel: distanceLabel,
            featured: featured,
            onTap: () {},
            onSave: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the card prints the trip, its creator and its counts',
      (tester) async {
    await tester.pumpWidget(
      _card(
        feedTrip(
          title: 'เที่ยวย่านพระนคร เก็บไฮไลต์ครบ',
          destination: 'Phra Nakhon, Thai',
          durationDays: 1,
          totalBudget: 200,
          creatorName: 'BKKwalker',
          remixCount: 3500,
          likeCount: 2000,
        ),
        distanceLabel: '2.3 Km',
        featured: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('เที่ยวย่านพระนคร เก็บไฮไลต์ครบ'), findsOneWidget);
    expect(find.text('BKKwalker'), findsOneWidget);
    expect(find.text('2.3 Km'), findsOneWidget);
    expect(find.text('Top PunGuide'), findsOneWidget);
    expect(find.text('Phra Nakhon, Thai'), findsOneWidget);
    // The facts line is rich text so its separator can be violet.
    expect(find.textContaining('1 วัน', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('฿ 200 /คน', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('3.5K'), findsOneWidget);
    expect(find.text('2K'), findsOneWidget);
  });

  testWidgets('no distance means no violet chip, not a guessed one',
      (tester) async {
    await tester.pumpWidget(_card(feedTrip()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Km'), findsNothing);
    // Not featured either, so the badge stays off.
    expect(find.text('Top PunGuide'), findsNothing);
  });

  testWidgets('a row with no cover, schedule, budget or creator still renders',
      (tester) async {
    await tester.pumpWidget(
      _card(
        feedTrip(
          title: 'ทริปที่ยังไม่มีข้อมูลครบ',
          durationDays: null,
          totalBudget: 0,
          coverUrl: null,
          creatorName: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ทริปที่ยังไม่มีข้อมูลครบ'), findsOneWidget);
    expect(find.text('ผู้ใช้ที่ถูกลบ'), findsOneWidget);
    // Neither fact is known, so the line is empty rather than showing zeroes.
    expect(find.textContaining('วัน', findRichText: true), findsNothing);
    expect(find.textContaining('฿', findRichText: true), findsNothing);
  });

  testWidgets('a plan wears the violet accent and says แผนทริป',
      (tester) async {
    await tester.pumpWidget(
      _card(feedTrip(durationDays: 2, totalBudget: 2000),
          distanceLabel: '1 Km'),
    );
    await tester.pumpAndSettle();

    expect(find.text('แผนทริป'), findsOneWidget);
    expect(find.text('คู่มือ'), findsNothing);
    expect(chipColourOf(tester, '1 Km'), AppColors.cardPlanAccent);
    // Rendered as rich text so the bullet can be violet.
    expect(
      find.textContaining('2 วัน', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('฿ 2,000 /คน', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('a guide wears the lime accent and says คู่มือ', (tester) async {
    await tester.pumpWidget(
      _card(
        TripListItem.fromJson(
          feedTripJson(type: 'content', placeCount: 7),
        ),
        distanceLabel: '8.5 Km',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('คู่มือ'), findsOneWidget);
    expect(find.text('แผนทริป'), findsNothing);
    expect(chipColourOf(tester, '8.5 Km'), AppColors.cardGuideAccent);
    // A guide is measured in places, not days and money.
    expect(find.textContaining('7 สถานที่', findRichText: true), findsOneWidget);
  });

  testWidgets('a plan that costs nothing reads ฟรี, not a blank', (tester) async {
    await tester.pumpWidget(_card(feedTrip(durationDays: 0, totalBudget: 0)));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ครึ่งวัน', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('ฟรี / คน', findRichText: true),
      findsOneWidget,
    );
  });
}
