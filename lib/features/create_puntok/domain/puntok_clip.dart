import 'package:flutter/material.dart';

import '../../../core/api/pluno_api.dart';

/// One video file the traveller picked for a Puntok.
///
/// The app has no device-library plugin, so clips come from the system
/// picker (`image_picker`) as files on disk; each one is uploaded to
/// `POST /media` as it is when the post is saved — the server keeps the file
/// as uploaded and does no transcoding.
@immutable
class PuntokClip {
  const PuntokClip({
    required this.id,
    required this.path,
    this.duration,
    this.sizeBytes,
    this.poster,
  });

  final String id;

  /// The file on disk.
  final String path;

  /// Read off the file once it has been probed; null when it could not be.
  final Duration? duration;
  final int? sizeBytes;

  /// An asset still to show in place of the file's first frame. Real picks
  /// leave it null and show the frame itself.
  final String? poster;

  @override
  bool operator ==(Object other) => other is PuntokClip && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// What `POST /media` accepts for a video, checked before uploading so a
/// clip that would bounce says so at pick time rather than at Share.
abstract final class PuntokClipLimits {
  static const maxBytes = 50 * 1024 * 1024;
  static const maxLength = Duration(seconds: 60);

  /// A section's `mediaIds` hold at most 20.
  static const maxClips = 20;

  static const extensions = {'mp4', 'mov', 'm4v'};
}

/// "0:05", "1:20" — the way the grid and the timeline print a length.
String clipTimeLabel(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Who sees the clip, as the "การมองเห็นโพส" pill offers it.
enum PuntokVisibility {
  public('Public', Icons.public, TripVisibility.public),
  followers('Followers', Icons.group, TripVisibility.followers),
  private('Private', Icons.lock, TripVisibility.private);

  const PuntokVisibility(this.label, this.icon, this.wire);

  final String label;
  final IconData icon;

  /// What goes up as the post's `visibility`.
  final TripVisibility wire;
}

/// Who may remix the clip once "เปิดให้ remix" is on.
enum PuntokRemixAudience {
  everyone('ทุกคน', 'ทุกคน Remix ได้เลย', Icons.public, RemixAudience.everyone),
  followers('คนที่ติดตาม', 'เฉพาะคนที่ติดตามคุณอยู่', Icons.group_outlined,
      RemixAudience.followers),
  withLink('คนที่มีลิงก์', 'ต้องมีลิงก์นี้ถึงจะ remix ได้', Icons.link,
      RemixAudience.link);

  const PuntokRemixAudience(this.label, this.hint, this.icon, this.wire);

  final String label;
  final String hint;
  final IconData icon;

  /// What goes up as the post's `remixAudience`.
  final RemixAudience wire;
}
