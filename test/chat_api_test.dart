import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/pluno_api.dart';

import 'support/fake_api.dart';

/// One SSE turn, written the way the server writes it: records separated by a
/// blank line, a keep-alive comment, and one `data:` split across two lines.
const _stream = ''
    'event: accepted\n'
    'data: {"conversationId":"room-1","messageId":"msg-2","userMessageId":"msg-1"}\n'
    '\n'
    ': keep-alive\n'
    '\n'
    'event: status\n'
    'data: {"stage":"drafting_itinerary"}\n'
    '\n'
    'event: block\n'
    'data: {"type":"trip_results","totalMatches":9,\n'
    'data: "trips":[{"tripId":"t1","title":"เชียงใหม่ชิล ๆ"}]}\n'
    '\n'
    'event: sparkle\n'
    'data: {"unknown":"kind"}\n'
    '\n'
    'event: text\n'
    'data: {"text":"เจอสามทริปครับ"}\n'
    '\n'
    'event: complete\n'
    'data: {"schemaVersion":1,"conversationId":"room-1","messageId":"msg-2",'
    '"status":"complete","text":"เจอสามทริปครับ","blocks":[],'
    '"suggestedReplies":["ขอแบบไม่เดินเยอะ"],"warnings":[],"error":null}\n';

PlunoApi _api(FakeAdapter adapter) => fakeApi(adapter);

