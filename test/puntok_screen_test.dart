import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/puntok/data/puntok_mock_posts.dart';
import 'package:pluno/features/puntok/domain/models/puntok_post.dart';
import 'package:pluno/features/puntok/presentation/puntok_screen.dart';
import 'package:pluno/features/puntok/presentation/providers/puntok_providers.dart';
import 'package:pluno/features/puntok/presentation/widgets/puntok_action_rail.dart';

/// `video_player` has no plugin under `flutter test`, so every `initialize()`
/// fails and each page falls back to its poster. That is the path these tests
/// exercise — the chrome and the toggles, not playback.
Widget _harness() {
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/puntok',
        routes: [
          GoRoute(
            path: '/puntok',
            name: AppRoute.puntok.name,
            builder: (_, __) => const PuntokScreen(),
          ),
          GoRoute(
            path: '/search',
            name: AppRoute.search.name,
            builder: (_, __) => const Scaffold(body: Text('search')),
          ),
        ],
      ),
    ),
  );
}

Future<void> _pumpPuntok(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_harness());
  await tester.pump();
}

void main() {
  testWidgets('the header carries the title, the discs and the three tabs',
      (tester) async {
    await _pumpPuntok(tester);

    expect(find.text('Puntok'), findsWidgets);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('Top Punguide'), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('the first page matches the design card', (tester) async {
    await _pumpPuntok(tester);

    expect(find.text('TravelWithTawn'), findsOneWidget);
    expect(find.text('เที่ยวหลวงพระบาง 3 วัน ชิลล์ๆ'), findsOneWidget);
    expect(find.text('ติดตาม'), findsOneWidget);
    expect(find.text('5,597'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('39'), findsOneWidget);
    expect(find.text('126'), findsOneWidget);
  });

  testWidgets('the poster stands in while no clip is decoded', (tester) async {
    await _pumpPuntok(tester);

    final posters = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName);
    expect(posters, contains('assets/images/puntok_osaka.jpg'));
  });

  testWidgets('liking bumps the count and fills the heart', (tester) async {
    await _pumpPuntok(tester);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();

    expect(find.text('5,598'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('saving bumps the count and fills the bookmark', (tester) async {
    await _pumpPuntok(tester);

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();

    expect(find.text('40'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets('following swaps the chip and the avatar badge', (tester) async {
    await _pumpPuntok(tester);

    await tester.tap(find.text('ติดตาม'));
    await tester.pump();

    expect(find.text('กำลังติดตาม'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('the nav bar shows Puntok as the tab in force', (tester) async {
    await _pumpPuntok(tester);

    // Two "Puntok" labels: the header title and the nav item.
    expect(find.text('Puntok'), findsNWidgets(2));
  });

  testWidgets('swiping up advances to the next clip', (tester) async {
    await _pumpPuntok(tester);

    await tester.fling(
        find.text('TravelWithTawn'), const Offset(0, -600), 1200);
    await tester.pumpAndSettle();

    expect(find.text('NamPloyWalks'), findsOneWidget);
    expect(find.text('TravelWithTawn'), findsNothing);
  });

  testWidgets('Top Punguide orders by likes', (tester) async {
    await _pumpPuntok(tester);

    await tester.tap(find.text('Top Punguide'));
    await tester.pumpAndSettle();

    expect(find.text('SeoulSoGood'), findsOneWidget);
  });

  testWidgets('Following keeps only followed creators', (tester) async {
    await _pumpPuntok(tester);

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();

    expect(find.text('NamPloyWalks'), findsOneWidget);
    expect(find.text('TravelWithTawn'), findsNothing);
  });

  testWidgets('the Following tab reads empty once nobody is followed',
      (tester) async {
    await _pumpPuntok(tester);

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('กำลังติดตาม'));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีคลิปจากคนที่คุณติดตาม'), findsOneWidget);
  });

  test('counts carry thousands separators', () {
    expect(formatPuntokCount(5), '5');
    expect(formatPuntokCount(126), '126');
    expect(formatPuntokCount(5597), '5,597');
    expect(formatPuntokCount(48219), '48,219');
    expect(formatPuntokCount(1234567), '1,234,567');
  });

  test('every mock post points at a bundled clip and poster', () {
    for (final PuntokPost post in puntokMockPosts) {
      expect(post.video, startsWith('assets/videos/'));
      expect(post.video, endsWith('.mp4'));
      expect(post.poster, startsWith('assets/images/'));
      expect(post.authorAvatar, startsWith('assets/images/'));
    }
  });

  test('a tab switch keeps this session\'s likes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final id = container.read(puntokFeedProvider).first.id;
    container.read(puntokFeedProvider.notifier).toggleLike(id);
    container.read(puntokFeedTabProvider.notifier).state =
        PuntokFeed.topPunGuide;

    final liked =
        container.read(puntokFeedProvider).firstWhere((post) => post.id == id);
    expect(liked.liked, isTrue);
    expect(liked.likes, 5598);
  });
}
