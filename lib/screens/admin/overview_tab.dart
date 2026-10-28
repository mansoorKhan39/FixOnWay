import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/section_card.dart';
import '../../models/audit_log.dart';
import '../../models/enums/problem_type.dart';
import '../../models/enums/request_status.dart';
import '../../routes/app_router.dart';
import '../../services/admin_service.dart';

/// UC-39: reports and analytics.
class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminController c = context.watch<AdminController>();
    final Report? r = c.report;

    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Overview',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'My profile',
                icon: const Icon(Icons.account_circle_outlined),
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRouter.adminProfile),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final ({String label, int? days}) o in <({String label, int? days})>[
                (label: 'Last 7 days', days: 7),
                (label: 'Last 30 days', days: 30),
                (label: 'All time', days: null),
              ])
                ChoiceChip(
                  label: Text(o.label),
                  selected: c.reportDays == o.days,
                  onSelected: (_) => c.setReportDays(o.days),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (r == null)
            const Center(child: CircularProgressIndicator())
          else ...<Widget>[
            Row(
              children: <Widget>[
                _Kpi(label: 'Requests', value: '${r.totalRequests}'),
                const SizedBox(width: 8),
                _Kpi(label: 'Finished jobs', value: '${r.finishedJobs}'),
                const SizedBox(width: 8),
                _Kpi(label: 'Revenue', value: formatMoney(r.revenue)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                _Kpi(label: 'Customers', value: '${r.customers}'),
                const SizedBox(width: 8),
                _Kpi(
                  label: 'Mechanics',
                  value: '${r.mechanics} (${r.onlineMechanics} online)',
                ),
                const SizedBox(width: 8),
                _Kpi(
                  label: 'Avg rating',
                  value: r.averageRating.toStringAsFixed(1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                _Kpi(label: 'Open complaints', value: '${r.openComplaints}'),
                const SizedBox(width: 8),
                _Kpi(label: 'Cancelled / expired', value: '${r.lostRequests}'),
                const SizedBox(width: 8),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
            const SizedBox(height: 20),
            const _Heading('Requests in the last 7 days'),
            SectionCard(child: _WeekChart(days: r.last7Days)),
            const _Heading('Requests by status'),
            SectionCard(
              child: Column(
                children: <Widget>[
                  if (r.byStatus.isEmpty) const Text('No requests in this period.'),
                  for (final RequestStatus s in RequestStatus.values)
                    if ((r.byStatus[s] ?? 0) > 0)
                      _BarRow(
                        label: s.label,
                        value: r.byStatus[s]!,
                        max: r.totalRequests,
                        color: s.color,
                      ),
                ],
              ),
            ),
            const _Heading('Requests by problem'),
            SectionCard(
              child: Column(
                children: <Widget>[
                  if (r.byProblem.isEmpty) const Text('No requests in this period.'),
                  for (final ProblemType p in ProblemType.values)
                    if ((r.byProblem[p] ?? 0) > 0)
                      _BarRow(
                        label: p.label,
                        value: r.byProblem[p]!,
                        max: r.totalRequests,
                        color: AppColors.primary,
                      ),
                ],
              ),
            ),
            const _Heading('Top mechanics (by earnings)'),
            SectionCard(
              child: Column(
                children: <Widget>[
                  if (r.topMechanics.isEmpty)
                    const Text('No paid jobs in this period.'),
                  for (final MechanicStat m in r.topMechanics)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              m.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text('${m.jobs} jobs  '),
                          Text(
                            formatMoney(m.earnings),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const _Heading('Recent admin activity'),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (c.activity.isEmpty)
                  const Text(
                    'Nothing yet. Approvals, blocks and complaint decisions '
                    'are listed here.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                for (final AuditLog a in c.activity)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${formatDateTime(a.createdAt)}  -  ${a.adminName}: '
                      '${a.action} (${a.targetId})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});

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

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double fraction = max <= 0 ? 0 : value / max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.02, 1.0).toDouble(),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.days});

  final List<DayCount> days;

  static const List<String> _names = <String>[
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    int max = 1;
    for (final DayCount d in days) {
      if (d.count > max) max = d.count;
    }
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final DayCount d in days)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Text('${d.count}', style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 2),
                  Container(
                    height: 4 + 70 * d.count / max,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _names[d.day.weekday - 1],
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
