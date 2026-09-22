import 'package:flutter/foundation.dart';

import 'json.dart';

/// The envelope version the app was written against.
///
/// The server bumps this only when a field is removed or changes meaning —
/// new fields and new block types do not bump it, so a mismatch here is a
/// reason to be careful, not to refuse to render.
const int chatSchemaVersion = 1;

/// Who said a line.
enum ChatRole {
  user,
  assistant;

  static ChatRole from(Object? value) =>
      '$value' == 'user' ? ChatRole.user : ChatRole.assistant;
}

/// Where a turn got to.
///
/// `pending` is written before the model is called, which is what makes a
/// request that dies mid-flight recoverable — see [ChatApi.sendMessage].
enum ChatTurnStatus {
  pending,
  complete,
  failed;

  static ChatTurnStatus from(Object? value) => switch ('$value') {
        'pending' => ChatTurnStatus.pending,
        'failed' => ChatTurnStatus.failed,
        _ => ChatTurnStatus.complete,
      };
}

/// Why a turn failed.
///
/// Unknown codes read as [unknown] and are treated as retryable — a new code
/// the server adds should not strand the traveller with no way forward.
enum ChatErrorCode {
  providerUnavailable,
  invalidModelOutput,
  toolUnavailable,
  rateLimited,
  notConfigured,
  unknown;

  static ChatErrorCode from(Object? value) => switch ('$value') {
        'provider_unavailable' => ChatErrorCode.providerUnavailable,
        'invalid_model_output' => ChatErrorCode.invalidModelOutput,
        'tool_unavailable' => ChatErrorCode.toolUnavailable,
        'rate_limited' => ChatErrorCode.rateLimited,
        'not_configured' => ChatErrorCode.notConfigured,
        _ => ChatErrorCode.unknown,
      };
}

@immutable
class ChatTurnError {
  const ChatTurnError({
    required this.code,
    required this.message,
    required this.retryable,
  });

  factory ChatTurnError.fromJson(Map<String, dynamic> json) => ChatTurnError(
        code: ChatErrorCode.from(json['code']),
        message: Json.requiredString(json, 'message'),
        // Absent means "we don't know" — the safer default is to let the
        // traveller try again rather than to declare the turn unrecoverable.
        retryable: Json.boolean(json, 'retryable', fallback: true),
      );

  final ChatErrorCode code;
  final String message;
  final bool retryable;
}

/// Where a card leads. The server builds these from rows it has just read —
/// the model cannot author one, and there are no URLs in the system.
enum ChatActionType {
  openTrip,
  openPlace,
  openDraft,
  openTripPlanner,
  unknown;

  static ChatActionType from(Object? value) => switch ('$value') {
        'open_trip' => ChatActionType.openTrip,
        'open_place' => ChatActionType.openPlace,
        'open_draft' => ChatActionType.openDraft,
        'open_trip_planner' => ChatActionType.openTripPlanner,
        _ => ChatActionType.unknown,
      };
}

@immutable
class ChatAction {
  const ChatAction({required this.type, this.entityId, this.revision});

  static ChatAction? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Json.asMap(value);
    return ChatAction(
      type: ChatActionType.from(json['type']),
      entityId: Json.string(json, 'entityId'),
      revision: Json.integer(json, 'revision'),
    );
  }

  final ChatActionType type;
  final String? entityId;

  /// Only on `open_draft`: which revision of the draft the card is showing.
  final int? revision;
}

/// A trip someone else published. Never something the model invented.
@immutable
class ChatTripResult {
  const ChatTripResult({
    required this.tripId,
    required this.title,
    this.destination,
    this.summary,
    this.imageUrl,
    this.durationDays,
    this.durationNights,
    this.estimatedCost,
    this.currency,
    this.placeCount,
    this.likeCount,
    this.creatorName,
    this.action,
  });

