import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The card the traveller writes in, and the suggestion that floats over it.
///
/// Two rows rather than one: the field and the send key share the top, and the
/// attach and dictate tools sit under them. That keeps the send key on the
/// same line as the words it sends, however many lines they run to.
class AiChatComposer extends StatelessWidget {
  const AiChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onSuggestion,
    this.suggestion,
    this.sending = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  /// A turn is in flight — the send key is held until it lands, so one tap
  /// cannot become two turns.
  final bool sending;

  /// The one-tap opener above the card. Null once the conversation has
  /// started — it is a way in, not a permanent shortcut.
  final String? suggestion;
  final ValueChanged<String> onSuggestion;

  static const _hint = 'What are you looking for today?';

  @override
  Widget build(BuildContext context) {
    final suggestion = this.suggestion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (suggestion != null) ...[
          _SuggestionChip(
            label: suggestion,
            onTap: () => onSuggestion(suggestion),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.aiComposer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.foreground,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: _hint,
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: AppColors.aiHint,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SendKey(onTap: sending ? null : onSend),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ComposerTool(
                    icon: Icons.add,
                    label: 'แนบไฟล์',
                    onTap: () {},
                  ),
                  const SizedBox(width: 10),
                  // Drawn in Figma, but there is no route on the API that
                  // takes audio — so it is shown and held rather than wired to
                  // nothing.
                  const _ComposerTool(
                    icon: Icons.mic_none,
                    label: 'พูด (ยังไม่เปิดใช้งาน)',
                    onTap: null,
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The opener — white, so it lifts off the composer's cream rather than
/// blending into it.
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.foreground,
          ),
        ),
      ),
    );
  }
}

/// Send: the spark gradient again, under a dark arrow.
class _SendKey extends StatelessWidget {
  const _SendKey({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'ส่ง',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [
                AppColors.aiSparkEnd,
                AppColors.aiSparkMid,
                AppColors.aiSparkStart,
              ],
            ),
            // Dimmed, not hidden: the key stays where the thumb expects it.
            backgroundBlendMode: onTap == null ? BlendMode.luminosity : null,
          ),
          child: const Icon(
            Icons.near_me,
            size: 20,
            color: AppColors.foreground,
          ),
        ),
      ),
    );
  }
}

class _ComposerTool extends StatelessWidget {
  const _ComposerTool({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.aiComposerTool,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 19,
            color: onTap == null ? AppColors.postFieldHint : AppColors.foreground,
          ),
        ),
      ),
    );
  }
}
