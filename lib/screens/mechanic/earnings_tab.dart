import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/mechanic_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_card.dart';
import '../../models/service_request.dart';
import '../../services/mechanic_service.dart';

/// UC-32: earnings.
class EarningsTab extends StatelessWidget {
  const EarningsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final Earnings? e = context.watch<MechanicController>().earnings;
    if (e == null) {
      return const EmptyState(
        icon: Icons.payments_outlined,
        message: 'No earnings yet.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text(
          'Earnings',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            _Tile(label: 'Today', value: formatMoney(e.today)),
            const SizedBox(width: 8),
            _Tile(label: 'Last 7 days', value: formatMoney(e.last7Days)),
            const SizedBox(width: 8),
            _Tile(label: 'All time', value: formatMoney(e.total)),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Paid jobs (${e.jobs.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (e.jobs.isEmpty)
          const Text(
            'Jobs appear here once the customer has paid.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        for (final ServiceRequest r in e.jobs)
          SectionCard(
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(r.problem.icon, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        r.problem.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${r.customerName}  -  '
                        '${formatDateTime(r.paidAt ?? r.updatedAt)}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatMoney(r.agreedAmount ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
