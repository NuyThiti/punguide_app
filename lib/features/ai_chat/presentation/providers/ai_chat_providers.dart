import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../core/api/pluno_api.dart';
import '../../../location_access/domain/location_service.dart';
import '../../../location_access/presentation/providers/location_providers.dart';
import 'ai_chat_context.dart';

/// Everything the Ai Chat screen draws itself from.
@immutable
class AiChatState {
  const AiChatState({
    this.conversationId,
    this.messages = const <ChatMessage>[],
    this.stage,
    this.sending = false,
    this.transportError,
  });

  /// Null until the first message — a room is opened lazily so that merely
  /// looking at the page does not litter the traveller's history with empty
  /// ones.
  final String? conversationId;

  /// Oldest first, the order the list renders in. Includes the pending
  /// assistant row while a turn is in flight.
  final List<ChatMessage> messages;

  /// What the assistant is doing right now, from the stream. Null when idle.
  final ChatStage? stage;

  final bool sending;

  /// A fault below the envelope — no network, a 429, a room that is gone.
  /// Turn-level failures live on the assistant message instead, because the
  /// server reports those as a normal 200.
  final String? transportError;

  bool get isEmpty => messages.isEmpty;

  AiChatState copyWith({
    String? conversationId,
    List<ChatMessage>? messages,
    ChatStage? stage,
    bool? sending,
    String? transportError,
    bool clearStage = false,
    bool clearTransportError = false,
  }) =>
      AiChatState(
        conversationId: conversationId ?? this.conversationId,
        messages: messages ?? this.messages,
        stage: clearStage ? null : (stage ?? this.stage),
        sending: sending ?? this.sending,
        transportError:
            clearTransportError ? null : (transportError ?? this.transportError),
      );
}

final aiChatControllerProvider =
    NotifierProvider.autoDispose<AiChatController, AiChatState>(
  AiChatController.new,
);

class AiChatController extends AutoDisposeNotifier<AiChatState> {
  @override
  AiChatState build() {
    ref.onDispose(() => _turn?.cancel());
    return const AiChatState();
  }

  StreamSubscription<ChatStreamEvent>? _turn;

  /// The id of the send that is in flight, kept so a retry reuses it.
  ///
  /// The server keys on it: replaying the same id returns the same answer
  /// rather than paying for a second turn, and a turn that died mid-flight is
  /// picked up where it stopped instead of being asked again.
  String? _requestId;
  String? _pendingText;

  /// Sends [text], streaming the reply.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;

