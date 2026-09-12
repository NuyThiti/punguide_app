import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/models/trip.dart';
import 'package:pluno/core/api/models/trip_content.dart';
import 'package:pluno/core/api/models/trip_draft.dart';
import 'support/fake_api.dart';

void main() {
  const first = TripContent(
      title: 'สวน',
      content: 'เดินเล่น',
      imageUrls: ['https://example.com/park.jpg'],
      mapId: 'google-place');
  const second = TripContent(title: '', content: 'อาหาร');
  test('contents round trip, legacy and null responses', () {
    for (final value in [null, <dynamic>[]]) {
      expect(
          ApiTrip.fromJson({...createdTripJson(), 'contents': value}).contents,
          isEmpty);
    }
    expect(ApiTrip.fromJson(createdTripJson()).contents, isEmpty);
    final trip = ApiTrip.fromJson({
      ...createdTripJson(),
      'contents': [first.toJson(), second.toJson()]
    });
    expect(trip.contents.map((item) => item.toJson()),
        [first.toJson(), second.toJson()]);
  });
  test('create and PATCH preserve order; omission differs from clearing',
      () async {
    final adapter = FakeAdapter({
      'POST /trips': [FakeReply(201, createdTripJson())],
      'PATCH /trips/trip-new': [FakeReply(200, createdTripJson())],
    });
    final api = fakeApi(adapter);
    addTearDown(api.close);
    await api.trips.createDraft(
        title: 'Trip', destination: 'Bangkok', contents: [first, second]);
    expect(adapter.requests.last.data['contents'],
        [first.toJson(), second.toJson()]);
    expect(adapter.requests.last.data.containsKey('visibility'), isFalse);
    await api.trips.update('trip-new', contents: [second, first]);
    expect(adapter.requests.last.data['contents'],
        [second.toJson(), first.toJson()]);
    await api.trips.update('trip-new', title: 'Renamed');
    expect(adapter.requests.last.data.containsKey('contents'), isFalse);
    await api.trips.update('trip-new', contents: []);
    expect(adapter.requests.last.data['contents'], isEmpty);
  });
  test('itinerary copy preserves contents and rejects local image paths', () {
    const draft = TripDraft(
        title: 'Trip', destination: 'Bangkok', days: [], contents: [first]);
    expect(draft.copyWith(title: 'New').toJson()['contents'], [first.toJson()]);
    expect(
        () => const TripContent(
            title: '', content: '', imageUrls: ['/tmp/photo.jpg']).toJson(),
        throwsFormatException);
    expect(second.toJson().containsKey('mapId'), isFalse);
  });
}
