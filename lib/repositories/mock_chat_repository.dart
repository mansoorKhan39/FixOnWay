import 'dart:async';

import '../models/chat_message.dart';
import 'chat_repository.dart';
import 'mock_data_store.dart';

class MockChatRepository implements ChatRepository {
  MockChatRepository(this._store);

  final MockDataStore _store;
  final StreamController<String> _changed = StreamController<String>.broadcast();

  @override
  Future<List<ChatMessage>> messages(String requestId) async {
    await _store.simulate();
    final List<ChatMessage> list = _store.messages.values
        .where((ChatMessage m) => m.requestId == requestId)
        .toList();
    list.sort((ChatMessage a, ChatMessage b) => a.sentAt.compareTo(b.sentAt));
    return list;
  }

  @override
  Stream<List<ChatMessage>> watch(String requestId) {
    late final StreamController<List<ChatMessage>> controller;
    StreamSubscription<String>? changes;

    Future<void> emit() async {
      final List<ChatMessage> list = await messages(requestId);
      if (!controller.isClosed) controller.add(list);
    }

    controller = StreamController<List<ChatMessage>>(
      onListen: () {
        // Subscribe first so no change is missed while the first load runs.
        changes = _changed.stream
            .where((String id) => id == requestId)
            .listen((_) => emit());
        emit();
      },
      onCancel: () async {
        await changes?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<ChatMessage> add(ChatMessage message) async {
    await _store.simulate();
    final String id = _store.newId('c');
    final ChatMessage saved = ChatMessage(
      id: id,
      requestId: message.requestId,
      senderId: message.senderId,
      senderName: message.senderName,
      text: message.text,
      sentAt: message.sentAt,
    );
    _store.messages[id] = saved;
    _changed.add(saved.requestId);
    return saved;
  }
}
