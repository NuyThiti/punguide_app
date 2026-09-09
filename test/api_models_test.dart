import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/pluno_api.dart';

void main() {
  group('Json', () {
    test('reads an empty string as absent', () {
      // Day.date and Activity.time both use '' for "not set".
      final json = <String, dynamic>{'date': '', 'time': '', 'notes': null};
      expect(Json.date(json, 'date'), isNull);
      expect(Json.time(json, 'time'), isNull);
      expect(Json.string(json, 'notes'), isNull);
      expect(Json.string(json, 'missing'), isNull);
    });

    test('formats dates and times the way the API expects', () {
      final moment = DateTime(2026, 9, 8, 9, 5);
      expect(Json.formatDate(moment), '2026-09-08');
      expect(Json.formatTime(moment), '09:05');
    });

    test('compact drops nulls but keeps an explicit clear', () {
      final body = Json.compact(<String, dynamic>{
        'kept': 'value',
        'omitted': null,
        'cleared': const Patch<String>.clear(),
        'patched': const Patch<String>.value('new'),
      });
      expect(body.containsKey('omitted'), isFalse);
      expect(body['kept'], 'value');
      expect(body.containsKey('cleared'), isTrue);
      expect(body['cleared'], isNull);
      expect(body['patched'], 'new');
    });
  });

  group('enums', () {
    test('parse from their wire values and ignore unknown ones', () {
      expect(TravelMode.from('DRIVE'), TravelMode.drive);
      expect(TravelType.from('tuk_tuk'), TravelType.tukTuk);
      expect(TripStatus.from('nonsense'), isNull);
      expect(TripStatus.from(null), isNull);
    });

    test('only DRIVE is routable today', () {
      expect(TravelMode.drive.isSupported, isTrue);
      expect(TravelMode.walk.isSupported, isFalse);
    });

    test('place categories fold into the itinerary taxonomy', () {
      expect(
        PlaceCategory.cafe.asActivityCategory,
        ActivityCategory.food,
      );
      expect(
        PlaceCategory.shopping.asActivityCategory,
        ActivityCategory.other,
      );
    });

    test('constraints cap the pace they disagree with', () {
      expect(TripIntensity.hardcore.maxItemsPerDay, 16);
      expect(TripConstraint.wheelchair.maxItemsPerDay, 6);
    });
  });

  group('ItineraryDay', () {
    final day = ItineraryDay.fromJson(<String, dynamic>{
      'id': 'day-1',
      'dayNumber': 1,
      'date': '',
      'activities': [
        <String, dynamic>{
          'id': 'stop-1',
          'time': '',
          'title': 'วัดเชียงทอง',
          'category': 'sightseeing',
          'order': 0,
          'cost': 300,
        },
        <String, dynamic>{
          'id': 'stop-2',
          'time': '11:30',
          'title': 'ตลาดเช้า',
          'category': 'food',
          'order': 1,
          'cost': 0,
          'location': <String, dynamic>{'name': 'ตลาดเช้า', 'lat': 19.88},
        },
      ],
      'travelSegments': [
        <String, dynamic>{
          'id': 'seg-1',
          'dayId': 'day-1',
          'fromPlaceId': 'stop-1',
          'toPlaceId': 'stop-2',
          'order': 0,
          'travelMode': 'DRIVE',
          'routeStatus': 'FAILED',
          'durationSeconds': null,
          'durationMinutes': null,
          'distanceMeters': null,
          'distanceKilometers': null,
          'calculatedAt': null,
        },
      ],
    });

    test('an undated day and an untimed stop decode to null', () {
      expect(day.date, isNull);
      expect(day.activities.first.time, isNull);
      expect(day.activities.last.time, '11:30');
    });

    test('a failed segment keeps its shape with null measures', () {
      final segment = day.travelSegments.single;
      expect(segment.hasFailed, isTrue);
      expect(segment.durationMinutes, isNull);
      expect(segment.calculatedAt, isNull);
    });

    test('segments are matched by stop id, not by position', () {
      expect(day.segmentInto(day.activities.last)?.id, 'seg-1');
      // The first stop of a day has nothing leading into it.
      expect(day.segmentInto(day.activities.first), isNull);
    });

    test('a hand-typed stop has no location', () {
      expect(day.activities.first.location, isNull);
      expect(day.activities.last.location?.name, 'ตลาดเช้า');
    });
  });

  group('DestinationPlace', () {
    test('is absent rather than coordinate-less', () {
      expect(DestinationPlace.maybeFromJson(null), isNull);
      final place = DestinationPlace.maybeFromJson(<String, dynamic>{
        'name': 'Luang Prabang',
        'latitude': 19.8856,
        'longitude': 102.1347,
      });
      expect(place!.hasCoordinates, isTrue);
    });
  });

  group('BudgetSummary', () {
    final summary = BudgetSummary.fromJson(<String, dynamic>{
      'budgetLimit': 36000,
      'totalBudget': 28400,
      'byCategory': [
        <String, dynamic>{
          'category': 'food',
          'amount': 12000,
          'percentage': 42,
          'itemCount': 8,
        },
      ],
      'byDay': [
        <String, dynamic>{
          'dayId': 'day-1',
          'dayNumber': 1,
          'date': '2026-09-12',
          'amount': 6400,
        },
      ],
      'items': [
        <String, dynamic>{
          'id': 'stop-1',
          'title': 'วัดเชียงทอง',
          'category': 'sightseeing',
          'amount': 1000,
          'source': 'activity',
        },
        <String, dynamic>{
          'id': 'stop-1',
          'title': 'เดินทางไป วัดเชียงทอง',
          'category': 'transport',
          'amount': 200,
          'source': 'travel',
        },
      ],
    });

    test('a stop and its travel leg share an id but not a key', () {
      final ids = summary.items.map((item) => item.id).toSet();
      expect(ids, hasLength(1));
      final keys = summary.items.map((item) => item.key).toSet();
      expect(keys, hasLength(2));
    });

    test('reports how much of the cap is spent', () {
      expect(summary.hasLimit, isTrue);
      expect(summary.isOverBudget, isFalse);
      expect(summary.limitUsedRatio, closeTo(0.789, 0.001));
    });

    test('no limit is different from a limit of zero', () {
      final uncapped = BudgetSummary.fromJson(<String, dynamic>{
        'totalBudget': 500,
      });
      expect(uncapped.hasLimit, isFalse);
      expect(uncapped.limitUsedRatio, isNull);
      expect(uncapped.isOverBudget, isFalse);
    });
  });

  group('TripDraft', () {
    final generated = <String, dynamic>{
      'title': 'หลวงพระบาง 4 วัน 3 คืน',
      'destination': 'หลวงพระบาง, ลาว',
      'planMode': 'ai',
      'status': 'draft',
      'startDate': '2026-09-12',
      'endDate': '2026-09-15',
      'numPeople': 4,
      'budgetTier': 'comfort',
      'budgetLimit': 36000,
      'styles': ['culture', 'food'],
      'intensity': 'balance',
      'transport': ['rental_car'],
      'days': [
        <String, dynamic>{
          'dayNumber': 1,
          'date': '2026-09-12',
          'activities': [
            <String, dynamic>{
              'id': 'act-1',
              'time': '09:00',
              'title': 'วัดเชียงทอง',
              'category': 'sightseeing',
              'cost': 300,
              // Accepted by the API, then dropped on save.
              'travelNote': 'เดิน ~10 นาที',
              'icon': 'temple',
            },
          ],
        },
      ],
      'expenses': [
        <String, dynamic>{
          'id': 'exp-1',
          'title': 'น้ำมัน',
          'amount': 500,
          'category': 'fuel',
        },
        <String, dynamic>{
          'id': 'exp-2',
          'title': 'ค่าเข้าวัด',
          'amount': 300,
          'linkedActivityId': 'act-1',
        },
      ],
    };

    test('round-trips a generated draft back into a save payload', () {
      final draft = TripDraft.fromJson(generated);
      final body = draft.toJson();

      expect(body['title'], 'หลวงพระบาง 4 วัน 3 คืน');
      expect(body['startDate'], '2026-09-12');
      expect(body['planMode'], 'ai');
      expect(body['styles'], <String>['culture', 'food']);
      expect((body['days'] as List), hasLength(1));

      final activity =
          ((body['days'] as List).first as Map)['activities'] as List;
      expect((activity.first as Map)['title'], 'วัดเชียงทอง');
      expect((activity.first as Map)['time'], '09:00');
    });

    test('flags the expense rows the API will drop', () {
      final draft = TripDraft.fromJson(generated);
      expect(draft.expenses.first.willBeDropped, isFalse);
      expect(draft.expenses.last.willBeDropped, isTrue);
    });

    test('an empty styles list still reaches the server', () {
      // '[]' means "the traveller skipped this step", so it must not be pruned.
      final draft = TripDraft(
        title: 'ทริป',
        destination: 'เชียงใหม่',
        planMode: PlanMode.ai,
        styles: const <TravelStyle>[],
        days: const <DraftDay>[],
      );
      expect(draft.toJson()['styles'], isEmpty);
      expect(draft.toJson().containsKey('styles'), isTrue);
    });

    test('names the fields AI mode still needs', () {
      final draft = TripDraft(
        title: 'ทริป',
        destination: 'เชียงใหม่',
        planMode: PlanMode.ai,
        days: const <DraftDay>[],
      );
      expect(
        draft.missingAiFields,
        containsAll(<String>[
          'numPeople',
          'budgetTier',
          'styles',
          'intensity',
          'transport',
        ]),
      );

      final manual = TripDraft(
        title: 'ทริป',
        destination: 'เชียงใหม่',
        days: const <DraftDay>[],
      );
      expect(manual.missingAiFields, isEmpty);
    });
  });

  group('PlanGenerationRequest', () {
    test('sends only what was filled in', () {
      final request = PlanGenerationRequest(
        trip: PlanTripInput(
          destination: 'หลวงพระบาง, ลาว',
          dates: PlanDates.fixed(
            startDate: DateTime(2026, 9, 12),
            endDate: DateTime(2026, 9, 15),
          ),
          guests: const PlanGuests(adults: 4, groupType: GroupType.friends),
        ),
        preferences: const PlanPreferences(
          styles: [TravelStyle.culture],
          budget: PlanBudget(tier: BudgetTier.comfort),
          accommodation: PlanAccommodation.notBooked(
            grade: HotelGrade.midscale,
            styles: [HotelStyle.boutique],
          ),
        ),
      );

      final body = request.toJson();
      final trip = body['trip'] as Map<String, dynamic>;
      expect(trip['dates'], <String, dynamic>{
        'mode': 'fixed',
        'startDate': '2026-09-12',
        'endDate': '2026-09-15',
      });
      expect((trip['guests'] as Map)['adults'], 4);

      final preferences = body['preferences'] as Map<String, dynamic>;
      expect(preferences['styles'], <String>['culture']);
      expect((preferences['budget'] as Map)['tier'], 'comfort');
      expect((preferences['accommodation'] as Map)['status'], 'not_booked');
      // Untouched preferences are absent, not null.
      expect(preferences.containsKey('intensity'), isFalse);
      expect(body.containsKey('selectedPlaceIds'), isFalse);
    });
  });

  group('AuthTokenStore.parseExpiresIn', () {
    test('reads the API spellings', () {
      expect(AuthTokenStore.parseExpiresIn('15m'), const Duration(minutes: 15));
      expect(
          AuthTokenStore.parseExpiresIn('900s'), const Duration(seconds: 900));
      expect(AuthTokenStore.parseExpiresIn('1h'), const Duration(hours: 1));
      expect(AuthTokenStore.parseExpiresIn('90'), const Duration(seconds: 90));
      expect(AuthTokenStore.parseExpiresIn('soon'), isNull);
      expect(AuthTokenStore.parseExpiresIn(null), isNull);
    });
  });
}
