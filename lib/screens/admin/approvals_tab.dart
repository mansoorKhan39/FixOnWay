import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/section_card.dart';
import '../../models/enums/problem_type.dart';
import '../../models/enums/vehicle_type.dart';
import '../../models/mechanic_application.dart';

/// UC-34: verify or reject mechanics.
class ApprovalsTab extends StatelessWidget {
  const ApprovalsTab({super.key});

  Future<void> _reject(BuildContext context, MechanicApplication a) async {
    final AdminController c = context.read<AdminController>();
    final TextEditingController reason = TextEditingController();
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Reject ${a.name}?'),
        content: TextField(
          controller: reason,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Reason (the mechanic will see this)',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    final String text = reason.text;
    reason.dispose();
    if (go == true) await c.reject(a.userId, text);
  }

  @override
  Widget build(BuildContext context) {
    final AdminController c = context.watch<AdminController>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text(
          'Mechanic approvals',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (c.errorMessage != null) ErrorBanner(message: c.errorMessage!),
        if (c.applications.isEmpty)
          const SizedBox(
            height: 300,
            child: EmptyState(
              icon: Icons.verified_user_outlined,
              message: 'No mechanics are waiting for verification.',
            ),
          ),
        for (final MechanicApplication a in c.applications)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  a.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${a.phone}  -  submitted ${formatDateTime(a.submittedAt)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text('CNIC: ${a.cnic}'),
                Text('Experience: ${a.experienceYears} years'),
                Text('Workshop: ${a.workshopAddress}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final ProblemType p in a.services)
                      Chip(label: Text(p.label)),
                    for (final VehicleType t in a.vehicleTypes)
                      Chip(label: Text(t.label)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Documents: ${a.documents.join(', ')}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: c.isLoading ? null : () => _reject(context, a),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed: c.isLoading ? null : () => c.approve(a.userId),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
