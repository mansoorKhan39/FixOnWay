import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/chat_message.dart';
import '../chat_repository.dart';
import 'codecs.dart';
import 'firebase_support.dart';

class FirestoreChatRepository implements ChatRepository {
  FirestoreChatRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _messages =>
      _db.collection(Col.messages);

  @override
  Future<List<ChatMessage>> messages(String requestId) {
    return guardFirebase(() async {
      final QuerySnapshot<Map<String, dynamic>> snap =
          await _messages.where('requestId', isEqualTo: requestId).get();
      final List<ChatMessage> list = snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              Codecs.messageFromMap(d.id, d.data()))
          .toList();
      list.sort((ChatMessage a, ChatMessage b) => a.sentAt.compareTo(b.sentAt));
      return list;
    });
  }

  @override
  Stream<List<ChatMessage>> watch(String requestId) {
    return _messages
        .where('requestId', isEqualTo: requestId)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      final List<ChatMessage> list = snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              Codecs.messageFromMap(d.id, d.data()))
          .toList();
      list.sort((ChatMessage a, ChatMessage b) => a.sentAt.compareTo(b.sentAt));
      return list;
    });
  }

  @override
  Future<ChatMessage> add(ChatMessage message) {
    return guardFirebase(() async {
      final DocumentReference<Map<String, dynamic>> ref = _messages.doc();
      final Map<String, dynamic> map = Codecs.messageToMap(message);
      await ref.set(map);
      return Codecs.messageFromMap(ref.id, map);
    });
  }
}