  factory ChatTripResult.fromJson(Map<String, dynamic> json) => ChatTripResult(
        tripId: Json.requiredString(json, 'tripId'),
        title: Json.requiredString(json, 'title'),
        destination: Json.string(json, 'destination'),
        summary: Json.string(json, 'summary'),
        imageUrl: Json.string(json, 'imageUrl'),
        durationDays: Json.integer(json, 'durationDays'),
        durationNights: Json.integer(json, 'durationNights'),
        estimatedCost: Json.number(json, 'estimatedCost'),
        currency: Json.string(json, 'currency'),
        placeCount: Json.integer(json, 'placeCount'),
        likeCount: Json.integer(json, 'likeCount'),
        creatorName: Json.string(json, 'creatorName'),
        action: ChatAction.fromJson(json['action']),
      );

  final String tripId;
  final String title;
  final String? destination;
  final String? summary;
  final String? imageUrl;
  final int? durationDays;
  final int? durationNights;

  /// What the trip's owner typed in, not a current price. Null when unknown —
  /// never zero.
  final double? estimatedCost;
  final String? currency;
  final int? placeCount;
  final int? likeCount;
  final String? creatorName;
  final ChatAction? action;
}

@immutable
class ChatPlaceResult {
  const ChatPlaceResult({
    required this.placeId,
    required this.name,
    this.category,
    this.address,
    this.latitude,
    this.longitude,
    this.rating,
    this.imageUrl,
    this.distanceKm,
    this.openingHours = const <String>[],
    this.action,
  });

  factory ChatPlaceResult.fromJson(Map<String, dynamic> json) =>
      ChatPlaceResult(
        placeId: Json.requiredString(json, 'placeId'),
        name: Json.requiredString(json, 'name'),
        category: Json.string(json, 'category'),
        address: Json.string(json, 'address'),
        latitude: Json.number(json, 'lat'),
        longitude: Json.number(json, 'lng'),
        rating: Json.number(json, 'rating'),
        imageUrl: Json.string(json, 'imageUrl'),
        distanceKm: Json.number(json, 'distanceKm'),
        openingHours: Json.stringList(json, 'openingHours'),
        action: ChatAction.fromJson(json['action']),
      );

  final String placeId;
  final String name;
  final String? category;
  final String? address;
  final double? latitude;
  final double? longitude;

  /// Null when the server has Google's ratings field switched off. No number
  /// is ever invented to fill the gap.
  final double? rating;
  final String? imageUrl;

  /// Straight-line, not driving distance. Label it as such wherever it shows.
  final double? distanceKm;

  /// The posted weekly hours, and only when the search narrowed to one place.
  /// This never answers "is it open right now" — see the API notes.
  final List<String> openingHours;
  final ChatAction? action;
}

@immutable
class ChatItineraryStop {
  const ChatItineraryStop({
    required this.name,
    this.placeId,
    this.category,
    this.startTime,
    this.estimatedDurationMin,
    this.travelTimeFromPrevMin,
    this.travelTimeIsEstimate = true,
    this.estimatedCost,
    this.imageUrl,
    this.notes,
  });

  factory ChatItineraryStop.fromJson(Map<String, dynamic> json) =>
      ChatItineraryStop(
        name: Json.requiredString(json, 'name'),
        // Null when the model named a stop no real place could be matched to.
        // Check it before opening a place sheet.
        placeId: Json.string(json, 'placeId'),
        category: Json.string(json, 'category'),
        startTime: Json.time(json, 'startTime'),
        estimatedDurationMin: Json.integer(json, 'estimatedDurationMin'),
        travelTimeFromPrevMin: Json.integer(json, 'travelTimeFromPrevMin'),
        // Absent reads as an estimate: claiming a measured number we were not
        // given is the failure that matters here.
        travelTimeIsEstimate:
            Json.boolean(json, 'travelTimeIsEstimate', fallback: true),
        estimatedCost: Json.number(json, 'estimatedCost'),
        imageUrl: Json.string(json, 'imageUrl'),
        notes: Json.string(json, 'notes'),
      );

  final String name;
  final String? placeId;
  final String? category;
  final String? startTime;
  final int? estimatedDurationMin;
  final int? travelTimeFromPrevMin;

  /// False only when the number came from Google Routes. True means it is a
  /// straight-line guess.
  final bool travelTimeIsEstimate;
  final double? estimatedCost;
  final String? imageUrl;
  final String? notes;
}

