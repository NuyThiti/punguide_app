import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/models/puntok_post.dart';
import 'puntok_action_rail.dart';
import 'puntok_video_layer.dart';

/// One page of the Puntok feed: the clip full-bleed, a scrim at each end so
/// the chrome stays legible, the action rail on the right and the creator plus
/// caption along the bottom.
class PuntokPostView extends StatelessWidget {
  const PuntokPostView({
    super.key,
    required this.post,
    required this.controller,
    required this.paused,
    required this.bottomInset,
    required this.onTogglePlay,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
    required this.onCreator,
    required this.onFollow,
  });

  final PuntokPost post;
  final VideoPlayerController? controller;

  /// Whether the traveller tapped to hold the clip — draws the play glyph.
  final bool paused;

  /// Room the bottom nav takes, so the rail and caption clear it.
  final double bottomInset;

  final VoidCallback onTogglePlay;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onCreator;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTogglePlay,
          child: PuntokVideoLayer(poster: post.poster, controller: controller),
        ),
        const _Scrim(alignment: Alignment.topCenter, extent: 0.28),
        const _Scrim(alignment: Alignment.bottomCenter, extent: 0.42),
        if (paused)
          const Center(
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white70,
              size: 76,
            ),
          ),
        Positioned(
          right: 12,
          bottom: bottomInset + 8,
          child: PuntokActionRail(
            post: post,
            onLike: onLike,
            onComment: onComment,
            onSave: onSave,
            onShare: onShare,
            onAvatar: onCreator,
            onFollow: onFollow,
          ),
        ),
        Positioned(
          left: 16,
          right: 16 + PuntokActionRail.discSize + 16,
          bottom: bottomInset + 12,
          child: _CreatorBlock(
            post: post,
            onCreator: onCreator,
            onFollow: onFollow,
          ),
        ),
      ],
    );
  }
}

class _CreatorBlock extends StatelessWidget {
  const _CreatorBlock({
    required this.post,
    required this.onCreator,
    required this.onFollow,
  });

  final PuntokPost post;
  final VoidCallback onCreator;
  final VoidCallback onFollow;

  static const _shadow = <Shadow>[
    Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: GestureDetector(
                onTap: onCreator,
                child: Text(
                  post.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    shadows: _shadow,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _FollowChip(following: post.following, onTap: onFollow),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          post.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w500,
            shadows: _shadow,
          ),
        ),
      ],
    );
  }
}

class _FollowChip extends StatelessWidget {
  const _FollowChip({required this.following, required this.onTap});

  final bool following;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
        ),
        child: Text(
          following ? 'กำลังติดตาม' : 'ติดตาม',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Keeps white chrome readable over a bright frame.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.alignment, required this.extent});

  final Alignment alignment;

  /// Share of the page height the gradient covers.
  final double extent;

  @override
  Widget build(BuildContext context) {
    final top = alignment == Alignment.topCenter;

    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: FractionallySizedBox(
          heightFactor: extent,
          widthFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
