import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';

/// The cap of the Ai Chat page: back, the board's name, and the badge that
/// says which of ไปกัน's faces this is.
///
/// It sits straight on the page's wash rather than on a bar of its own — the
/// design has no seam here, so neither does this.
class AiChatHeader extends StatelessWidget {
  const AiChatHeader({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'ย้อนกลับ',
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chevron_left,
                  size: 24,
                  color: AppColors.foreground,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'ไปกัน',
            style: TextStyle(
              color: AppColors.foreground,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          const _AiChatBadge(),
        ],
      ),
    );
  }
}

/// "Ai Chat" — the spark gradient laid out flat, with the assistant's own
/// glyph knocked to white so it reads on top of it.
class _AiChatBadge extends StatelessWidget {
  const _AiChatBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          colors: [
            AppColors.aiSparkStart,
            AppColors.aiSparkMid,
            AppColors.aiSparkEnd,
          ],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/ai_assistant.svg',
            width: 15,
            height: 17,
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Ai Chat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