@immutable
class ChatItineraryDay {
  const ChatItineraryDay({
    required this.dayNumber,
    this.date,
    this.summary,
    this.stops = const <ChatItineraryStop>[],
  });

  factory ChatItineraryDay.fromJson(Map<String, dynamic> json) =>
      ChatItineraryDay(
        dayNumber: Json.integer(json, 'dayNumber') ?? 0,
        date: Json.date(json, 'date'),
        summary: Json.string(json, 'summary'),
        stops: Json.asMapList(json['stops'])
            .map(ChatItineraryStop.fromJson)
            .toList(growable: false),
      );

  final int dayNumber;
  final DateTime? date;
  final String? summary;
  final List<ChatItineraryStop> stops;
}

/// A block of a turn's reply.
///
/// Subclassed rather than left as a map so the screen can switch on a type it
/// understands. An unfamiliar `type` becomes [UnknownChatBlock] instead of
/// throwing: block kinds ship without an app release.
@immutable
sealed class ChatBlock {
  const ChatBlock();

  factory ChatBlock.fromJson(Map<String, dynamic> json) {
    return switch (Json.string(json, 'type')) {
      'trip_results' => TripResultsBlock.fromJson(json),
      'place_results' => PlaceResultsBlock.fromJson(json),
      'itinerary_preview' => ItineraryPreviewBlock.fromJson(json),
      'clarification' => ClarificationBlock.fromJson(json),
      final other => UnknownChatBlock(type: other ?? ''),
    };
  }

  static List<ChatBlock> listFrom(Object? value) =>
      Json.asMapList(value).map(ChatBlock.fromJson).toList(growable: false);
}

/// A block type this build of the app has never heard of. Kept so it can be
/// counted and skipped, never rendered.
@immutable
class UnknownChatBlock extends ChatBlock {
  const UnknownChatBlock({required this.type});

  final String type;
}

@immutable
class TripResultsBlock extends ChatBlock {
  const TripResultsBlock({required this.trips, this.totalMatches});

  factory TripResultsBlock.fromJson(Map<String, dynamic> json) =>
      TripResultsBlock(
        totalMatches: Json.integer(json, 'totalMatches'),
        trips: Json.asMapList(json['trips'])
            .map(ChatTripResult.fromJson)
            .toList(growable: false),
      );

  /// How many matched in total, of which [trips] is the shown slice.
  final int? totalMatches;
  final List<ChatTripResult> trips;
}

@immutable
class PlaceResultsBlock extends ChatBlock {
  const PlaceResultsBlock({
    required this.places,
    this.nearLabel,
    this.totalMatches,
  });

  factory PlaceResultsBlock.fromJson(Map<String, dynamic> json) =>
      PlaceResultsBlock(
        nearLabel: Json.string(json, 'nearLabel'),
        totalMatches: Json.integer(json, 'totalMatches'),
        places: Json.asMapList(json['places'])
            .map(ChatPlaceResult.fromJson)
            .toList(growable: false),
      );

  /// The label the traveller's own device sent, echoed back. The server does
  /// not reverse-geocode, so this is never a name they did not give.
  final String? nearLabel;
  final int? totalMatches;
  final List<ChatPlaceResult> places;
}

@immutable
class ItineraryPreviewBlock extends ChatBlock {
  const ItineraryPreviewBlock({
    required this.draftId,
    required this.draftRevision,
    required this.title,
    this.destination,
    this.durationDays,
    this.durationNights,
    this.summary,
    this.estimatedCost,
    this.currency,
    this.budgetScope,
    this.assumptions = const <String>[],
    this.warnings = const <String>[],
    this.feasibilityUnverified = true,
    this.days = const <ChatItineraryDay>[],
    this.action,
  });

