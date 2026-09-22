import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import 'providers/ai_chat_providers.dart';
import 'widgets/ai_chat_bubble.dart';
import 'widgets/ai_chat_cards.dart';
import 'widgets/ai_chat_composer.dart';
import 'widgets/ai_chat_empty_state.dart';
import 'widgets/ai_chat_header.dart';
import 'widgets/ai_chat_stage.dart';
import 'widgets/ai_chat_warnings.dart';

/// Ai Chat — the assistant behind Home's floating spark (Figma 2281-46309).
///
/// The design draws one page with two faces: an empty state built around the
/// spark, and the same page with a transcript in its place. They share the
/// wash, the header and the composer, so this is one screen that swaps its
/// middle rather than two routes.
///
/// Turns are streamed. What the stream buys is not typing — the assistant's
/// text arrives whole — but honest progress across the ten to thirty seconds a
/// plan takes, plus each card the moment it is built.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  /// Draft revisions already written to the planner, mapped to their trip.
  /// Keyed by revision because saving revision 2 says nothing about revision 3.
  final _savedDrafts = <String, String>{};
  String? _savingKey;

  /// The opener the design prints above the composer. It stays put once the
  /// conversation has started — the design keeps it there, and a shortcut that
  /// vanished the moment it was used would be the harder one to find again.
  static const _opener = 'สถานที่ใกล้ฉัน';

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatControllerProvider);

    ref.listen(aiChatControllerProvider, (previous, next) {
      if (next.messages.length != previous?.messages.length) _scrollToEnd();
      final failure = next.transportError;
      if (failure != null && failure != previous?.transportError) {
        _showMessage(failure);
        ref.read(aiChatControllerProvider.notifier).dismissError();
      }
    });

    return AppFrame(
      background: AppColors.screen,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          // Amber at the crown, spent by the time the conversation starts, and
          // lit again under the composer — the page's only ornament.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.09, 0.28, 0.82, 1],
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
                child: state.isEmpty
                    ? const AiChatEmptyState()
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        children: [
                          for (final message in state.messages)
                            _message(message),
                          if (state.stage != null)
                            AiChatStageLine(stage: state.stage!),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: AiChatComposer(
                  controller: _controller,
                  onSend: _send,
                  onSuggestion: _sendText,
                  suggestion: _opener,
                  sending: state.sending,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One message: its words, then whatever cards the turn produced, then the
  /// caveats that qualify them.
  Widget _message(ChatMessage message) {
    if (message.isPending) return const AiChatThinking();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((message.text ?? '').isNotEmpty) AiChatBubble(message: message),
        for (final block in message.blocks) _block(block),
        AiChatWarnings(warnings: message.warnings),
        if (message.failed) _RetryLine(onRetry: _retry),
        if (message.suggestedReplies.isNotEmpty)
          AiChatClarification(
            block: ClarificationBlock(
              question: '',
              options: message.suggestedReplies,
            ),
            onAnswer: _sendText,
          ),
      ],
    );
  }

  /// A block kind this build does not know about renders as nothing rather
  /// than breaking the turn around it — new kinds ship without an app release.
  Widget _block(ChatBlock block) => switch (block) {
        TripResultsBlock() =>
          AiChatTripResults(block: block, onOpenTrip: _openTrip),
        PlaceResultsBlock() =>
          AiChatPlaceResults(block: block, onOpenPlace: _openPlace),
        ItineraryPreviewBlock() => AiChatItineraryPreview(
            block: block,
            saving: _savingKey == _draftKey(block),
            savedTripId: _savedDrafts[_draftKey(block)],
            onSave: () => _saveDraft(block),
          ),
        ClarificationBlock() =>
          AiChatClarification(block: block, onAnswer: _sendText),
        UnknownChatBlock() => const SizedBox.shrink(),
      };

  static String _draftKey(ItineraryPreviewBlock block) =>
      '${block.draftId}:${block.draftRevision}';

  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  void _send() => _sendText(_controller.text);

  void _sendText(String text) {
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref.read(aiChatControllerProvider.notifier).send(text);
  }

  void _retry() => ref.read(aiChatControllerProvider.notifier).retry();

  void _openTrip(String tripId) =>
      context.pushNamed(AppRoute.tripDetail.name, params: {'tripId': tripId});

  /// The API hands back a place id, but the app has no place page to spend it
  /// on yet — so it says so rather than swallowing the tap.
  void _openPlace(String placeId) =>
      _showMessage('หน้ารายละเอียดสถานที่ยังไม่เปิดใช้งาน');

  Future<void> _saveDraft(ItineraryPreviewBlock block) async {
    final key = _draftKey(block);
    if (_savingKey != null || _savedDrafts.containsKey(key)) return;

    setState(() => _savingKey = key);
    final result = await ref
        .read(aiChatControllerProvider.notifier)
        .saveDraft(block.draftId, block.draftRevision);
    if (!mounted) return;

    setState(() {
      _savingKey = null;
      if (result != null) _savedDrafts[key] = result.tripId;
    });
    if (result == null) return;

    // A revision saved twice is a success, not a conflict — either way the
    // trip exists and that is where the traveller wants to go.
    _showMessage(
      result.alreadySaved ? 'บันทึกไว้แล้ว' : 'บันทึกลง Trip Planner แล้ว',
      onOpen: () => context.pushNamed(
        AppRoute.tripDetail.name,
        params: {'tripId': result.tripId},
      ),
    );
  }

  void _showMessage(String message, {VoidCallback? onOpen}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: onOpen == null
              ? null
              : SnackBarAction(label: 'เปิดทริป', onPressed: onOpen),
        ),
      );
  }

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

class _RetryLine extends StatelessWidget {
  const _RetryLine({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 12),
      child: TextButton.icon(
        onPressed: onRetry,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('ลองใหม่', style: TextStyle(fontSize: 13)),
      ),
    );
  }
}
