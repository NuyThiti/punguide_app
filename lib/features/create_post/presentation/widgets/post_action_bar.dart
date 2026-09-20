import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'post_block.dart';

/// "+ เพิ่มจุดต่อไป" — the next spot in the same post.
class AddSpotButton extends StatelessWidget {
  const AddSpotButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: Material(
        color: AppColors.screen,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            painter:
                const PostDashedBorder(color: AppColors.postDashed, radius: 16),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 21, color: AppColors.foreground),
                  SizedBox(width: 8),
                  Text(
                    'เพิ่มจุดต่อไป',
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar pinned to the bottom: keep it for later, or share it now.
class PostActionBar extends StatelessWidget {
  const PostActionBar({
    super.key,
    required this.onSaveDraft,
    required this.onShare,
    required this.canShare,
    required this.busy,
  });

  final VoidCallback onSaveDraft;
  final VoidCallback onShare;

  /// Nothing worth sharing yet — the action greys out rather than
  /// disappearing, so its place on the bar stays predictable.
  final bool canShare;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.screen,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: busy ? null : onSaveDraft,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.postDraftBg,
                  foregroundColor: AppColors.foreground,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                ),
                child: const Text(
                  'Save Draft',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: canShare ? onShare : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.postShare,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.postPurpleSoft,
                  disabledForegroundColor: AppColors.postPurple,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
