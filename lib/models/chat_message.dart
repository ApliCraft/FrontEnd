/// Model class representing a chat message
class ChatMessage {
  /// The text content of the message
  final String text;
  
  /// Whether the message is from the user (true) or the AI (false)
  final bool isUser;
  
  /// When the message was created
  final DateTime timestamp;

  /// Creates a new chat message
  /// 
  /// [text] is the content of the message
  /// [isUser] indicates if the message is from the user (true) or AI (false)
  /// [timestamp] is optional and defaults to now
  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
} 