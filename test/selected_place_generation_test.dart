import 'package:pluno/core/api/models/trip_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'support/fake_api.dart';

const media = 'aaaaaaaa-0000-4000-8000-000000000001';
const selected = 'c541e08c-32c4-417d-bba8-a2373e48a696';

void main() {
  test('selected internal UUID replaces legacy name and current location',
      () async {
    final adapter = FakeAdapter({
      'POST /trips/t/contents/generate': [
        const FakeReply(200, {
          'contents': [
            {
              'content': 'test',
              'mediaIds': [media],
              'location': {
                'status': 'suggested',
                'name': 'สนามหลวง',
                'placeId': 'ChIJ-google'
              }
            }
          ],
          'locationOptions': [
            {
              'sectionIndex': 0,
              'source': 'confirmedPlace',
              'confidence': 'high',
              'options': [],
              'openingHours': null
            }
          ],
          'currentArea': null,
        }),
      ]
    });
    final api = fakeApi(adapter);
    addTearDown(api.close);
    final draft = await api.trips.generateContents(
      't',
      photos: const [PostAssistantPhoto(mediaId: media)],
      selectedPlaceId: selected,
      locationName: 'ignored',
      currentLat: 13,
      currentLng: 100,
      idempotencyKey: media,
    );
    expect(adapter.requests.single.data, {
      'photos': [
        {'mediaId': media}
      ],
      'selectedPlaceId': selected,
    });
    expect(adapter.requests.single.headers['Idempotency-Key'], media);
    expect(draft.optionsFor(0)!.source, PlaceSource.confirmedPlace);
    expect(draft.optionsFor(0)!.openingHours, isNull);
    expect(draft.contents.single.location!.status,
        ContentLocationStatus.suggested);
    expect(draft.contents.single.location!.placeId, 'ChIJ-google');
    expect(draft.currentArea, isNull);
  });

  test('cleared selection is omitted; Google IDs and blank IDs are rejected',
      () async {
    final adapter = FakeAdapter({
      'POST /trips/t/contents/generate': [const FakeReply(200, {})]
    });
    final api = fakeApi(adapter);
    addTearDown(api.close);
    for (final id in ['', 'ChIJ-google', 'not-a-uuid']) {
      await expectLater(
          api.trips.generateContents(
            't',
            photos: const [PostAssistantPhoto(mediaId: media)],
            selectedPlaceId: id,
          ),
          throwsFormatException);
    }
    expect(adapter.requests, isEmpty);
    await api.trips.generateContents('t',
        photos: const [PostAssistantPhoto(mediaId: media)]);
    expect(
        adapter.requests.single.data.containsKey('selectedPlaceId'), isFalse);
  });
}
