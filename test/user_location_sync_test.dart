import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/location_access/data/location_permission_store.dart';
import 'package:pluno/features/location_access/data/location_sync.dart';
import 'package:pluno/features/location_access/domain/location_service.dart';
import 'package:pluno/features/location_access/presentation/providers/location_providers.dart';

import 'support/fake_api.dart';
import 'support/home_feed_fixtures.dart';

const _path = '/users/me/location';

FakeAdapter _adapter({
  Map<String, dynamic>? stored,
  int putStatus = 200,
}) {
  return FakeAdapter(<String, List<FakeReply>>{
    'GET $_path': <FakeReply>[
      FakeReply(200, <String, dynamic>{'location': stored}),
    ],
    'PUT $_path': <FakeReply>[
      FakeReply(putStatus, <String, dynamic>{
        'location': stored ??
            <String, dynamic>{
              'lat': 12.6814,
              'lng': 101.2816,
              'accuracyM': 25,
              'capturedAt': '2026-09-21T07:43:00.000Z',
            },
      }),
    ],
    'DELETE $_path': <FakeReply>[const FakeReply(204, null)],
  });
}

ProviderContainer _container(
  FakeAdapter adapter, {
  bool signedIn = true,
  LocationPermissionStatus? answered,
}) {
  final container = ProviderContainer(
    overrides: [
      ...paigunOverrides(adapter, session: signedIn ? AuthSession.demo : null),
      storedLocationPermissionProvider.overrideWithValue(answered),
      locationPermissionStoreProvider
          .overrideWithValue(InMemoryLocationPermissionStore(answered)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// A reading the API will accept: recent, and stamped by the device.
LocationFix _fix({
  double latitude = 12.6814,
  double longitude = 101.2816,
  int? accuracyMeters = 25,
  Duration age = Duration.zero,
}) {
  return LocationFix(
    latitude: latitude,
    longitude: longitude,
    accuracyMeters: accuracyMeters,
    capturedAt: DateTime.now().subtract(age),
  );
}

void main() {
  group('UserLocation', () {
    test('an account with nothing stored reads as null, not as an error', () {
      expect(
        UserLocation.fromEnvelope(<String, dynamic>{'location': null}),
        isNull,
      );
    });

    test('half a position is distrusted rather than used', () {
      // lat and lng are only ever written together, so one alone means the
      // response is not what we think it is.
      expect(
        UserLocation.fromEnvelope(<String, dynamic>{
          'location': <String, dynamic>{'lat': 12.68},
        }),
        isNull,
      );
    });

    test('capturedAt always goes up with a timezone', () {
      // The API rejects a bare local timestamp, which is exactly what
      // toIso8601String writes for a non-UTC DateTime.
      final local = DateTime(2026, 9, 21, 14, 43);
      expect(local.toIso8601String().endsWith('Z'), isFalse);

      final body = UserLocation(
        latitude: 12.6814,
        longitude: 101.2816,
        capturedAt: local,
      ).toJson();

      expect(body['capturedAt'], endsWith('Z'));
      expect(
        DateTime.parse(body['capturedAt'] as String).toLocal(),
        local,
      );
    });

    test('no accuracy means the field is left out, which clears it', () {
      final body = UserLocation(latitude: 1, longitude: 2).toJson();

      expect(body.containsKey('accuracyM'), isFalse);
      expect(body, containsPair('lat', 1));
      expect(body, containsPair('lng', 2));
    });
  });

  group('UsersApi', () {
    test('reading, saving and erasing hit the documented routes', () async {
      final adapter = _adapter(stored: <String, dynamic>{
        'lat': 12.6814,
        'lng': 101.2816,
        'accuracyM': 25,
        'capturedAt': '2026-09-21T07:43:00.000Z',
      });
      final api = fakeApi(adapter);

      final read = await api.users.location();
      expect(read!.latitude, 12.6814);
      expect(read.accuracyMeters, 25);
      expect(read.capturedAt!.toUtc().hour, 7);

      await api.users.saveLocation(
        UserLocation(latitude: 1, longitude: 2, accuracyMeters: 9),
      );
      await api.users.deleteLocation();

      expect(adapter.paths, [
        'GET $_path',
        'PUT $_path',
        'DELETE $_path',
      ]);
      expect(adapter.bodyOf('PUT $_path'), containsPair('accuracyM', 9));
    });
  });

  group('LocationSync', () {
    test('a signed-out traveller is never sent up', () async {
      final adapter = _adapter();
      final container = _container(adapter, signedIn: false);

      final pushed = await container.read(locationSyncProvider).push(_fix());

      // Every one of these routes is behind the auth guard; calling them
      // anonymously would only earn a 401.
      expect(pushed, isFalse);
      expect(adapter.paths, isEmpty);
    });

    test('the first fix of a run is always sent', () async {
      final adapter = _adapter();
      final container = _container(adapter);

      expect(await container.read(locationSyncProvider).push(_fix()), isTrue);
      expect(adapter.paths, ['PUT $_path']);
    });

    test('staying put costs no second request', () async {
      final adapter = _adapter();
      final sync = _container(adapter).read(locationSyncProvider);
      await sync.push(_fix());

      // ~300 m away: the account would learn nothing.
      final moved = await sync.push(_fix(latitude: 12.6841));

      expect(moved, isFalse);
      expect(adapter.paths, ['PUT $_path']);
    });

    test('moving a kilometre or more is sent', () async {
      final adapter = _adapter();
      final sync = _container(adapter).read(locationSyncProvider);
      await sync.push(_fix());

      expect(await sync.push(_fix(latitude: 12.7614)), isTrue);
      expect(adapter.paths, ['PUT $_path', 'PUT $_path']);
    });

    test('a reading too old for the API is never offered to it', () async {
      final adapter = _adapter();
      final container = _container(adapter);

      // getLastKnownPosition can hand back something days old, and the API
      // answers 400 past 24 hours — so it is not worth the request.
      final pushed = await container
          .read(locationSyncProvider)
          .push(_fix(age: const Duration(hours: 25)));

      expect(pushed, isFalse);
      expect(adapter.paths, isEmpty);
    });

    test('a device clock running fast is not sent either', () async {
      final adapter = _adapter();
      final container = _container(adapter);

      final pushed = await container.read(locationSyncProvider).push(
            _fix(age: const Duration(minutes: -10)),
          );

      expect(pushed, isFalse);
      expect(adapter.paths, isEmpty);
    });

    test('forget erases the stored position', () async {
      final adapter = _adapter();

      await _container(adapter).read(locationSyncProvider).forget();

      expect(adapter.paths, ['DELETE $_path']);
    });
  });

  group('the fix and permission controllers', () {
    test('a refusal erases the account copy as well as this run', () async {
      final adapter = _adapter();
      final container = _container(adapter);
      await container.read(locationFixProvider.notifier).capture(_fix());
      expect(container.read(locationFixProvider), isNotNull);

      await container
          .read(locationPermissionProvider.notifier)
          .record(LocationPermissionStatus.denied);

      // Taking the permission back is a request for the data to be gone.
      expect(container.read(locationFixProvider), isNull);
      expect(adapter.paths, ['PUT $_path', 'DELETE $_path']);
    });

    test('"could not ask" does not throw away a good stored position',
        () async {
      final adapter = _adapter();
      final container = _container(adapter);

      await container
          .read(locationPermissionProvider.notifier)
          .record(LocationPermissionStatus.unavailable);

      // Location services switched off for a moment is not a withdrawal.
      expect(adapter.paths, isEmpty);
    });

    test('ensureFix falls back to the account when the device has nothing',
        () async {
      final adapter = _adapter(stored: <String, dynamic>{
        'lat': 18.7883,
        'lng': 98.9853,
        'accuracyM': 30,
        'capturedAt': '2026-09-21T07:43:00.000Z',
      });
      // Permission refused, so the device is never asked — this is the run
      // that would otherwise have no position at all.
      final container =
          _container(adapter, answered: LocationPermissionStatus.denied);

      await container.read(locationFixProvider.notifier).ensureFix();

      expect(container.read(locationFixProvider)!.latitude, 18.7883);
      expect(adapter.paths, ['GET $_path']);
    });
  });
}
