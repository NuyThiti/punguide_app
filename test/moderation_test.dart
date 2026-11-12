import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/shared/formatting/moderation_text.dart';

void main() {
  group('Moderation.fromJson', () {
    test('reads the nested shape ApiTrip.moderation carries', () {
      final moderation = Moderation.fromJson({
        'status': 'PENDING',
        'reasonCode': 'UNDER_REVIEW',
        'message': 'Your content is being reviewed.',
        'requestedVisibility': 'public',
        'canAppeal': false,
      });

      expect(moderation.status, ModerationStatus.pending);
      expect(moderation.reasonCode, 'UNDER_REVIEW');
      expect(moderation.requestedVisibility, TripVisibility.public);
      expect(moderation.canAppeal, isFalse);
      // Only GET /trips/:id/moderation and the appeal response carry these.
      expect(moderation.contentId, isNull);
      expect(moderation.visibility, isNull);
    });

    test('reads the full shape GET /trips/:id/moderation carries', () {
      final moderation = Moderation.fromJson({
        'contentId': '6f1c2c1e',
        'status': 'REVIEW_REQUIRED',
        'reasonCode': 'TRAVEL_RELEVANCE_UNCERTAIN',
        'message': 'We need to review this content before publishing.',
        'visibility': 'private',
        'requestedVisibility': 'public',
        'canAppeal': false,
      });

      expect(moderation.contentId, '6f1c2c1e');
      expect(moderation.visibility, TripVisibility.private);
      expect(moderation.status, ModerationStatus.reviewRequired);
    });

    test('an unrecognised status reads as pending rather than throwing', () {
      final moderation = Moderation.fromJson({'status': 'SOMETHING_NEW'});
      expect(moderation.status, ModerationStatus.pending);
    });
  });

  group('ApiTrip.moderation', () {
    test('is null on a draft that was never submitted', () {
      final trip = ApiTrip.fromJson(_tripJson());
      expect(trip.moderation, isNull);
    });

    test('is parsed once a shared post carries one', () {
      final trip = ApiTrip.fromJson({
        ..._tripJson(),
        'visibility': 'private',
        'moderation': {
          'status': 'APPROVED',
          'reasonCode': 'APPROVED',
          'canAppeal': false,
        },
      });
      expect(trip.moderation?.status, ModerationStatus.approved);
    });
  });

  group('ApiException.fromDio', () {
    test('carries moderation off a 422 CONTENT_REJECTED body', () {
      final error = ApiException.fromDio(_dioFailure(
        statusCode: 422,
        body: {
          'statusCode': 422,
          'error': 'CONTENT_REJECTED',
          'message': 'Your content was not approved.',
          'tripId': 'trip-1',
          'moderation': {
            'status': 'REJECTED',
            'reasonCode': 'NOT_TRAVEL_RELATED',
            'canAppeal': true,
          },
        },
      ));

      expect(error.isContentRejected, isTrue);
      expect(error.moderation?.status, ModerationStatus.rejected);
      expect(error.moderation?.canAppeal, isTrue);
    });

    test('a 422 from another endpoint is not read as content-rejected', () {
      // `remixItemsInto` also answers 422, for an unrelated reason (no linked
      // plan) — `isContentRejected` must not fire just because the status
      // code matches.
      final error = ApiException.fromDio(_dioFailure(
        statusCode: 422,
        body: {'statusCode': 422, 'error': 'NO_LINKED_PLAN', 'message': '…'},
      ));

      expect(error.isContentRejected, isFalse);
      expect(error.moderation, isNull);
    });

    test('an ordinary error carries no moderation at all', () {
      final error = ApiException.fromDio(_dioFailure(
        statusCode: 404,
        body: {'statusCode': 404, 'message': 'Not found'},
      ));

      expect(error.isContentRejected, isFalse);
      expect(error.moderation, isNull);
    });
  });

  group('moderationMessage', () {
    test('translates a known reasonCode regardless of its status', () {
      expect(
        moderationMessage(Moderation.fromJson({
          'status': 'REVIEW_REQUIRED',
          'reasonCode': 'DUPLICATE_CONTENT',
        })),
        'โพสต์นี้คล้ายกับที่คุณเคยแชร์แล้ว',
      );
      // The same code, landed as REJECTED instead — same copy either way.
      expect(
        moderationMessage(Moderation.fromJson({
          'status': 'REJECTED',
          'reasonCode': 'DUPLICATE_CONTENT',
        })),
        'โพสต์นี้คล้ายกับที่คุณเคยแชร์แล้ว',
      );
    });

    test('falls back to status-based copy for an unrecognised reasonCode',
        () {
      expect(
        moderationMessage(Moderation.fromJson({
          'status': 'REVIEW_REQUIRED',
          'reasonCode': 'SOME_FUTURE_CODE',
        })),
        'รอทีมงานตรวจสอบ',
      );
    });

    test('falls back to status-based copy when reasonCode is absent', () {
      expect(
        moderationMessage(Moderation.fromJson({'status': 'REJECTED'})),
        'ไม่สามารถเผยแพร่ได้',
      );
    });
  });
}

Map<String, dynamic> _tripJson() => {
      'id': 'trip-1',
      'ownerId': 'u1',
      'title': 'ทริปใหม่',
      'destination': 'ดานัง, เวียดนาม',
      'status': 'draft',
      'schedule': const <String, dynamic>{},
      'totalBudget': 0,
      'visibility': 'private',
      'remixCount': 0,
      'mediaSummary': const <String, dynamic>{},
      'isSaved': false,
      'isLiked': false,
      'likeCount': 0,
      'days': const <Map<String, dynamic>>[],
      'createdAt': '2026-09-09T00:00:00.000Z',
      'updatedAt': '2026-09-09T00:00:00.000Z',
    };

DioException _dioFailure({
  required int statusCode,
  required Map<String, dynamic> body,
}) {
  final requestOptions = RequestOptions(path: '/trips/posts', method: 'PUT');
  return DioException(
    requestOptions: requestOptions,
    response: Response<dynamic>(
      requestOptions: requestOptions,
      statusCode: statusCode,
      data: body,
    ),
    type: DioExceptionType.badResponse,
  );
}
