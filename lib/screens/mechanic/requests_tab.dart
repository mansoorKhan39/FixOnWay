import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/mechanic_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/photo_strip.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/mechanic_profile.dart';
import '../../models/service_request.dart';
import '../../routes/app_router.dart';
import '../../services/job_service.dart';

typedef _EstimateForm = ({int amount, int eta, String note});

/// UC-25 online switch, UC-26 incoming requests, UC-27 accept/reject,
/// UC-28 send estimate.
class RequestsTab extends StatelessWidget {
  const RequestsTab({super.key});

  Future<void> _estimate(BuildContext context, IncomingRequest item) async {
    final MechanicController c = context.read<MechanicController>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final _EstimateForm? form = await showDialog<_EstimateForm>(
      context: context,
      builder: (BuildContext _) => _EstimateDialog(request: item.request),
    );
    if (form == null) return;
    final bool ok = await c.sendEstimate(
      requestId: item.request.id,
      amount: form.amount,
      etaMinutes: form.eta,
      note: form.note,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Estimate sent.' : c.errorMessage ?? 'Failed.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    final MechanicController c = context.watch<MechanicController>();
    final MechanicProfile? profile = c.profile;
    final ServiceRequest? active = c.activeJob;
    final bool online = profile?.isOnline ?? false;

    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(
            'Hello, ${auth.user?.firstName ?? ''}',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (c.errorMessage != null) ErrorBanner(message: c.errorMessage!),
          SectionCard(
            child: Row(
              children: <Widget>[
                Icon(
                  online ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                  color: online ? AppColors.success : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        online ? 'You are online' : 'You are offline',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        online
                            ? 'Customers nearby can see you.'
                            : 'Go online to receive requests.',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: online,
                  onChanged: profile == null || c.isLoading
                      ? null
                      : (bool v) => c.setOnline(v),
                ),
              ],
            ),
          ),
          if (active != null)
            SectionCard(
              onTap: () => Navigator.of(context).pushNamed(
                AppRouter.mechanicJob,
                arguments: active.id,
              ),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: AppColors.primarySoft,
                    child: Icon(active.problem.icon, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Active job',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${active.problem.label} - ${active.customerName}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        StatusChip(status: active.status),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Incoming requests',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (profile == null)
            const Text(
              'Your account is not verified yet.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else if (!online)
            const Text(
              'Go online to see requests near you.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else if (c.incoming.isEmpty)
            const Text(
              'No open requests nearby right now. Pull down to refresh.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          for (final IncomingRequest item in c.incoming)
            _RequestCard(
              item: item,
              onEstimate: () => _estimate(context, item),
              onReject: () => c.reject(item.request.id),
              busy: c.isLoading,
            ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.item,
    required this.onEstimate,
    required this.onReject,
    required this.busy,
  });

  final IncomingRequest item;
  final VoidCallback onEstimate;
  final VoidCallback onReject;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ServiceRequest r = item.request;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${r.vehicleTitle}\n${formatDateTime(r.createdAt)}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatDistance(item.distanceKm),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.address),
          if (r.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              r.description,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
          if (r.photos.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            PhotoStrip(photos: r.photos),
          ],
          const SizedBox(height: 12),
          if (item.myEstimate != null)
            Text(
              'Estimate sent: ${formatMoney(item.myEstimate!.amount)} - '
              'waiting for the customer',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: busy ? null : onEstimate,
                    child: const Text('Send estimate'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EstimateDialog extends StatefulWidget {
  const _EstimateDialog({required this.request});

  final ServiceRequest request;

  @override
  State<_EstimateDialog> createState() => _EstimateDialogState();
}

class _EstimateDialogState extends State<_EstimateDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _eta = TextEditingController();
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _eta.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Estimate: ${widget.request.problem.label}'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (PKR)',
                  hintText: '1500',
                ),
                validator: Validators.amount,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _eta,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Arrival time (minutes)',
                  hintText: '15',
                ),
                validator: Validators.eta,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.of(context).pop((
              amount: int.parse(_amount.text.trim()),
              eta: int.parse(_eta.text.trim()),
              note: _note.text.trim(),
            ));
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}
