import 'package:flutter_test/flutter_test.dart';
import 'package:fixonway/models/chat_message.dart';
import 'package:fixonway/models/document_ref.dart';
import 'package:fixonway/models/photo_attachment.dart';
import 'package:fixonway/repositories/mock_chat_repository.dart';
import 'package:fixonway/repositories/mock_data_store.dart';
import 'package:fixonway/services/photo_service.dart';

ChatMessage msg(String requestId, String text) => ChatMessage(
      id: '',
      requestId: requestId,
      senderId: 'u1',
      senderName: 'Ali',
      text: text,
      sentAt: DateTime(2026, 1, 1),
    );

Future<void> settle() =>
    Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  group('live chat (mock repository)', () {
    test('watch sends the current messages, then every new one', () async {
      final MockChatRepository repo =
          MockChatRepository(MockDataStore(simulatedDelay: Duration.zero));
      final List<List<ChatMessage>> seen = <List<ChatMessage>>[];
      final sub = repo.watch('rq1').listen(seen.add);
      await settle();
      expect(seen.length, 1);
      expect(seen.last, isEmpty);

      await repo.add(msg('rq1', 'hello'));
      await settle();
      expect(seen.length, 2);
      expect(seen.last.single.text, 'hello');
      await sub.cancel();
    });

    test('messages of another request do not wake the stream', () async {
      final MockChatRepository repo =
          MockChatRepository(MockDataStore(simulatedDelay: Duration.zero));
      final List<List<ChatMessage>> seen = <List<ChatMessage>>[];
      final sub = repo.watch('rq1').listen(seen.add);
      await settle();
      await repo.add(msg('rq2', 'not for you'));
      await settle();
      expect(seen.length, 1);
      await sub.cancel();
    });
  });

  group('PhotoService (no backend)', () {
    test('without a backend it returns a demo photo', () async {
      const PhotoService service = PhotoService();
      expect(service.enabled, isFalse);
      final PhotoAttachment? photo = await service.pick(2);
      expect(photo, isNotNull);
      expect(photo!.name, 'photo_3.jpg');
      expect(photo.url, isNull);
    });

    test('without a backend a document is just its name', () async {
      const PhotoService service = PhotoService();
      expect(await service.pickDocument('CNIC front'), 'CNIC front');
      expect(service.documentUrl('abc'), isNull);
    });
  });

  group('DocumentRef', () {
    test('encodes and parses an uploaded document', () {
      const DocumentRef ref = DocumentRef('CNIC front', 'abc123');
      expect(ref.encode(), 'CNIC front::abc123');
      final DocumentRef back = DocumentRef.parse('CNIC front::abc123');
      expect(back.label, 'CNIC front');
      expect(back.fileId, 'abc123');
      expect(back.hasFile, isTrue);
    });

    test('a plain name has no file', () {
      final DocumentRef ref = DocumentRef.parse('Workshop photo');
      expect(ref.label, 'Workshop photo');
      expect(ref.hasFile, isFalse);
      expect(ref.encode(), 'Workshop photo');
    });
  });
}