    _requestId = uuidV4();
    _pendingText = trimmed;
    await _run(trimmed, _requestId!);
  }

  /// Re-sends the turn that failed, under its original request id.
  Future<void> retry() async {
    final text = _pendingText;
    final requestId = _requestId;
    if (text == null || requestId == null || state.sending) return;

    // Drop the failed assistant row; the replay writes a fresh one.
    final kept = state.messages.where((m) => !m.failed).toList(growable: false);
    state = state.copyWith(messages: kept, clearTransportError: true);
    await _run(text, requestId);
  }

  Future<void> _run(String text, String requestId) async {
    final api = await _api();
    if (api == null) return;

    final conversationId = await _ensureConversation(api);
    if (conversationId == null) return;

    // Both bubbles go up before the network does anything, so the traveller
    // sees their own words immediately and the assistant's row has somewhere
    // to fill in. The ids are local until the server names them.
    final userRow = ChatMessage(
      id: 'local-user-$requestId',
      role: ChatRole.user,
      status: ChatTurnStatus.complete,
      text: text,
    );
    final pendingRow = ChatMessage(
      id: 'local-assistant-$requestId',
      role: ChatRole.assistant,
      status: ChatTurnStatus.pending,
    );
    state = state.copyWith(
      messages: <ChatMessage>[...state.messages, userRow, pendingRow],
      sending: true,
      stage: ChatStage.understanding,
      clearTransportError: true,
    );

    final origin = await _originForTurn();
    final completer = Completer<void>();

    _turn = api.chat
        .streamMessage(
          conversationId,
          text: text,
          requestId: requestId,
          origin: origin,
        )
        .listen(
          (event) => _onEvent(event, pendingRow.id),
          onError: (Object error) {
            _onTransportError(error, pendingRow.id);
            if (!completer.isCompleted) completer.complete();
          },
          onDone: () {
            state = state.copyWith(sending: false, clearStage: true);
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );

    await completer.future;
  }

  void _onEvent(ChatStreamEvent event, String placeholderId) {
    switch (event) {
      case ChatAcceptedEvent(:final messageId):
        // Swap the local id for the server's, so later events land on the row
        // and history reconciles with it.
        state = state.copyWith(
          messages: _replace(
            placeholderId,
            (row) => ChatMessage(
              id: messageId,
              role: row.role,
              status: row.status,
              text: row.text,
              blocks: row.blocks,
            ),
          ),
        );
      case ChatStageEvent(:final stage):
        state = state.copyWith(stage: stage);
      case ChatBlockEvent(:final block):
        // Cards are drawn the moment each one is built, rather than waiting
        // for the whole turn.
        state = state.copyWith(
          messages: _replaceLastAssistant(
            (row) => row.copyWith(blocks: <ChatBlock>[...row.blocks, block]),
          ),
        );
      case ChatTextEvent(:final text):
        state = state.copyWith(
          messages: _replaceLastAssistant((row) => row.copyWith(text: text)),
        );
      case ChatCompleteEvent(:final turn):
      case ChatErrorEvent(:final turn):
        state = state.copyWith(
          conversationId: turn.conversationId,
          // The envelope is authoritative: it carries the final blocks, so the
          // ones streamed in are replaced rather than added to.
          messages: _replaceLastAssistant((row) => row.applyTurn(turn)),
          sending: false,
          clearStage: true,
        );
        if (turn.status == ChatTurnStatus.complete) {
          _requestId = null;
          _pendingText = null;
        }
    }
  }

  void _onTransportError(Object error, String placeholderId) {
    state = state.copyWith(
      messages: _replaceLastAssistant(
        (row) => row.copyWith(status: ChatTurnStatus.failed),
      ),
      sending: false,
      clearStage: true,
      transportError: error is ApiException
          ? error.messages.join('\n')
          : 'ส่งข้อความไม่สำเร็จ ลองใหม่อีกครั้งนะ',
    );
  }

  List<ChatMessage> _replace(
    String id,
    ChatMessage Function(ChatMessage) update,
  ) =>
      state.messages
          .map((row) => row.id == id ? update(row) : row)
          .toList(growable: false);

  /// The assistant row a turn is filling in is always the last one.
  List<ChatMessage> _replaceLastAssistant(
    ChatMessage Function(ChatMessage) update,
  ) {
    final rows = List<ChatMessage>.of(state.messages);
    for (var i = rows.length - 1; i >= 0; i--) {
      if (rows[i].isAssistant) {
        rows[i] = update(rows[i]);
        break;
      }
    }
    return List<ChatMessage>.unmodifiable(rows);
  }

  Future<PlunoApi?> _api() async {
    try {
      return await ref.read(plunoApiProvider.future);
    } on Object {
      state = state.copyWith(transportError: 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้');
      return null;
    }
  }

  Future<String?> _ensureConversation(PlunoApi api) async {
    final existing = state.conversationId;
    if (existing != null) return existing;
    try {
      final room = await api.chat.createConversation(locale: 'th');
      state = state.copyWith(conversationId: room.id);
      return room.id;
    } on ApiException catch (failure) {
      state = state.copyWith(transportError: failure.messages.join('\n'));
      return null;
    }
  }

  /// Where to tell the assistant the traveller is.
  ///
  /// A reading taken *now* wins. Failing that it falls back to the place the
  /// account has stored, which is what lets one tap on "ร้านอาหารใกล้ฉัน" be
  /// answered instead of earning a question back.
  ///
  /// That fallback is the thing §8.2 of the API notes warns about: a position
  /// allowed on another screen at another time. What makes it fair here is
  /// that the page *says so* — [AiChatEmptyState] names the area and offers to
  /// change it before a word is sent, so the assistant works from something
  /// the traveller can see and correct rather than something inferred behind
  /// them. Remove that line and this fallback has to go with it.
  Future<ChatOrigin?> _originForTurn() async {
    if (ref.read(locationPermissionProvider) ==
        LocationPermissionStatus.granted) {
      final fix = await ref.read(locationServiceProvider).currentFix();
      if (fix != null) {
        return ChatOrigin(latitude: fix.latitude, longitude: fix.longitude);
      }
    }
    return ref.read(aiChatContextProvider).valueOrNull?.toOrigin();
  }

  /// Saves the draft the traveller is looking at, and returns the trip id.
  ///
  /// [revision] is the one on the card rather than the newest, so what lands in
  /// the planner is the plan they were reading.
  Future<ChatSaveResult?> saveDraft(String draftId, int revision) async {
    final conversationId = state.conversationId;
    if (conversationId == null) return null;

    final api = await _api();
    if (api == null) return null;
    try {
      return await api.chat.saveDraft(
        conversationId,
        draftId,
        revision: revision,
      );
    } on ApiException catch (failure) {
      state = state.copyWith(transportError: failure.messages.join('\n'));
      return null;
    }
  }

  void dismissError() => state = state.copyWith(clearTransportError: true);
}
