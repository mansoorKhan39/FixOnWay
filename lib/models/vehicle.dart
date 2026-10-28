import 'enums/vehicle_type.dart';

class Vehicle {
  const Vehicle({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.make,
    required this.model,
    required this.plate,
  });

  final String id;
  final String ownerId;
  final VehicleType type;
  final String make;
  final String model;
  final String plate;

  String get title => '$make $model';

  Vehicle copyWith({
    VehicleType? type,
    String? make,
    String? model,
    String? plate,
  }) {
    return Vehicle(
      id: id,
      ownerId: ownerId,
      type: type ?? this.type,
      make: make ?? this.make,
      model: model ?? this.model,
      plate: plate ?? this.plate,
    );
  }

  factory Vehicle.fromMap(String id, Map<String, dynamic> map) {
    return Vehicle(
      id: id,
      ownerId: map['ownerId'] as String,
      type: VehicleType.values.byName(map['type'] as String),
      make: map['make'] as String,
      model: map['model'] as String,
      plate: map['plate'] as String,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerId': ownerId,
        'type': type.name,
        'make': make,
        'model': model,
        'plate': plate,
      };
}
