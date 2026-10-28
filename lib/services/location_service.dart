import 'package:geolocator/geolocator.dart';

import '../models/lat_lng.dart';

/// The result of asking for the device position: either a position or a
/// message that explains what went wrong.
class LocationResult {
  const LocationResult.found(LatLng this.position) : message = null;
  const LocationResult.failed(String this.message) : position = null;

  final LatLng? position;
  final String? message;

  bool get isFound => position != null;
}

/// Reads the real GPS position (browser location on the web).
class LocationService {
  const LocationService();

  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failed(
          'Location is turned off. Turn it on and try again.',
        );
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.failed(
          'Location permission was denied. Allow it and try again.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failed(
          'Location is blocked. Allow it in the browser or phone settings.',
        );
      }
      final Position p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationResult.found(LatLng(p.latitude, p.longitude));
    } catch (_) {
      return const LocationResult.failed(
        'Could not get your location. Check that location is allowed.',
      );
    }
  }
}
