import 'package:flutter/material.dart';

/// One clip the traveller can put into a Puntok.
///
/// Puntok has no endpoint and the app has no device-library plugin yet, so
/// the picker offers the bundled sample clips the feed already ships with.
/// Swapping in the real library means producing these from it — the screens
/// only read [video], [poster] and [duration].
@immutable
class PuntokClip {
  const PuntokClip({
    required this.id,
    required this.video,
    required this.poster,
    required this.duration,
  });

  final String id;

  /// Asset path of the footage.
  final String video;

  /// Asset path of a still from it, for the grid, the timeline and the cover.
  final String poster;

  final Duration duration;

  @override
  bool operator ==(Object other) => other is PuntokClip && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// What the clip picker offers today.
const puntokSampleClips = <PuntokClip>[
  PuntokClip(
    id: 'clip-osaka',
    video: 'assets/videos/puntok_osaka.mp4',
    poster: 'assets/images/puntok_osaka.jpg',
    duration: Duration(seconds: 5),
  ),
  PuntokClip(
    id: 'clip-beijing',
    video: 'assets/videos/puntok_beijing.mp4',
    poster: 'assets/images/puntok_beijing.jpg',
    duration: Duration(seconds: 5),
  ),
  PuntokClip(
    id: 'clip-seoul',
    video: 'assets/videos/puntok_seoul.mp4',
    poster: 'assets/images/puntok_seoul.jpg',
    duration: Duration(seconds: 5),
  ),
  PuntokClip(
    id: 'clip-london',
    video: 'assets/videos/puntok_london.mp4',
    poster: 'assets/images/puntok_london.jpg',
    duration: Duration(seconds: 5),
  ),
];

/// "0:05", "1:20" — the way the grid and the timeline print a length.
String clipTimeLabel(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Who sees the clip, as the "การมองเห็นโพส" pill offers it.
enum PuntokVisibility {
  public('Public', Icons.public),
  followers('Followers', Icons.group),
  private('Private', Icons.lock);

  const PuntokVisibility(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Who may remix the clip once "เปิดให้ remix" is on.
enum PuntokRemixAudience {
  everyone('ทุกคน', 'ทุกคน Remix ได้เลย', Icons.public),
  followers('คนที่ติดตาม', 'เฉพาะคนที่ติดตามคุณอยู่', Icons.group_outlined),
  withLink('คนที่มีลิงก์', 'ต้องมีลิงก์นี้ถึงจะ remix ได้', Icons.link);

  const PuntokRemixAudience(this.label, this.hint, this.icon);

  final String label;
  final String hint;
  final IconData icon;
}
