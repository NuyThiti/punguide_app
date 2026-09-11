import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/features/home/presentation/widgets/pun_guide_card.dart';

import 'support/home_feed_fixtures.dart';

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
    // Budget reads as an estimate, and the counts are abbreviated.
    expect(find.text('1 วัน • ฿ ~200 /คน'), findsOneWidget);
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
    expect(find.textContaining('วัน'), findsNothing);
    expect(find.textContaining('฿'), findsNothing);
  });
}
