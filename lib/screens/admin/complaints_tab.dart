import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/section_card.dart';
import '../../models/complaint.dart';
import '../../models/enums/complaint_status.dart';
import '../../routes/app_router.dart';

/// UC-38: review and resolve complaints.
class ComplaintsTab extends StatelessWidget {
  const ComplaintsTab({super.key});

  Future<void> _decide(
    BuildContext context,
    Complaint x, {
    required bool upheld,
  }) async {
    final AdminController c = context.read<AdminController>();
    final TextEditingController note = TextEditingController();
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(upheld ? 'Uphold complaint' : 'Dismiss complaint'),
        content: TextField(
          controller: note,
          maxLength: 300,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Decision note (both users will see this)',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save decision'),
          ),
        ],
      ),
    );
    final String text = note.text;
    note.dispose();
    if (go == true) {
      await c.resolveComplaint(x.id, upheld: upheld, resolution: text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AdminController c = context.watch<AdminController>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text(
          'Complaints',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (c.errorMessage != null) ErrorBanner(message: c.errorMessage!),
        if (c.complaints.isEmpty)
          const SizedBox(
            height: 300,
            child: EmptyState(
              icon: Icons.report_gmailerrorred_outlined,
              message: 'No complaints have been filed.',
            ),
          ),
        for (final Complaint x in c.complaints)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        x.category.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    _StatusPill(status: x.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${x.customerName} vs ${x.mechanicName ?? 'unknown'}  -  '
                  '${formatDateTime(x.createdAt)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(x.description),
                if (x.status != ComplaintStatus.open) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'Decision: ${x.resolution}',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pushNamed(
                        AppRouter.adminRequest,
                        arguments: x.requestId,
                      ),
                      child: const Text('View request'),
                    ),
                    const Spacer(),
                    if (x.status == ComplaintStatus.open) ...<Widget>[
                      OutlinedButton(
                        onPressed: c.isLoading
                            ? null
                            : () => _decide(context, x, upheld: false),
                        child: const Text('Dismiss'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: c.isLoading
                            ? null
                            : () => _decide(context, x, upheld: true),
                        child: const Text('Uphold'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ComplaintStatus status;

  @override
  Widget build(BuildContext context) {
    final (String, Color) look = switch (status) {
      ComplaintStatus.open => ('Open', AppColors.error),
      ComplaintStatus.resolved => ('Upheld', AppColors.success),
      ComplaintStatus.rejected => ('Dismissed', AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: look.$2.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        look.$1,
        style: TextStyle(
          color: look.$2,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
