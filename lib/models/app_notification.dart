/// UC-06: an in-app notification.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.requestId,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String? requestId;

  AppNotification markRead() => AppNotification(
        id: id,
        userId: userId,
        title: title,
        body: body,
        createdAt: createdAt,
        read: true,
        requestId: requestId,
      );
}
