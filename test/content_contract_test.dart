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
  testWidgets(
      'public reader keeps unavailable slot and hides suggested/legacy pins',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: TripContentSections(sections: [
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
    expect(find.text('ร้านที่ยืนยัน'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(tester.getTopLeft(find.text('first')).dy,
        lessThan(tester.getTopLeft(find.text('second')).dy));
  });
}