  factory ItineraryPreviewBlock.fromJson(Map<String, dynamic> json) =>
      ItineraryPreviewBlock(
        draftId: Json.requiredString(json, 'draftId'),
        draftRevision: Json.integer(json, 'draftRevision') ?? 1,
        title: Json.requiredString(json, 'title'),
        destination: Json.string(json, 'destination'),
        durationDays: Json.integer(json, 'durationDays'),
        durationNights: Json.integer(json, 'durationNights'),
        summary: Json.string(json, 'summary'),
        estimatedCost: Json.number(json, 'estimatedCost'),
        currency: Json.string(json, 'currency'),
        budgetScope: Json.string(json, 'budgetScope'),
        assumptions: Json.stringList(json, 'assumptions'),
        warnings: Json.stringList(json, 'warnings'),
        // Absent reads as unverified, for the same reason as the travel-time
        // flag: the honest default is the cautious one.
        feasibilityUnverified:
            Json.boolean(json, 'feasibilityUnverified', fallback: true),
        days: Json.asMapList(json['days'])
            .map(ChatItineraryDay.fromJson)
            .toList(growable: false),
        action: ChatAction.fromJson(json['action']),
      );

  /// **Not a trip id.** A draft becomes a trip only once it is saved.
  final String draftId;
  final int draftRevision;
  final String title;
  final String? destination;
  final int? durationDays;
  final int? durationNights;
  final String? summary;

  /// Always an estimate. `budgetScope` says whether it is per person.
  final double? estimatedCost;
  final String? currency;
  final String? budgetScope;

  bool get isPerPerson => budgetScope == 'per_person';

  /// Defaults the server filled in because the traveller never said.
  final List<String> assumptions;
  final List<String> warnings;

  /// Travel times and opening hours have not been checked across the whole
  /// plan. Must be visible on the card.
  final bool feasibilityUnverified;
  final List<ChatItineraryDay> days;
  final ChatAction? action;
}

@immutable
class ClarificationBlock extends ChatBlock {
  const ClarificationBlock({
    required this.question,
    this.options = const <String>[],
    this.field,
  });

  factory ClarificationBlock.fromJson(Map<String, dynamic> json) =>
      ClarificationBlock(
        question: Json.requiredString(json, 'question'),
        options: Json.stringList(json, 'options'),
        field: Json.string(json, 'field'),
      );

  final String question;

  /// May be empty for an open question.
  final List<String> options;

  /// Which part of the brief is missing, so the screen can offer a date picker
  /// or a location prompt instead of chips.
  final String? field;
}

/// One turn's reply — the shape both the JSON response and the stream's
/// `complete` event carry, so one parser serves both.
@immutable
class ChatTurn {
  const ChatTurn({
    required this.conversationId,
    required this.messageId,
    required this.status,
    this.schemaVersion = chatSchemaVersion,
    this.text,
    this.blocks = const <ChatBlock>[],
    this.suggestedReplies = const <String>[],
    this.draftId,
    this.draftRevision,
    this.warnings = const <String>[],
    this.error,
  });

  factory ChatTurn.fromJson(Map<String, dynamic> json) => ChatTurn(
        schemaVersion:
            Json.integer(json, 'schemaVersion') ?? chatSchemaVersion,
        conversationId: Json.requiredString(json, 'conversationId'),
        messageId: Json.requiredString(json, 'messageId'),
        status: ChatTurnStatus.from(json['status']),
        text: Json.string(json, 'text'),
        blocks: ChatBlock.listFrom(json['blocks']),
        suggestedReplies: Json.stringList(json, 'suggestedReplies'),
        draftId: Json.string(json, 'draftId'),
        draftRevision: Json.integer(json, 'draftRevision'),
        warnings: Json.stringList(json, 'warnings'),
        error: json['error'] is Map
            ? ChatTurnError.fromJson(Json.asMap(json['error']))
            : null,
      );

  final int schemaVersion;
  final String conversationId;
  final String messageId;
  final ChatTurnStatus status;
  final String? text;
  final List<ChatBlock> blocks;
  final List<String> suggestedReplies;
  final String? draftId;
  final int? draftRevision;

  /// Written for the traveller to read. Half of the answer's honesty lives
  /// here, so it belongs on screen rather than in a log.
  final List<String> warnings;
  final ChatTurnError? error;

  bool get failed => status == ChatTurnStatus.failed;
}

