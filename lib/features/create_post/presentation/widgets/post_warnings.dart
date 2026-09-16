import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// What the assistant could not do, above the draft it did write.
///
/// The contract requires every warning to reach the traveller — they are the
/// reason a draft does not match what they expected (a place it could not look
/// up, photos it skipped, a suggestion it invented and the server threw away).
class PostWarnings extends StatelessWidget {
  const PostWarnings({
    super.key,
    required this.warnings,
    required this.onDismiss,
  });

  final List<String> warnings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.locationLayerWell,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline,
                size: 19, color: AppColors.locationPin),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ผู้ช่วยมีข้อสังเกต',
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                for (final warning in warnings)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '• $warning',
                      style: const TextStyle(
                        color: Color(0xFF6B726D),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.muted,
            tooltip: 'ปิดข้อสังเกต',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
