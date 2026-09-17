import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// "เชื่อมแผนของฉัน" — hangs one of the traveller's own plans off the post so
/// readers can open it and remix it.
///
/// The same link the composer always had, moved to the top of the page and
/// given the card the design draws.
class PostPlanLinkCard extends StatelessWidget {
  const PostPlanLinkCard({super.key, required this.trip, required this.onTap});

  /// The linked plan's name, or null while nothing is linked.
  final String? trip;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final linked = trip;

    return Material(
      color: AppColors.postDraftBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              const Icon(Icons.add_link, size: 26, color: AppColors.postPurple),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'เชื่อมแผนของฉัน',
                      style: TextStyle(
                        color: AppColors.postPurple,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      linked ?? 'เชื่อมแผนเที่ยวคุณ ให้คนอื่นดูและ Remix ได้',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: linked == null
                            ? AppColors.muted
                            : AppColors.foreground,
                        fontSize: 13,
                        fontWeight:
                            linked == null ? FontWeight.w500 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  size: 22, color: Color(0xFF9A9A95)),
            ],
          ),
        ),
      ),
    );
  }
}
