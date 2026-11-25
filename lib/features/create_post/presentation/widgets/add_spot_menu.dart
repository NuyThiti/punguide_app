import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'composer_sheet.dart';

/// What the "+" button's menu was asked for.
enum AddSpotChoice {
  /// "เพิ่มหัวข้อ" — reveals the spot's own heading row, hidden until asked
  /// for since a title is ไม่บังคับ.
  heading,

  /// "เพิ่มเนื้อหา" — another content item under the current spot's own
  /// heading.
  content,

  /// "เพิ่มจุดถัดไป" — a whole new spot/section of its own.
  nextSpot,
}

/// The menu behind the composer's "+" button. Returns null when dismissed.
///
/// "เพิ่มหัวข้อ" only shows while the heading row is still hidden
/// ([headingShown] false) — once it's on screen, asking for it again would
/// do nothing. "เพิ่มเนื้อหา" only makes sense once the spot actually has a
/// heading to group items under — [hasHeading] hides it otherwise, leaving
/// just the other two choices.
Future<AddSpotChoice?> showAddSpotMenu(
  BuildContext context, {
  required bool headingShown,
  required bool hasHeading,
}) {
  return showModalBottomSheet<AddSpotChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => ComposerSheet(
      title: 'เพิ่ม',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!headingShown)
            _AddSpotMenuTile(
              icon: Icons.title,
              label: 'เพิ่มหัวข้อ',
              onTap: () => Navigator.of(context).pop(AddSpotChoice.heading),
            ),
          if (hasHeading)
            _AddSpotMenuTile(
              icon: Icons.post_add,
              label: 'เพิ่มเนื้อหา',
              onTap: () => Navigator.of(context).pop(AddSpotChoice.content),
            ),
          _AddSpotMenuTile(
            icon: Icons.add_location_alt_outlined,
            label: 'เพิ่มจุดถัดไป',
            onTap: () => Navigator.of(context).pop(AddSpotChoice.nextSpot),
          ),
        ],
      ),
    ),
  );
}

class _AddSpotMenuTile extends StatelessWidget {
  const _AddSpotMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 21, color: AppColors.postPurple),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.foreground,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
