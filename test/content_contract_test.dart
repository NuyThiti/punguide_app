import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/core/api/models/trip_content.dart';
import 'package:pluno/features/trip_detail/presentation/widgets/trip_content_sections.dart';
import 'support/fake_api.dart';

const a = 'aaaaaaaa-0000-4000-8000-000000000001';
const b = 'bbbbbbbb-0000-4000-8000-000000000002';
void main() {
  test('type defaults only on create; list/detail and copy retain content',
      () async {
    final json = {...createdTripJson(), 'type': 'content'};
    expect(ApiTrip.fromJson(json).type, TripType.content);
    expect(TripListItem.fromJson(json).withSaved(true).type, TripType.content);
    expect(ApiTrip.fromJson(createdTripJson()).type, TripType.planTrip);
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, json)],
      'PATCH /trips/trip-new': [FakeReply(200, json)],
      'POST /trips/create': [FakeReply(201, json)]
    });
    final api = fakeApi(adapter);
    addTearDown(api.close);
    await api.trips.createDraft(title: 'Plan', destination: 'Home');
    expect(adapter.requests.last.data['type'], 'plan_trip');
    await api.trips.createDraft(
        type: TripType.content,
        title: 'Post',
        destination: 'Home',
        idempotencyKey: a);
    expect(adapter.requests.last.data['type'], 'content');
    expect(adapter.requests.last.headers['Idempotency-Key'], a);
    await api.trips.update('trip-new', visibility: TripVisibility.public);
    expect(adapter.requests.last.data, {'visibility': 'public'});
    await api.trips.update('trip-new', type: TripType.content);
    expect(adapter.requests.last.data, {'type': 'content'});
    await api.trips.createFromDraft(
        const TripDraft(title: 'Plan', destination: 'Home', days: []));
    expect(adapter.requests.last.data['type'], 'plan_trip');
  });
  test(
      'request allowlist retains ordered media and omits response/local fields',
      () {
    final section = TripContent.fromJson({
      'content': '',
      'mediaIds': [b, a],
      'images': [
        {'mediaId': b, 'unavailable': true}
      ],
      'photoMetadata': [
        {'mediaId': a, 'takenAt': '2026-09-01T09:30:00+07:00'}
      ],
      'location': {'status': 'none', 'name': 'stale'},
      'localId': 'local',
      'imageUrls': ['https://old.example/image.jpg']
    });
    expect(section.toRequest().toJson(), {
      'content': '',
      'mediaIds': [b, a],
      'photoMetadata': [
        {'mediaId': a, 'takenAt': '2026-09-01T09:30:00+07:00'}
      ],
      'location': {'status': 'none'}
    });
    expect(section.images.first.unavailable, isTrue);
    expect(const TripContentRequest(content: '').toJson(), {'content': ''});
  });
  test('validation rejects mixed/duplicate references and invalid metadata',
      () {
    for (final request in [
      const TripContentRequest(content: '', mediaIds: [a, a]),
      const TripContentRequest(
          content: '', mediaIds: [a], imageUrls: ['https://old.example/a.jpg']),
      const TripContentRequest(
          content: '',
          mediaIds: [a],
          photoMetadata: [PhotoMetadata(mediaId: b)]),
      const TripContentRequest(content: '', mediaIds: [
        a
      ], photoMetadata: [
        PhotoMetadata(mediaId: a, takenAt: '2026-09-01T09:30:00')
      ]),
      const TripContentRequest(
          content: '',
          location: ContentLocation(
              status: ContentLocationStatus.confirmed, latitude: 13)),
      const TripContentRequest(
          content: '',
          location: ContentLocation(
              status: ContentLocationStatus.confirmed,
              name: 'x',
              latitude: 91,
              longitude: 0)),
    ]) {
      expect(request.toJson, throwsFormatException);
    }
    final section = TripContentRequest(
        content: '',
        mediaIds: List.generate(20,
            (i) => 'aaaaaaaa-0000-4000-8000-${i.toString().padLeft(12, '0')}'));
    expect(() => TripContentRequest.serializeAll(List.filled(11, section)),
        throwsFormatException);
  });
  test('the assistant call carries the photos, its context and its key',
      () async {
    final adapter = FakeAdapter({
      'POST /trips/trip-new/contents/generate': [
        const FakeReply(200, {
          'title': 'สองวันช้า ๆ',
          'contents': [
            {
              'content': 'แดดเช้าตกลงมาบนอิฐเก่าพอดี',
              'mediaIds': [a],
              'location': {
                'status': 'suggested',
                'name': 'วัดเจดีย์หลวง',
                'placeId': 'ChIJ',
                'latitude': 18.787,
                'longitude': 98.9867,
              },
            },
            {
              'content': '',
              'mediaIds': [b],
              'location': {'status': 'none'},
            },
          ],
          'locationOptions': [
            {
              'sectionIndex': 0,
              'confidence': 'high',
              'source': 'photo',
              'options': [
                {'name': 'วัดเจดีย์หลวง', 'placeId': 'ChIJ', 'rating': 4.6}
              ],
            },
            {'sectionIndex': 1, 'confidence': 'low', 'options': []},
          ],
          'warnings': ['2 photos have no caption yet'],
        })
      ]
    });
    final api = fakeApi(adapter);
    addTearDown(api.close);

    final draft = await api.trips.generateContents(
      'trip-new',
      photos: const [
        PostAssistantPhoto(
            mediaId: a,
            takenAt: '2026-09-01T09:30:00+07:00',
            latitude: 18.7871,
            longitude: 98.9867),
        PostAssistantPhoto(mediaId: b),
      ],
      language: 'th',
      notes: 'ทริปเชียงใหม่กับเพื่อน 3 วัน',
      locationName: 'วัดเจดีย์หลวง',
      idempotencyKey: a,
    );

    // The photos go up in order with only the EXIF that was actually read.
    expect(adapter.requests.last.data, {
      'photos': [
        {
          'mediaId': a,
          'takenAt': '2026-09-01T09:30:00+07:00',
          'latitude': 18.7871,
          'longitude': 98.9867,
        },
        {'mediaId': b},
      ],
      'language': 'th',
      'notes': 'ทริปเชียงใหม่กับเพื่อน 3 วัน',
      'locationName': 'วัดเจดีย์หลวง',
    });
    expect(adapter.requests.last.headers['Idempotency-Key'], a);

    // A card per photo, the wordless one kept, and the place still unconfirmed.
    expect(draft.title, 'สองวันช้า ๆ');
    expect(draft.contents, hasLength(2));
    expect(draft.contents.last.content, isEmpty);
    expect(
        draft.contents.first.location!.status, ContentLocationStatus.suggested);
    expect(draft.optionsFor(0)!.options.single.name, 'วัดเจดีย์หลวง');
    expect(draft.optionsFor(0)!.source, PlaceSource.photo);
    expect(draft.optionsFor(1)!.confidence, PlaceConfidence.low);
    expect(draft.optionsFor(1)!.options, isEmpty);
    // An answer from before `source` existed, or one naming a source this
    // build has never heard of, says nothing rather than claiming a provenance.
    expect(draft.optionsFor(1)!.source, PlaceSource.none);
    expect(draft.warnings, ['2 photos have no caption yet']);
  });

  test('the assistant call refuses what the endpoint would reject', () async {
    final api = fakeApi(FakeAdapter({}));
    addTearDown(api.close);

    Future<void> call({
      List<PostAssistantPhoto> photos = const [PostAssistantPhoto(mediaId: a)],
      String? notes,
      String? locationName,
      double? currentLat,
      double? currentLng,
    }) =>
        api.trips.generateContents('trip-new',
            photos: photos,
            notes: notes,
            locationName: locationName,
            currentLat: currentLat,
            currentLng: currentLng);

    // 1-20 photos, none repeated.
    expect(() => call(photos: const []), throwsA(isA<FormatException>()));
    expect(
        () => call(
            photos:
                List.generate(21, (_) => const PostAssistantPhoto(mediaId: a))),
        throwsA(isA<FormatException>()));
    expect(
        () => call(photos: const [
              PostAssistantPhoto(mediaId: a),
              PostAssistantPhoto(mediaId: a),
            ]),
        throwsA(isA<FormatException>()));

    // Context and the one place name it may write are both capped.
    expect(() => call(notes: 'x' * 501), throwsA(isA<FormatException>()));
    expect(
        () => call(locationName: 'x' * 201), throwsA(isA<FormatException>()));

    // A time without a zone is a guess; coordinates come in pairs.
    expect(
        () => call(photos: const [
              PostAssistantPhoto(mediaId: a, takenAt: '2026-09-01T09:30:00')
            ]),
        throwsA(isA<FormatException>()));
    expect(
        () => call(
            photos: const [PostAssistantPhoto(mediaId: a, latitude: 18.7)]),
        throwsA(isA<FormatException>()));

    // So does the traveller's own position — half of it would be dropped by
    // the server and the draft would quietly lose its near-me suggestions.
    expect(() => call(currentLat: 13.7), throwsA(isA<FormatException>()));
    expect(() => call(currentLng: 100.5), throwsA(isA<FormatException>()));
    expect(() => call(currentLat: 91, currentLng: 100.5),
        throwsA(isA<FormatException>()));
    expect(() => call(currentLat: 13.7, currentLng: 181),
        throwsA(isA<FormatException>()));
  });

  test('the traveller position rides along and comes back as currentArea',
      () async {
    final adapter = FakeAdapter({
      'POST /trips/trip-new/contents/generate': [
        FakeReply(201, {
          'title': 'ร่างจากรูป',
          'contents': [
            {'content': 'เดินเล่นตอนเย็น', 'mediaIds': []},
          ],
          'locationOptions': [],
          'warnings': [
            'These photos carry no coordinates, so suggestions are near you',
          ],
          'currentArea': {
            'name': 'สนามหลวง',
            'placeId': 'ChIJ',
            'latitude': 13.7565,
            'longitude': 100.4932,
            'distanceM': 42,
          },
        })
      ]
    });
    final api = fakeApi(adapter);
    addTearDown(api.close);

    final draft = await api.trips.generateContents(
      'trip-new',
      photos: const [PostAssistantPhoto(mediaId: a)],
      language: 'th',
      currentLat: 13.7563,
      currentLng: 100.493,
    );

    // One nested object, and nothing invented: the endpoint whitelists keys.
    expect(adapter.requests.last.data, {
      'photos': [
        {'mediaId': a}
      ],
      'language': 'th',
      'currentLocation': {'lat': 13.7563, 'lng': 100.493},
    });

    expect(draft.currentArea!.name, 'สนามหลวง');
    expect(draft.currentArea!.distanceMeters, 42);
    expect(draft.currentArea!.isNearby, isTrue);
    // The warning saying the suggestions are near the person, not the photo,
    // has to survive to the screen.
    expect(draft.warnings, hasLength(1));
  });

  test('every suggestion source the contract names is understood', () {
    SectionPlaceOptions parse(Object? source) => SectionPlaceOptions.fromJson(
        {'sectionIndex': 0, 'confidence': 'high', 'source': source});

    expect(parse('photo').source, PlaceSource.photo);
    expect(parse('locationName').source, PlaceSource.locationName);
    expect(parse('currentLocation').source, PlaceSource.currentLocation);
    // The one the screen has to say out loud: the assistant reading the
    // picture is the easiest of the four to get wrong.
    expect(parse('image').source, PlaceSource.image);
    expect(parse('none').source, PlaceSource.none);
    expect(parse(null).source, PlaceSource.none);
    expect(parse('something-later').source, PlaceSource.none);
  });

  test('currentArea absent, blank or far away never names a place', () {
    GeneratedPostDraft parse(Object? area) =>
        GeneratedPostDraft.fromJson({'currentArea': area});

    // Every one of these is an ordinary answer, not a failure.
    expect(parse(null).currentArea, isNull);
    expect(parse('สนามหลวง').currentArea, isNull);
    expect(parse({'placeId': 'ChIJ'}).currentArea, isNull);
    expect(parse({'name': '  '}).currentArea, isNull);

    // No distance means the server still answered with the closest thing it
    // found, so it shows; two kilometres out it is a different neighbourhood.
    expect(parse({'name': 'สนามหลวง'}).currentArea!.isNearby, isTrue);
    expect(parse({'name': 'สนามหลวง', 'distanceM': 2000}).currentArea!.isNearby,
        isTrue);
    expect(
        parse({'name': 'ไอคอนสยาม', 'distanceM': 2001}).currentArea!.isNearby,
        isFalse);
  });

  testWidgets(
      'public reader keeps unavailable slot and hides suggested/legacy pins',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: TripContentSections(gutter: 16, sections: [
      TripContent.fromJson({
        'content': 'first',
        'mediaIds': [a],
        'images': [
          {'mediaId': a, 'unavailable': true}
        ],
        'location': {'status': 'suggested', 'name': 'hidden'}
      }),
      const TripContent(
          content: 'second',
          location: ContentLocation(
              status: ContentLocationStatus.confirmed, name: 'ร้านที่ยืนยัน')),
      const TripContent(content: 'third', mapId: 'legacy'),
    ])))));
    expect(find.text('รูปนี้ไม่พร้อมใช้งาน'), findsOneWidget);
    expect(find.text('hidden'), findsNothing);
    // A confirmed place is the card's name now (Figma 2183-21784), where it
    // used to be a pinned row — the pin belongs to the address line, and a
    // stored ContentLocation has no address.
    expect(find.text('ร้านที่ยืนยัน'), findsOneWidget);
    expect(tester.getTopLeft(find.text('first')).dy,
        lessThan(tester.getTopLeft(find.text('second')).dy));
  });

  test('spot extras serialize only what was filled in', () {
    expect(
      const TripContentRequest(
        content: 'ตลาดเช้า',
        visitedAt: '06:00',
        opensAt: '06:00',
        closesAt: '14:30',
        transportModes: ['MRT', 'เดิน'],
        transportCost: 100,
        transportCurrency: 'THB',
        tripHack: 'ไปเช้าคนน้อยกว่า',
      ).toJson(),
      {
        'content': 'ตลาดเช้า',
        'visitedAt': '06:00',
        'opensAt': '06:00',
        'closesAt': '14:30',
        'transportModes': ['MRT', 'เดิน'],
        'transportCost': 100,
        'transportCurrency': 'THB',
        'tripHack': 'ไปเช้าคนน้อยกว่า',
      },
    );

    // Nothing filled in means none of the keys travel.
    expect(const TripContentRequest(content: 'เปล่า').toJson(),
        {'content': 'เปล่า'});
  });

  test('contactInfo travels as one line and is capped at 500', () {
    expect(
      const TripContentRequest(
              content: 'x', contactInfo: 'คุณบุญอนันต์ 081-234-5678')
          .toJson()['contactInfo'],
      'คุณบุญอนันต์ 081-234-5678',
    );
    expect(
      () => TripContentRequest(content: 'x', contactInfo: 'ก' * 501).toJson(),
      throwsA(isA<FormatException>()),
    );

    final read = TripContent.fromJson(
        {'content': 'x', 'contactInfo': 'คุณบุญอนันต์ 081-234-5678'});
    expect(read.contactInfo, 'คุณบุญอนันต์ 081-234-5678');
    expect(
        read.toRequest().toJson()['contactInfo'], 'คุณบุญอนันต์ 081-234-5678');
  });

  test('description is public and separate from specialNotes', () {
    final trip = ApiTrip.fromJson({
      'id': 't1',
      'ownerId': 'u1',
      'title': 'ทริป',
      'destination': 'ระยอง',
      'status': 'draft',
      'schedule': <String, dynamic>{},
      'totalBudget': 0,
      'isSaved': false,
      'isLiked': false,
      'likeCount': 0,
      'remixCount': 0,
      'createdAt': '2026-09-21T00:00:00.000Z',
      'updatedAt': '2026-09-21T00:00:00.000Z',
      'description': 'ระยองเป็นจังหวัดที่มีสถานที่ท่องเที่ยวมากมาย',
      'specialNotes': 'เดินเยอะไม่ได้',
    });
    expect(trip.description, 'ระยองเป็นจังหวัดที่มีสถานที่ท่องเที่ยวมากมาย');
    expect(trip.specialNotes, 'เดินเยอะไม่ได้');

    // A reader who is not the owner gets the blurb but not the private note.
    final asReader = ApiTrip.fromJson({
      'id': 't1',
      'ownerId': 'u1',
      'title': 'ทริป',
      'destination': 'ระยอง',
      'status': 'draft',
      'schedule': <String, dynamic>{},
      'totalBudget': 0,
      'isSaved': false,
      'isLiked': false,
      'likeCount': 0,
      'remixCount': 0,
      'createdAt': '2026-09-21T00:00:00.000Z',
      'updatedAt': '2026-09-21T00:00:00.000Z',
      'description': 'ระยองเป็นจังหวัดที่มีสถานที่ท่องเที่ยวมากมาย',
    });
    expect(asReader.description, isNotNull);
    expect(asReader.specialNotes, isNull);
  });

  test('closing before opening is allowed, malformed times are not', () {
    // A bar that opens 18:00 and closes 02:00 crosses midnight.
    expect(
      const TripContentRequest(
              content: 'บาร์', opensAt: '18:00', closesAt: '02:00')
          .toJson()['closesAt'],
      '02:00',
    );

    for (final bad in ['6:00', '24:00', '06:60', '0600', 'เช้า']) {
      expect(
        () => TripContentRequest(content: 'x', visitedAt: bad).toJson(),
        throwsA(isA<FormatException>()),
        reason: bad,
      );
    }
  });

  test('transport limits follow the contract', () {
    expect(
      () => TripContentRequest(
        content: 'x',
        transportModes: List.generate(11, (i) => 'mode$i'),
      ).toJson(),
      throwsA(isA<FormatException>()),
    );
    expect(
      () =>
          TripContentRequest(content: 'x', transportModes: ['x' * 51]).toJson(),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => const TripContentRequest(content: 'x', transportCost: -1).toJson(),
      throwsA(isA<FormatException>()),
    );
    expect(
      () =>
          const TripContentRequest(content: 'x', transportCost: 1.005).toJson(),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => const TripContentRequest(content: 'x', transportCurrency: 'thb')
          .toJson(),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => TripContentRequest(content: 'x', tripHack: 'ก' * 2001).toJson(),
      throwsA(isA<FormatException>()),
    );
  });

  test('a section read back keeps its extras through toRequest', () {
    final section = TripContent.fromJson({
      'content': 'ตลาดเช้า',
      'visitedAt': '06:00',
      'closesAt': '14:30',
      'transportModes': ['MRT'],
      'transportCost': 100,
      'transportCurrency': 'THB',
      'tripHack': 'ไปเช้า',
    });

    expect(section.visitedAt, '06:00');
    expect(section.transportModes, ['MRT']);
    expect(section.toRequest().toJson()['tripHack'], 'ไปเช้า');
  });

  test('placeCount and linkedTrip read off a trip response', () {
    final trip = ApiTrip.fromJson({
      'id': 'post-1',
      'ownerId': 'u1',
      'title': 'โพสต์',
      'destination': 'กรุงเทพ',
      'status': 'draft',
      'schedule': <String, dynamic>{},
      'totalBudget': 0,
      'isSaved': false,
      'isLiked': false,
      'likeCount': 0,
      'remixCount': 0,
      'createdAt': '2026-09-20T00:00:00.000Z',
      'updatedAt': '2026-09-20T00:00:00.000Z',
      'placeCount': 3,
      'linkedTrip': {
        'id': 'plan-1',
        'title': 'เดินเล่นพระนคร',
        'schedule': {'startDate': '2026-12-28', 'durationDays': 1},
        'placeCount': 11,
      },
    });
    expect(trip.placeCount, 3);
    expect(trip.linkedTrip?.title, 'เดินเล่นพระนคร');
    expect(trip.linkedTrip?.placeCount, 11);

    // No linkedTrip key covers three cases at once — nothing linked, the plan
    // was deleted, or it is private and the reader is not its owner.
    final unlinked = ApiTrip.fromJson({
      'id': 'post-1',
      'ownerId': 'u1',
      'title': 'โพสต์',
      'destination': 'กรุงเทพ',
      'status': 'draft',
      'schedule': <String, dynamic>{},
      'totalBudget': 0,
      'isSaved': false,
      'isLiked': false,
      'likeCount': 0,
      'remixCount': 0,
      'createdAt': '2026-09-20T00:00:00.000Z',
      'updatedAt': '2026-09-20T00:00:00.000Z',
    });
    expect(unlinked.linkedTrip, isNull);
    // Never absent: an empty trip answers 0 so a card needs no fallback.
    expect(unlinked.placeCount, 0);
  });

  test('a trip response reads the owner-only fields', () {
    final trip = ApiTrip.fromJson({
      'id': 't1',
      'ownerId': 'u1',
      'title': 'ทริป',
      'destination': 'กรุงเทพ',
      'status': 'draft',
      'schedule': <String, dynamic>{},
      'totalBudget': 0,
      'isSaved': false,
      'isLiked': false,
      'likeCount': 0,
      'remixCount': 0,
      'createdAt': '2026-09-20T00:00:00.000Z',
      'updatedAt': '2026-09-20T00:00:00.000Z',
      'specialNotes': 'ส่วนตัว',
      'guestCount': 2,
      'budgetCurrency': 'USD',
    });
    expect(trip.specialNotes, 'ส่วนตัว');
    expect(trip.guestCount, 2);
    expect(trip.budgetCurrency, 'USD');

    // A viewer gets no key at all, which reads as null rather than blank.
    final asViewer = ApiTrip.fromJson({
      'id': 't1',
      'ownerId': 'u1',
      'title': 'ทริป',
      'destination': 'กรุงเทพ',
      'status': 'draft',
      'schedule': <String, dynamic>{},
      'totalBudget': 0,
      'isSaved': false,
      'isLiked': false,
      'likeCount': 0,
      'remixCount': 0,
      'createdAt': '2026-09-20T00:00:00.000Z',
      'updatedAt': '2026-09-20T00:00:00.000Z',
    });
    expect(asViewer.specialNotes, isNull);
    // No currency on the wire means baht, not "unknown".
    expect(asViewer.budgetCurrency, isNull);
  });
}
