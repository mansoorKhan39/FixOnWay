import 'package:flutter_test/flutter_test.dart';
import 'package:fixonway/core/utils/ui_helpers.dart';
import 'package:fixonway/models/lat_lng.dart';

void main() {
  test('formatMoney groups thousands', () {
    expect(formatMoney(0), 'PKR 0');
    expect(formatMoney(999), 'PKR 999');
    expect(formatMoney(1500), 'PKR 1,500');
    expect(formatMoney(100000), 'PKR 100,000');
  });

  test('formatDistance uses metres below 1 km', () {
    expect(formatDistance(0.45), '450 m');
    expect(formatDistance(2.345), '2.3 km');
  });

  test('formatDateTime shows 12 hour time', () {
    expect(formatDateTime(DateTime(2026, 10, 24, 21, 5)), '24 Oct, 9:05 PM');
    expect(formatDateTime(DateTime(2026, 1, 1, 0, 0)), '1 Jan, 12:00 AM');
    expect(formatDateTime(DateTime(2026, 1, 1, 12, 30)), '1 Jan, 12:30 PM');
  });

  group('LatLng', () {
    test('distance to itself is zero', () {
      expect(LatLng.islamabad.distanceKmTo(LatLng.islamabad), 0);
    });

    test('Islamabad to Lahore is roughly 270 km', () {
      const LatLng lahore = LatLng(31.5204, 74.3587);
      final double km = LatLng.islamabad.distanceKmTo(lahore);
      expect(km > 240 && km < 300, isTrue);
    });

    test('bounding box of Pakistan', () {
      expect(LatLng.islamabad.isInPakistan, isTrue);
      expect(const LatLng(51.5, -0.12).isInPakistan, isFalse);
    });
  });
}
