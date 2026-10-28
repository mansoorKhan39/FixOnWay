import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/vehicle.dart';
import '../vehicle_repository.dart';
import 'firebase_support.dart';

class FirestoreVehicleRepository implements VehicleRepository {
  FirestoreVehicleRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _vehicles =>
      _db.collection(Col.vehicles);

  @override
  Future<List<Vehicle>> byOwner(String ownerId) {
    return guardFirebase(() async {
      final QuerySnapshot<Map<String, dynamic>> snap =
          await _vehicles.where('ownerId', isEqualTo: ownerId).get();
      final List<Vehicle> list = snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              Vehicle.fromMap(d.id, d.data()))
          .toList();
      list.sort((Vehicle a, Vehicle b) => a.title.compareTo(b.title));
      return list;
    });
  }

  @override
  Future<Vehicle> save(Vehicle vehicle) {
    return guardFirebase(() async {
      final DocumentReference<Map<String, dynamic>> ref = vehicle.id.isEmpty
          ? _vehicles.doc()
          : _vehicles.doc(vehicle.id);
      await ref.set(vehicle.toMap());
      return Vehicle.fromMap(ref.id, vehicle.toMap());
    });
  }

  @override
  Future<void> delete(String vehicleId) {
    return guardFirebase(() => _vehicles.doc(vehicleId).delete());
  }
}
