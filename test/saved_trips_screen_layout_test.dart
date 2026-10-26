import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/home/presentation/widgets/pun_guide_card.dart';
import 'package:pluno/features/saved_trips/presentation/saved_trips_screen.dart';
import 'package:pluno/shared/widgets/app_bottom_nav.dart';

import 'support/home_feed_fixtures.dart';

final _saved = <TripListItem>[
  feedTrip(id: 'saved-1', title: 'เที่ยวดานัง 4 วัน', isSaved: true),
  feedTrip(id: 'saved-2', title: 'รวมคาเฟ่ลับย่านพระนคร', isSaved: true),
];

Widget _harness({
  List<TripListItem>? saved,
  AuthSession? session = AuthSession.demo,
}) {
  return ProviderScope(
    overrides: profileOverrides(saved: saved ?? _saved, session: session),
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.savedTrips.name,
            builder: (_, __) => const SavedTripsScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: AppRoute.profile.name,
            builder: (_, __) => const Scaffold(body: Text('profile-stub')),
          ),
          GoRoute(
            path: '/trips/:tripId',
            name: AppRoute.tripDetail.name,
            builder: (_, __) => const Scaffold(body: Text('detail-stub')),
          ),
        ],
      ),
    ),
  );
}

void _phone(WidgetTester tester, {double width = 393, double height = 852}) {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the wall is the bookmarks shelf, not the local store',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('ทริปที่บันทึกไว้'), findsOneWidget);
    for (final trip in _saved) {
      expect(find.text(trip.title), findsOneWidget);
    }
    expect(find.byType(PunGuideCard), findsNWidgets(2));
  });

  testWidgets('un-bookmarking takes the row out of the wall', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // The save button sits on the first card's cover.
    await tester.tap(find.byIcon(Icons.bookmark).first);
    await tester.pumpAndSettle();

    expect(find.text(_saved.first.title), findsNothing);
    expect(find.byType(PunGuideCard), findsOneWidget);
  });

  testWidgets('bookmarks carry no delete — they are somebody else trips',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsNothing);
    // The corner stays a bookmark, so a tap un-saves rather than deletes.
    expect(find.byIcon(Icons.bookmark), findsNWidgets(2));
  });

  testWidgets('a card opens the trip behind it', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text(_saved.first.title));
    await tester.pumpAndSettle();

    expect(find.text('detail-stub'), findsOneWidget);
  });

  testWidgets('an empty shelf says so', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(saved: const <TripListItem>[]));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่ได้บันทึกทริปไหนไว้'), findsOneWidget);
  });

  testWidgets('signed out, it asks for an account', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(session: null));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบเพื่อดูทริปที่บันทึกไว้'), findsOneWidget);
  });

  testWidgets('back falls through to the profile when there is no stack',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('profile-stub'), findsOneWidget);
  });

  testWidgets('saved trips keeps the shared bottom nav', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomNav), findsOneWidget);
    // Reached from the profile menu, so that tab stays lit.
    expect(find.text('My Post'), findsOneWidget);
  });

  testWidgets('saved trips lays out on a narrow phone without overflow',
      (tester) async {
    _phone(tester, width: 320, height: 700);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byType(PunGuideCard), findsNWidgets(2));
  });
}
