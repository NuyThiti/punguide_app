import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/puntok_post.dart';

/// Right-hand column of a Puntok card: the creator's avatar with its follow
/// badge, then like, comment, save and share — each a translucent disc with
/// its count underneath (Figma "Puntok" board).
class PuntokActionRail extends StatelessWidget {
  const PuntokActionRail({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
    required this.onAvatar,
    required this.onFollow,
  });

  final PuntokPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onAvatar;
  final VoidCallback onFollow;

  static const double discSize = 44;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Avatar(post: post, onTap: onAvatar, onFollow: onFollow),
        const SizedBox(height: 18),
        _RailAction(
          icon: post.liked ? Icons.favorite : Icons.favorite_border,
          tint: post.liked ? AppColors.brandOrange : Colors.white,
          count: post.likes,
          onTap: onLike,
        ),
        const SizedBox(height: 14),
        _RailAction(
          icon: Icons.chat_bubble_outline,
          count: post.comments,
          onTap: onComment,
        ),
        const SizedBox(height: 14),
        _RailAction(
          icon: post.saved ? Icons.bookmark : Icons.bookmark_border,
          tint: post.saved ? AppColors.brandOrange : Colors.white,
          count: post.saves,
          onTap: onSave,
        ),
        const SizedBox(height: 14),
        _RailAction(
          icon: Icons.share,
          count: post.shares,
          onTap: onShare,
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.post, required this.onTap, required this.onFollow});

  final PuntokPost post;
  final VoidCallback onTap;
  final VoidCallback onFollow;

  static const double _size = 48;
  static const double _badge = 20;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      // Room for the badge that overhangs the bottom edge.
      height: _size + _badge / 2,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                image: DecorationImage(
                  image: AssetImage(post.authorAvatar),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: GestureDetector(
              onTap: onFollow,
              child: Container(
                width: _badge,
                height: _badge,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.createTop, AppColors.brandOrangeDeep],
                  ),
                ),
                child: Icon(
                  post.following ? Icons.check : Icons.add,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.count,
    required this.onTap,
    this.tint = Colors.white,
  });

  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: PuntokActionRail.discSize,
            height: PuntokActionRail.discSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.28),
            ),
            child: Icon(icon, color: tint, size: 22),
          ),
          const SizedBox(height: 5),
          Text(
            formatPuntokCount(count),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thousands separators, as the design writes them ("5,597").
String formatPuntokCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