void main() {
  group('block parsing', () {
    test('an unfamiliar block type is kept as unknown, not thrown away',
        () {
      final blocks = ChatBlock.listFrom(<dynamic>[
        <String, dynamic>{'type': 'trip_results', 'trips': <dynamic>[]},
        <String, dynamic>{'type': 'weather_forecast'},
      ]);

      expect(blocks, hasLength(2));
      expect(blocks.first, isA<TripResultsBlock>());
      expect(blocks.last, isA<UnknownChatBlock>());
      expect((blocks.last as UnknownChatBlock).type, 'weather_forecast');
    });

    test('missing numbers stay null rather than becoming zero', () {
      final trip = ChatTripResult.fromJson(<String, dynamic>{
        'tripId': 't1',
        'title': 'ทริป',
      });

      expect(trip.estimatedCost, isNull);
      expect(trip.placeCount, isNull);
      expect(trip.likeCount, isNull);

      final place = ChatPlaceResult.fromJson(<String, dynamic>{
        'placeId': 'p1',
        'name': 'ร้านกาแฟ',
      });
      expect(place.rating, isNull);
      expect(place.distanceKm, isNull);
    });

    test('the cautious flags default to true when the field is absent', () {
      final stop = ChatItineraryStop.fromJson(<String, dynamic>{'name': 'วัด'});
      expect(stop.travelTimeIsEstimate, isTrue);

      final plan = ItineraryPreviewBlock.fromJson(<String, dynamic>{
        'draftId': 'd1',
        'title': 'เชียงใหม่',
      });
      expect(plan.feasibilityUnverified, isTrue);

      final error = ChatTurnError.fromJson(<String, dynamic>{
        'code': 'brand_new_code',
        'message': 'อะไรสักอย่าง',
      });
      expect(error.retryable, isTrue);
      expect(error.code, ChatErrorCode.unknown);
    });

    test('a draft id is never mistaken for a trip id', () {
      final plan = ItineraryPreviewBlock.fromJson(<String, dynamic>{
        'draftId': 'draft-7',
        'draftRevision': 2,
        'title': 'เชียงใหม่',
        'action': <String, dynamic>{
          'type': 'open_draft',
          'entityId': 'draft-7',
          'revision': 2,
        },
      });

      expect(plan.draftId, 'draft-7');
      expect(plan.draftRevision, 2);
      expect(plan.action!.type, ChatActionType.openDraft);
      expect(plan.action!.revision, 2);
    });
  });

  group('streaming', () {
    test('decodes records, spans split data lines, skips comments and '
        'unknown events', () async {
      final adapter = FakeAdapter(<String, List<FakeReply>>{
        'POST /chat/conversations/room-1/messages': [
          const FakeReply.text(200, _stream),
        ],
      });

      final events = await _api(adapter)
          .chat
          .streamMessage('room-1', text: 'หาทริปเชียงใหม่', requestId: 'r1')
          .toList();

      expect(
        events.map((e) => e.runtimeType.toString()),
        <String>[
          'ChatAcceptedEvent',
          'ChatStageEvent',
          'ChatBlockEvent',
          'ChatTextEvent',
          'ChatCompleteEvent',
        ],
      );

      final accepted = events.first as ChatAcceptedEvent;
      expect(accepted.messageId, 'msg-2');
      expect(accepted.userMessageId, 'msg-1');

      expect((events[1] as ChatStageEvent).stage, ChatStage.draftingItinerary);

      // The block's data was split across two `data:` lines and still parses.
      final block = (events[2] as ChatBlockEvent).block as TripResultsBlock;
      expect(block.totalMatches, 9);
      expect(block.trips.single.title, 'เชียงใหม่ชิล ๆ');

      final done = events.last as ChatCompleteEvent;
      expect(done.turn.status, ChatTurnStatus.complete);
      expect(done.turn.suggestedReplies, ['ขอแบบไม่เดินเยอะ']);
    });

    test('the last record still arrives without a trailing blank line',
        () async {
      final adapter = FakeAdapter(<String, List<FakeReply>>{
        'POST /chat/conversations/room-1/messages': [
          const FakeReply.text(
            200,
            'event: text\ndata: {"text":"จบแล้ว"}\n',
          ),
        ],
      });

      final events = await _api(adapter)
          .chat
          .streamMessage('room-1', text: 'ว่าไง')
          .toList();

      expect((events.single as ChatTextEvent).text, 'จบแล้ว');
    });

    test('asks for the event stream and carries the request id', () async {
      final adapter = FakeAdapter(<String, List<FakeReply>>{
        'POST /chat/conversations/room-1/messages': [
          const FakeReply.text(200, 'event: text\ndata: {"text":"ok"}\n'),
        ],
      });

      await _api(adapter)
          .chat
          .streamMessage(
            'room-1',
            text: 'สวัสดี',
            requestId: 'r-9',
            origin: const ChatOrigin(
              latitude: 18.78,
              longitude: 98.98,
              label: 'นิมมานเหมินท์',
            ),
          )
          .toList();

      final request = adapter.requests.single;
      expect(request.headers['Accept'], 'text/event-stream');
      expect(request.data['requestId'], 'r-9');
      expect(request.data['origin'], <String, dynamic>{
        'lat': 18.78,
        'lng': 98.98,
        'label': 'นิมมานเหมินท์',
      });
    });
  });

  group('turns and drafts', () {
    test('a failed turn is a 200 with an error, not an exception', () async {
      final adapter = FakeAdapter(<String, List<FakeReply>>{
        'POST /chat/conversations/room-1/messages': [
          const FakeReply(200, <String, dynamic>{
            'schemaVersion': 1,
            'conversationId': 'room-1',
            'messageId': 'msg-9',
            'status': 'failed',
            'text': null,
            'blocks': <dynamic>[],
            'error': <String, dynamic>{
              'code': 'provider_unavailable',
              'message': 'ผู้ช่วยไม่ว่างชั่วคราว',
              'retryable': true,
            },
          }),
        ],
      });

      final turn =
          await _api(adapter).chat.sendMessage('room-1', text: 'สวัสดี');

      expect(turn.failed, isTrue);
      expect(turn.error!.code, ChatErrorCode.providerUnavailable);
      expect(turn.error!.retryable, isTrue);
    });

    test('saving a draft sends the revision that is on screen', () async {
      final adapter = FakeAdapter(<String, List<FakeReply>>{
        'POST /chat/conversations/room-1/drafts/draft-7/save': [
          const FakeReply(201, <String, dynamic>{
            'tripId': 'trip-3',
            'alreadySaved': true,
          }),
        ],
      });

      final result = await _api(adapter)
          .chat
          .saveDraft('room-1', 'draft-7', revision: 2);

      expect(result.tripId, 'trip-3');
      // Saving the same revision twice is a success, not a conflict.
      expect(result.alreadySaved, isTrue);
      expect(
        adapter.bodyOf('POST /chat/conversations/room-1/drafts/draft-7/save'),
        <String, dynamic>{'revision': 2},
      );
    });
  });
}
