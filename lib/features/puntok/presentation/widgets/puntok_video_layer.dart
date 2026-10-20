import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// The clip itself: the still frame, with the video faded in over it once the
/// controller reports a first frame.
///
/// The poster stays mounted underneath rather than being swapped out — a page
/// that is scrolled past before its controller is ready would otherwise flash
/// black, and the clips are 3-8 MB each.
class PuntokVideoLayer extends StatelessWidget {
  const PuntokVideoLayer({
    super.key,
    required this.poster,
    required this.controller,
    this.fallback,
  });

  /// A bundled asset, or an `http(s)` URL for a clip that came from the
  /// server (its first-frame WebP). Null shows [fallback] instead.
  final String? poster;
  final VideoPlayerController? controller;

  /// What sits under the clip when there is no [poster]; black by default.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final player = controller;
    final ready = player != null && player.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        _still(),
        AnimatedOpacity(
          opacity: ready ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: ready ? _cover(player) : const SizedBox.expand(),
        ),
      ],
    );
  }

  Widget _still() {
    final source = poster;
    if (source == null)
      return fallback ?? const ColoredBox(color: Colors.black);
    if (source.startsWith('http')) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
      );
    }
    return Image.asset(source, fit: BoxFit.cover);
  }

  /// Fills the frame the way the poster does. `VideoPlayer` honours its box,
  /// so the aspect ratio has to be imposed from outside it.
  Widget _cover(VideoPlayerController player) {
    final size = player.value.size;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(player),
      ),
    );
  }
}
