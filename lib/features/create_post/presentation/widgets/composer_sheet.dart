import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The shell every composer sheet shares: a handle, a title, and a body that
/// keeps clear of the keyboard and the home indicator.
class ComposerSheet extends StatelessWidget {
  const ComposerSheet({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
  });

  final String title;
  final Widget child;

  /// A close chip beside the title instead of relying on the drag handle
  /// alone (Figma 2480-80871's "เพิ่มรูป"). Sheets that don't pass this keep
  /// their plain title, unchanged.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    // Material rather than a decorated box: these sheets are full of
    // ListTiles, which paint their ink on the nearest Material ancestor and
    // assert when a coloured box sits in between.
    return Material(
      color: AppColors.screen,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          18 +
              MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D6D1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            if (onClose == null)
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              )
            else
              Row(
                children: [
                  const SizedBox(width: 30),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.foreground,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Material(
                    color: AppColors.postCloseChip,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onClose,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 30,
                        height: 30,
                        child: Icon(Icons.close,
                            size: 19, color: AppColors.foreground),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
