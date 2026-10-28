import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/customer_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/map_canvas.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/enums/problem_type.dart';
import '../../models/lat_lng.dart';
import '../../models/service_request.dart';
import '../../routes/app_router.dart';
import '../../services/location_service.dart';
import '../../services/request_service.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  Future<void> _locate(BuildContext context) async {
    final CustomerController c = context.read<CustomerController>();
    final LocationService locator = context.read<LocationService>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final LocationResult result = await locator.current();
    final LatLng? found = result.position;
    if (found != null) {
      await c.setMyLocation(found);
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(result.message ?? 'Could not get your location.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    final CustomerController c = context.watch<CustomerController>();
    final ServiceRequest? active = c.activeRequest;

    return RefreshIndicator(
      onRefresh: () async {
        await c.refresh();
        await c.loadNearby(c.searchCenter);
      },
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
          const SizedBox(height: 4),
          const Text(
            'Stuck on the road? We will send help.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          if (active != null) _ActiveCard(request: active),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: active != null
                  ? null
                  : () => Navigator.of(context)
                      .pushNamed(AppRouter.createRequest),
              icon: const Icon(Icons.sos),
              label: Text(
                active != null
                    ? 'You have an active request'
                    : 'Request roadside help',
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'What happened?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final ProblemType p in ProblemType.values)
                ActionChip(
                  avatar: Icon(p.icon, size: 18, color: AppColors.primary),
                  label: Text(p.label),
                  onPressed: active != null
                      ? null
                      : () => Navigator.of(context).pushNamed(
                            AppRouter.createRequest,
                            arguments: p,
                          ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Mechanics near you',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () => _locate(context),
                icon: const Icon(Icons.my_location, size: 18),
                label: Text(c.myLocation == null ? 'Use my location' : 'Update'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MapCanvas(
            center: c.searchCenter,
            height: 220,
            markers: <MapMarker>[
              MapMarker(
                position: c.searchCenter,
                color: AppColors.info,
                icon: Icons.my_location,
              ),
              for (final NearbyMechanic m in c.nearby)
                MapMarker(
                  position: m.profile.location,
                  color: AppColors.primary,
                  icon: Icons.build_circle,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (c.nearby.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No mechanics online nearby right now.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          for (final NearbyMechanic m in c.nearby)
            SectionCard(
              onTap: () => Navigator.of(context).pushNamed(
                AppRouter.mechanicProfile,
                arguments: m.profile.userId,
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
                          m.profile.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${m.profile.rating.toStringAsFixed(1)} rating  -  '
                          '${m.profile.jobsDone} jobs',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatDistance(m.distanceKm),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      onTap: () => Navigator.of(context).pushNamed(
        AppRouter.requestDetail,
        arguments: request.id,
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            child: Icon(request.problem.icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  request.problem.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                StatusChip(status: request.status),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
