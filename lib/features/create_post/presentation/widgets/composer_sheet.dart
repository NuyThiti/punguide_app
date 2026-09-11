import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The shell every composer sheet shares: a handle, a title, and a body that
/// keeps clear of the keyboard and the home indicator.
class ComposerSheet extends StatelessWidget {
  const ComposerSheet({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

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
            Text(
              title,
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