/// A stored message, as the history endpoint returns it.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.status,
    this.schemaVersion = chatSchemaVersion,
    this.text,
    this.blocks = const <ChatBlock>[],
    this.suggestedReplies = const <String>[],
    this.warnings = const <String>[],
    this.draftId,
    this.draftRevision,
    this.errorCode,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        schemaVersion:
            Json.integer(json, 'schemaVersion') ?? chatSchemaVersion,
        id: Json.requiredString(json, 'id'),
        role: ChatRole.from(json['role']),
        status: ChatTurnStatus.from(json['status']),
        text: Json.string(json, 'text'),
        blocks: ChatBlock.listFrom(json['blocks']),
        suggestedReplies: Json.stringList(json, 'suggestedReplies'),
        warnings: Json.stringList(json, 'warnings'),
        draftId: Json.string(json, 'draftId'),
        draftRevision: Json.integer(json, 'draftRevision'),
        errorCode: json['errorCode'] == null
            ? null
            : ChatErrorCode.from(json['errorCode']),
        createdAt: Json.timestamp(json, 'createdAt'),
      );

  final int schemaVersion;
  final String id;
  final ChatRole role;
  final ChatTurnStatus status;
  final String? text;
  final List<ChatBlock> blocks;
  final List<String> suggestedReplies;
  final List<String> warnings;
  final String? draftId;
  final int? draftRevision;
  final ChatErrorCode? errorCode;
  final DateTime? createdAt;

  bool get isAssistant => role == ChatRole.assistant;

  /// The turn is still being answered — shown as a thinking bubble.
  bool get isPending => status == ChatTurnStatus.pending;

  bool get failed => status == ChatTurnStatus.failed;

  ChatMessage copyWith({
    ChatTurnStatus? status,
    String? text,
    List<ChatBlock>? blocks,
    List<String>? suggestedReplies,
    List<String>? warnings,
    String? draftId,
    int? draftRevision,
    ChatErrorCode? errorCode,
  }) =>
      ChatMessage(
        schemaVersion: schemaVersion,
        id: id,
        role: role,
        status: status ?? this.status,
        text: text ?? this.text,
        blocks: blocks ?? this.blocks,
        suggestedReplies: suggestedReplies ?? this.suggestedReplies,
        warnings: warnings ?? this.warnings,
        draftId: draftId ?? this.draftId,
        draftRevision: draftRevision ?? this.draftRevision,
        errorCode: errorCode ?? this.errorCode,
        createdAt: createdAt,
      );

  /// Folds a finished turn back into the placeholder row it was written for.
  ChatMessage applyTurn(ChatTurn turn) => copyWith(
        status: turn.status,
        text: turn.text,
        blocks: turn.blocks,
        suggestedReplies: turn.suggestedReplies,
        warnings: turn.warnings,
        draftId: turn.draftId,
        draftRevision: turn.draftRevision,
        errorCode: turn.error?.code,
      );
}

