import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';
import 'empty_state.dart';
import 'section_card.dart';

/// UC-06: the notification list, shared by customer and mechanic.
class NotificationList extends StatelessWidget {
  const NotificationList({
    super.key,
    required this.items,
    required this.unreadCount,
    required this.onMarkAllRead,
    required this.onOpen,
  });

  final List<AppNotification> items;
  final int unreadCount;
  final VoidCallback onMarkAllRead;
  final ValueChanged<AppNotification> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Notifications',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: unreadCount == 0 ? null : onMarkAllRead,
                child: const Text('Mark all read'),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none,
                  message: 'No notifications yet.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  itemBuilder: (BuildContext context, int i) {
                    final AppNotification n = items[i];
                    return SectionCard(
                      onTap: n.requestId == null ? null : () => onOpen(n),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            n.read
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                            color: n.read
                                ? AppColors.textMuted
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  n.title,
                                  style: TextStyle(
                                    fontWeight: n.read
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(n.body),
                                const SizedBox(height: 4),
                                Text(
                                  formatDateTime(n.createdAt),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
