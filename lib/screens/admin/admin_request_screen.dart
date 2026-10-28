import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/complaint.dart';
import '../../models/estimate.dart';
import '../../models/service_request.dart';
import '../../services/admin_service.dart';

/// UC-37: read-only detail of one request, for the admin.
class AdminRequestScreen extends StatefulWidget {
  const AdminRequestScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<AdminRequestScreen> createState() => _AdminRequestScreenState();
}

class _AdminRequestScreenState extends State<AdminRequestScreen> {
  late final Future<AdminRequestView?> _future =
      context.read<AdminController>().requestView(widget.requestId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request details')),
      body: FutureBuilder<AdminRequestView?>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<AdminRequestView?> s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final AdminRequestView? v = s.data;
          if (v == null) {
            return const Center(child: Text('Request not found.'));
          }
          final ServiceRequest r = v.request;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                r.problem.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            StatusChip(status: r.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _Line('Customer', r.customerName),
                        _Line('Mechanic', r.mechanicName ?? '-'),
                        _Line('Vehicle', r.vehicleTitle),
                        _Line('Address', r.address),
                        _Line('Created', formatDateTime(r.createdAt)),
                        if (r.agreedAmount != null)
                          _Line('Agreed price', formatMoney(r.agreedAmount!)),
                        if (r.paymentMethod != null)
                          _Line('Payment', r.paymentMethod!.name),
                        if (r.cancelReason != null)
                          _Line('Cancel reason', r.cancelReason!),
                        const SizedBox(height: 8),
                        Text(
                          r.description.isEmpty
                              ? 'No description.'
                              : r.description,
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Estimates',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (v.estimates.isEmpty)
                    const SectionCard(child: Text('No estimates yet.')),
                  for (final Estimate e in v.estimates)
                    SectionCard(
                      child: Text(
                        '${e.mechanicName}: ${formatMoney(e.amount)}, '
                        '${e.etaMinutes} min  (${e.status.name})',
                      ),
                    ),
                  if (v.review != null) ...<Widget>[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Review',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    SectionCard(
                      child: Text(
                        '${v.review!.rating} / 5  -  ${v.review!.comment}',
                      ),
                    ),
                  ],
                  if (v.complaints.isNotEmpty) ...<Widget>[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Complaint',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    for (final Complaint x in v.complaints)
                      SectionCard(
                        child: Text(
                          '${x.category.label}: ${x.description}\n'
                          'Status: ${x.status.name}'
                          '${x.resolution.isEmpty ? '' : '\nDecision: ${x.resolution}'}',
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
