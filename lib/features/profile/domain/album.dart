import 'package:flutter/foundation.dart';

/// A photo album on a traveller's profile.
///
/// Thin on purpose: the API has no albums endpoint yet (checked 2026-10-21),
/// so this carries only what the grid prints. When one ships, this gains a
/// `fromJson` and the mock list goes away — nothing else on the tab changes.
@immutable
class Album {
  const Album({
    required this.id,
    required this.title,
    required this.cover,
    this.photoCount,
  });

  final String id;
  final String title;

  /// A bundled asset or an `http(s)` URL — [CoverImage] takes either.
  final String cover;

  /// Null hides the count rather than printing a made-up one.
  final int? photoCount;
}

/// Which shelf of albums the sub-tabs are showing.
enum AlbumShelf { personal, shared }

extension AlbumShelfLabel on AlbumShelf {
  String get label => switch (this) {
        AlbumShelf.personal => 'Personal',
        AlbumShelf.shared => 'Share',
      };
}
