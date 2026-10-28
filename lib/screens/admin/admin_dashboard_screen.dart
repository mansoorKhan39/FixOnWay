import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/complaint.dart';
import '../../models/enums/complaint_status.dart';
import 'admin_requests_tab.dart';
import 'approvals_tab.dart';
import 'complaints_tab.dart';
import 'overview_tab.dart';
import 'users_tab.dart';

/// The admin's main screen.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final AuthController auth = context.read<AuthController>();
      if (auth.user != null) {
        context.read<AdminController>().load(auth.user!);
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) context.read<AdminController>().refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AdminController c = context.watch<AdminController>();
    final int openComplaints = c.complaints
        .where((Complaint x) => x.status == ComplaintStatus.open)
        .length;
    const List<Widget> tabs = <Widget>[
      OverviewTab(),
      ApprovalsTab(),
      UsersTab(),
      AdminRequestsTab(),
      ComplaintsTab(),
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: IndexedStack(index: _index, children: tabs),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: c.applications.isNotEmpty,
              label: Text('${c.applications.length}'),
              child: const Icon(Icons.verified_user_outlined),
            ),
            selectedIcon: const Icon(Icons.verified_user),
            label: 'Approvals',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Users',
          ),
          const NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: openComplaints > 0,
              label: Text('$openComplaints'),
              child: const Icon(Icons.report_problem_outlined),
            ),
            selectedIcon: const Icon(Icons.report_problem),
            label: 'Complaints',
          ),
        ],
      ),
    );
  }
}
