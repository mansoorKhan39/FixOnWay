import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/chat_controller.dart';
import '../../controllers/customer_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/job_progress.dart';
import '../../core/widgets/map_canvas.dart';
import '../../core/widgets/photo_strip.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/star_row.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/enums/estimate_status.dart';
import '../../models/enums/request_status.dart';
import '../../models/estimate.dart';
import '../../models/lat_lng.dart';
import '../../models/live_location.dart';
import '../../models/review.dart';
import '../../models/service_request.dart';
import '../../routes/app_router.dart';
import '../../services/tracking.dart';
import '../chat_screen.dart';

/// UC-13 View estimate, UC-14 Accept/decline, UC-15 Track mechanic,
/// UC-16 Chat, UC-17 Cancel, UC-18 Pay, UC-19 Rate, UC-22 Complaint.
class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  Timer? _tick;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    context.read<CustomerController>().clearError();
    // Redraw every second (countdown, moving mechanic); reload every 5 s.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _ticks++;
      if (_ticks % 5 == 0) context.read<CustomerController>().refresh();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _cancel(ServiceRequest r) async {
    final TextEditingController reason = TextEditingController();
    final CustomerController c = context.read<CustomerController>();
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: TextField(
          controller: reason,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep request'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    final String text = reason.text;
    reason.dispose();
    if (sure == true) await c.cancelRequest(r.id, text);
  }

  LatLng? _mechanicPosition(ServiceRequest r, LiveLocation? live) {
    if (r.status == RequestStatus.onTheWay && live != null) {
      return live.position;
    }
    if (r.status == RequestStatus.onTheWay &&
        r.startedAt != null &&
        r.mechanicStart != null &&
        r.etaMinutes != null) {
      final double p = Tracking.progress(
        startedAt: r.startedAt!,
        etaMinutes: r.etaMinutes!,
        now: DateTime.now(),
      );
      return Tracking.position(
        start: r.mechanicStart!,
        end: r.location,
        progress: p,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final CustomerController c = context.watch<CustomerController>();
    final ServiceRequest? r = c.requestById(widget.requestId);
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final List<Estimate> offers = c
        .estimatesOf(r.id)
        .where((Estimate e) => e.status == EstimateStatus.offered)
        .toList();
    final bool open = r.status == RequestStatus.pending ||
        r.status == RequestStatus.estimated;
    final DateTime now = DateTime.now();
    final LiveLocation? live = c.liveLocationOf(r.id);
    final LatLng? mechanicPos = _mechanicPosition(r, live);
    final bool canChat = context.read<ChatController>().canChat(r);
    final Review? review = c.reviewOf(r.id);
    final bool complaintAllowed = (r.status == RequestStatus.completed ||
            r.status == RequestStatus.paid ||
            r.status == RequestStatus.closed) &&
        !c.hasComplaint(r.id);

    int? remaining;
    if (r.status == RequestStatus.onTheWay &&
        live == null &&
        r.startedAt != null &&
        r.etaMinutes != null) {
      remaining = Tracking.remainingMinutes(
        etaMinutes: r.etaMinutes!,
        progress: Tracking.progress(
          startedAt: r.startedAt!,
          etaMinutes: r.etaMinutes!,
          now: now,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(r.problem.label)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                if (c.errorMessage != null)
                  ErrorBanner(message: c.errorMessage!),
                Row(
                  children: <Widget>[
                    StatusChip(status: r.status),
                    const Spacer(),
                    Text(
                      formatDateTime(r.createdAt),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                JobProgress(status: r.status),
                const SizedBox(height: 12),
                MapCanvas(
                  center: r.location,
                  height: mechanicPos != null ? 200 : 160,
                  spanDegrees: mechanicPos != null ? 0.08 : 0.06,
                  path: mechanicPos != null
                      ? <LatLng>[mechanicPos, r.location]
                      : const <LatLng>[],
                  markers: <MapMarker>[
                    MapMarker(
                      position: r.location,
                      color: AppColors.error,
                      icon: Icons.location_on,
                    ),
                    if (mechanicPos != null)
                      MapMarker(
                        position: mechanicPos,
                        color: AppColors.info,
                        icon: Icons.directions_car,
                      ),
                  ],
                ),
                if (live != null && r.status == RequestStatus.onTheWay)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Live GPS: your mechanic is '
                      '${formatDistance(live.position.distanceKmTo(r.location))} '
                      'away.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                if (remaining != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      remaining == 0
                          ? 'Your mechanic has arrived.'
                          : 'Your mechanic arrives in about $remaining min.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                const SizedBox(height: 12),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _row(Icons.directions_car_outlined, r.vehicleTitle),
                      _row(Icons.place_outlined, r.address),
                      if (r.description.isNotEmpty)
                        _row(Icons.notes, r.description),
                      if (r.photos.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: PhotoStrip(photos: r.photos),
                        ),
                    ],
                  ),
                ),
                if (open) ...<Widget>[
                  Text(
                    'Estimates',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (offers.isEmpty)
                    const SectionCard(
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Waiting for nearby mechanics to send an '
                              'estimate. This request expires after '
                              '15 minutes.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final Estimate e in offers)
                    _EstimateCard(estimate: e, now: now, requestId: r.id),
                  if (kDebugMode)
                    TextButton.icon(
                      onPressed:
                          c.isLoading ? null : () => c.simulateEstimate(r.id),
                      icon: const Icon(Icons.bug_report_outlined),
                      label: const Text('Demo: simulate a mechanic estimate'),
                    ),
                ],
                if (r.mechanicId != null && r.status != RequestStatus.cancelled)
                  SectionCard(
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRouter.mechanicProfile,
                      arguments: r.mechanicId,
                    ),
                    child: Row(
                      children: <Widget>[
                        const CircleAvatar(
                          backgroundColor: AppColors.primarySoft,
                          child: Icon(Icons.handyman, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                r.mechanicName ?? 'Mechanic',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (r.agreedAmount != null)
                                Text(
                                  'Agreed price: ${formatMoney(r.agreedAmount!)}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                if (canChat)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed(
                        AppRouter.chat,
                        arguments: ChatArgs(r.id, r.mechanicName ?? 'Mechanic'),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat with mechanic'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                if (r.status == RequestStatus.completed)
                  _PayCard(request: r),
                if (r.status == RequestStatus.paid)
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Payment received. How was the service?',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pushNamed(
                            AppRouter.review,
                            arguments: r.id,
                          ),
                          child: const Text('Rate your mechanic'),
                        ),
                      ],
                    ),
                  ),
                if (r.status == RequestStatus.closed && review != null)
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Your review',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        StarRow(rating: review.rating),
                        if (review.comment.isNotEmpty) Text(review.comment),
                      ],
                    ),
                  ),
                if (r.status == RequestStatus.disputed)
                  const SectionCard(
                    child: Text(
                      'Your complaint is under review. We will update you soon.',
                    ),
                  ),
                if (r.status == RequestStatus.cancelled)
                  SectionCard(
                    child: Text('Cancelled: ${r.cancelReason ?? ''}'),
                  ),
                if (r.status == RequestStatus.expired)
                  const SectionCard(
                    child: Text(
                      'No mechanic accepted in time. You can create a new '
                      'request from the home screen.',
                    ),
                  ),
                if (complaintAllowed)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppRouter.complaint,
                      arguments: r.id,
                    ),
                    icon: const Icon(Icons.report_problem_outlined),
                    label: const Text('Submit a complaint'),
                  ),
                if (kDebugMode &&
                    r.mechanicId != null &&
                    (r.status == RequestStatus.accepted ||
                        r.status == RequestStatus.onTheWay ||
                        r.status == RequestStatus.arrived ||
                        r.status == RequestStatus.working ||
                        r.awaitingCashConfirmation))
                  TextButton.icon(
                    onPressed:
                        c.isLoading ? null : () => c.debugAdvanceJob(r.id),
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('Demo: mechanic does the next step'),
                  ),
                if (r.status.canMoveTo(RequestStatus.cancelled))
                  OutlinedButton.icon(
                    onPressed: c.isLoading ? null : () => _cancel(r),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel request'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _PayCard extends StatelessWidget {
  const _PayCard({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final bool waiting = request.awaitingCashConfirmation;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            waiting
                ? 'Waiting for your mechanic to confirm the cash payment.'
                : 'The job is done. Please pay '
                    '${formatMoney(request.agreedAmount ?? 0)}.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).pushNamed(
              AppRouter.payment,
              arguments: request.id,
            ),
            child: Text(waiting ? 'Change payment method' : 'Pay now'),
          ),
        ],
      ),
    );
  }
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard({
    required this.estimate,
    required this.now,
    required this.requestId,
  });

  final Estimate estimate;
  final DateTime now;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    final CustomerController c = context.read<CustomerController>();
    final Duration left = estimate.expiresAt.difference(now);
    final bool expired = left.isNegative;
    final String seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
    final String timeLeft = expired ? 'Expired' : '${left.inMinutes}:$seconds left';

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRouter.mechanicProfile,
                    arguments: estimate.mechanicId,
                  ),
                  child: Text(
                    estimate.mechanicName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              Text(
                formatMoney(estimate.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Arrives in about ${estimate.etaMinutes} min  -  $timeLeft',
            style: TextStyle(
              color: expired ? AppColors.error : AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          if (estimate.note.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(estimate.note),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: c.isLoading
                      ? null
                      : () => c.declineEstimate(estimate.id),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: c.isLoading || expired
                      ? null
                      : () => c.acceptEstimate(requestId, estimate.id),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
