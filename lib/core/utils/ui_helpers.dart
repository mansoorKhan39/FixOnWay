import 'package:flutter/material.dart';

import '../../models/enums/problem_type.dart';
import '../../models/enums/request_status.dart';
import '../../models/enums/vehicle_type.dart';
import '../theme/app_theme.dart';

extension ProblemTypeUi on ProblemType {
  IconData get icon => switch (this) {
        ProblemType.flatTire => Icons.tire_repair,
        ProblemType.batteryJump => Icons.battery_charging_full,
        ProblemType.outOfFuel => Icons.local_gas_station,
        ProblemType.engineTrouble => Icons.engineering,
        ProblemType.towing => Icons.rv_hookup,
        ProblemType.lockout => Icons.key,
        ProblemType.other => Icons.build,
      };
}

extension VehicleTypeUi on VehicleType {
  IconData get icon => switch (this) {
        VehicleType.car => Icons.directions_car,
        VehicleType.bike => Icons.two_wheeler,
        VehicleType.rickshaw => Icons.electric_rickshaw,
        VehicleType.van => Icons.local_shipping,
      };
}

extension RequestStatusUi on RequestStatus {
  String get label => switch (this) {
        RequestStatus.pending => 'Finding mechanics',
        RequestStatus.estimated => 'Estimates received',
        RequestStatus.accepted => 'Mechanic assigned',
        RequestStatus.onTheWay => 'Mechanic on the way',
        RequestStatus.arrived => 'Mechanic arrived',
        RequestStatus.working => 'Work in progress',
        RequestStatus.completed => 'Work completed',
        RequestStatus.paid => 'Paid',
        RequestStatus.disputed => 'Disputed',
        RequestStatus.closed => 'Closed',
        RequestStatus.cancelled => 'Cancelled',
        RequestStatus.expired => 'Expired',
      };

  Color get color => switch (this) {
        RequestStatus.pending => AppColors.info,
        RequestStatus.estimated => AppColors.primary,
        RequestStatus.accepted ||
        RequestStatus.onTheWay ||
        RequestStatus.arrived ||
        RequestStatus.working =>
          AppColors.primaryDark,
        RequestStatus.completed ||
        RequestStatus.paid ||
        RequestStatus.closed =>
          AppColors.success,
        RequestStatus.disputed ||
        RequestStatus.cancelled ||
        RequestStatus.expired =>
          AppColors.error,
      };
}

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// e.g. "24 Oct, 9:15 PM".
String formatDateTime(DateTime t) {
  final int hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final String minute = t.minute.toString().padLeft(2, '0');
  final String period = t.hour >= 12 ? 'PM' : 'AM';
  return '${t.day} ${_months[t.month - 1]}, $hour12:$minute $period';
}

String formatMoney(int amount) {
  final String digits = amount.toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return 'PKR $out';
}

String formatDistance(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
