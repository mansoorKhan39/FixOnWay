import '../models/mechanic_application.dart';

abstract class ApplicationRepository {
  Future<MechanicApplication?> byUser(String userId);

  Future<void> save(MechanicApplication application);

  Future<List<MechanicApplication>> all();

  Future<void> remove(String userId);
}
