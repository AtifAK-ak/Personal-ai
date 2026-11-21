class ChatMessage {
  const ChatMessage(this.text, {required this.fromUser, required this.time});
  final String text;
  final bool fromUser;
  final DateTime time;
}
