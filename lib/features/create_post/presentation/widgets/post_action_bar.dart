import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A bare "+" — opens the menu between "เพิ่มเนื้อหา" (another item under
/// this spot) and "เพิ่มจุดถัดไป" (a whole new spot), rather than doing
/// either one itself.
class AddMenuButton extends StatelessWidget {
  const AddMenuButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A filled circle, same height as the two pills beside it on the bar —
    // a dashed square read as an empty placeholder next to them.
    return SizedBox(
      height: 52,
      width: 52,
      child: Material(
        color: AppColors.postDraftBg,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const Center(
            child: Icon(Icons.add, size: 24, color: AppColors.foreground),
          ),
        ),
      ),
    );
  }
}

/// The bar pinned to the bottom: add another spot, keep it for later, or
/// share it now.
class PostActionBar extends StatelessWidget {
  const PostActionBar({
    super.key,
    required this.onAddSpot,
    required this.onSaveDraft,
    required this.onShare,
    required this.canShare,
    required this.busy,
  });

  /// Null hides the "+" — the same spot-must-have-something condition the
  /// button has always used, decided by the caller.
  final VoidCallback? onAddSpot;

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
          if (onAddSpot != null) ...[
            AddMenuButton(onTap: onAddSpot!),
            const SizedBox(width: 12),
          ],
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
