import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/home/presentation/widgets/pun_guide_card.dart';
import 'package:pluno/features/my_trips/presentation/delete_trip.dart';
import 'package:pluno/features/profile/presentation/profile_screen.dart';
import 'package:pluno/features/profile/presentation/providers/profile_providers.dart';
import 'package:pluno/features/profile/presentation/widgets/profile_albums_view.dart';
import 'package:pluno/features/profile/presentation/widgets/profile_hero.dart';
import 'package:pluno/features/profile/presentation/widgets/profile_tab_bar.dart';
import 'package:pluno/features/profile/presentation/widgets/profile_top_bar.dart';
import 'package:pluno/features/puntok/presentation/puntok_viewer_screen.dart';
import 'package:pluno/features/puntok/presentation/widgets/puntok_card.dart';
import 'package:pluno/shared/widgets/app_bottom_nav.dart';

import 'support/home_feed_fixtures.dart';

final _mine = <TripListItem>[
  feedTrip(id: 'plan-1', title: 'เที่ยวดานัง 4 วัน'),
  feedTrip(id: 'post-1', title: 'รวมคาเฟ่ลับย่านพระนคร', type: 'content'),
  // The live server still sends a clip as type "content" with a video cover,
  // which is exactly the row the two tabs must not both claim.
  feedTrip(
    id: 'clip-1',
    title: 'คลิปเยาวราช',
    destination: 'เยาวราช, กรุงเทพฯ',
    type: 'content',
    coverUrl: 'https://cdn.test/videos/clip-1.mov',
    coverMediaType: 'video',
  ),
];

final _albums = <TripListItem>[
  feedTrip(id: 'album-1', title: 'มุมถ่ายรูปย่านเมืองเก่า', type: 'content'),
  feedTrip(id: 'album-2', title: 'ของอร่อยเยาวราช', type: 'content'),
];

final _saved = <TripListItem>[
  feedTrip(id: 'saved-1', title: 'ทริปที่บุ๊กมาร์กไว้', isSaved: true),
];

/// Enough rows that the wall is taller than the viewport — the sticky-bar
/// cases need something to scroll past.
List<TripListItem> _tallWall() => <TripListItem>[
      for (var i = 0; i < 10; i++)
        feedTrip(id: 'tall-$i', title: 'ทริปที่ $i'),
    ];

Widget _harness({
  List<TripListItem>? mine,
  List<TripListItem>? saved,
  List<TripListItem>? albums,
  AuthSession? session = AuthSession.demo,
}) {
  return ProviderScope(
    overrides: profileOverrides(
      mine: mine ?? _mine,
      saved: saved ?? _saved,
      albums: albums ?? _albums,
      session: session,
    ),
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.profile.name,
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/profile/account',
            name: AppRoute.profileAccount.name,
            builder: (_, __) => const Scaffold(body: Text('account-stub')),
          ),
          GoRoute(
            path: '/trips/:tripId',
            name: AppRoute.tripDetail.name,
            builder: (_, __) => const Scaffold(body: Text('detail-stub')),
          ),
          GoRoute(
            path: '/puntok/view',
            name: AppRoute.puntokViewer.name,
            builder: (_, state) => PuntokViewerScreen(
              args: state.extra as PuntokViewerArgs?,
            ),
          ),
        ],
      ),
    ),
  );
}

