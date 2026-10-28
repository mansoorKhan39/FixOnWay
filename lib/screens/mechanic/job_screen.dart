import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/chat_controller.dart';
import '../../controllers/mechanic_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/job_progress.dart';
import '../../core/widgets/map_canvas.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/enums/request_status.dart';
import '../../models/lat_lng.dart';
import '../../models/service_request.dart';
import '../../routes/app_router.dart';
import '../../services/location_service.dart';
import '../../services/tracking.dart';
import '../chat_screen.dart';

/// UC-29 update job status, UC-30 navigate to customer, UC-31 complete job,
/// UC-40 confirm payment.
class MechanicJobScreen extends StatefulWidget {
  const MechanicJobScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<MechanicJobScreen> createState() => _MechanicJobScreenState();
}

class _MechanicJobScreenState extends State<MechanicJobScreen> {
  Timer? _tick;
  Timer? _gpsTimer;
  LatLng? _myGps;
  bool _gpsFailed = false;

  @override
  void initState() {
    super.initState();
    context.read<MechanicController>().clearError();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // Live GPS: while on the way, share the phone's position every 8 s.
    _gpsTimer = Timer.periodic(const Duration(seconds: 8), (_) => _shareGps());
    WidgetsBinding.instance.addPostFrameCallback((_) => _shareGps());
  }

  Future<void> _shareGps() async {
    if (!mounted || _gpsFailed) return;
    final MechanicController c = context.read<MechanicController>();
    final LocationService locator = context.read<LocationService>();
    final ServiceRequest? r = c.jobById(widget.requestId);
    if (r == null || r.status != RequestStatus.onTheWay) return;
    final LocationResult result = await locator.current();
    if (!mounted) return;
    final LatLng? found = result.position;
    if (found == null) {
      // No permission or no GPS: stop asking, the demo tracking is shown.
      _gpsFailed = true;
      return;
    }
    setState(() => _myGps = found);
    await c.shareLocation(widget.requestId, found);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _gpsTimer?.cancel();
    super.dispose();
  }

  LatLng _mechanicPosition(ServiceRequest r, LatLng? home) {
    if (r.status == RequestStatus.onTheWay && _myGps != null) return _myGps!;
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
    if (r.status == RequestStatus.accepted) return home ?? r.location;
    return r.location;
  }

  @override
  Widget build(BuildContext context) {
    final MechanicController c = context.watch<MechanicController>();
    final ServiceRequest? r = c.jobById(widget.requestId);
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final LatLng mechanicPos = _mechanicPosition(r, c.profile?.location);
    final double km = mechanicPos.distanceKmTo(r.location);
    final bool travelling = r.status == RequestStatus.accepted ||
        r.status == RequestStatus.onTheWay;
    final bool canChat = context.read<ChatController>().canChat(r);

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
                    if (r.agreedAmount != null)
                      Text(
                        formatMoney(r.agreedAmount!),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.primaryDark,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                JobProgress(status: r.status),
                const SizedBox(height: 12),
                MapCanvas(
                  center: r.location,
                  height: 200,
                  spanDegrees: 0.08,
                  path: travelling
                      ? <LatLng>[mechanicPos, r.location]
                      : const <LatLng>[],
                  markers: <MapMarker>[
                    MapMarker(
                      position: r.location,
                      color: AppColors.error,
                      icon: Icons.location_on,
                    ),
                    if (travelling)
                      MapMarker(
                        position: mechanicPos,
                        color: AppColors.info,
                        icon: Icons.directions_car,
                      ),
                  ],
                ),
                if (travelling)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Distance to customer: ${formatDistance(km)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 12),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _row(Icons.person_outline, r.customerName),
                      _row(Icons.directions_car_outlined, r.vehicleTitle),
                      _row(Icons.place_outlined, r.address),
                      if (r.description.isNotEmpty)
                        _row(Icons.notes, r.description),
                    ],
                  ),
                ),
                if (canChat)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppRouter.chat,
                      arguments: ChatArgs(r.id, r.customerName),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat with customer'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                const SizedBox(height: 12),
                ..._actions(context, c, r),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    MechanicController c,
    ServiceRequest r,
  ) {
    Widget button(String label, Future<bool> Function() action) {
      return SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: c.isLoading ? null : () => action(),
          child: Text(label),
        ),
      );
    }

    switch (r.status) {
      case RequestStatus.accepted:
        return <Widget>[button('Start trip', () => c.startTrip(r.id))];
      case RequestStatus.onTheWay:
        return <Widget>[button('I have arrived', () => c.markArrived(r.id))];
      case RequestStatus.arrived:
        return <Widget>[button('Start work', () => c.startWork(r.id))];
      case RequestStatus.working:
        return <Widget>[button('Complete job', () => c.completeJob(r.id))];
      case RequestStatus.completed:
        if (r.awaitingCashConfirmation) {
          return <Widget>[
            const Text('The customer chose to pay cash.'),
            const SizedBox(height: 8),
            button(
              'Confirm ${formatMoney(r.agreedAmount ?? 0)} received',
              () => c.confirmCash(r.id),
            ),
          ];
        }
        return <Widget>[
          const SectionCard(
            child: Text('Waiting for the customer to pay.'),
          ),
        ];
      case RequestStatus.paid:
      case RequestStatus.closed:
        return <Widget>[
          const SectionCard(
            child: Text('Paid. Well done! The money is in your earnings.'),
          ),
        ];
      case RequestStatus.disputed:
        return <Widget>[
          const SectionCard(
            child: Text('The customer raised a complaint. Our team is looking into it.'),
          ),
        ];
      case RequestStatus.cancelled:
        return <Widget>[
          SectionCard(child: Text('Cancelled: ${r.cancelReason ?? ''}')),
        ];
      default:
        return <Widget>[];
    }
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
