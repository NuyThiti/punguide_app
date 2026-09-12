import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../auth/domain/auth_session.dart';
import '../../domain/models/post_draft.dart';
import 'post_audience_chip.dart';

/// The composer's top bar: close, title, and เผยแพร่ as a text action.
class CreatePostHeader extends StatelessWidget {
  const CreatePostHeader({
    super.key,
    required this.onClose,
    required this.onPublish,
    required this.canPublish,
  });

  final VoidCallback onClose;
  final VoidCallback onPublish;

  /// Nothing worth publishing yet — the action greys out rather than
  /// disappearing, so its place on the bar stays predictable.
  final bool canPublish;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 26),
            color: AppColors.foreground,
            tooltip: 'ปิด',
          ),
          const Expanded(
            child: Text(
              'สร้างโพสต์',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: canPublish ? onPublish : null,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.createTop,
              disabledForegroundColor: const Color(0xFFD9B3A6),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 44),
            ),
            child: const Text(
              'ปันไกด์',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Who is posting, and who will see it.
class PostAuthorRow extends StatelessWidget {
  const PostAuthorRow({
    super.key,
    required this.session,
    required this.audience,
    required this.onChangeAudience,
  });

  /// Null while signed out — the guest path still reaches the composer, so the
  /// avatar falls back to a placeholder rather than blowing up.
  final AuthSession? session;

  final PostAudience audience;
  final VoidCallback onChangeAudience;

  @override
  Widget build(BuildContext context) {
    final avatar = session?.avatarImage;
    final name = session?.displayName ?? 'ผู้ใช้ PunGuide';

    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: AppColors.postField,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: avatar == null || avatar.isEmpty
                ? const Icon(
                    Icons.person,
                    size: 30,
                    color: AppColors.muted,
                  )
                : CoverImage(source: avatar),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              PostAudienceChip(
                audience: audience,
                onTap: onChangeAudience,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
