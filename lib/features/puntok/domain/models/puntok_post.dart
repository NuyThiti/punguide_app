import 'package:flutter/foundation.dart';

/// Which of the three Puntok feeds is showing.
enum PuntokFeed { topPunGuide, forYou, following }

extension PuntokFeedLabel on PuntokFeed {
  String get label => switch (this) {
        PuntokFeed.topPunGuide => 'Top Punguide',
        PuntokFeed.forYou => 'For you',
        PuntokFeed.following => 'Following',
      };
}

/// One full-screen clip in the Puntok feed.
///
/// Puntok has no endpoint yet, so posts come from
/// `lib/features/puntok/data/puntok_mock_posts.dart` and the like / save /
/// follow toggles live in memory for the session.
@immutable
class PuntokPost {
  const PuntokPost({
    required this.id,
    required this.video,
    required this.poster,
    required this.author,
    required this.authorAvatar,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.shares,
    this.liked = false,
    this.saved = false,
    this.following = false,
  });

  final String id;

  /// Asset path of the clip, played muted-looping while the page is in view.
  final String video;

  /// Still frame shown under the clip, so a page never opens on black.
  final String poster;

  final String author;
  final String authorAvatar;
  final String caption;

  final int likes;
  final int comments;
  final int saves;
  final int shares;

  final bool liked;
  final bool saved;
  final bool following;

  PuntokPost copyWith({
    int? likes,
    int? saves,
    bool? liked,
    bool? saved,
    bool? following,
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
      saves: saves ?? this.saves,
      shares: shares,
      liked: liked ?? this.liked,
      saved: saved ?? this.saved,
      following: following ?? this.following,
    );
  }
}
