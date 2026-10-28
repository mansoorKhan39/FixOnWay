import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/customer_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_card.dart';
import '../../models/enums/vehicle_type.dart';
import '../../models/vehicle.dart';

typedef _VehicleForm = ({
  VehicleType type,
  String make,
  String model,
  String plate,
});

/// UC-21: manage saved vehicles.
class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  Future<void> _showResult(
    BuildContext context,
    Future<bool> action,
    String success,
  ) async {
    final CustomerController c = context.read<CustomerController>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool ok = await action;
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? success : c.errorMessage ?? 'Failed.')),
    );
  }

  Future<void> _add(BuildContext context) async {
    final CustomerController c = context.read<CustomerController>();
    if (c.vehicles.length >= AppConstants.maxVehicles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You can save up to ${AppConstants.maxVehicles} vehicles.',
          ),
        ),
      );
      return;
    }
    final _VehicleForm? form = await showDialog<_VehicleForm>(
      context: context,
      builder: (BuildContext _) => const _VehicleDialog(),
    );
    if (form == null || !context.mounted) return;
    await _showResult(
      context,
      c.addVehicle(
        type: form.type,
        make: form.make,
        model: form.model,
        plate: form.plate,
      ),
      'Vehicle saved.',
    );
  }

  Future<void> _edit(BuildContext context, Vehicle v) async {
    final CustomerController c = context.read<CustomerController>();
    final _VehicleForm? form = await showDialog<_VehicleForm>(
      context: context,
      builder: (BuildContext _) => _VehicleDialog(vehicle: v),
    );
    if (form == null || !context.mounted) return;
    await _showResult(
      context,
      c.updateVehicle(
        v,
        type: form.type,
        make: form.make,
        model: form.model,
        plate: form.plate,
      ),
      'Vehicle updated.',
    );
  }

  Future<void> _delete(BuildContext context, Vehicle v) async {
    final CustomerController c = context.read<CustomerController>();
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Remove vehicle?'),
        content: Text('${v.title} (${v.plate}) will be removed.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    await _showResult(context, c.removeVehicle(v), 'Vehicle removed.');
  }

  @override
  Widget build(BuildContext context) {
    final CustomerController c = context.watch<CustomerController>();
    return Scaffold(
      appBar: AppBar(title: const Text('My vehicles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add vehicle'),
      ),
      body: c.vehicles.isEmpty
          ? const EmptyState(
              icon: Icons.directions_car_outlined,
              message: 'No vehicles yet. Add one to request help.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              itemCount: c.vehicles.length,
              itemBuilder: (BuildContext context, int i) {
                final Vehicle v = c.vehicles[i];
                return SectionCard(
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        backgroundColor: AppColors.primarySoft,
                        child: Icon(v.type.icon, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              v.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${v.type.label}  -  ${v.plate}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(context, v),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, v),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _VehicleDialog extends StatefulWidget {
  const _VehicleDialog({this.vehicle});

  final Vehicle? vehicle;

  @override
  State<_VehicleDialog> createState() => _VehicleDialogState();
}

class _VehicleDialogState extends State<_VehicleDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _make =
      TextEditingController(text: widget.vehicle?.make ?? '');
  late final TextEditingController _model =
      TextEditingController(text: widget.vehicle?.model ?? '');
  late final TextEditingController _plate =
      TextEditingController(text: widget.vehicle?.plate ?? '');
  late VehicleType _type = widget.vehicle?.type ?? VehicleType.car;

  @override
  void dispose() {
    _make.dispose();
    _model.dispose();
    _plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.vehicle == null ? 'Add vehicle' : 'Edit vehicle'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final VehicleType t in VehicleType.values)
                    ChoiceChip(
                      label: Text(t.label),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _make,
                decoration: const InputDecoration(
                  labelText: 'Make',
                  hintText: 'Suzuki',
                ),
                validator: (String? v) => Validators.required(v, 'Make'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _model,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'Cultus',
                ),
                validator: (String? v) => Validators.required(v, 'Model'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Number plate',
                  hintText: 'ICT-1234',
                ),
                validator: Validators.plate,
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
              type: _type,
              make: _make.text.trim(),
              model: _model.text.trim(),
              plate: _plate.text.trim(),
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
