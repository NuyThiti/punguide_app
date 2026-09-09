import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/create_trip/domain/destination_lookup.dart';
import 'package:pluno/features/create_trip/presentation/create_trip_screen.dart';
import 'package:pluno/features/create_trip/presentation/providers/destination_search_providers.dart';

import 'support/home_feed_fixtures.dart';

/// Records what the picker asked for, so the debounce and the session token
/// can be asserted on.
class _FakeLookup implements DestinationLookup {
  _FakeLookup({this.results = const [], this.failure});

  List<PlaceSuggestion> results;
  Object? failure;
  final calls = <({String query, String sessionToken})>[];

  @override
  Future<List<PlaceSuggestion>> search(
    String query, {
    required String sessionToken,
  }) async {
    calls.add((query: query, sessionToken: sessionToken));
    if (failure != null) throw failure!;
    return results;
  }
}

PlaceSuggestion _suggestion(String main, String secondary) {
  return PlaceSuggestion.fromJson(<String, dynamic>{
    'description': '$main, $secondary',
    'mainText': main,
    'secondaryText': secondary,
    'externalRef': 'ref-$main',
  });
}

Widget _harness(_FakeLookup lookup, List<TripListItem> trips) {
  return ProviderScope(
    overrides: [
      ...homeOverrides(trips),
      destinationLookupProvider.overrideWithValue(lookup),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.createTrip.name,
            builder: (_, __) => const CreateTripScreen(),
          ),
        ],
      ),
    ),
  );
}

