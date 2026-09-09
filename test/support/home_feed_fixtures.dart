import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pluno/core/api/pluno_api.dart';
import 'package:pluno/features/auth/domain/auth_session.dart';
import 'package:pluno/features/auth/presentation/providers/auth_providers.dart';
import 'package:pluno/features/home/presentation/providers/home_feed_providers.dart';

/// A feed row with every optional field present. Pass nulls to exercise the
/// degraded shapes the API is documented to return.
TripListItem feedTrip({
  String id = 'trip-1',
  String title = 'หลวงพระบาง 3 วัน 2 คืน',
  String destination = 'หลวงพระบาง, ลาว',
  String? country = 'ลาว',
  int? durationDays = 3,
  double totalBudget = 3000,
  String? coverUrl = 'https://example.test/cover.jpg',
  String? creatorName = 'makitravels',
  bool isSaved = false,
  int likeCount = 127,
  int remixCount = 127,
}) {
  return TripListItem.fromJson(<String, dynamic>{
    'id': id,
    'title': title,
    'destination': destination,
    if (country != null)
      'destinationPlace': <String, dynamic>{
        'name': destination,
        'country': country
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
    'createdAt': '2026-09-01T00:00:00.000Z',
    'updatedAt': '2026-09-01T00:00:00.000Z',
  });
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
