import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/features/create_trip/domain/destination_lookup.dart';
import 'package:pluno/features/create_trip/presentation/create_trip_screen.dart';
import 'package:pluno/features/create_trip/presentation/providers/destination_search_providers.dart';
import 'package:pluno/features/trips/domain/models/trip.dart';
import 'package:pluno/features/trips/presentation/providers/trip_providers.dart';

import 'package:pluno/core/api/api_providers.dart';

import 'support/fake_api.dart';
import 'support/home_feed_fixtures.dart';

/// Keeps the local store out of it — the create path posts to the API, and
/// the edit path is not what these tests exercise.
class _NoRepoActions extends TripActions {
  _NoRepoActions(super.ref);

  @override
  Future<void> saveTrip(Trip trip) async {}
}

/// Answers the type-ahead with whatever [suggestions] holds.
class _StubLookup implements DestinationLookup {
  const _StubLookup();

  @override
  Future<List<PlaceSuggestion>> search(
    String query, {
    required String sessionToken,
  }) async =>
      suggestions;
}

List<PlaceSuggestion> suggestions = const [];

late FakeAdapter adapter;

Widget _harness() {
  return ProviderScope(
    overrides: [
      ...homeOverrides(const []),
      destinationLookupProvider.overrideWithValue(const _StubLookup()),
      plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
      tripActionsProvider.overrideWith(_NoRepoActions.new),
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
          GoRoute(
            path: '/trips/:tripId/edit',
            name: AppRoute.editTrip.name,
            builder: (_, state) =>
                Scaffold(body: Text('edit ${state.params['tripId']}')),
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
    suggestions = const [];
    adapter = FakeAdapter(<String, List<FakeReply>>{
      'POST /trips': [FakeReply(201, createdTripJson())],
    });
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

  testWidgets('date and guest read as placeholders until they hold an answer',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    Color inkOf(String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;

    // Nothing chosen yet: both read grey, like the hint they are.
    const placeholder = Color(0xFF8C8C8C);
    const ink = Color(0xFF1E1E1E);
    expect(inkOf('Date'), placeholder);
    expect(inkOf('ผู้ใหญ่, 1 คน'), placeholder);

    // A party the traveller actually picked reads in the page's own ink.
    await tester.tap(find.text('ผู้ใหญ่, 1 คน'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยืนยัน'));
    await tester.pumpAndSettle();

    expect(inkOf('ผู้ใหญ่, 2 คน'), ink);
    // The date is still untouched, so it has not changed with it.
    expect(inkOf('Date'), placeholder);
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

  group('the AI half and the design icons', () {
    /// The three header fields and, once AI is chosen, the sparkle.
    Iterable<String> svgPaths(WidgetTester tester) => tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .map((picture) => picture.bytesLoader)
        .whereType<SvgAssetLoader>()
        .map((loader) => loader.assetName);

    testWidgets('the header fields use the design\'s own icons',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(
        svgPaths(tester),
        containsAll(<String>[
          'assets/icons/field_location.svg',
          'assets/icons/field_calendar.svg',
          'assets/icons/field_guests.svg',
        ]),
      );
    });

    testWidgets('the sparkle rides the AI half, and only while it is chosen',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // สร้างด้วยตัวเอง is the opening choice, so no sparkle yet.
      expect(svgPaths(tester), isNot(contains('assets/icons/ai_sparkle.svg')));

      await tester.tap(find.text('AI จัดแผนให้'));
      await tester.pumpAndSettle();
      expect(svgPaths(tester), contains('assets/icons/ai_sparkle.svg'));

      await tester.tap(find.text('สร้างด้วยตัวเอง'));
      await tester.pumpAndSettle();
      expect(svgPaths(tester), isNot(contains('assets/icons/ai_sparkle.svg')));
    });

    testWidgets('the chosen AI pill is actually filled', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI จัดแผนให้'));
      await tester.pumpAndSettle();

      final filled = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.gradient != null);
      expect(filled, isNotEmpty, reason: 'the AI half should carry a gradient');

      // A BoxDecoration's colour modulates its gradient's alpha, so pairing a
      // gradient with Colors.transparent paints nothing at all — which is
      // invisible to a tree-only assertion and cost a device round trip once.
      for (final decoration in filled) {
        expect(
          decoration.color,
          isNull,
          reason: 'a gradient must not be paired with a colour',
        );
      }
    });

    testWidgets('step two carries the explore banner', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      await _setDestination(tester);

      expect(find.text('ยังไม่รู้จะไปไหน? สำรวจสถานที่แนะนำ'), findsNothing);
      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();

      expect(find.text('ยังไม่รู้จะไปไหน? สำรวจสถานที่แนะนำ'), findsOneWidget);
      expect(svgPaths(tester), contains('assets/icons/explore_compass.svg'));

      // There is no trip yet, so the explorer cannot open on anything.
      await tester.tap(find.text('สำรวจ'));
      await tester.pumpAndSettle();
      expect(
        find.text('สร้างแผนก่อน แล้วจึงสำรวจสถานที่แนะนำได้'),
        findsOneWidget,
      );
    });
  });

  group('POST /trips', () {
    Future<void> fillAndSubmit(
      WidgetTester tester, {
      List<String> styles = const [],
      String? pace,
      String? bracket,
      String? custom,
      List<String> constraints = const [],
    }) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      await _setDestination(tester);

      for (final style in styles) {
        await tester.tap(find.text(style));
        await tester.pumpAndSettle();
      }
      if (pace != null) {
        await tester.tap(find.text(pace));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();

      if (bracket != null) {
        await tester.tap(find.text(bracket));
        await tester.pumpAndSettle();
      }
      if (custom != null) {
        await tester.enterText(find.widgetWithText(TextField, '฿'), custom);
        await tester.pumpAndSettle();
      }
      for (final constraint in constraints) {
        await tester.tap(find.text(constraint));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('สร้างแผน'));
      await tester.pumpAndSettle();
    }

    testWidgets('sends the wizard as a manual draft', (tester) async {
      await fillAndSubmit(
        tester,
        styles: ['วัฒนธรรม', 'อาหาร'],
        pace: 'Chill',
        bracket: 'Comfort',
      );

      final body = adapter.bodyOf('POST /trips');
      expect(body, isNotNull);
      expect(body!['planMode'], 'manual');
      expect(body['destination'], 'ดานัง, เวียดนาม');
      expect(body['guestCount'], 1);
      expect(body['travelStyles'], ['culture', 'food']);
      expect(body['pace'], 'chill');
      expect(body['budgetTier'], 'comfort');
      // ฿3,000 a head a day — the middle of the bracket — over seven days.
      expect(body['budgetLimit'], 3000 * 7);
    });

    testWidgets('creating opens the editor on the new trip', (tester) async {
      await fillAndSubmit(tester, bracket: 'Comfort');

      // A fresh plan is empty, so the traveller belongs in the editor filling
      // it in — not back on Home wondering where the plan went.
      expect(find.text('edit trip-new'), findsOneWidget);
      expect(find.text('home'), findsNothing);
    });

    testWidgets('never sends status: the backend rejects the field',
        (tester) async {
      await fillAndSubmit(tester, bracket: 'Comfort');
      expect(adapter.bodyOf('POST /trips')!.containsKey('status'), isFalse);
    });

    testWidgets('constraints with no enum ride in specialNotes, not the array',
        (tester) async {
      await fillAndSubmit(
        tester,
        constraints: ['เดินเยอะไม่ได้', 'อิสลาม', 'มังสวิรัติ'],
      );

      final body = adapter.bodyOf('POST /trips')!;
      // Sending the dietary ones as constraints would be a 400.
      expect(body['constraints'], ['limited_walking']);
      expect(body['specialNotes'], 'อิสลาม, มังสวิรัติ');
    });

    testWidgets('an amount typed with no bracket still lands in one',
        (tester) async {
      await fillAndSubmit(tester, custom: '7000');

      final body = adapter.bodyOf('POST /trips')!;
      expect(body['budgetTier'], 'premium');
      expect(body['budgetLimit'], 7000 * 7);
    });

    testWidgets('a picked suggestion sends destinationPlace, without lat/lng',
        (tester) async {
      suggestions = [
        PlaceSuggestion.fromJson(<String, dynamic>{
          'description': 'ดานัง, เวียดนาม',
          'mainText': 'ดานัง',
          'secondaryText': 'เวียดนาม',
          'externalRef': 'ChIJ-place-ref',
        }),
      ];

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextFormField, 'Destination').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ดานัง');
      await tester.pumpAndSettle();
      await tester.tap(find.text('เวียดนาม'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('สร้างแผน'));
      await tester.pumpAndSettle();

      final place = adapter.bodyOf('POST /trips')!['destinationPlace']
          as Map<String, dynamic>;
      expect(place['placeId'], 'ChIJ-place-ref');
      expect(place['name'], 'ดานัง');
      expect(place['country'], 'เวียดนาม');
      // The backend resolves coordinates from the placeId itself.
      expect(place.containsKey('latitude'), isFalse);
      expect(place.containsKey('longitude'), isFalse);
    });

    testWidgets('จำนวนคืน goes up as a duration, with no dates',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      await _setDestination(tester);

      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('จำนวนคืน'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ยืนยัน'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('สร้างแผน'));
      await tester.pumpAndSettle();

      final body = adapter.bodyOf('POST /trips')!;
      expect(body['durationNights'], 2);
      expect(body['durationDays'], 3);
      expect(body.containsKey('startDate'), isFalse);
      expect(body.containsKey('endDate'), isFalse);
    });
  });

  group('AI จัดแผนให้', () {
    Map<String, dynamic> planResponse() => <String, dynamic>{
          'draft': <String, dynamic>{
            'title': 'เที่ยวดานัง 3 วัน',
            'destination': 'ดานัง, เวียดนาม',
            'planMode': 'ai',
            'numPeople': 1,
            'budgetTier': 'comfort',
            'styles': <String>['culture'],
            'intensity': 'chill',
            'transport': <String>['recommend'],
            'days': <Map<String, dynamic>>[
              {
                'dayNumber': 1,
                'daySummary': 'วันแรก',
                'activities': <Map<String, dynamic>>[
                  {
                    'title': 'สะพานมังกร',
                    'category': 'sightseeing',
                    'orderIndex': 0,
                    'time': '09:00'
                  },
                ],
              },
            ],
          },
          'resolvedBrief': <String, dynamic>{
            'durationDays': 3,
            'numPeople': 1,
            'defaultsApplied': <String>[],
            'warnings': <String>[],
          },
          'generation': <String, dynamic>{
            'attempts': 1,
            'resolvedWithoutErrors': true,
            'modelWarnings': <String>[],
            'violations': <dynamic>[],
          },
        };

    Future<void> runWizard(WidgetTester tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      await _setDestination(tester);
      await tester.tap(find.text('AI จัดแผนให้'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comfort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('สร้างแผน'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks the planner with what the wizard collected',
        (tester) async {
      adapter.replies['POST /trips/plan/generate'] = [
        FakeReply(200, planResponse()),
      ];
      await runWizard(tester);

      final body = adapter.bodyOf('POST /trips/plan/generate');
      expect(body, isNotNull);
      expect(body!['trip']['destination'], 'ดานัง, เวียดนาม');
      expect(body['trip']['guests']['adults'], 1);
      final prefs = body['preferences'] as Map<String, dynamic>;
      expect(prefs['budget']['tier'], 'comfort');
      // Transport is required and non-empty for an AI plan; nothing chosen
      // becomes the enum's own "recommend".
      expect(prefs['transport'], isNotEmpty);
    });

    testWidgets('nothing is written until the plan is kept', (tester) async {
      adapter.replies['POST /trips/plan/generate'] = [
        FakeReply(200, planResponse()),
      ];
      await runWizard(tester);

      // The review sheet is up and no trip exists yet.
      expect(find.text('เที่ยวดานัง 3 วัน'), findsOneWidget);
      expect(adapter.bodyOf('POST /trips/create'), isNull);

      await tester.tap(find.text('ทิ้งแผนนี้'));
      await tester.pumpAndSettle();
      expect(adapter.bodyOf('POST /trips/create'), isNull);
    });

    testWidgets('บันทึกแผน posts the draft and opens the trip', (tester) async {
      adapter.replies['POST /trips/plan/generate'] = [
        FakeReply(200, planResponse()),
      ];
      adapter.replies['POST /trips/create'] = [
        FakeReply(201, createdTripJson()),
      ];
      await runWizard(tester);
      await tester.tap(find.text('บันทึกแผน'));
      await tester.pumpAndSettle();

      final saved = adapter.bodyOf('POST /trips/create');
      expect(saved, isNotNull);
      // The draft goes back untouched — planMode and the fields an AI plan
      // insists on must survive the round trip.
      expect(saved!['planMode'], 'ai');
      expect(saved['transport'], isNotEmpty);
      expect(saved['numPeople'], 1);
      expect(find.text('edit trip-new'), findsOneWidget);
    });

    testWidgets('a spent quota says so instead of failing blankly',
        (tester) async {
      adapter.replies['POST /trips/plan/generate'] = [
        FakeReply(429, <String, dynamic>{'message': 'Too many requests'}),
      ];
      await runWizard(tester);

      expect(
        find.textContaining('ครบโควตาชั่วโมงนี้แล้ว'),
        findsOneWidget,
      );
    });
  });
}
