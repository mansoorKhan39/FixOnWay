import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/customer_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/section_card.dart';
import '../../models/enums/problem_type.dart';
import '../../models/enums/vehicle_type.dart';
import '../../models/mechanic_profile.dart';

/// UC-41: a mechanic's public profile.
class MechanicProfileScreen extends StatefulWidget {
  const MechanicProfileScreen({super.key, required this.mechanicId});

  final String mechanicId;

  @override
  State<MechanicProfileScreen> createState() => _MechanicProfileScreenState();
}

class _MechanicProfileScreenState extends State<MechanicProfileScreen> {
  late final Future<MechanicProfile?> _future =
      context.read<CustomerController>().mechanicProfile(widget.mechanicId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mechanic')),
      body: FutureBuilder<MechanicProfile?>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<MechanicProfile?> snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final MechanicProfile? m = snap.data;
          if (m == null) {
            return const Center(child: Text('Mechanic not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    m.name[0],
                    style: const TextStyle(
                      fontSize: 34,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  m.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Center(
                child: Text(
                  m.isOnline ? 'Online now' : 'Offline',
                  style: TextStyle(
                    color: m.isOnline ? AppColors.success : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  _Stat(label: 'Rating', value: m.rating.toStringAsFixed(1)),
                  _Stat(label: 'Reviews', value: '${m.reviewCount}'),
                  _Stat(label: 'Jobs', value: '${m.jobsDone}'),
                  _Stat(label: 'Years', value: '${m.experienceYears}'),
                ],
              ),
              const SizedBox(height: 16),
              if (m.bio.isNotEmpty)
                SectionCard(child: Text(m.bio)),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Services',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final ProblemType p in m.services)
                          Chip(
                            avatar: Icon(p.icon, size: 16),
                            label: Text(p.label),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Vehicles served',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final VehicleType t in m.vehicleTypes)
                          Chip(
                            avatar: Icon(t.icon, size: 16),
                            label: Text(t.label),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Working hours: ${m.workingHours}'),
                    const SizedBox(height: 4),
                    Text('Service area: within ${m.serviceRadiusKm} km'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
