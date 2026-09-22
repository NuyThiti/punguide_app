import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The caveats a turn carries — straight-line distances, unchecked opening
/// hours, budgets that were assumed rather than asked.
///
/// Rendered as part of the answer rather than tucked away: the API writes them
/// in the traveller's own language precisely because they are half of what
/// makes the answer honest.
class AiChatWarnings extends StatelessWidget {
  const AiChatWarnings({super.key, required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppColors.aiGreeting,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      warning,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.aiGreeting,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
