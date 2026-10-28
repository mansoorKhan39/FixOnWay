import 'package:flutter_test/flutter_test.dart';
import 'package:fixonway/models/chat_message.dart';
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

  group('PhotoService', () {
    test('without Cloudinary settings it returns a demo photo', () async {
      const PhotoService service = PhotoService(cloud: '', preset: '');
      expect(service.enabled, isFalse);
      final PhotoAttachment? photo = await service.pick(2);
      expect(photo, isNotNull);
      expect(photo!.name, 'photo_3.jpg');
      expect(photo.url, isNull);
    });

    test('with both settings it is enabled', () {
      const PhotoService service =
          PhotoService(cloud: 'demo', preset: 'fixonway');
      expect(service.enabled, isTrue);
    });
  });
}
