import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/mechanic_controller.dart';
import '../../core/widgets/notification_list.dart';
import '../../models/app_notification.dart';
import '../../routes/app_router.dart';
import 'earnings_tab.dart';
import 'mechanic_profile_tab.dart';
import 'requests_tab.dart';
import 'reviews_tab.dart';

/// The verified mechanic's main screen.
class MechanicDashboardScreen extends StatefulWidget {
  const MechanicDashboardScreen({super.key});

  @override
  State<MechanicDashboardScreen> createState() =>
      _MechanicDashboardScreenState();
}

class _MechanicDashboardScreenState extends State<MechanicDashboardScreen> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final AuthController auth = context.read<AuthController>();
      if (auth.user != null) {
        context.read<MechanicController>().load(auth.user!);
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) context.read<MechanicController>().refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MechanicController c = context.watch<MechanicController>();
    final List<Widget> tabs = <Widget>[
      const RequestsTab(),
      const EarningsTab(),
      const ReviewsTab(),
      NotificationList(
        items: c.notifications,
        unreadCount: c.unreadCount,
        onMarkAllRead: c.markNotificationsRead,
        onOpen: (AppNotification n) {
          if (n.requestId != null && c.jobById(n.requestId!) != null) {
            Navigator.of(context).pushNamed(
              AppRouter.mechanicJob,
              arguments: n.requestId,
            );
          } else {
            setState(() => _index = 0);
          }
        },
      ),
      const MechanicProfileTab(),
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: IndexedStack(index: _index, children: tabs),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Jobs',
          ),
          const NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Earnings',
          ),
          const NavigationDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star),
            label: 'Reviews',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: c.unreadCount > 0,
              label: Text('${c.unreadCount}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
