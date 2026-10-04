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
const _suggest = '/places/suggest';

const _placeId = '5df26fd1-078d-4a4f-a256-f0aa30678a80';

/// A `PlaceResponseDto`, as the GET and PUT both answer with.
Map<String, dynamic> _place({
  String id = _placeId,
  String name = 'ลาดพร้าว',
  double? lat = 12.6814,
  double? lng = 101.2816,
}) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'address': 'ลาดพร้าว กรุงเทพมหานคร 10230',
      'category': 'attraction',
      'type': 'attraction',
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };

FakeAdapter _adapter({
  Map<String, dynamic>? stored,
  int putStatus = 200,
  List<Map<String, dynamic>>? nearby,
}) {
  return FakeAdapter(<String, List<FakeReply>>{
    'GET $_path': <FakeReply>[
      FakeReply(200, <String, dynamic>{'location': stored}),
    ],
    'PUT $_path': <FakeReply>[
      FakeReply(putStatus, <String, dynamic>{'location': stored ?? _place()}),
    ],
    'DELETE $_path': <FakeReply>[const FakeReply(204, null)],
    'GET $_suggest': <FakeReply>[FakeReply(200, nearby ?? [_place()])],
  });
}

/// Only the writes, without the `/places/suggest` lookups ahead of them.
List<String> _locationCalls(FakeAdapter adapter) =>
    adapter.paths.where((path) => path.endsWith(_path)).toList();

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

/// A fresh reading, stamped by the device.
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

    test('the stored place reads back as a place', () {
      final read = UserLocation.fromEnvelope(<String, dynamic>{
        'location': _place(),
      })!;

      expect(read.placeId, _placeId);
      expect(read.name, 'ลาดพร้าว');
      expect(read.address, 'ลาดพร้าว กรุงเทพมหานคร 10230');
      expect(read.latitude, 12.6814);
      expect(read.longitude, 101.2816);
    });

    test('a place with no coordinates is no location at all', () {
      // The server says as much when the post assistant falls back to it, and
      // every caller here wants a point to measure from.
      expect(
        UserLocation.fromEnvelope(<String, dynamic>{
          'location': _place(lat: null, lng: null),
        }),
        isNull,
      );
    });
  });

  group('UsersApi', () {
    test('reading, saving and erasing hit the documented routes', () async {
      final adapter = _adapter(stored: _place());
      final api = fakeApi(adapter);

      final read = await api.users.location();
      expect(read!.latitude, 12.6814);

      final saved = await api.users.saveLocation(_placeId);
      expect(saved!.placeId, _placeId);
      await api.users.deleteLocation();

      expect(adapter.paths, [
        'GET $_path',
        'PUT $_path',
        'DELETE $_path',
      ]);
      // placeId and nothing else: an extra field is a 400.
      expect(adapter.bodyOf('PUT $_path'), {'placeId': _placeId});
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

    test('a fix goes up as the nearest place, not as coordinates', () async {
      final adapter = _adapter(nearby: [
        // Listed first — the route orders by popularity — but ~3 km out.
        _place(id: 'far', name: 'ไกล', lat: 12.7084),
        _place(id: 'near', name: 'ใกล้', lat: 12.6816),
      ]);
      final container = _container(adapter);

      expect(await container.read(locationSyncProvider).push(_fix()), isTrue);
      expect(adapter.paths, ['GET $_suggest', 'PUT $_path']);
      expect(adapter.bodyOf('PUT $_path'), {'placeId': 'near'});
      expect(adapter.queriesOf('GET $_suggest').single['lat'], 12.6814);
    });

    test('nothing nearby at either radius sends nothing', () async {
      final adapter = _adapter(nearby: const []);
      final container = _container(adapter);

      expect(await container.read(locationSyncProvider).push(_fix()), isFalse);
      expect(
        adapter.queriesOf('GET $_suggest').map((query) => query['radius']),
        LocationSync.searchRadiiMeters,
      );
      expect(_locationCalls(adapter), isEmpty);
    });

    test('staying put costs no second request', () async {
      final adapter = _adapter();
      final sync = _container(adapter).read(locationSyncProvider);
      await sync.push(_fix());

      // ~300 m away: the account would learn nothing.
      final moved = await sync.push(_fix(latitude: 12.6841));

      expect(moved, isFalse);
      expect(adapter.paths, ['GET $_suggest', 'PUT $_path']);
    });

    test('moving a kilometre or more is sent', () async {
      final adapter = _adapter();
      final sync = _container(adapter).read(locationSyncProvider);
      await sync.push(_fix());

      expect(await sync.push(_fix(latitude: 12.7614)), isTrue);
      expect(_locationCalls(adapter), ['PUT $_path', 'PUT $_path']);
    });

    test('a reading days old is not filed as where the traveller is',
        () async {
      final adapter = _adapter();
      final container = _container(adapter);

      // getLastKnownPosition can hand back something days old.
      final pushed = await container
          .read(locationSyncProvider)
          .push(_fix(age: const Duration(hours: 25)));

      expect(pushed, isFalse);
      expect(adapter.paths, isEmpty);
    });

    test('a place picked from search goes up as its own id, no lookup',
        () async {
      final adapter = _adapter();
      final container = _container(adapter);

      final sent = await container.read(locationSyncProvider).pushChosen(
            placeId: 'chosen',
            latitude: 18.7883,
            longitude: 98.9853,
          );

      expect(sent, isTrue);
      expect(adapter.paths, ['PUT $_path']);
      expect(adapter.bodyOf('PUT $_path'), {'placeId': 'chosen'});
    });

    test('a pin dropped on the map goes up as the nearest place', () async {
      final adapter = _adapter();
      final container = _container(adapter);

      final sent = await container.read(locationSyncProvider).pushChosen(
            latitude: 12.6814,
            longitude: 101.2816,
          );

      expect(sent, isTrue);
      expect(adapter.paths, ['GET $_suggest', 'PUT $_path']);
      expect(adapter.bodyOf('PUT $_path'), {'placeId': _placeId});
    });

    test('confirming a spot nearby is sent even though a fix would not be',
        () async {
      final adapter = _adapter();
      final sync = _container(adapter).read(locationSyncProvider);
      await sync.push(_fix());

      // ~300 m: a passive reading this close is dropped, but choosing it by
      // hand is a deliberate act and has to stick.
      expect(await sync.push(_fix(latitude: 12.6841)), isFalse);
      expect(
        await sync.pushChosen(
          placeId: _placeId,
          latitude: 12.6841,
          longitude: 101.2816,
        ),
        isTrue,
      );
      expect(_locationCalls(adapter), ['PUT $_path', 'PUT $_path']);
    });

    test('a signed-out traveller keeps their pin to themselves', () async {
      final adapter = _adapter();
      final container = _container(adapter, signedIn: false);

      final sent = await container
          .read(locationSyncProvider)
          .pushChosen(placeId: _placeId, latitude: 1, longitude: 2);

      expect(sent, isFalse);
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
      expect(_locationCalls(adapter), ['PUT $_path', 'DELETE $_path']);
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
      final adapter = _adapter(stored: _place(lat: 18.7883, lng: 98.9853));
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
