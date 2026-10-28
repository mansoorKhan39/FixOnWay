enum VehicleType {
  car('Car'),
  bike('Motorbike'),
  rickshaw('Rickshaw'),
  van('Van / Pickup');

  const VehicleType(this.label);

  final String label;
}
