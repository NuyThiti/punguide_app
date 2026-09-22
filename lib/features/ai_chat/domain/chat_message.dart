/// Who said a line in the Ai Chat transcript.
enum ChatAuthor {
  /// The traveller. Right-aligned, graphite.
  traveller,

  /// The assistant. Left-aligned behind its spark, on warm paper.
  assistant,
}

/// One line of the conversation.
///
/// Deliberately thin: the screen it feeds is the design's, and there is no
/// assistant endpoint on the Pluno API yet. When one lands this grows an id
/// and a timestamp, and [AiChatScreen] trades its canned reply for the call —
/// nothing else on the page has to move.
class ChatMessage {
  const ChatMessage({required this.author, required this.text});

  const ChatMessage.assistant(String text)
      : this(author: ChatAuthor.assistant, text: text);

  const ChatMessage.traveller(String text)
      : this(author: ChatAuthor.traveller, text: text);

  final ChatAuthor author;
  final String text;

  bool get isAssistant => author == ChatAuthor.assistant;
}