void _usePhone(WidgetTester tester, {double width = 393, double height = 852}) {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Taps a tab by name — the bar renders in enum order, so this survives the
/// strip being reordered or added to.
Future<void> _tapTab(WidgetTester tester, ProfileTab tab) async {
  final tabs = find.descendant(
    of: find.byType(ProfileTabBar),
    matching: find.byType(InkWell),
  );
  await tester.tap(tabs.at(ProfileTab.values.indexOf(tab)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the hero prints the account and the four counts',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // The name is printed twice on purpose: large on the hero, and again in
    // the pinned bar, which is what shows once the hero scrolls away.
    expect(
      find.descendant(
        of: find.byType(ProfileHero),
        matching: find.text(AuthSession.demo.displayName),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ProfileTopBar),
        matching: find.text(AuthSession.demo.displayName),
      ),
      findsOneWidget,
    );
    expect(find.text(AuthSession.demo.handle), findsOneWidget);

    for (final (value, label) in ProfileHero.counts) {
      expect(find.text(value), findsOneWidget);
      expect(find.text(label), findsOneWidget);
    }

    // Back and menu both ride on the cover.
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);

    // The old row-menu profile is gone.
    expect(find.text('ทริปของฉัน'), findsNothing);
    expect(find.text('ตั้งค่าระบบ'), findsNothing);
  });

  testWidgets('the top bar stays put while the wall scrolls under it',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness(mine: _tallWall()));
    await tester.pumpAndSettle();

    final before = tester.getTopLeft(find.byType(ProfileTopBar));
    // Far enough that the hero itself is long gone.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileTopBar), findsOneWidget);
    expect(tester.getTopLeft(find.byType(ProfileTopBar)), before);
    // Back and จัดการบัญชี stay reachable from anywhere on the wall.
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byType(ProfileHero), findsNothing);
  });

  testWidgets('the bar hands over from glyphs-on-cover to a titled bar',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness(mine: _tallWall()));
    await tester.pumpAndSettle();

    double progress() =>
        tester.widget<ProfileTopBar>(find.byType(ProfileTopBar)).progress;

    expect(progress(), 0);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(progress(), 1);
  });

  testWidgets('the strip carries five tabs, albums among them', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final tabs = find.descendant(
      of: find.byType(ProfileTabBar),
      matching: find.byType(InkWell),
    );
    expect(tabs, findsNWidgets(ProfileTab.values.length));
    expect(ProfileTab.values, contains(ProfileTab.albums));
  });

  testWidgets('the albums tab shows the Personal shelf as a grid',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.albums);

    expect(find.byType(ProfileAlbumsView), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    // Share has no endpoint, so it is hidden rather than shown as a dead tab.
    expect(find.text('Share'), findsNothing);

    for (final album in _albums) {
      expect(find.text(album.title), findsOneWidget);
    }
    // It is not a wall of trips.
    expect(find.byType(PunGuideCard), findsNothing);
  });

  testWidgets('an album opens its trip page', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.albums);

    await tester.tap(find.text(_albums.first.title));
    await tester.pumpAndSettle();

    expect(find.text('detail-stub'), findsOneWidget);
  });

  testWidgets('an empty album shelf says so', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness(albums: const <TripListItem>[]));
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.albums);

    expect(find.text('ยังไม่มีอัลบั้มของคุณ'), findsOneWidget);
  });

  testWidgets('own trips offer no bookmark at all', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // You cannot bookmark your own trip, so the corner stays empty rather
    // than holding a button that answers "no".
    final cards = tester.widgetList<PunGuideCard>(find.byType(PunGuideCard));
    expect(cards, isNotEmpty);
    expect(cards.every((card) => card.onSave == null), isTrue);
  });

  testWidgets('the delete on own trips follows its flag', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Saving your own trip does nothing, so when the trash is on it takes
    // that corner — one per card, clip cards included.
    expect(
      find.byIcon(Icons.delete_outline),
      tripDeleteEnabled ? findsNWidgets(_mine.length) : findsNothing,
    );
  });

  testWidgets('deleting asks first, then drops the card', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    // Cancelling leaves the wall alone.
    await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
    await tester.pumpAndSettle();
    expect(find.text(_mine.first.title), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'ลบ'));
    await tester.pumpAndSettle();

    expect(find.text(_mine.first.title), findsNothing);
  }, skip: !tripDeleteEnabled);

  testWidgets('albums carry no delete, whatever the flag says',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.albums);

    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('a clip gets the plainer card, a plan does not', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.clips);

    expect(find.byType(PuntokCard), findsOneWidget);
    expect(find.byType(PunGuideCard), findsNothing);

    // The card prints the title and where it was shot, and nothing else the
    // reference leaves off.
    expect(find.text('คลิปเยาวราช'), findsOneWidget);
    expect(find.text('เยาวราช, กรุงเทพฯ'), findsOneWidget);
    expect(find.text('Editing'), findsNothing);
  });

  testWidgets('tab 1 walls everything the traveller owns', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    for (final trip in _mine) {
      expect(find.text(trip.title), findsOneWidget);
    }
  });

  testWidgets('tab 2 keeps posts and leaves the clip to the Puntok tab',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.content);

    expect(find.text('รวมคาเฟ่ลับย่านพระนคร'), findsOneWidget);
    // Same wire type, but a video cover makes it a clip, not a post.
    expect(find.text('คลิปเยาวราช'), findsNothing);
    expect(find.text('เที่ยวดานัง 4 วัน'), findsNothing);
  });

  testWidgets('tab 3 keeps only plan trips', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.plans);

    expect(find.text('เที่ยวดานัง 4 วัน'), findsOneWidget);
    expect(find.text('รวมคาเฟ่ลับย่านพระนคร'), findsNothing);
    expect(find.text('คลิปเยาวราช'), findsNothing);
  });

  testWidgets('tab 4 keeps only the clips', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.clips);

    expect(find.text('คลิปเยาวราช'), findsOneWidget);
    expect(find.text('รวมคาเฟ่ลับย่านพระนคร'), findsNothing);
    expect(find.text('เที่ยวดานัง 4 วัน'), findsNothing);
  });

  testWidgets('an empty shelf explains itself per tab', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness(mine: const <TripListItem>[]));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีอะไรของคุณที่นี่'), findsOneWidget);
  });

  testWidgets('a guest sees neither counts nor a wall', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness(session: null));
    await tester.pumpAndSettle();

    expect(find.text('ผู้เยี่ยมชม'), findsOneWidget);
    expect(find.text('ยังไม่ได้เข้าสู่ระบบ'), findsOneWidget);
    expect(find.byType(ProfileCountsRow), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.text('เข้าสู่ระบบเพื่อดูโพสต์และทริปของคุณ'), findsOneWidget);
  });

  testWidgets('the menu button opens จัดการบัญชี', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('account-stub'), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
  });

  testWidgets('a card opens the trip behind it', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('รวมคาเฟ่ลับย่านพระนคร'));
    await tester.pumpAndSettle();

    expect(find.text('detail-stub'), findsOneWidget);
  });

  testWidgets('the shared nav is present and labelled My Post',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(find.text('My Post'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
  });

  testWidgets('profile lays out on a narrow phone without overflow',
      (tester) async {
    _usePhone(tester, width: 320, height: 700);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomNav), findsOneWidget);
  });
}
