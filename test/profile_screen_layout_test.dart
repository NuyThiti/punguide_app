import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/home/presentation/widgets/pun_guide_card.dart';
import 'package:pluno/features/profile/data/mock_albums.dart';
import 'package:pluno/features/profile/domain/album.dart';
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
  feedTrip(id: 'mine-1', title: 'รวมคาเฟ่ลับย่านพระนคร'),
  feedTrip(id: 'mine-2', title: 'อั๋วจะไปเยาวราช'),
  // A clip: the live feed marks one with a video cover, not the type.
  feedTrip(
    id: 'clip-1',
    title: 'คลิปเยาวราช',
    destination: 'เยาวราช, กรุงเทพฯ',
    coverUrl: 'https://cdn.test/videos/clip-1.mov',
    coverMediaType: 'video',
  ),
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
  AuthSession? session = AuthSession.demo,
}) {
  return ProviderScope(
    overrides: profileOverrides(
      mine: mine ?? _mine,
      saved: saved ?? _saved,
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
    expect(find.text('Share'), findsOneWidget);

    for (final album in albumsFor(AlbumShelf.personal)) {
      expect(find.text(album.title), findsOneWidget);
    }
    // It is not a wall of trips.
    expect(find.byType(PunGuideCard), findsNothing);
  });

  testWidgets('Share swaps the shelf under the grid', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.albums);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    for (final album in albumsFor(AlbumShelf.shared)) {
      expect(find.text(album.title), findsOneWidget);
    }
    expect(
      find.text(albumsFor(AlbumShelf.personal).first.title),
      findsNothing,
    );
  });

  testWidgets('an album with nothing behind it reports instead of opening',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.albums);

    final first = albumsFor(AlbumShelf.personal).first;
    await tester.tap(find.text(first.title));
    await tester.pump();

    expect(find.text('อัลบั้ม "${first.title}" ยังไม่เปิดใช้งาน'), findsOneWidget);
  });

  testWidgets('the posts tab walls the traveller own trips, clips excluded',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byType(PunGuideCard), findsNWidgets(2));
    expect(find.text('รวมคาเฟ่ลับย่านพระนคร'), findsOneWidget);
    expect(find.text('อั๋วจะไปเยาวราช'), findsOneWidget);
    expect(find.text('คลิปเยาวราช'), findsNothing);
  });

  testWidgets('the bookmark tab reads GET /trips/saved, not the own shelf',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.saved);

    expect(find.text('ทริปที่บุ๊กมาร์กไว้'), findsOneWidget);
    expect(find.text('รวมคาเฟ่ลับย่านพระนคร'), findsNothing);
  });

  testWidgets('the remix tab says so rather than showing an empty wall',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.remixes);

    expect(find.text('รีมิกซ์ของฉันยังไม่เปิดใช้งาน'), findsOneWidget);
    expect(find.byType(PunGuideCard), findsNothing);
  });

  testWidgets('the Puntok tab keeps only the clips', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.clips);

    expect(find.text('คลิปเยาวราช'), findsOneWidget);
    expect(find.text('รวมคาเฟ่ลับย่านพระนคร'), findsNothing);
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

  testWidgets('tapping a clip opens it full screen, not the trip page',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.clips);

    await tester.tap(find.byType(PuntokCard));
    await tester.pumpAndSettle();

    expect(find.byType(PuntokViewerScreen), findsOneWidget);
    expect(find.text('detail-stub'), findsNothing);
  });

  testWidgets('the viewer opens on the clip that was tapped', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness(
      mine: <TripListItem>[
        feedTrip(
          id: 'clip-a',
          title: 'คลิปหนึ่ง',
          coverUrl: 'https://cdn.test/videos/a.mov',
          coverMediaType: 'video',
        ),
        feedTrip(
          id: 'clip-b',
          title: 'คลิปสอง',
          coverUrl: 'https://cdn.test/videos/b.mov',
          coverMediaType: 'video',
        ),
      ],
    ));
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.clips);

    await tester.tap(find.widgetWithText(PuntokCard, 'คลิปสอง'));
    await tester.pumpAndSettle();

    final viewer = tester.widget<PuntokViewerScreen>(
      find.byType(PuntokViewerScreen),
    );
    expect(viewer.args!.posts.map((post) => post.id), ['clip-a', 'clip-b']);
    expect(viewer.args!.initialIndex, 1);
  });

  testWidgets('a clip with no playable cover says so instead of stalling',
      (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness(
      // type puntok, but the cover carries no video file to play.
      mine: <TripListItem>[
        feedTrip(id: 'clip-dead', title: 'คลิปเสีย', type: 'puntok'),
      ],
    ));
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.clips);

    await tester.tap(find.byType(PuntokCard));
    await tester.pump();

    expect(find.text('คลิปนี้ยังเล่นไม่ได้'), findsOneWidget);
    expect(find.byType(PuntokViewerScreen), findsNothing);
  });

  testWidgets('an empty shelf explains itself per tab', (tester) async {
    _usePhone(tester);

    await tester.pumpWidget(_harness(mine: const <TripListItem>[]));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีโพสต์หรือทริปของคุณ'), findsOneWidget);
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
