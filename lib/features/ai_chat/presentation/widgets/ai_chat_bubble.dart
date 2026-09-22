import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/chat_message.dart';
import 'ai_spark.dart';

/// One line of the transcript.
///
/// The two sides are not mirror images: the assistant is announced by its
/// spark and speaks on warm paper, while the traveller gets graphite and no
/// avatar at all — on their own screen they need no introduction.
class AiChatBubble extends StatelessWidget {
  const AiChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final assistant = message.isAssistant;

    // Capped rather than free: a bubble that ran the full width would lose the
    // ragged edge that tells the two speakers apart at a glance.
    final bubble = Flexible(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.74,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: assistant
              ? AppColors.aiBubbleAssistant
              : AppColors.aiBubbleUser,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: assistant ? AppColors.foreground : Colors.white,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            assistant ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (assistant) ...[
            // Nudged down so the mark sits on the bubble's first line rather
            // than above it.
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: AiSpark(size: 20),
            ),
            const SizedBox(width: 8),
          ],
          bubble,
        ],
      ),
    );
  }
}
