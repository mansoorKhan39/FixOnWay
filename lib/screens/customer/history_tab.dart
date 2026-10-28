import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/customer_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/enums/request_status.dart';
import '../../models/service_request.dart';
import '../../routes/app_router.dart';

enum _Filter { all, active, completed, cancelled }

/// UC-20: request history.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  _Filter _filter = _Filter.all;

  bool _matches(ServiceRequest r) {
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.active:
        return r.isActive;
      case _Filter.completed:
        return r.status == RequestStatus.completed ||
            r.status == RequestStatus.paid ||
            r.status == RequestStatus.disputed ||
            r.status == RequestStatus.closed;
      case _Filter.cancelled:
        return r.status == RequestStatus.cancelled ||
            r.status == RequestStatus.expired;
    }
  }

  String _label(_Filter f) => switch (f) {
        _Filter.all => 'All',
        _Filter.active => 'Active',
        _Filter.completed => 'Completed',
        _Filter.cancelled => 'Cancelled',
      };

  @override
  Widget build(BuildContext context) {
    final CustomerController c = context.watch<CustomerController>();
    final List<ServiceRequest> items =
        c.requests.where(_matches).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            'My requests',
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
              for (final _Filter f in _Filter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_label(f)),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: items.isEmpty
              ? const EmptyState(
                  icon: Icons.inbox_outlined,
                  message: 'No requests here yet.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  itemBuilder: (BuildContext context, int i) {
                    final ServiceRequest r = items[i];
                    return SectionCard(
                      onTap: () => Navigator.of(context).pushNamed(
                        AppRouter.requestDetail,
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
                                  r.problem.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${r.vehicleTitle}\n'
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
                                fontWeight: FontWeight.w600,
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
