import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../domain/puntok_clip.dart';

/// One paused player per picked clip, sitting on its first frame.
///
/// There is no thumbnail package, so a clip's still is the video itself,
/// paused. The same player is drawn in the grid, the tray, the timeline and
/// the cover sheet — a texture can be shown in several places — and reading
/// it once is also how a pick learns its length.
///
/// Auto-disposed: the players go when the last screen or sheet showing a
/// still does.
final puntokClipStillsProvider =
    ChangeNotifierProvider.autoDispose<PuntokClipStills>(
  (ref) => PuntokClipStills(),
);

class PuntokClipStills extends ChangeNotifier {
  final _players = <String, VideoPlayerController>{};
  bool _disposed = false;

  /// Opens [path] and returns its length, or null when the file will not
  /// decode (and under `flutter test`, where there is no video plugin).
  Future<Duration?> load(String id, String path) async {
    final player = VideoPlayerController.file(File(path));
    try {
      await player.initialize();
      await player.setVolume(0);
    } catch (_) {
      // Not awaited: a player that never started can take its time going,
      // and the pick should not wait on it.
      player.dispose();
      return null;
    }
    if (_disposed) {
      player.dispose();
      return null;
    }
    _players.remove(id)?.dispose();
    _players[id] = player;
    notifyListeners();
    return player.value.duration;
  }

  VideoPlayerController? of(String id) {
    final player = _players[id];
    return player != null && player.value.isInitialized ? player : null;
  }

  void drop(String id) {
    final player = _players.remove(id);
    if (player == null) return;
    notifyListeners();
    player.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
    super.dispose();
  }
}

/// A clip's still, filling its box: the asset poster when it has one, the
/// paused first frame once loaded, a dark tile with a film icon until then.
class PuntokClipStill extends ConsumerWidget {
  const PuntokClipStill({super.key, required this.clip});

  final PuntokClip clip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poster = clip.poster;
    if (poster != null) return Image.asset(poster, fit: BoxFit.cover);

    final player = ref.watch(puntokClipStillsProvider).of(clip.id);
    if (player == null) {
      return const ColoredBox(
        color: Color(0xFF2B2B2E),
        child: Center(
          child: Icon(Icons.movie_outlined, color: Colors.white54, size: 22),
        ),
      );
    }
    final size = player.value.size;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(player),
        ),
      ),
    );
  }
}
