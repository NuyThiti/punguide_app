import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// One row of [showActionSheet].
class ActionSheetItem<T> {
  const ActionSheetItem({
    required this.value,
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final T value;
  final IconData icon;
  final String label;

  /// Drawn in the warning orange-red — ลบทริป and the like.
  final bool destructive;
}

/// A short list of actions sliding up from the bottom, in place of a popup
/// menu. Returns the chosen row's value, or null when dismissed.
///
/// [title] heads the sheet when the actions belong to one thing on a page of
/// many — a stop's name, say — so it is clear which one they act on.
Future<T?> showActionSheet<T>(
  BuildContext context, {
  required List<ActionSheetItem<T>> items,
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (context) => _ActionSheet<T>(title: title, items: items),
  );
}

class _ActionSheet<T> extends StatelessWidget {
  const _ActionSheet({required this.title, required this.items});

  final String? title;
  final List<ActionSheetItem<T>> items;

  @override
  Widget build(BuildContext context) {
    final heading = title?.trim() ?? '';

    return Material(
      color: AppColors.screen,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D6D1),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (heading.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                child: Text(
                  heading,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            for (final item in items)
              _ActionRow(
                item: item,
                onTap: () => Navigator.of(context).pop(item.value),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow<T> extends StatelessWidget {
  const _ActionRow({required this.item, required this.onTap});

  final ActionSheetItem<T> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        item.destructive ? AppColors.brandOrangeDeep : AppColors.foreground;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 22,
              color: item.destructive
                  ? AppColors.brandOrangeDeep
                  : AppColors.postPurple,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
