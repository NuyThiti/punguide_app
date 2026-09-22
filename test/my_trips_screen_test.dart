import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/my_trips/presentation/my_trips_screen.dart';
import 'package:pluno/features/my_trips/presentation/widgets/my_trip_card.dart';
import 'package:pluno/shared/widgets/app_bottom_nav.dart';

import 'support/fake_api.dart';
import 'support/home_feed_fixtures.dart';

/// The shelf as the server hands it over: a draft plan nobody can see yet, a
/// finished one, and a photo post.
final _rows = <Map<String, dynamic>>[
  feedTripJson(
    id: 'draft',
    title: 'เชียงราย 2 วัน 1 คืน',
    destination: 'เชียงราย',
    durationDays: 2,
    totalBudget: 1800,
    coverUrl: null,
  ),
  feedTripJson(
    id: 'done',
    title: 'ปาย ฤดูหนาว',
    destination: 'แม่ฮ่องสอน',
    status: 'completed',
    durationDays: 3,
    totalBudget: 4200,
  ),
  feedTripJson(
    id: 'post',
    title: 'คาเฟ่ริมน้ำ',
    destination: 'อัมพวา',
    type: 'content',
    placeCount: 4,
    durationDays: null,
    totalBudget: 0,
  ),
];

FakeAdapter _adapter({
  List<Map<String, dynamic>>? rows,
  Map<String, List<FakeReply>> extra = const <String, List<FakeReply>>{},
}) =>
    FakeAdapter(<String, List<FakeReply>>{
      'GET /trips/mine': <FakeReply>[FakeReply(200, rows ?? _rows)],
      ...extra,
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

void main() {
  testWidgets('my trips reads /trips/mine and shows how each one stands',
      (tester) async {
    _phone(tester);
    final adapter = _adapter();

    await tester.pumpWidget(_harness(adapter, session: AuthSession.demo));
    await tester.pumpAndSettle();

    expect(
      adapter.requests.map((r) => '${r.method} ${r.path}'),
      contains('GET /trips/mine'),
    );
    expect(find.byType(MyTripCard), findsNWidgets(3));
    expect(find.text('ทริปฉัน'), findsOneWidget);
    expect(find.text('3 ทริปที่คุณสร้างไว้'), findsOneWidget);
    // The one thing the feed card cannot say: this plan is not out yet.
    expect(find.text('แบบร่าง'), findsOneWidget);
    expect(find.text('เที่ยวจบแล้ว'), findsOneWidget);
    expect(find.text('โพสต์'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chip narrows the shelf without asking the server again',
      (tester) async {
    _phone(tester);
    final adapter = _adapter();

    await tester.pumpWidget(_harness(adapter, session: AuthSession.demo));
    await tester.pumpAndSettle();

    final before = adapter.requests.length;
    await tester.tap(find.text('แผนเที่ยว'));
    await tester.pumpAndSettle();

    expect(find.byType(MyTripCard), findsNWidgets(2));
    expect(find.text('คาเฟ่ริมน้ำ'), findsNothing);
    // `GET /trips/mine` takes no parameters, so a chip is a filter in memory.
    expect(adapter.requests.length, before);
  });

  testWidgets('signed out, the shelf asks for an account instead of fetching',
      (tester) async {
    _phone(tester);
    final adapter = _adapter();

    await tester.pumpWidget(_harness(adapter));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบเพื่อดูทริปของคุณ'), findsOneWidget);
    expect(find.byType(MyTripCard), findsNothing);
    expect(
      adapter.requests.map((r) => '${r.method} ${r.path}'),
      isNot(contains('GET /trips/mine')),
    );
  });

  testWidgets('deleting asks first, then drops the row', (tester) async {
    _phone(tester);
    final adapter = _adapter(
      extra: <String, List<FakeReply>>{
        'DELETE /trips/draft': <FakeReply>[const FakeReply(204, null)],
      },
    );

    await tester.pumpWidget(_harness(adapter, session: AuthSession.demo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบทริป').last);
    await tester.pumpAndSettle();

    // The dialog is the confirmation; nothing has gone up yet.
    expect(
      adapter.requests.map((r) => '${r.method} ${r.path}'),
      isNot(contains('DELETE /trips/draft')),
    );

    await tester.tap(find.widgetWithText(TextButton, 'ลบทริป'));
    await tester.pumpAndSettle();

    expect(
      adapter.requests.map((r) => '${r.method} ${r.path}'),
      contains('DELETE /trips/draft'),
    );
    expect(find.text('เชียงราย 2 วัน 1 คืน'), findsNothing);
    expect(find.byType(MyTripCard), findsNWidgets(2));
  });

  testWidgets('the list reserves room for the bottom nav', (tester) async {
    _phone(tester);

    await tester.pumpWidget(
      _harness(_adapter(), session: AuthSession.demo),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomNav), findsOneWidget);
    // Not `.first`: the chip row is a horizontal ListView of its own.
    final list = tester.widget<ListView>(
      find.ancestor(
        of: find.byType(MyTripCard).first,
        matching: find.byType(ListView),
      ),
    );
    final padding = list.padding! as EdgeInsets;
    expect(
      padding.bottom,
      greaterThanOrEqualTo(AppBottomNav.bumpHeight + AppBottomNav.barHeight),
    );
  });
}
