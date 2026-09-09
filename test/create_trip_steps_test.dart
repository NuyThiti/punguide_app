import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/features/create_trip/domain/destination_lookup.dart';
import 'package:pluno/features/create_trip/presentation/create_trip_screen.dart';
import 'package:pluno/features/create_trip/presentation/providers/destination_search_providers.dart';
import 'package:pluno/features/trips/domain/models/trip.dart';
import 'package:pluno/features/trips/presentation/providers/trip_providers.dart';

import 'support/home_feed_fixtures.dart';

/// Captures what step two adds up to, without a repository behind it.
class _CapturingActions extends TripActions {
  _CapturingActions(super.ref);

  double? budget;

  @override
  Future<Trip> createTrip({
    required String title,
    required String destination,
    required String coverImage,
    required double budget,
    required int duration,
    required String description,
  }) async {
    this.budget = budget;
    final now = DateTime.now();
    return Trip(
      id: 'stub',
      title: title,
      destination: destination,
      coverImage: coverImage,
      budget: budget,
      duration: duration,
      description: description,
      createdAt: now,
      updatedAt: now,
      isSaved: true,
    );
  }

  @override
  Future<void> saveTrip(Trip trip) async {}
}

/// The picker's type-ahead is not what these tests are about.
class _NoLookup implements DestinationLookup {
  const _NoLookup();

  @override
  Future<List<PlaceSuggestion>> search(
    String query, {
    required String sessionToken,
  }) async =>
      const [];
}

_CapturingActions? lastActions;

Widget _harness() {
  return ProviderScope(
    overrides: [
      ...homeOverrides(const []),
      destinationLookupProvider.overrideWithValue(const _NoLookup()),
      tripActionsProvider.overrideWith((ref) {
        return lastActions = _CapturingActions(ref);
      }),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.createTrip.name,
            builder: (_, __) => const CreateTripScreen(),
          ),
          GoRoute(
            path: '/home',
            name: AppRoute.home.name,
            builder: (_, __) => const Scaffold(body: Text('home')),
          ),
        ],
      ),
    ),
  );
}

/// The Destination field is read-only, so it is filled the only way the UI
/// allows: through the picker, accepting what was typed.
Future<void> _setDestination(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextFormField, 'Destination').first);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'ดานัง, เวียดนาม');
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.chevron_right));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 1400 * 3);
    view.devicePixelRatio = 3;
    lastActions = null;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetPhysicalSize();
  });

  testWidgets('opens on step one', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('1 จาก 2'), findsOneWidget);
    expect(find.text('สไตล์การเที่ยว'), findsOneWidget);
    expect(find.text('ข้ามไปก่อน'), findsOneWidget);
    expect(find.text('ถัดไป'), findsOneWidget);
    expect(find.text('งบต่อคน / วัน'), findsNothing);
  });

  testWidgets('ถัดไป is inert until a destination is chosen', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();
    expect(find.text('1 จาก 2'), findsOneWidget);

    await _setDestination(tester);
    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();
    expect(find.text('2 จาก 2'), findsOneWidget);
  });

  testWidgets('ถัดไป opens step two, ย้อนกลับ comes back', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _setDestination(tester);

    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();

    expect(find.text('2 จาก 2'), findsOneWidget);
    expect(find.text('งบต่อคน / วัน'), findsOneWidget);
    expect(find.text('ที่พัก / โรงแรม'), findsOneWidget);
    expect(find.text('เงื่อนไข / ข้อจำกัด'), findsOneWidget);
    expect(find.text('สร้างแผน'), findsOneWidget);
    expect(find.text('ย้อนกลับ'), findsOneWidget);
    // Step one is gone, not merely scrolled past.
    expect(find.text('สไตล์การเที่ยว'), findsNothing);

    await tester.tap(find.text('ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('1 จาก 2'), findsOneWidget);
    expect(find.text('สไตล์การเที่ยว'), findsOneWidget);
    // What was chosen survives the round trip.
    expect(find.text('ดานัง, เวียดนาม'), findsOneWidget);
  });

  testWidgets('the header reads choices back in the reference formats',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('ผู้ใหญ่, 1 คน'), findsOneWidget);
    expect(find.text('1 Guest'), findsNothing);
  });

  testWidgets('the action bar and the guest sheet reach the bottom edge',
      (tester) async {
    const inset = 34.0;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.padding = const FakeViewPadding(bottom: inset * 3);
    tester.view.viewPadding = const FakeViewPadding(bottom: inset * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final screenBottom = tester.getRect(find.byType(MaterialApp).first).bottom;

    // The bar's own background box, not the button inside it: a SafeArea
    // wrapped around the bar leaves the button in the same place and only the
    // painted panel short, so asserting on the label would prove nothing.
    final bar = find
        .ancestor(of: find.text('ถัดไป'), matching: find.byType(Container))
        .last;
    expect(tester.getRect(bar).bottom, screenBottom);
    // …while the label still clears the home indicator.
    expect(tester.getRect(find.text('ถัดไป')).bottom,
        lessThan(screenBottom - inset));

    await tester.tap(find.text('ผู้ใหญ่, 1 คน'));
    await tester.pumpAndSettle();

    final sheet = find
        .ancestor(of: find.text('ยืนยัน'), matching: find.byType(Container))
        .last;
    expect(tester.getRect(sheet).bottom, screenBottom);
    expect(tester.getRect(find.text('ยืนยัน')).bottom,
        lessThan(screenBottom - inset));
  });

  group('the date sheet', () {
    const thaiMonths = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens on this month, dated in the Buddhist era',
        (tester) async {
      await open(tester);
      final now = DateTime.now();

      expect(
        find.text('${thaiMonths[now.month - 1]} ${now.year + 543}'),
        findsOneWidget,
      );
      for (final day in ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส']) {
        expect(find.text(day), findsWidgets);
      }
    });

    testWidgets('ยืนยัน does nothing until a day is picked', (tester) async {
      await open(tester);

      await tester.tap(find.text('ยืนยัน'));
      await tester.pumpAndSettle();
      // Still open, and the field still empty.
      expect(find.text('ยกเลิก'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
    });

    testWidgets('a picked range lands in the header', (tester) async {
      await open(tester);
      // Next month, so the days are always in the future whenever this runs.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('13'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ยืนยัน'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final next = DateTime(now.year, now.month + 1);
      final mm = next.month.toString().padLeft(2, '0');
      expect(find.text('10/$mm/${next.year} - 13/$mm/${next.year}'),
          findsOneWidget);
    });

    testWidgets('จำนวนคืน records a length with no dates', (tester) async {
      await open(tester);
      await tester.tap(find.text('จำนวนคืน'));
      await tester.pumpAndSettle();

      expect(find.text('1 คืน'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('3 คืน'), findsOneWidget);

      await tester.tap(find.text('ยืนยัน'));
      await tester.pumpAndSettle();

      expect(find.text('3 คืน'), findsOneWidget);
      expect(find.text('Date'), findsNothing);
    });
  });

  testWidgets('a bracket sets the budget, and ระบุเอง overrides it',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _setDestination(tester);
    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comfort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('สร้างแผน'));
    await tester.pumpAndSettle();
    // ฿3,000 per person per day, one traveller, the default seven days.
    expect(lastActions?.budget, 3000 * 7);

    // An exact figure beats the bracket.
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await _setDestination(tester);
    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comfort'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '฿'), '500');
    await tester.pumpAndSettle();
    await tester.tap(find.text('สร้างแผน'));
    await tester.pumpAndSettle();
    expect(lastActions?.budget, 500 * 7);
  });
}