@immutable
class ChatConversation {
  const ChatConversation({
    required this.id,
    this.title,
    this.locale,
    this.preferences,
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) =>
      ChatConversation(
        id: Json.requiredString(json, 'id'),
        title: Json.string(json, 'title'),
        locale: Json.string(json, 'locale'),
        preferences: json['preferences'] is Map
            ? Json.asMap(json['preferences'])
            : null,
        lastMessageAt: Json.timestamp(json, 'lastMessageAt'),
        createdAt: Json.timestamp(json, 'createdAt'),
        updatedAt: Json.timestamp(json, 'updatedAt'),
      );

  final String id;

  /// Null until the first message; the server names the room from it.
  final String? title;
  final String? locale;

  /// The brief the assistant has accumulated — destination, dates, party size
  /// and so on. Useful for a "planning: Chiang Mai, 3 days" chip.
  final Map<String, dynamic>? preferences;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

@immutable
class ChatConversationPage {
  const ChatConversationPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory ChatConversationPage.fromJson(Map<String, dynamic> json) =>
      ChatConversationPage(
        items: Json.asMapList(json['items'])
            .map(ChatConversation.fromJson)
            .toList(growable: false),
        total: Json.integer(json, 'total') ?? 0,
        limit: Json.integer(json, 'limit') ?? 0,
        offset: Json.integer(json, 'offset') ?? 0,
      );

  final List<ChatConversation> items;
  final int total;
  final int limit;
  final int offset;
}

/// One page of history, oldest first within the page.
@immutable
class ChatMessagePage {
  const ChatMessagePage({required this.messages, this.nextCursor});

  factory ChatMessagePage.fromJson(Map<String, dynamic> json) =>
      ChatMessagePage(
        messages: Json.asMapList(json['messages'])
            .map(ChatMessage.fromJson)
            .toList(growable: false),
        nextCursor: Json.string(json, 'nextCursor'),
      );

  final List<ChatMessage> messages;

  /// Feed back as `before` to read further back. Null means the start.
  final String? nextCursor;
}

/// Where the traveller is, sent only on the turn they allowed it.
///
/// The server refuses to guess this from anything — no IP, and deliberately
/// not the stored fix behind "near me" — so a turn without it gets a question
/// back instead of a silent lookup.
@immutable
class ChatOrigin {
  const ChatOrigin({
    required this.latitude,
    required this.longitude,
    this.label,
  });

  final double latitude;
  final double longitude;

  /// Used verbatim; the server does not reverse-geocode it into a name the
  /// traveller never offered.
  final String? label;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lat': latitude,
        'lng': longitude,
        if (label != null && label!.isNotEmpty) 'label': label,
      };
}

@immutable
class ChatSaveResult {
  const ChatSaveResult({required this.tripId, required this.alreadySaved});

  factory ChatSaveResult.fromJson(Map<String, dynamic> json) => ChatSaveResult(
        tripId: Json.requiredString(json, 'tripId'),
        alreadySaved: Json.boolean(json, 'alreadySaved'),
      );

  final String tripId;

  /// This revision had been saved before. Not an error — open the trip.
  final bool alreadySaved;
}

/// What a turn is doing, while it does it.
enum ChatStage {
  understanding,
  searchingTrips,
  searchingPlaces,
  draftingItinerary,
  writingReply,
  unknown;

  static ChatStage from(Object? value) => switch ('$value') {
        'understanding' => ChatStage.understanding,
        'searching_trips' => ChatStage.searchingTrips,
        'searching_places' => ChatStage.searchingPlaces,
        'drafting_itinerary' => ChatStage.draftingItinerary,
        'writing_reply' => ChatStage.writingReply,
        _ => ChatStage.unknown,
      };
}

/// One server-sent event from a streamed turn.
@immutable
sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

/// The message rows exist. Arrives before the model is called, so the bubbles
/// can be placed immediately.
@immutable
class ChatAcceptedEvent extends ChatStreamEvent {
  const ChatAcceptedEvent({
    required this.conversationId,
    required this.messageId,
    this.userMessageId,
  });

  factory ChatAcceptedEvent.fromJson(Map<String, dynamic> json) =>
      ChatAcceptedEvent(
        conversationId: Json.requiredString(json, 'conversationId'),
        messageId: Json.requiredString(json, 'messageId'),
        userMessageId: Json.string(json, 'userMessageId'),
      );

  final String conversationId;
  final String messageId;
  final String? userMessageId;
}

@immutable
class ChatStageEvent extends ChatStreamEvent {
  const ChatStageEvent(this.stage);

  final ChatStage stage;
}

@immutable
class ChatBlockEvent extends ChatStreamEvent {
  const ChatBlockEvent(this.block);

  final ChatBlock block;
}

@immutable
class ChatTextEvent extends ChatStreamEvent {
  const ChatTextEvent(this.text);

  final String text;
}

/// The turn is over — [turn] is the same envelope the JSON route returns.
@immutable
class ChatCompleteEvent extends ChatStreamEvent {
  const ChatCompleteEvent(this.turn);

  final ChatTurn turn;
}

@immutable
class ChatErrorEvent extends ChatStreamEvent {
  const ChatErrorEvent(this.turn);

  final ChatTurn turn;
}
