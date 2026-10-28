import '../models/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatMessage>> messages(String requestId);

  /// Emits the full, sorted message list now and again on every change.
  Stream<List<ChatMessage>> watch(String requestId);

  Future<ChatMessage> add(ChatMessage message);
}
