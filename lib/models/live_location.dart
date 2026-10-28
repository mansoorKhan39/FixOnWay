import 'lat_lng.dart';

/// Where the mechanic is right now while driving to the customer.
class LiveLocation {
  const LiveLocation({required this.position, required this.updatedAt});

  final LatLng position;
  final DateTime updatedAt;

  /// True when the position is recent enough to trust.
  bool isFreshAt(DateTime now, Duration maxAge) =>
      now.difference(updatedAt) <= maxAge;
}
