import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// "ใช้ข้อมูลจากทริป (ไม่บังคับ)" — the one row under the composer, between
/// hairlines rather than inside a card.
class PostTripRow extends StatelessWidget {
  const PostTripRow({super.key, required this.trip, required this.onTap});

  /// The linked trip's title, or null while nothing is linked.
  final String? trip;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final linked = trip;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.postPurpleWell,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.route,
                size: 22,
                color: AppColors.postPurple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: linked == null
                  ? Text.rich(
                      const TextSpan(
                        text: 'ใช้ข้อมูลจากทริป',
                        style: TextStyle(
                          color: AppColors.foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          TextSpan(
                            text: ' (ไม่บังคับ)',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ใช้ข้อมูลจากทริป',
                          style: TextStyle(
                            color: AppColors.foreground,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          linked,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B726D),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right,
              size: 24,
              color: Color(0xFF9A9A95),
            ),
          ],
        ),
      ),
    );
  }
}
