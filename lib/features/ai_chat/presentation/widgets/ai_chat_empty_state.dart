import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'ai_spark.dart';

/// What the page shows before a word has been said: the spark, gone soft, over
/// an opening question.
///
/// The greeting is English in the design even though the chrome around it is
/// Thai — left as drawn rather than translated, because it is the assistant's
/// voice and the same line repeats as the composer's hint.
class AiChatEmptyState extends StatelessWidget {
  const AiChatEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          AiSpark(size: 116, blur: 20),
          SizedBox(height: 28),
          Text(
            'Hi! Travelers\nWhat are you looking for today?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.aiGreeting,
              fontSize: 18,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
