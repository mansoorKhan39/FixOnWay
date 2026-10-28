import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/app_user.dart';
import '../models/chat_message.dart';
import '../models/enums/request_status.dart';
import '../models/service_request.dart';
import '../repositories/chat_repository.dart';
import '../repositories/request_repository.dart';

/// UC-16 Chat between the customer and the assigned mechanic.
class ChatService {
  ChatService(this._chat, this._requests, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final ChatRepository _chat;
  final RequestRepository _requests;
  final DateTime Function() _now;

  static const Set<RequestStatus> _chatStatuses = <RequestStatus>{
    RequestStatus.accepted,
    RequestStatus.onTheWay,
    RequestStatus.arrived,
    RequestStatus.working,
    RequestStatus.completed,
  };

  Future<ServiceRequest> _forParticipant(String requestId, String userId) async {
    final ServiceRequest? r = await _requests.byId(requestId);
    if (r == null) throw const AppException('Request not found.');
    if (r.customerId != userId && r.mechanicId != userId) {
      throw const AppException('You are not part of this job.');
    }
    return r;
  }

  Future<List<ChatMessage>> messages(String requestId, String userId) async {
    await _forParticipant(requestId, userId);
    return _chat.messages(requestId);
  }

  /// Live messages (checks first that the user is part of the job).
  Stream<List<ChatMessage>> watch(String requestId, String userId) {
    return Stream<ServiceRequest>.fromFuture(_forParticipant(requestId, userId))
        .asyncExpand((ServiceRequest _) => _chat.watch(requestId));
  }

  /// Is chatting possible for this request right now?
  bool canChat(ServiceRequest r) =>
      r.mechanicId != null && _chatStatuses.contains(r.status);

  Future<ChatMessage> send({
    required String requestId,
    required AppUser sender,
    required String text,
  }) async {
    final ServiceRequest r = await _forParticipant(requestId, sender.id);
    if (!canChat(r)) {
      throw const AppException(
        'Chat is available while a mechanic is assigned to the job.',
      );
    }
    final String clean = text.trim();
    if (clean.isEmpty) throw const AppException('Type a message first.');
    if (clean.length > AppConstants.maxMessageLength) {
      throw const AppException(
        'Messages can have up to ${AppConstants.maxMessageLength} characters.',
      );
    }
    return _chat.add(
      ChatMessage(
        id: '',
        requestId: requestId,
        senderId: sender.id,
        senderName: sender.name,
        text: clean,
        sentAt: _now(),
      ),
    );
  }
}
