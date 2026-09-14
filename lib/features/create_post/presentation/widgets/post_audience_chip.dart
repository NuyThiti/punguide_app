import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/post_draft.dart';
import 'composer_sheet.dart';

/// The pill under the author's name: who will see the post.
class PostAudienceChip extends StatelessWidget {
  const PostAudienceChip({
    super.key,
    required this.audience,
    required this.onTap,
  });

  final PostAudience audience;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.screen,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.chipBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(audience.icon, size: 15, color: AppColors.foreground),
              const SizedBox(width: 6),
              Text(
                audience.label,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppColors.foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks who the post is for. Returns null when dismissed.
Future<PostAudience?> showAudiencePicker(
  BuildContext context,
  PostAudience current,
) {
  return showModalBottomSheet<PostAudience>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => ComposerSheet(
      title: 'ใครเห็นโพสต์นี้',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: PostAudience.values.map((audience) {
          final chosen = audience == current;
          return ListTile(
            onTap: () => Navigator.of(context).pop(audience),
            contentPadding: EdgeInsets.zero,
            leading: Icon(audience.icon, size: 21, color: AppColors.foreground),
            title: Text(
              audience.label,
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: chosen
                ? const Icon(
                    Icons.check_circle,
                    size: 20,
                    color: AppColors.brandOrange,
                  )
                : null,
          );
        }).toList(),
      ),
    ),
  );
}
