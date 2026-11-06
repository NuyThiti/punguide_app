import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/paigun/domain/trip_filter.dart';
import 'package:pluno/features/paigun/presentation/providers/paigun_providers.dart';
import 'package:pluno/features/trip_style/data/trip_style_store.dart';
import 'package:pluno/features/trip_style/domain/trip_style_preference.dart';
import 'package:pluno/features/trip_style/presentation/providers/trip_style_providers.dart';
import 'package:pluno/features/trip_style/presentation/trip_style_screen.dart';

ProviderContainer _container({
  TripStylePreference? answered,
  TripStyleStore? store,
}) {
  final container = ProviderContainer(
    overrides: [
      storedTripStyleProvider.overrideWithValue(answered),
      tripStyleStoreProvider
          .overrideWithValue(store ?? InMemoryTripStyleStore(answered)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _harness(ProviderContainer container, {String? then}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation:
            then == null ? '/trip-style' : '/trip-style?then=$then',
        routes: [
          GoRoute(
            path: '/trip-style',
            name: AppRoute.tripStyle.name,
            builder: (_, state) =>
                TripStyleScreen(then: state.queryParams['then']),
          ),
          GoRoute(
            path: '/',
            name: AppRoute.home.name,
            builder: (_, __) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/paigun',
            name: AppRoute.paigun.name,
            builder: (_, __) => const Scaffold(body: Text('paigun board')),
          ),
        ],
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget harness) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(harness);
  await tester.pumpAndSettle();
}

/// The lower chips sit under the foot bar until the list is scrolled, and the
/// bar grows the moment the first one is picked — so every tap gets the chip
/// into view first and its own frame afterwards.
Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('both sections of the design are on the page', (tester) async {
    await _pump(tester, _harness(_container()));

    expect(find.text('สไตล์เที่ยวของฉัน'), findsOneWidget);
    expect(find.text('เงื่อนไข / ข้อจำกัด'), findsOneWidget);
    for (final label in TripStyleScreen.styleOrder) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    for (final label in TripStyleScreen.constraintOrder) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // One "+ เพิ่ม" per section.
    expect(find.text('+ เพิ่ม'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the foot only counts once something is chosen', (tester) async {
    await _pump(tester, _harness(_container()));

    expect(find.text('ถัดไป'), findsOneWidget);
    expect(find.text('ล้างที่เลือก'), findsNothing);

    for (final label in ['ธรรมชาติ', 'คาเฟ่', 'มีเด็กเล็ก']) {
      await _tapChip(tester, label);
    }

    // Across both sections, as the design counts them.
    expect(find.text('3 รายการ'), findsOneWidget);
    expect(find.text('ตกลง'), findsOneWidget);
    expect(find.text('ถัดไป'), findsNothing);

    await tester.ensureVisible(find.text('ล้างที่เลือก'));
    await tester.tap(find.text('ล้างที่เลือก'));
    await tester.pumpAndSettle();

    expect(find.text('ถัดไป'), findsOneWidget);
    expect(find.text('3 รายการ'), findsNothing);
  });

  testWidgets('confirming saves the answer and narrows the board',
      (tester) async {
    final store = InMemoryTripStyleStore();
    final container = _container(store: store);
    await _pump(tester, _harness(container, then: '/'));

    for (final label in ['ทะเล', 'ผู้ใช้รถเข็น']) {
      await _tapChip(tester, label);
    }
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();

    // Kept, so the launch sequence does not ask again.
    final saved = await store.read();
    expect(saved!.styles, ['ทะเล']);
    expect(saved.constraints, ['ผู้ใช้รถเข็น']);

    // And in force on the board this run, without waiting for a restart.
    final filter = container.read(tripFilterProvider);
    expect(filter.styles, ['ทะเล']);
    expect(filter.constraints, ['ผู้ใช้รถเข็น']);

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('ข้ามไปก่อน is an answer too, so the page stops coming back',
      (tester) async {
    final store = InMemoryTripStyleStore();
    final container = _container(store: store);
    await _pump(tester, _harness(container, then: '/'));

    await tester.tap(find.text('ข้ามไปก่อน'));
    await tester.pumpAndSettle();

    // Empty, but stored — null would mean "never asked" and the launch
    // sequence would put the page up again on the next run.
    expect(await store.read(), isNotNull);
    expect((await store.read())!.isEmpty, isTrue);
    expect(container.read(needsTripStyleProvider), isFalse);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('reopening shows the chips already in force', (tester) async {
    final container = _container(
      answered: const TripStylePreference(
        styles: ['ภูเขา'],
        constraints: ['อิสลาม'],
      ),
    );
    await _pump(tester, _harness(container));

    expect(find.text('2 รายการ'), findsOneWidget);
  });

  testWidgets('+ เพิ่ม keeps a chip the traveller names themselves',
      (tester) async {
    final store = InMemoryTripStyleStore();
    final container = _container(store: store);
    await _pump(tester, _harness(container, then: '/'));

    await tester.tap(find.text('+ เพิ่ม').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ดำน้ำ');
    await tester.tap(find.text('เพิ่ม'));
    await tester.pumpAndSettle();

    // Added and chosen in one go — nobody types a chip they did not want.
    expect(find.text('ดำน้ำ'), findsOneWidget);
    expect(find.text('1 รายการ'), findsOneWidget);

    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();

    expect((await store.read())!.styles, ['ดำน้ำ']);
    // No enum behind it, so it rides up as free text rather than being lost.
    final query = container.read(tripFilterProvider).toFeedQuery(
          sort: FeedSort.recent,
        );
    expect(query.customStyles, ['ดำน้ำ']);
    expect(query.styles, isEmpty);
  });
}
