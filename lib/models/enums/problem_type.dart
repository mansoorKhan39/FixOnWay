/// UC-09: what is wrong with the vehicle.
enum ProblemType {
  flatTire('Flat tire'),
  batteryJump('Battery / jump start'),
  outOfFuel('Out of fuel'),
  engineTrouble('Engine trouble'),
  towing('Towing'),
  lockout('Locked out'),
  other('Other');

  const ProblemType(this.label);

  final String label;
}
