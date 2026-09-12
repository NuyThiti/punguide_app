import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/features/location_access/data/location_permission_store.dart';
import 'package:pluno/features/location_access/domain/location_service.dart';
import 'package:pluno/features/location_access/presentation/providers/location_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrefsLocationPermissionStore', () {
    test('nothing stored reads as unanswered', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await const PrefsLocationPermissionStore().read(), isNull);
    });

    test('an answer survives being written and read back', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const store = PrefsLocationPermissionStore();

      await store.write(LocationPermissionStatus.denied);

      expect(await store.read(), LocationPermissionStatus.denied);
    });

    test('clearing the storage brings the question back', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const store = PrefsLocationPermissionStore();
      await store.write(LocationPermissionStatus.granted);

      await store.clear();

      expect(await store.read(), isNull);
    });

    test('a value this build cannot read counts as unanswered', () async {
      // Rather than throwing, or silently letting an unknown answer open the
      // gate — one extra ask is the cheaper mistake.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'flutter.pluno.locationPermission': 'someFutureAnswer',
      });

      expect(await const PrefsLocationPermissionStore().read(), isNull);
    });
  });

  test('recording an answer writes it through to storage', () async {
    final store = InMemoryLocationPermissionStore();
    final container = ProviderContainer(
      overrides: [locationPermissionStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await container
        .read(locationPermissionProvider.notifier)
        .record(LocationPermissionStatus.granted);

    expect(
      container.read(locationPermissionProvider),
      LocationPermissionStatus.granted,
    );
    expect(await store.read(), LocationPermissionStatus.granted);
  });

  test('the answer read at startup seeds the provider', () async {
    final container = ProviderContainer(
      overrides: [
        storedLocationPermissionProvider
            .overrideWithValue(LocationPermissionStatus.denied),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(locationPermissionProvider),
      LocationPermissionStatus.denied,
    );
  });
}
