import 'dart:async';
import 'dart:convert';

import '../../network/api_client.dart';
import '../models/chat.dart';
import '../models/json.dart';

/// The travel assistant: rooms, turns, and saving a draft it wrote.
///
/// Every route here requires a token — unlike the trip feed there is no
/// anonymous mode, because a room has an owner from its first second. A room
/// belonging to someone else answers 404 rather than 403, so treat "not found"
/// as "not yours" too.
class ChatApi {
  const ChatApi(this._client);

  final PlunoApiClient _client;

  /// Opens a room. [locale] is only a hint — each reply follows the language
  /// of the message it answers, not the room's.
  Future<ChatConversation> createConversation({String? locale}) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/chat/conversations',
      body: <String, dynamic>{if (locale != null) 'locale': locale},
    );
    return ChatConversation.fromJson(Json.asMap(body));
  }

  /// The traveller's own rooms, newest activity first.
  Future<ChatConversationPage> listConversations({
    int? limit,
    int? offset,
  }) async {
    final body = await _client.get<Map<String, dynamic>>(
      '/chat/conversations',
      query: <String, dynamic>{'limit': limit, 'offset': offset},
    );
    return ChatConversationPage.fromJson(Json.asMap(body));
  }

  Future<ChatConversation> conversation(String conversationId) async {
    final body = await _client.get<Map<String, dynamic>>(
      '/chat/conversations/$conversationId',
    );
    return ChatConversation.fromJson(Json.asMap(body));
  }

  /// History, read backwards. Omit [before] for the latest page, then pass the
  /// page's `nextCursor` to walk further back; null means the start of the
  /// room. Messages within a page run oldest to newest.
  Future<ChatMessagePage> messages(
    String conversationId, {
    int? limit,
    String? before,
  }) async {
    final body = await _client.get<Map<String, dynamic>>(
      '/chat/conversations/$conversationId/messages',
      query: <String, dynamic>{'limit': limit, 'before': before},
    );
    return ChatMessagePage.fromJson(Json.asMap(body));
  }

  /// Sends a message and waits for the whole reply.
  ///
  /// Answers 200 even when the turn failed — the request was fine and the room
  /// is intact, so read [ChatTurn.status] and [ChatTurn.error] rather than
  /// catching. Only transport faults and 429 throw.
  ///
  /// Pass a [requestId] generated once per tap of send and reuse it on retry:
  /// the same id returns the same answer instead of paying for a second turn.
  Future<ChatTurn> sendMessage(
    String conversationId, {
    required String text,
    String? requestId,
    ChatOrigin? origin,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/chat/conversations/$conversationId/messages',
      body: _messageBody(text: text, requestId: requestId, origin: origin),
    );
    return ChatTurn.fromJson(Json.asMap(body));
  }

  /// The same turn, reported as it happens.
  ///
  /// Emits [ChatAcceptedEvent] before the model is called, then stages, blocks
  /// and text, and ends with [ChatCompleteEvent] or [ChatErrorEvent] carrying
  /// the identical envelope [sendMessage] returns — so one handler serves both
  /// transports.
  ///
  /// Text arrives in one piece, not token by token: the model is called
  /// through a structured-output request that does not stream. What the stream
  /// buys is honest progress during the ten to thirty seconds a plan takes.
  ///
  /// If a proxy buffers the response the events simply arrive late or all at
  /// once; nothing is lost, because the reply is stored before it is sent.
  Stream<ChatStreamEvent> streamMessage(
    String conversationId, {
    required String text,
    String? requestId,
    ChatOrigin? origin,
  }) async* {
    final bytes = await _client.streamPost(
      '/chat/conversations/$conversationId/messages',
      body: _messageBody(text: text, requestId: requestId, origin: origin),
      headers: const <String, String>{'Accept': 'text/event-stream'},
    );

    await for (final event in _decodeEvents(bytes)) {
      yield event;
    }
  }

  /// Writes a draft into the Trip Planner as a real trip.
  ///
  /// [revision] is required so that what gets saved is the plan on screen, not
  /// a newer one the assistant produced in the meantime. Saving the same
  /// revision twice is safe — the second call answers `alreadySaved: true`
  /// with the original trip id, which is a success, not a conflict.
  ///
  /// The trip is created private. Publishing is still `PATCH /trips/:id`.
  Future<ChatSaveResult> saveDraft(
    String conversationId,
    String draftId, {
    required int revision,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/chat/conversations/$conversationId/drafts/$draftId/save',
      body: <String, dynamic>{'revision': revision},
    );
    return ChatSaveResult.fromJson(Json.asMap(body));
  }

  /// Deletes a room and everything said in it. Idempotent — deleting one that
  /// is already gone succeeds.
  ///
  /// Trips already saved out of the room survive; they are the traveller's own
  /// rows now.
  Future<void> deleteConversation(String conversationId) =>
      _client.delete<void>('/chat/conversations/$conversationId');

  static Map<String, dynamic> _messageBody({
    required String text,
    String? requestId,
    ChatOrigin? origin,
  }) =>
      <String, dynamic>{
        'text': text,
        if (requestId != null) 'requestId': requestId,
        if (origin != null) 'origin': origin.toJson(),
      };

  /// Parses the `event:`/`data:` wire format into typed events.
  ///
  /// Records are separated by a blank line and a single record's `data:` may
  /// be split across lines, so the parser buffers until it sees the break
  /// rather than treating each line as a message.
  static Stream<ChatStreamEvent> _decodeEvents(Stream<List<int>> bytes) async* {
    var name = '';
    final data = StringBuffer();

    // `cast` because the transport hands back `Stream<Uint8List>`, which is
    // not assignable to the `Stream<List<int>>` the utf8 decoder transforms.
    // Both decoders are chunked, so a multi-byte character or a line split
    // across two packets is buffered rather than mangled.
    final lines = bytes
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.isEmpty) {
        final event = _toEvent(name, data.toString());
        name = '';
        data.clear();
        if (event != null) yield event;
        continue;
      }
      // Comment lines (": keep-alive") exist to hold the socket open.
      if (line.startsWith(':')) continue;
      if (line.startsWith('event:')) {
        name = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        if (data.isNotEmpty) data.write('\n');
        data.write(line.substring(5).trimLeft());
      }
    }

    // A stream that ends without its final blank line still has a record in
    // hand; dropping it would lose the turn's result.
    final trailing = _toEvent(name, data.toString());
    if (trailing != null) yield trailing;
  }

  static ChatStreamEvent? _toEvent(String name, String payload) {
    if (name.isEmpty || payload.isEmpty) return null;

    Map<String, dynamic> json;
    try {
      json = Json.asMap(jsonDecode(payload));
    } on FormatException {
      return null;
    }

    return switch (name) {
      'accepted' => ChatAcceptedEvent.fromJson(json),
      'status' => ChatStageEvent(ChatStage.from(json['stage'])),
      'block' => ChatBlockEvent(ChatBlock.fromJson(json)),
      'text' => ChatTextEvent(Json.requiredString(json, 'text')),
      'complete' => ChatCompleteEvent(ChatTurn.fromJson(json)),
      'error' => ChatErrorEvent(ChatTurn.fromJson(json)),
      // An event kind this build does not know about is skipped, the same way
      // an unknown block is.
      _ => null,
    };
  }
}
