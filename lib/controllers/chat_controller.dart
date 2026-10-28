import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../models/app_user.dart';
import '../models/chat_message.dart';
import '../models/service_request.dart';
import '../services/chat_service.dart';

/// State of one open chat (UC-16).
class ChatController extends ChangeNotifier {
  ChatController(this._service);

  final ChatService _service;

  List<ChatMessage> _messages = <ChatMessage>[];
  String? _errorMessage;
  bool _isSending = false;
  StreamSubscription<List<ChatMessage>>? _subscription;

  List<ChatMessage> get messages => _messages;
  String? get errorMessage => _errorMessage;
  bool get isSending => _isSending;

  bool canChat(ServiceRequest r) => _service.canChat(r);

  /// Starts live updates for one chat. Call [stop] when the screen closes.
  void start(String requestId, AppUser user) {
    _subscription?.cancel();
    _subscription = _service.watch(requestId, user.id).listen(
      (List<ChatMessage> list) {
        _messages = list;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object e) {
        _errorMessage = e is AppException
            ? e.message
            : 'Live chat is unavailable. Check your connection.';
        notifyListeners();
      },
    );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  void reset() {
    stop();
    _messages = <ChatMessage>[];
    _errorMessage = null;
    _isSending = false;
    Future<void>.microtask(notifyListeners);
  }

  Future<void> load(String requestId, AppUser user) async {
    try {
      _messages = await _service.messages(requestId, user.id);
      notifyListeners();
    } on AppException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  Future<bool> send(String requestId, AppUser user, String text) async {
    _isSending = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.send(requestId: requestId, sender: user, text: text);
      _messages = await _service.messages(requestId, user.id);
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }
}
