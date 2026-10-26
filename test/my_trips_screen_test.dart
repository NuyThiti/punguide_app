import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/home/presentation/widgets/pun_guide_card.dart';
import 'package:pluno/features/my_trips/presentation/my_trips_screen.dart';
import 'package:pluno/features/profile/presentation/providers/profile_providers.dart';
import 'package:pluno/features/profile/presentation/widgets/profile_tab_bar.dart';
import 'package:pluno/features/puntok/presentation/widgets/puntok_card.dart';
import 'package:pluno/shared/widgets/app_bottom_nav.dart';

import 'support/fake_api.dart';
import 'support/home_feed_fixtures.dart';

/// The shelf as the server hands it over: two drafts, one of them a clip, and
/// a finished plan that Save Draft must leave out.
final _rows = <Map<String, dynamic>>[
  feedTripJson(
    id: 'draft-plan',
    title: 'เชียงราย 2 วัน 1 คืน',
    destination: 'เชียงราย',
    durationDays: 2,
    totalBudget: 1800,
  ),
  feedTripJson(
    id: 'draft-clip',
    title: 'อั๋วจะไปเยาวราช',
    destination: 'เยาวราช, กรุงเทพฯ',
    type: 'content',
    coverUrl: 'https://cdn.test/videos/draft-clip.mov',
    coverMediaType: 'video',
  ),
  feedTripJson(
    id: 'published',
    title: 'ปาย ฤดูหนาว',
    destination: 'แม่ฮ่องสอน',
    status: 'completed',
    durationDays: 3,
    totalBudget: 4200,
  ),
];

FakeAdapter _adapter({List<Map<String, dynamic>>? rows}) =>
    FakeAdapter(<String, List<FakeReply>>{
      'GET /trips/mine': <FakeReply>[FakeReply(200, rows ?? _rows)],
    });

Widget _harness(FakeAdapter adapter, {AuthSession? session}) {
  return ProviderScope(
    overrides: <Override>[
      plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
      authSessionProvider.overrideWith((ref) => AuthController(session)),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.myTrips.name,
            builder: (_, __) => const MyTripsScreen(),
          ),
          GoRoute(
            path: '/login',
            name: AppRoute.login.name,
            builder: (_, __) => const SizedBox.shrink(),
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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _tapTab(WidgetTester tester, ProfileTab tab) async {
  final tabs = find.descendant(
    of: find.byType(ProfileTabBar),
    matching: find.byType(InkWell),
  );
  await tester.tap(tabs.at(ProfileTab.values.indexOf(tab)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Save Draft reads /trips/mine and keeps only the drafts',
      (tester) async {
    _phone(tester);
    final adapter = _adapter();

    await tester.pumpWidget(_harness(adapter, session: AuthSession.demo));
    await tester.pumpAndSettle();

    expect(
      adapter.requests.map((r) => '${r.method} ${r.path}'),
      contains('GET /trips/mine'),
    );
    expect(find.text('Save Draft'), findsOneWidget);

    expect(find.text('เชียงราย 2 วัน 1 คืน'), findsOneWidget);
    // Published, so it is not a draft and has no business here.
    expect(find.text('ปาย ฤดูหนาว'), findsNothing);
  });

  testWidgets('every card on the wall wears the Editing tag', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_adapter(), session: AuthSession.demo));
    await tester.pumpAndSettle();

    // One draft plan on this tab, and it carries the tag.
    expect(find.byType(PunGuideCard), findsOneWidget);
    expect(find.text('Editing'), findsOneWidget);
  });

  testWidgets('the clips tab keeps the draft clip and drops the plan',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_adapter(), session: AuthSession.demo));
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.clips);

    expect(find.byType(PuntokCard), findsOneWidget);
    expect(find.text('อั๋วจะไปเยาวราช'), findsOneWidget);
    expect(find.text('เชียงราย 2 วัน 1 คืน'), findsNothing);
    // The tag rides on a clip card too.
    expect(find.text('Editing'), findsOneWidget);
  });

  testWidgets('a tab that cannot hold a draft says so', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_adapter(), session: AuthSession.demo));
    await tester.pumpAndSettle();
    await _tapTab(tester, ProfileTab.saved);

    expect(
      find.text('ที่บันทึกไว้เป็นทริปของคนอื่น ไม่มีแบบร่าง'),
      findsOneWidget,
    );
    expect(find.byType(PunGuideCard), findsNothing);
  });

  testWidgets('opening a draft goes to its trip page', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_adapter(), session: AuthSession.demo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('เชียงราย 2 วัน 1 คืน'));
    await tester.pumpAndSettle();

    expect(find.text('detail-stub'), findsOneWidget);
  });

  testWidgets('an empty shelf says so rather than showing a blank wall',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(
      _adapter(rows: const <Map<String, dynamic>>[]),
      session: AuthSession.demo,
    ));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีแบบร่างที่ค้างไว้'), findsOneWidget);
  });

  testWidgets('signed out, the shelf asks for an account instead of fetching',
      (tester) async {
    _phone(tester);
    final adapter = _adapter();

    await tester.pumpWidget(_harness(adapter));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบเพื่อดูแบบร่างของคุณ'), findsOneWidget);
    expect(
      adapter.requests.map((r) => '${r.method} ${r.path}'),
      isNot(contains('GET /trips/mine')),
    );
  });

  testWidgets('the wall reserves room for the bottom nav', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(_adapter(), session: AuthSession.demo));
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomNav), findsOneWidget);
    final list = tester.widget<ListView>(find.byType(ListView).last);
    final padding = list.padding! as EdgeInsets;
    expect(
      padding.bottom,
      greaterThanOrEqualTo(AppBottomNav.bumpHeight + AppBottomNav.barHeight),
    );
  });
}
