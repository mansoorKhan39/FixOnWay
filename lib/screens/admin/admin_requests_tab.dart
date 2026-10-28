import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/enums/request_status.dart';
import '../../models/service_request.dart';
import '../../routes/app_router.dart';

/// UC-37: monitor all service requests.
class AdminRequestsTab extends StatelessWidget {
  const AdminRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminController c = context.watch<AdminController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            'All requests',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: c.requestStatus == null,
                  onSelected: (_) => c.filterRequests(null),
                ),
              ),
              for (final RequestStatus s in RequestStatus.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s.label),
                    selected: c.requestStatus == s,
                    onSelected: (_) => c.filterRequests(s),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: c.requests.isEmpty
              ? const EmptyState(
                  icon: Icons.inbox_outlined,
                  message: 'No requests with this status.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: c.requests.length,
                  itemBuilder: (BuildContext context, int i) {
                    final ServiceRequest r = c.requests[i];
                    return SectionCard(
                      onTap: () => Navigator.of(context).pushNamed(
                        AppRouter.adminRequest,
                        arguments: r.id,
                      ),
                      child: Row(
                        children: <Widget>[
                          CircleAvatar(
                            backgroundColor: AppColors.primarySoft,
                            child: Icon(
                              r.problem.icon,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '${r.problem.label} - ${r.customerName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${r.mechanicName ?? 'No mechanic yet'}  -  '
                                  '${formatDateTime(r.createdAt)}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                StatusChip(status: r.status),
                              ],
                            ),
                          ),
                          if (r.agreedAmount != null)
                            Text(
                              formatMoney(r.agreedAmount!),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
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
