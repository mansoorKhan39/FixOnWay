import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/mechanic_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/enums/problem_type.dart';
import '../../models/lat_lng.dart';
import '../../models/enums/vehicle_type.dart';
import '../../models/mechanic_profile.dart';
import '../../services/location_service.dart';
import '../../services/mechanic_service.dart';

/// UC-24: service area, working hours and what the mechanic offers.
class ServiceAreaScreen extends StatefulWidget {
  const ServiceAreaScreen({super.key});

  @override
  State<ServiceAreaScreen> createState() => _ServiceAreaScreenState();
}

class _ServiceAreaScreenState extends State<ServiceAreaScreen> {
  late double _radius;
  late int _start;
  late int _end;
  late Set<ProblemType> _services;
  late Set<VehicleType> _vehicles;

  @override
  void initState() {
    super.initState();
    final MechanicController c = context.read<MechanicController>();
    c.clearError();
    final MechanicProfile? p = c.profile;
    _radius = (p?.serviceRadiusKm ?? AppConstants.defaultRadiusKm).toDouble();
    final ({int start, int end}) hours =
        MechanicService.parseHours(p?.workingHours ?? '');
    _start = hours.start;
    _end = hours.end;
    _services = <ProblemType>{...?p?.services};
    _vehicles = <VehicleType>{...?p?.vehicleTypes};
  }

  Future<void> _pick(bool isStart) async {
    final int current = isStart ? _start : _end;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    setState(() {
      final int minutes = picked.hour * 60 + picked.minute;
      if (isStart) {
        _start = minutes;
      } else {
        _end = minutes;
      }
    });
  }

  Future<void> _useGps() async {
    final MechanicController c = context.read<MechanicController>();
    final LocationService locator = context.read<LocationService>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final LocationResult result = await locator.current();
    final LatLng? found = result.position;
    if (found == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.message ?? 'Could not get your location.')),
      );
      return;
    }
    final bool ok = await c.setLocation(found);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Work location updated.' : c.errorMessage ?? 'Could not save.',
        ),
      ),
    );
  }

  Future<void> _save() async {
    final MechanicController c = context.read<MechanicController>();
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool ok = await c.updateServiceArea(
      radiusKm: _radius.round(),
      startMinutes: _start,
      endMinutes: _end,
      services: _services,
      vehicleTypes: _vehicles,
    );
    if (ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Saved.')));
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final MechanicController c = context.watch<MechanicController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Service area')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                if (c.errorMessage != null)
                  ErrorBanner(message: c.errorMessage!),
                OutlinedButton.icon(
                  onPressed: _useGps,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use my current location as work location'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Service radius: ${_radius.round()} km',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: _radius,
                  min: AppConstants.minRadiusKm.toDouble(),
                  max: AppConstants.maxRadiusKm.toDouble(),
                  divisions: AppConstants.maxRadiusKm - AppConstants.minRadiusKm,
                  label: '${_radius.round()} km',
                  onChanged: (double v) => setState(() => _radius = v),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Working hours',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pick(true),
                        child: Text('From ${MechanicService.formatMinutes(_start)}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pick(false),
                        child: Text('To ${MechanicService.formatMinutes(_end)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Services you offer',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final ProblemType p in ProblemType.values)
                      FilterChip(
                        label: Text(p.label),
                        selected: _services.contains(p),
                        onSelected: (bool on) => setState(() {
                          if (on) {
                            _services.add(p);
                          } else {
                            _services.remove(p);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Vehicles you work on',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final VehicleType t in VehicleType.values)
                      FilterChip(
                        label: Text(t.label),
                        selected: _vehicles.contains(t),
                        onSelected: (bool on) => setState(() {
                          if (on) {
                            _vehicles.add(t);
                          } else {
                            _vehicles.remove(t);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Save',
                  isLoading: c.isLoading,
                  onPressed: _save,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Customers within your radius who need one of your services '
                  'will see you as available.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
