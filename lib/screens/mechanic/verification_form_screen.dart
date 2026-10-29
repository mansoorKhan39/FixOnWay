import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/mechanic_controller.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/document_ref.dart';
import '../../models/enums/problem_type.dart';
import '../../models/enums/vehicle_type.dart';
import '../../services/photo_service.dart';

/// UC-23: details and documents for verification.
class VerificationFormScreen extends StatefulWidget {
  const VerificationFormScreen({super.key});

  @override
  State<VerificationFormScreen> createState() => _VerificationFormScreenState();
}

class _VerificationFormScreenState extends State<VerificationFormScreen> {
  static const List<String> _documentNames = <String>[
    'CNIC front',
    'CNIC back',
    'Driving licence',
    'Workshop photo',
    'Skill certificate',
  ];

  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _cnic = TextEditingController();
  final TextEditingController _experience = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final Set<ProblemType> _services = <ProblemType>{};
  final Set<VehicleType> _vehicles = <VehicleType>{};
  final List<String> _documents = <String>[];
  String? _choiceError;
  String? _documentError;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    context.read<MechanicController>().clearError();
  }

  @override
  void dispose() {
    _cnic.dispose();
    _experience.dispose();
    _address.dispose();
    super.dispose();
  }

  /// Asks which document it is, then picks the picture and uploads it.
  Future<void> _addDocument() async {
    final Set<String> used = <String>{
      for (final String d in _documents) DocumentRef.parse(d).label,
    };
    final List<String> choices =
        _documentNames.where((String n) => !used.contains(n)).toList();
    if (choices.isEmpty) return;
    final PhotoService service = context.read<PhotoService>();
    final String? label = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text('Which document?'),
        children: <Widget>[
          for (final String name in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(name),
              child: Text(name),
            ),
        ],
      ),
    );
    if (label == null || !mounted) return;
    setState(() {
      _documentError = null;
      _uploading = true;
    });
    try {
      final String? saved = await service.pickDocument(label);
      if (!mounted) return;
      if (saved != null) setState(() => _documents.add(saved));
    } on AppException catch (e) {
      if (mounted) setState(() => _documentError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _documentError = 'Could not upload the picture. Try again.');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final bool valid = _form.currentState!.validate();
    setState(() {
      _choiceError = _services.isEmpty || _vehicles.isEmpty
          ? 'Choose at least one service and one vehicle type.'
          : null;
    });
    if (!valid || _choiceError != null) return;
    final MechanicController c = context.read<MechanicController>();
    final AuthController auth = context.read<AuthController>();
    final NavigatorState navigator = Navigator.of(context);
    final bool ok = await c.submitApplication(
      user: auth.user!,
      cnic: _cnic.text,
      experienceYears: int.parse(_experience.text.trim()),
      workshopAddress: _address.text,
      services: _services,
      vehicleTypes: _vehicles,
      documents: _documents,
    );
    if (ok) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final MechanicController c = context.watch<MechanicController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Verification details')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  if (c.errorMessage != null)
                    ErrorBanner(message: c.errorMessage!),
                  AppTextField(
                    controller: _cnic,
                    label: 'CNIC number',
                    hint: '12345-1234567-1',
                    icon: Icons.badge_outlined,
                    keyboardType: TextInputType.number,
                    validator: Validators.cnic,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _experience,
                    label: 'Years of experience',
                    icon: Icons.work_history_outlined,
                    keyboardType: TextInputType.number,
                    validator: Validators.experience,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _address,
                    label: 'Workshop address',
                    icon: Icons.store_outlined,
                    validator: Validators.workshopAddress,
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
                  const SizedBox(height: 16),
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
                  if (_choiceError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _choiceError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'Documents (at least 2)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      for (final String d in _documents)
                        InputChip(
                          avatar: Icon(
                            DocumentRef.parse(d).hasFile
                                ? Icons.check_circle
                                : Icons.description,
                            size: 18,
                          ),
                          label: Text(DocumentRef.parse(d).label),
                          onDeleted: () =>
                              setState(() => _documents.remove(d)),
                        ),
                      if (_documents.length < _documentNames.length)
                        OutlinedButton.icon(
                          onPressed: _uploading ? null : _addDocument,
                          icon: _uploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_file),
                          label: Text(_uploading ? 'Uploading...' : 'Add document'),
                        ),
                    ],
                  ),
                  if (_documentError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _documentError!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pictures only (JPG, PNG), up to 5 MB each. Only you and the admin can open them.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Submit for verification',
                    isLoading: c.isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
