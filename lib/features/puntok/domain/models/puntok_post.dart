import 'package:flutter/foundation.dart';

import '../../../../core/api/pluno_api.dart';

/// The `type` a Puntok is stored and listed as.
///
/// `content` until the server accepts `puntok` — on 2026-10-20 `GET /trips`
/// answered `type=puntok` with a 400 ("must be one of plan_trip, content").
/// Change this one line to [TripType.puntok] once it ships: the feed queries
/// it, and Create Puntok starts sending it.
const puntokTripType = TripType.content;

/// Which of the three Puntok feeds is showing.
enum PuntokFeed { topPunGuide, forYou, following }

extension PuntokFeedLabel on PuntokFeed {
  String get label => switch (this) {
        PuntokFeed.topPunGuide => 'Top Punguide',
        PuntokFeed.forYou => 'For you',
        PuntokFeed.following => 'Following',
      };
}

/// One full-screen clip in the Puntok feed: a [puntokTripType] post from
/// `GET /trips` whose cover is a video.
@immutable
class PuntokPost {
  const PuntokPost({
    required this.id,
    required this.video,
    required this.author,
    required this.caption,
    required this.likes,
    this.poster,
    this.authorAvatar,
    this.comments,
    this.saves,
    this.shares,
    this.liked = false,
    this.saved = false,
    this.following = false,
    this.linkedTrip,
  });

  /// The row as a clip, or null when its cover is not a playable video —
  /// the feed also carries ordinary photo posts, which are not Puntoks.
  static PuntokPost? fromListItem(TripListItem item) {
    final cover = item.coverImage;
    final video = cover?.urls.original;
    if (cover == null || !cover.isVideo || video == null) return null;
    final blurb = item.description?.trim() ?? '';
    return PuntokPost(
      id: item.id,
      video: video,
      poster: cover.stillUrl,
      author: item.creator?.name ?? '',
      authorAvatar: item.creator?.avatarUrl,
      caption: blurb.isEmpty ? item.title : blurb,
      likes: item.likeCount,
      liked: item.isLiked,
      saved: item.isSaved,
      linkedTrip: item.linkedTrip,
    );
  }

  /// The post's id — a trip id, so `/trips/:id` opens it.
  final String id;

  /// The clip: an `http(s)` URL from the server, or a bundled asset path.
  final String video;

  /// A still shown under the clip until it plays; null draws black.
  final String? poster;

  final String author;

  /// An `http(s)` URL or a bundled asset; null draws a placeholder.
  final String? authorAvatar;
  final String caption;

  final int likes;

  /// Counts the list endpoint does not send — null hides the number.
  final int? comments;
  final int? saves;
  final int? shares;

  final bool liked;
  final bool saved;

  /// There is no follow API yet, so this is never true from the server.
  final bool following;

  /// The แผนทริป card under the caption; null hides it.
  final LinkedTrip? linkedTrip;

  PuntokPost copyWith({
    int? likes,
    bool? liked,
    bool? saved,
  }) {
    return PuntokPost(
      id: id,
      video: video,
      poster: poster,
      author: author,
      authorAvatar: authorAvatar,
      caption: caption,
      likes: likes ?? this.likes,
      comments: comments,
      saves: saves,
      shares: shares,
      liked: liked ?? this.liked,
      saved: saved ?? this.saved,
      following: following,
      linkedTrip: linkedTrip,
    );
  }
}
