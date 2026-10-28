import '../core/constants/app_constants.dart';
import '../models/lat_lng.dart';

/// UC-15: the demo mechanic drives in a straight line to the customer.
/// Real GPS positions come with the backend stage.
class Tracking {
  Tracking._();

  /// 0.0 at the start of the trip, 1.0 when the mechanic has arrived.
  static double progress({
    required DateTime startedAt,
    required int etaMinutes,
    required DateTime now,
  }) {
    final double totalSeconds =
        etaMinutes * 60 / AppConstants.trackingSpeedUp;
    if (totalSeconds <= 0) return 1;
    final double elapsed = now.difference(startedAt).inMilliseconds / 1000;
    if (elapsed <= 0) return 0;
    if (elapsed >= totalSeconds) return 1;
    return elapsed / totalSeconds;
  }

  static LatLng position({
    required LatLng start,
    required LatLng end,
    required double progress,
  }) {
    final double p = progress.clamp(0, 1).toDouble();
    return LatLng(
      start.lat + (end.lat - start.lat) * p,
      start.lng + (end.lng - start.lng) * p,
    );
  }

  /// Minutes still to go, as the customer sees it (never below 1 until arrival).
  static int remainingMinutes({
    required int etaMinutes,
    required double progress,
  }) {
    if (progress >= 1) return 0;
    final int left = ((1 - progress) * etaMinutes).ceil();
    return left < 1 ? 1 : left;
  }
}