/// Opens the picker by tapping the read-only Destination field.
Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextFormField, 'Destination').first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetPhysicalSize();
  });

  testWidgets('tapping Destination opens the search page', (tester) async {
    await tester.pumpWidget(_harness(_FakeLookup(), [feedTrip()]));
    await tester.pumpAndSettle();

    expect(find.text('ค้นหาชื่อที่ ย่าน หรือประเทศ'), findsNothing);
    await _openPicker(tester);
    expect(find.text('ค้นหาชื่อที่ ย่าน หรือประเทศ'), findsOneWidget);
  });

  testWidgets('before typing it offers destinations drawn from the feed',
      (tester) async {
    await tester.pumpWidget(_harness(_FakeLookup(), [
      feedTrip(id: 'a', destination: 'หลวงพระบาง, ลาว'),
      feedTrip(id: 'b', destination: 'เชียงใหม่, ไทย'),
      feedTrip(id: 'c', destination: 'เชียงใหม่, ไทย'),
    ]));
    await tester.pumpAndSettle();
    await _openPicker(tester);

    expect(find.text('Search Trend มาแรง'), findsOneWidget);
    final tiles = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Text),
        ))
        .map((t) => t.data)
        .toList();
    // Most-planned first: ไทย has two trips, ลาว one.
    expect(tiles.indexOf('ไทย'), lessThan(tiles.indexOf('ลาว')));
    // The country headlines the row, the city sits beneath it.
    expect(tiles.indexOf('ไทย') + 1, equals(tiles.indexOf('เชียงใหม่')));
  });

  testWidgets('a burst of keystrokes costs one request, on one session',
      (tester) async {
    final lookup = _FakeLookup(results: [_suggestion('ปูซาน', 'เกาหลีใต้')]);
    await tester.pumpWidget(_harness(lookup, [feedTrip()]));
    await tester.pumpAndSettle();
    await _openPicker(tester);

    for (final text in ['ปู', 'ปูซ', 'ปูซา', 'ปูซาน']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pumpAndSettle();

    expect(lookup.calls.map((c) => c.query), ['ปูซาน']);
    expect(find.text('ปูซาน'), findsWidgets);
    expect(find.text('เกาหลีใต้'), findsOneWidget);

    // A second search in the same picker rides the same billing session.
    await tester.enterText(find.byType(TextField), 'โซล');
    await tester.pumpAndSettle();
    expect(lookup.calls, hasLength(2));
    expect(lookup.calls.last.sessionToken, lookup.calls.first.sessionToken);

    // Closing the picker ends it, so the next one is billed separately.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await _openPicker(tester);
    await tester.enterText(find.byType(TextField), 'โซล');
    await tester.pumpAndSettle();

    expect(lookup.calls, hasLength(3));
    expect(
      lookup.calls.last.sessionToken,
      isNot(lookup.calls.first.sessionToken),
    );
  });

  testWidgets('one character is not worth a request', (tester) async {
    final lookup = _FakeLookup();
    await tester.pumpWidget(_harness(lookup, [feedTrip()]));
    await tester.pumpAndSettle();
    await _openPicker(tester);

    await tester.enterText(find.byType(TextField), 'ป');
    await tester.pumpAndSettle();

    expect(lookup.calls, isEmpty);
  });

  testWidgets('picking a result fills the Destination field and is remembered',
      (tester) async {
    final lookup = _FakeLookup(results: [_suggestion('ปูซาน', 'เกาหลีใต้')]);
    await tester.pumpWidget(_harness(lookup, [feedTrip()]));
    await tester.pumpAndSettle();
    await _openPicker(tester);

    await tester.enterText(find.byType(TextField), 'ปูซาน');
    await tester.pumpAndSettle();
    await tester.tap(find.text('เกาหลีใต้'));
    await tester.pumpAndSettle();

    // Back on the form, with the destination filled in.
    expect(find.text('ปูซาน, เกาหลีใต้'), findsOneWidget);

    await _openPicker(tester);
    expect(find.text('ค้นล่าสุด'), findsOneWidget);
    expect(find.text('ปูซาน, เกาหลีใต้'), findsOneWidget);

    await tester.tap(find.text('ล้าง'));
    await tester.pumpAndSettle();
    expect(find.text('ค้นล่าสุด'), findsNothing);
  });

  testWidgets('a lookup failure offers a retry rather than an empty list',
      (tester) async {
    final lookup = _FakeLookup(failure: Exception('offline'));
    await tester.pumpWidget(_harness(lookup, [feedTrip()]));
    await tester.pumpAndSettle();
    await _openPicker(tester);

    await tester.enterText(find.byType(TextField), 'ปูซาน');
    await tester.pumpAndSettle();

    expect(find.text('ค้นหาจุดหมายไม่สำเร็จ'), findsOneWidget);

    lookup.failure = null;
    lookup.results = [_suggestion('ปูซาน', 'เกาหลีใต้')];
    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();

    expect(find.text('เกาหลีใต้'), findsOneWidget);
  });

  testWidgets('the header survives a notch', (tester) async {
    // The default test view has no safe-area inset, which is why a fixed
    // header height that ignored one rendered fine here while collapsing the
    // search pill to nothing on a real iPhone.
    tester.view.padding = const FakeViewPadding(top: 59 * 3);
    addTearDown(() => tester.view.resetPadding());

    await tester.pumpWidget(_harness(_FakeLookup(), [feedTrip()]));
    await tester.pumpAndSettle();
    await _openPicker(tester);

    expect(tester.takeException(), isNull);
    // The pill keeps its full height, below the inset rather than under it.
    final pill = tester.getRect(find.byType(TextField));
    expect(pill.height, greaterThan(20));
    expect(pill.top, greaterThan(59));
  });

  testWidgets('a destination the API does not know is still usable',
      (tester) async {
    final lookup = _FakeLookup();
    await tester.pumpWidget(_harness(lookup, [feedTrip()]));
    await tester.pumpAndSettle();
    await _openPicker(tester);

    await tester.enterText(find.byType(TextField), 'บ้านยาย');
    await tester.pumpAndSettle();

    expect(find.text('ไม่พบจุดหมายที่ค้นหา'), findsOneWidget);
    await tester.tap(find.text('ใช้ "บ้านยาย"'));
    await tester.pumpAndSettle();

    expect(find.text('บ้านยาย'), findsOneWidget);
  });
}
