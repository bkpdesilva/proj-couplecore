/// Mirrors couples/{coupleId}/problemSessions/{id}/messages/{id} — one turn
/// in a problem-solving conversation, from a partner or from the AI (FR-48).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.senderUid,
    this.senderName = '',
  });

  final String id;

  /// user | model
  final String role;
  final String content;
  final String? senderUid;
  final String senderName;

  bool get isFromAi => role == 'model';

  factory ChatMessage.fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) {
      return ChatMessage(id: id, role: 'user', content: '');
    }
    return ChatMessage(
      id: id,
      role: data['role'] as String? ?? 'user',
      content: data['content'] as String? ?? '',
      senderUid: data['senderUid'] as String?,
      senderName: data['senderName'] as String? ?? '',
    );
  }
}
