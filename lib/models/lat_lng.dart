import 'dart:math' as math;

/// A point on the map.
class LatLng {
  const LatLng(this.lat, this.lng);

  factory LatLng.fromMap(Map<String, dynamic> map) {
    return LatLng(
      (map['lat'] as num).toDouble(),
      (map['lng'] as num).toDouble(),
    );
  }

  /// Default map centre (Islamabad).
  static const LatLng islamabad = LatLng(33.6844, 73.0479);

  final double lat;
  final double lng;

  /// Great-circle distance in kilometres (haversine formula).
  double distanceKmTo(LatLng other) {
    const double earthRadiusKm = 6371;
    double rad(double deg) => deg * math.pi / 180;
    final double dLat = rad(other.lat - lat);
    final double dLng = rad(other.lng - lng);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat)) *
            math.cos(rad(other.lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Rough bounding box of Pakistan.
  bool get isInPakistan =>
      lat >= 23.5 && lat <= 37.1 && lng >= 60.8 && lng <= 77.9;

  Map<String, dynamic> toMap() => <String, dynamic>{'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) =>
      other is LatLng && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}
