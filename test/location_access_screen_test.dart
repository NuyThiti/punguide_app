import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/core/router/app_router.dart';
import 'package:pluno/features/location_access/data/location_permission_store.dart';
import 'package:pluno/features/location_access/domain/location_service.dart';
import 'package:pluno/features/location_access/presentation/location_access_screen.dart';
import 'package:pluno/features/location_access/presentation/location_picker_screen.dart';
import 'package:pluno/features/location_access/presentation/providers/location_providers.dart';
import 'package:pluno/features/paigun/presentation/providers/paigun_providers.dart';

import 'support/fake_api.dart';
import 'support/home_feed_fixtures.dart';

/// A stand-in for the OS dialog: answers whatever the test says it does, and
/// records that it was asked at all.
class _FakeLocationService implements LocationService {
  _FakeLocationService(this.status, {this.fix});

  final LocationPermissionStatus status;
  final LocationFix? fix;
  int asked = 0;

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    asked++;
    return status;
  }

  @override
  Future<LocationFix?> currentFix() async => fix;
}

/// Nothing here should reach the platform's real preferences.
List<Override> _storeOverride() => [
      locationPermissionStoreProvider
          .overrideWithValue(InMemoryLocationPermissionStore()),
    ];

Widget _harness({
  required String initialLocation,
  LocationService? service,
  FakeAdapter? adapter,
  ProviderContainer? container,
}) {
  return UncontrolledProviderScope(
    container: container ??
        ProviderContainer(
          overrides: [
            ..._storeOverride(),
            if (service != null)
              locationServiceProvider.overrideWithValue(service),
            if (adapter != null)
              plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
          ],
        ),
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: '/location',
            name: AppRoute.locationAccess.name,
            builder: (_, __) => const LocationAccessScreen(),
          ),
          GoRoute(
            path: '/location/pick',
            name: AppRoute.locationPicker.name,
            builder: (_, __) => const LocationPickerScreen(),
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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the permission page lays out the design without overflow',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_harness(initialLocation: '/location'));
    await tester.pumpAndSettle();

    expect(
      find.text('อนุญาติการเข้าถึงตำแหน่ง\nเพื่อดูทริปใกล้ตัวคุณ'),
      findsOneWidget,
    );
    expect(
      find.text('เพื่อแสดงการค้นหาทริป และสถานที่ท่องเที่ยวที่อยู่ใกล้คุณ'),
      findsOneWidget,
    );
    expect(find.text('อนุญาต'), findsOneWidget);
    expect(find.text('ไว้ทีหลังนะ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a granted answer with no fix yet is not treated as a position',
      (tester) async {
    _phone(tester);

    // Permission granted, but the device never produced a fix — indoors, or
    // the request timed out. The picker must still open with no distance
    // rather than a made-up one, and with no pin either: nothing signed in,
    // nothing stored, nothing to show.
    final service = _FakeLocationService(LocationPermissionStatus.granted);
    final container = ProviderContainer(
      overrides: [
        ..._storeOverride(),
        locationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _harness(initialLocation: '/location', container: container),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('อนุญาต'));
    await tester.pumpAndSettle();

    expect(container.read(locationFixProvider), isNull);
    expect(find.text('ยังไม่ได้เลือกตำแหน่ง'), findsOneWidget);
  });

  testWidgets('allowing asks the OS, keeps the fix, and opens the picker',
      (tester) async {
    _phone(tester);

    final service = _FakeLocationService(
      LocationPermissionStatus.granted,
      fix: const LocationFix(latitude: 13.75, longitude: 100.49),
    );
    final container = ProviderContainer(
      overrides: [
        ..._storeOverride(),
        locationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _harness(initialLocation: '/location', container: container),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('อนุญาต'));
    await tester.pumpAndSettle();

    expect(service.asked, 1);
    expect(
      container.read(locationPermissionProvider),
      LocationPermissionStatus.granted,
    );
    expect(container.read(locationFixProvider)?.latitude, 13.75);
    expect(find.text('ยืนยันตำแหน่งนี้'), findsOneWidget);
  });

  testWidgets('"ไว้ทีหลังนะ" records the refusal and carries on regardless',
      (tester) async {
    _phone(tester);

    final container = ProviderContainer(overrides: _storeOverride());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _harness(initialLocation: '/location', container: container),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ไว้ทีหลังนะ'));
    await tester.pumpAndSettle();

    expect(
      container.read(locationPermissionProvider),
      LocationPermissionStatus.denied,
    );
    // With no destination carried in, the board is the fallback — a refusal is
    // not a dead end, it just means no GPS fix. (The gate passes the real
    // destination through; see location_gate_test.dart.)
    expect(find.text('paigun board'), findsOneWidget);
  });

  testWidgets('the picker opens blank when the account holds no location',
      (tester) async {
    _phone(tester);

    // No signed-in session, so the account pull short-circuits to null
    // without a request — same as a real signed-out visit.
    final container = ProviderContainer(overrides: _storeOverride());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _harness(initialLocation: '/location/pick', container: container),
    );
    await tester.pumpAndSettle();

    // Nothing stored, nothing pinned — the sheet says so plainly rather than
    // settling for the board's own hardcoded origin.
    expect(find.text('ยังไม่ได้เลือกตำแหน่ง'), findsOneWidget);
    expect(find.text('ตำแหน่งของฉัน'), findsNothing);

    // The confirm button is inert with nothing chosen — tapping it must not
    // move the board's origin or leave the picker.
    await tester.tap(find.text('ยืนยันตำแหน่งนี้'));
    await tester.pumpAndSettle();
    expect(find.text('paigun board'), findsNothing);
    expect(container.read(paigunOriginProvider).label, 'ตำแหน่งของฉัน');
    expect(tester.takeException(), isNull);
  });

  testWidgets("the picker opens on the account's stored location",
      (tester) async {
    _phone(tester);

    final adapter = FakeAdapter({
      'GET /users/me/location': [
        const FakeReply(200, {
          'location': {'lat': 13.75, 'lng': 100.5, 'accuracyM': 20},
        }),
      ],
    });
    final container = ProviderContainer(
      overrides: [..._storeOverride(), ...paigunOverrides(adapter)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _harness(initialLocation: '/location/pick', container: container),
    );
    await tester.pumpAndSettle();

    // No reverse geocode, so it is named for what it is rather than guessing
    // a place, and the coordinates stand in for an address. `textContaining`
    // rather than an exact match: the same pull also seeds the device fix, so
    // the row may additionally print a 0.0km distance to itself.
    expect(find.text('ตำแหน่งล่าสุดที่บันทึกไว้'), findsOneWidget);
    expect(find.textContaining('13.7500, 100.5000'), findsOneWidget);

    await tester.tap(find.text('ยืนยันตำแหน่งนี้'));
    await tester.pumpAndSettle();

    expect(find.text('paigun board'), findsOneWidget);
    expect(
      container.read(paigunOriginProvider).label,
      'ตำแหน่งล่าสุดที่บันทึกไว้',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Thai addresses, which carry no commas, are still trimmed',
      (tester) async {
    _phone(tester);

    // Both shapes the API actually answers with, copied from live responses:
    // one run of words ending in a postcode, and one with none at all.
    final adapter = FakeAdapter({
      'GET /places/search': [
        const FakeReply(200, [
          {
            'id': 'cnx',
            'name': 'เทศบาลนครเชียงใหม่',
            'address': 'เทศบาลนครเชียงใหม่ อำเภอเมืองเชียงใหม่ เชียงใหม่',
            'lat': 18.7883,
            'lng': 98.9853,
          },
          {
            'id': 'hkt',
            'name': 'เทศบาลนครภูเก็ต',
            'address': 'เทศบาลนครภูเก็ต อำเภอเมืองภูเก็ต ภูเก็ต 83000',
            'lat': 7.8804,
            'lng': 98.3923,
          },
        ]),
      ],
    });
    final container = ProviderContainer(
      overrides: [
        ..._storeOverride(),
        plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _harness(initialLocation: '/location/pick', container: container),
    );
    await tester.pumpAndSettle();

    // Not 'เชียงใหม่': the query is echoed in the field, and the point here is
    // what the row prints.
    await tester.enterText(find.byType(TextField), 'เทศบาล');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Not the whole line, which repeats the name and overruns the row.
    expect(find.text('เชียงใหม่'), findsOneWidget);
    expect(find.text('ภูเก็ต 83000'), findsOneWidget);
  });

  testWidgets('searching pins the chosen place and moves the origin to it',
      (tester) async {
    _phone(tester);

    final adapter = FakeAdapter({
      'GET /places/search': [
        const FakeReply(200, [
          {
            'id': 'p1',
            'name': 'เขตพระนคร',
            'address': '1 Na Phra Lan, Phra Nakhon, Bangkok 10200, Thailand',
            'lat': 13.7563,
            'lng': 100.4930,
          },
        ]),
      ],
    });
    final container = ProviderContainer(
      overrides: [
        plunoApiProvider.overrideWith((ref) async => fakeApi(adapter))
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _harness(initialLocation: '/location/pick', container: container),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'พระนคร');
    // The panel — and with it the debounce timer — is created on this frame;
    // only then can the clock be run past the 350ms window.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // The address is trimmed to the segment the design prints.
    expect(find.text('Bangkok 10200'), findsOneWidget);

    await tester.tap(find.text('Bangkok 10200'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ยืนยันตำแหน่งนี้'));
    await tester.pumpAndSettle();

    final origin = container.read(paigunOriginProvider);
    expect(origin.label, 'เขตพระนคร');
    expect(origin.address, 'Bangkok 10200');
    expect(origin.latitude, 13.7563);
  });
}
