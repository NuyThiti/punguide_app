import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import '../domain/chat_message.dart';
import 'widgets/ai_chat_bubble.dart';
import 'widgets/ai_chat_composer.dart';
import 'widgets/ai_chat_empty_state.dart';
import 'widgets/ai_chat_header.dart';

/// Ai Chat — the assistant behind Home's floating spark (Figma 2281-46309).
///
/// The design draws one page with two faces: an empty state built around the
/// spark, and the same page with a transcript in its place. They share the
/// wash, the header and the composer, so this is one screen that swaps its
/// middle rather than two routes.
///
/// The replies are canned. There is no assistant endpoint on the Pluno API
/// yet, and this page is the design's, not the wiring's — [_replyTo] is the
/// single seam to trade for the call when one lands.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  final _messages = <ChatMessage>[];

  /// The opener the design prints above the composer. It disappears once the
  /// traveller has said anything, their own words being the better prompt.
  static const _opener = 'สถานที่ใกล้ฉัน';

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFrame(
      background: AppColors.screen,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          // Amber at the crown, spent by the time the conversation starts, and
          // lit again under the composer — the page's only ornament.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.13, 0.38, 0.88, 1],
            colors: [
              AppColors.aiWashTop,
              AppColors.aiWashMid,
              AppColors.screen,
              AppColors.screen,
              AppColors.aiWashBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AiChatHeader(onBack: _close),
              Expanded(
                child: _messages.isEmpty
                    ? const AiChatEmptyState()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) =>
                            AiChatBubble(message: _messages[index]),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: AiChatComposer(
                  controller: _controller,
                  onSend: _send,
                  onSuggestion: _sendText,
                  suggestion: _messages.isEmpty ? _opener : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  void _send() => _sendText(_controller.text);

  void _sendText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages
        ..add(ChatMessage.traveller(trimmed))
        ..add(ChatMessage.assistant(_replyTo(trimmed)));
    });
    _scrollToEnd();
  }

  /// Stands in for the assistant until there is one to ask. Every question
  /// gets the same answer on purpose — a canned reply that varied would read
  /// as an assistant that is working, and none is.
  String _replyTo(String question) =>
      'กำลังหาที่เที่ยวให้อยู่นะ — เดี๋ยวจะรวบรวมมาให้เลย';

  /// Runs after the frame that added the message, so the list has already been
  /// measured with it in place and the extent below is real.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }
}
