import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/customer_controller.dart';
import '../../core/widgets/notification_list.dart';
import '../../models/app_notification.dart';
import '../../routes/app_router.dart';

/// UC-06: notifications.
class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final CustomerController c = context.watch<CustomerController>();
    return NotificationList(
      items: c.notifications,
      unreadCount: c.unreadCount,
      onMarkAllRead: c.markNotificationsRead,
      onOpen: (AppNotification n) => Navigator.of(context).pushNamed(
        AppRouter.requestDetail,
        arguments: n.requestId,
      ),
    );
  }
}
