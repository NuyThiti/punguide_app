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
  VoidCallback? onSave = _noop,
  VoidCallback? onTap = _noop,
  bool isMine = false,
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
            onTap: onTap ?? () {},
            onSave: onSave,
            isMine: isMine,
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

  testWidgets('the cover carries no bookmark; the tally is the save action',
      (tester) async {
    var saves = 0;
    var opens = 0;
    await tester.pumpWidget(
      _card(
        feedTrip(likeCount: 12),
        onSave: () => saves++,
        onTap: () => opens++,
      ),
    );
    await tester.pumpAndSettle();

    // One bookmark on the card, and it is the one in the counts row.
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pumpAndSettle();

    expect(saves, 1);
    // The tap stopped at the tally rather than opening the trip behind it.
    expect(opens, 0);
  });

  testWidgets('a saved row shows the filled bookmark', (tester) async {
    await tester.pumpWidget(_card(feedTrip(isSaved: true, likeCount: 3)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsNothing);
  });

  testWidgets('a zero tally keeps its icon on someone else\'s card',
      (tester) async {
    await tester.pumpWidget(
      _card(feedTrip(likeCount: 0, remixCount: 0)),
    );
    await tester.pumpAndSettle();

    // The icons are the affordance, so they stay; the 0s do not.
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(find.byIcon(Icons.shuffle), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('on my own card a zero tally disappears entirely',
      (tester) async {
    await tester.pumpWidget(
      _card(feedTrip(likeCount: 0, remixCount: 0), isMine: true, onSave: null),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_border), findsNothing);
    expect(find.byIcon(Icons.shuffle), findsNothing);
  });

  testWidgets('on my own card a tally that has a number still shows, inert',
      (tester) async {
    var opens = 0;
    await tester.pumpWidget(
      _card(
        feedTrip(likeCount: 9, remixCount: 0),
        isMine: true,
        onSave: null,
        onTap: () => opens++,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('9'), findsOneWidget);
    expect(find.byIcon(Icons.shuffle), findsNothing);

    // A readout, not a button: the tap falls through to the card itself.
    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pumpAndSettle();
    expect(opens, 1);
  });

  testWidgets('my own wall drops the creator pill', (tester) async {
    await tester.pumpWidget(
      _card(feedTrip(creatorName: 'makitravels'), isMine: true, onSave: null),
    );
    await tester.pumpAndSettle();

    // They know whose these are; the cover has better uses for the width.
    expect(find.text('makitravels'), findsNothing);
    // The type is still worth saying — it tells their own rows apart.
    expect(find.text('แผนทริป'), findsOneWidget);
  });

  testWidgets("someone else's wall keeps the creator pill", (tester) async {
    await tester.pumpWidget(_card(feedTrip(creatorName: 'makitravels')));
    await tester.pumpAndSettle();

    expect(find.text('makitravels'), findsOneWidget);
  });
}

void _noop() {}
