import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/ai_chat_context.dart';
import 'ai_spark.dart';

/// What the page shows before a word has been said: the spark, gone soft, over
/// an opening question.
///
/// The greeting is English in the design even though the chrome around it is
/// Thai — left as drawn rather than translated, because it is the assistant's
/// voice and the same line repeats as the composer's hint.
class AiChatEmptyState extends StatelessWidget {
  const AiChatEmptyState({super.key, this.context_, this.onChangeArea});

  /// Where the assistant thinks the traveller is. Null hides the line
  /// entirely — an assistant that says nothing knows nothing, and that is the
  /// honest reading.
  final AiChatContext? context_;

  /// Opens the place picker, so a wrong guess is one tap from being right.
  final VoidCallback? onChangeArea;

  @override
  Widget build(BuildContext context) {
    final here = context_;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AiSpark(size: 116, blur: 15),
          const SizedBox(height: 28),
          const Text(
            'Hi! Travelers\nWhat are you looking for today?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.aiGreeting,
              fontSize: 18,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (here != null) ...[
            const SizedBox(height: 18),
            _AreaLine(label: here.label, onChange: onChangeArea),
          ],
        ],
      ),
    );
  }
}

/// "กำลังดูแถว เชียงใหม่ · เปลี่ยน".
///
/// This line is what earns the page the right to send the account's stored
/// place as the turn's origin: the traveller is told what the assistant is
/// working from, in a name they chose, before they ask anything — and can move
/// it. Without it the page would be quietly using a position allowed on
/// another screen, which is the thing the API's §8.2 exists to prevent.
class _AreaLine extends StatelessWidget {
  const _AreaLine({required this.label, this.onChange});

  final String label;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.place_outlined,
            size: 15,
            color: AppColors.aiGreeting,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'กำลังดูแถว $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.foreground,
              ),
            ),
          ),
          if (onChange != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onChange,
              child: const Text(
                'เปลี่ยน',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.filterSelectedText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
