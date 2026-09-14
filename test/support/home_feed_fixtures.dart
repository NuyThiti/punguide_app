import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/core/api/api_providers.dart';
import 'package:pluno/features/home/presentation/providers/home_feed_providers.dart';

import 'fake_api.dart';

/// A feed row with every optional field present. Pass nulls to exercise the
/// degraded shapes the API is documented to return.
TripListItem feedTrip({
  String id = 'trip-1',
  String title = 'หลวงพระบาง 3 วัน 2 คืน',
  String destination = 'หลวงพระบาง, ลาว',
  String? country = 'ลาว',
  double? latitude,
  double? longitude,
  int? durationDays = 3,
  double totalBudget = 3000,
  String? coverUrl = 'https://example.test/cover.jpg',
  String? creatorName = 'makitravels',
  bool isSaved = false,
  int likeCount = 127,
  int remixCount = 127,
  double? distanceKm,
}) =>
    TripListItem.fromJson(feedTripJson(
      id: id,
      title: title,
      destination: destination,
      country: country,
      latitude: latitude,
      longitude: longitude,
      durationDays: durationDays,
      totalBudget: totalBudget,
      coverUrl: coverUrl,
      creatorName: creatorName,
      isSaved: isSaved,
      likeCount: likeCount,
      remixCount: remixCount,
      distanceKm: distanceKm,
    ));

/// The same row as raw JSON, for a test that answers `GET /trips` through
/// [FakeAdapter] rather than overriding a provider.
Map<String, dynamic> feedTripJson({
  String id = 'trip-1',
  String title = 'หลวงพระบาง 3 วัน 2 คืน',
  String destination = 'หลวงพระบาง, ลาว',
  String? country = 'ลาว',
  double? latitude,
  double? longitude,
  int? durationDays = 3,
  double totalBudget = 3000,
  String? coverUrl = 'https://example.test/cover.jpg',
  String? creatorName = 'makitravels',
  bool isSaved = false,
  int likeCount = 127,
  int remixCount = 127,
  double? distanceKm,
}) {
  return <String, dynamic>{
    'id': id,
    'title': title,
    'destination': destination,
    if (country != null)
      'destinationPlace': <String, dynamic>{
        'name': destination,
        'country': country,
        // Only sent once the backend has resolved the place, so a row without
        // them is the shape a card has to degrade to.
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    'status': 'draft',
    'schedule': <String, dynamic>{
      if (durationDays != null) 'durationDays': durationDays,
    },
    'totalBudget': totalBudget,
    'tags': <String>['culture'],
    if (coverUrl != null)
      'coverImage': <String, dynamic>{
        'mediaId': 'm-$id',
        'urls': <String, dynamic>{'large': coverUrl, 'thumbnail': coverUrl},
      },
    if (creatorName != null)
      'creator': <String, dynamic>{'id': 'u-$id', 'name': creatorName},
    'isSaved': isSaved,
    'isLiked': false,
    'likeCount': likeCount,
    'remixCount': remixCount,
    // The server only measures when the request carried both coordinates.
    if (distanceKm != null) 'distanceKm': distanceKm,
    'createdAt': '2026-09-01T00:00:00.000Z',
    'updatedAt': '2026-09-01T00:00:00.000Z',
  };
}

/// Overrides that let the Home screen render without a server: a canned feed
/// and an [AuthController] with no API behind it.
List<Override> homeOverrides(
  List<TripListItem> trips, {
  AuthSession? session = AuthSession.demo,
}) {
  return <Override>[
    homeFeedProvider.overrideWith(() => _StubHomeFeed(trips)),
    authSessionProvider.overrideWith((ref) => AuthController(session)),
  ];
}

class _StubHomeFeed extends HomeFeedNotifier {
  _StubHomeFeed(this._trips);

  final List<TripListItem> _trips;

  @override
  Future<List<TripListItem>> build() async => _trips;

  @override
  Future<void> refresh() async {}
}

/// Overrides that let the ไปกัน board run without a server.
///
/// Unlike [homeOverrides] this goes in at the transport, not at the provider:
/// the board's whole job now is the query string it builds, so a test has to
/// see the request rather than be handed the answer.
List<Override> paigunOverrides(
  FakeAdapter adapter, {
  AuthSession? session = AuthSession.demo,
}) {
  return <Override>[
    plunoApiProvider.overrideWith((ref) async => fakeApi(adapter)),
    authSessionProvider.overrideWith((ref) => AuthController(session)),
  ];
}

/// A `GET /trips` that answers every wall with [rows].
FakeAdapter feedAdapter(List<Map<String, dynamic>> rows) => FakeAdapter(
      <String, List<FakeReply>>{
        'GET /trips': <FakeReply>[FakeReply(200, rows)],
      },
    );
