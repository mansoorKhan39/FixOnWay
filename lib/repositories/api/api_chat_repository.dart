import 'dart:async';

import '../../models/chat_message.dart';
import '../chat_repository.dart';
import 'api_client.dart';
import 'codecs.dart';

class ApiChatRepository implements ChatRepository {
  ApiChatRepository(this._api, {this.pollEvery = const Duration(seconds: 2)});

  final ApiClient _api;

  /// How often [watch] asks the server for news.
  final Duration pollEvery;

  @override
  Future<List<ChatMessage>> messages(String requestId) async {
    final Object? json = await _api.get(
      '/api/messages',
      query: <String, String>{'requestId': requestId},
    );
    final List<ChatMessage> list = <ChatMessage>[
      for (final Map<String, dynamic> m in ApiClient.maps(json))
        Codecs.messageFromMap(m['id'] as String, m),
    ];
    list.sort((ChatMessage a, ChatMessage b) => a.sentAt.compareTo(b.sentAt));
    return list;
  }

  /// "Live" chat by asking the server every couple of seconds. A new list is
  /// only sent when something changed.
  @override
  Stream<List<ChatMessage>> watch(String requestId) {
    late final StreamController<List<ChatMessage>> controller;
    Timer? timer;
    bool busy = false;
    String? lastKey;

    Future<void> poll() async {
      if (busy || controller.isClosed) return;
      busy = true;
      try {
        final List<ChatMessage> list = await messages(requestId);
        final String key =
            '${list.length}:${list.isEmpty ? '' : list.last.id}';
        if (key != lastKey && !controller.isClosed) {
          lastKey = key;
          controller.add(list);
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      } finally {
        busy = false;
      }
    }

    controller = StreamController<List<ChatMessage>>(
      onListen: () {
        poll();
        timer = Timer.periodic(pollEvery, (_) => poll());
      },
      onCancel: () => timer?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<ChatMessage> add(ChatMessage message) async {
    final Map<String, dynamic> m = ApiClient.map(
      await _api.post('/api/messages', Codecs.messageToMap(message)),
    );
    return Codecs.messageFromMap(m['id'] as String, m);
  }
}
