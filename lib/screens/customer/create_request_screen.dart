import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/customer_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/map_canvas.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/section_card.dart';
import '../../models/enums/problem_type.dart';
import '../../models/lat_lng.dart';
import '../../models/photo_attachment.dart';
import '../../models/service_request.dart';
import '../../models/vehicle.dart';
import '../../routes/app_router.dart';
import '../../services/location_service.dart';
import '../../services/photo_service.dart';

/// UC-08 Create help request, with UC-09 (problem and vehicle), UC-10
/// (location) and UC-11 (photos).
class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key, this.initialProblem});

  final ProblemType? initialProblem;

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _address = TextEditingController();

  late ProblemType _problem = widget.initialProblem ?? ProblemType.flatTire;
  String? _vehicleId;
  LatLng _location = LatLng.islamabad;
  LatLng _mapCenter = LatLng.islamabad;
  bool _locating = false;
  String? _locationMessage;
  final List<PhotoAttachment> _photos = <PhotoAttachment>[];
  String? _photoError;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final CustomerController c = context.read<CustomerController>();
    c.clearError();
    _location = c.searchCenter;
    _mapCenter = _location;
  }

  @override
  void dispose() {
    _description.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= AppConstants.maxPhotos) {
      setState(() => _photoError =
          'You can attach up to ${AppConstants.maxPhotos} photos.');
      return;
    }
    final PhotoService service = context.read<PhotoService>();
    setState(() {
      _photoError = null;
      _uploading = true;
    });
    try {
      final PhotoAttachment? photo = await service.pick(_photos.length);
      if (!mounted) return;
      setState(() {
        if (photo != null) _photos.add(photo);
      });
    } on AppException catch (e) {
      if (mounted) setState(() => _photoError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _photoError = 'Could not add the photo. Try again.');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    final LocationService locator = context.read<LocationService>();
    setState(() {
      _locating = true;
      _locationMessage = null;
    });
    final LocationResult result = await locator.current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      final LatLng? found = result.position;
      if (found != null) {
        _location = found;
        _mapCenter = found;
        if (_address.text.trim().isEmpty) {
          _address.text = 'My current location (GPS)';
        }
      } else {
        _locationMessage = result.message;
      }
    });
  }

  Future<void> _submit(List<Vehicle> vehicles) async {
    if (!_form.currentState!.validate()) return;
    final Vehicle? vehicle = vehicles.cast<Vehicle?>().firstWhere(
          (Vehicle? v) => v!.id == _vehicleId,
          orElse: () => null,
        );
    if (vehicle == null) return;
    final AuthController auth = context.read<AuthController>();
    final CustomerController c = context.read<CustomerController>();
    final NavigatorState navigator = Navigator.of(context);
    final ServiceRequest? created = await c.createRequest(
      customer: auth.user!,
      vehicle: vehicle,
      problem: _problem,
      description: _description.text,
      location: _location,
      address: _address.text,
      photos: _photos,
    );
    if (created != null) {
      navigator.pushReplacementNamed(
        AppRouter.requestDetail,
        arguments: created.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final CustomerController c = context.watch<CustomerController>();
    final List<Vehicle> vehicles = c.vehicles;
    _vehicleId ??= vehicles.isEmpty ? null : vehicles.first.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Request help')),
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
                  _title('1. Your vehicle'),
                  if (vehicles.isEmpty)
                    SectionCard(
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRouter.vehicles),
                      child: const Row(
                        children: <Widget>[
                          Icon(Icons.add_circle_outline,
                              color: AppColors.primary),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text('Add a vehicle first (tap here)'),
                          ),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final Vehicle v in vehicles)
                          ChoiceChip(
                            avatar: Icon(v.type.icon, size: 18),
                            label: Text('${v.title} - ${v.plate}'),
                            selected: _vehicleId == v.id,
                            onSelected: (_) =>
                                setState(() => _vehicleId = v.id),
                          ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  _title('2. What is the problem?'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final ProblemType p in ProblemType.values)
                        ChoiceChip(
                          avatar: Icon(p.icon, size: 18),
                          label: Text(p.label),
                          selected: _problem == p,
                          onSelected: (_) => setState(() => _problem = p),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    maxLength: AppConstants.maxDescriptionLength,
                    decoration: InputDecoration(
                      labelText: _problem == ProblemType.other
                          ? 'Describe the problem'
                          : 'More details (optional)',
                    ),
                    validator: (String? v) => Validators.description(
                      v,
                      isRequired: _problem == ProblemType.other,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _title('3. Photos (optional)'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      for (int i = 0; i < _photos.length; i++)
                        InputChip(
                          avatar: const Icon(Icons.image, size: 18),
                          label: Text(_photos[i].name),
                          onDeleted: () => setState(() => _photos.removeAt(i)),
                        ),
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _addPhoto,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: Text(
                          _uploading
                              ? 'Uploading...'
                              : 'Add photo (${_photos.length}/${AppConstants.maxPhotos})',
                        ),
                      ),
                    ],
                  ),
                  if (_photoError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _photoError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _title('4. Where are you?'),
                  const Text(
                    'Tap the map to move the pin.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  MapCanvas(
                    center: _mapCenter,
                    height: 240,
                    onTap: (LatLng p) => setState(() => _location = p),
                    markers: <MapMarker>[
                      MapMarker(
                        position: _location,
                        color: AppColors.error,
                        icon: Icons.location_on,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _locating ? null : _useCurrentLocation,
                      icon: _locating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(
                        _locating
                            ? 'Finding your location...'
                            : 'Use my current location',
                      ),
                    ),
                  ),
                  if (_locationMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _locationMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'Address or landmark',
                      hintText: 'Near Faisal Avenue, Islamabad',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                    validator: (String? v) =>
                        Validators.required(v, 'Address or landmark'),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Send request',
                    isLoading: c.isLoading,
                    onPressed:
                        vehicles.isEmpty ? null : () => _submit(vehicles),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      );
}
