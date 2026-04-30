class ChatMessage {
  final String role; // "user" | "assistant"
  final String content;

  ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}
