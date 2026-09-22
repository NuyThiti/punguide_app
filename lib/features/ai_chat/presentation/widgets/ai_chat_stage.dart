import 'package:flutter/material.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import 'ai_spark.dart';

/// What the assistant is doing, while it does it.
///
/// Drafting a plan takes ten to thirty seconds, and the stream says which part
/// of that is running — so the wait reports progress instead of spinning.
class AiChatStageLine extends StatelessWidget {
  const AiChatStageLine({super.key, required this.stage});

  final ChatStage stage;

  @override
  Widget build(BuildContext context) {
    final label = switch (stage) {
      ChatStage.understanding => 'กำลังอ่านคำถาม…',
      ChatStage.searchingTrips => 'กำลังหาทริปที่คนอื่นแชร์ไว้…',
      ChatStage.searchingPlaces => 'กำลังหาสถานที่…',
      ChatStage.draftingItinerary => 'กำลังร่างแผนเที่ยว…',
      ChatStage.writingReply => 'กำลังเรียบเรียงคำตอบ…',
      // A stage this build has not heard of still means "working".
      ChatStage.unknown => 'กำลังทำงาน…',
    };

    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 12),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: AppColors.aiGreeting),
      ),
    );
  }
}

/// The assistant's row before anything has arrived in it.
class AiChatThinking extends StatelessWidget {
  const AiChatThinking({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: AiSpark(size: 20),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.aiBubbleAssistant,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const SizedBox(
              width: 18,
              height: 10,
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.aiGreeting,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
