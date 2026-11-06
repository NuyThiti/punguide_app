import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/location_access/domain/location_service.dart';
import 'package:pluno/features/onboarding/data/onboarding_sync.dart';
import 'package:pluno/features/trip_style/domain/trip_style_preference.dart';

import 'support/fake_api.dart';
import 'support/home_feed_fixtures.dart';

const _styleRoute = 'PUT /users/me/preferences/travel-style';
const _accessRoute = 'PUT /users/me/preferences/location-access';

Map<String, dynamic> _answered({
  String? status = 'granted',
  Map<String, dynamic>? style,
}) =>
    <String, dynamic>{
      'locationAccess':
          status == null ? null : <String, dynamic>{'status': status},
      'travelStyle': style,
    };

FakeAdapter _adapter({Map<String, dynamic>? stored}) =>
    FakeAdapter(<String, List<FakeReply>>{
      'GET /users/me/preferences': <FakeReply>[
        FakeReply(200, stored ?? _answered(status: null)),
      ],
      _accessRoute: <FakeReply>[FakeReply(200, _answered())],
      _styleRoute: <FakeReply>[FakeReply(200, _answered())],
    });

ProviderContainer _container(FakeAdapter adapter, {bool signedIn = true}) {
  final container = ProviderContainer(
    overrides:
        paigunOverrides(adapter, session: signedIn ? AuthSession.demo : null),
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('chip labels to the wire', () {
    test('a dietary chip has no enum, so it travels as free text', () {
      final payload = travelStyleFrom(
        const TripStylePreference(
          styles: ['ธรรมชาติ', 'คาเฟ่', 'ดำน้ำ'],
          constraints: ['มีผู้สูงอายุ', 'อิสลาม', 'มังสวิรัติ'],
        ),
      ).toJson();

      expect(payload['styles'], ['nature', 'cafe']);
      expect(payload['customStyles'], ['ดำน้ำ']);
      expect(payload['constraints'], ['seniors']);
      // Neither อิสลาม nor มังสวิรัติ is a TripConstraint, and dropping them
      // would quietly lose the answer.
      expect(payload['customConstraints'], ['อิสลาม', 'มังสวิรัติ']);
    });

    test('and comes back as the same chips', () {
      const stored = TripStylePreference(
        styles: ['ภูเขา', 'ดำน้ำ'],
        constraints: ['ผู้ใช้รถเข็น', 'อิสลาม'],
      );

      final round = tripStyleFrom(travelStyleFrom(stored));

      expect(round.styles, stored.styles);
      expect(round.constraints, stored.constraints);
    });

    test('a value this build does not know is dropped, not fatal', () {
      final parsed = TravelStylePreference.maybeFrom(<String, dynamic>{
        'styles': ['nature', 'teleporting'],
        'constraints': ['seniors', 'time_travel'],
      })!;

      expect(parsed.styles, [TravelStyle.nature]);
      expect(parsed.constraints, [TripConstraint.seniors]);
    });
  });

  group('OnboardingSync', () {
    test('an empty answer still goes up, which is how skip is recorded',
        () async {
      final adapter = _adapter();
      final sent = await _container(adapter)
          .read(onboardingSyncProvider)
          .pushTravelStyle(TripStylePreference.skipped);

      expect(sent, isTrue);
      final body = adapter.bodyOf(_styleRoute)!;
      // Every list, every time: the endpoint replaces the whole set, so one
      // left out would come back empty anyway.
      expect(body['styles'], isEmpty);
      expect(body['customStyles'], isEmpty);
      expect(body['constraints'], isEmpty);
      expect(body['customConstraints'], isEmpty);
    });

    test('"could not ask" is never sent as an answer', () async {
      final adapter = _adapter();

      final sent = await _container(adapter)
          .read(onboardingSyncProvider)
          .pushLocationAccess(LocationPermissionStatus.unavailable);

      expect(sent, isFalse);
      expect(adapter.paths, isEmpty);
    });

    test('a signed-out traveller keeps their answers to themselves', () async {
      final adapter = _adapter();
      final sync =
          _container(adapter, signedIn: false).read(onboardingSyncProvider);

      expect(
        await sync.pushLocationAccess(LocationPermissionStatus.granted),
        isFalse,
      );
      expect(await sync.pushTravelStyle(TripStylePreference.skipped), isFalse);
      expect(await sync.pull(), isNull);
      expect(adapter.paths, isEmpty);
    });

    test('a brand new account reads as nothing answered', () async {
      final preferences =
          await _container(_adapter()).read(onboardingSyncProvider).pull();

      expect(preferences!.locationAccess, isNull);
      expect(preferences.travelStyle, isNull);
    });

    test('an account that has answered reads back both halves', () async {
      final adapter = _adapter(
        stored: _answered(
          status: 'later',
          style: <String, dynamic>{
            'styles': ['nature'],
            'customStyles': <String>[],
            'constraints': <String>[],
            'customConstraints': ['อิสลาม'],
          },
        ),
      );

      final preferences =
          await _container(adapter).read(onboardingSyncProvider).pull();

      expect(preferences!.locationAccess!.status, LocationAccessAnswer.later);
      expect(tripStyleFrom(preferences.travelStyle!).styles, ['ธรรมชาติ']);
      expect(tripStyleFrom(preferences.travelStyle!).constraints, ['อิสลาม']);
    });
  });
}
