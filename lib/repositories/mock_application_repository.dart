import '../models/mechanic_application.dart';
import 'application_repository.dart';
import 'mock_data_store.dart';

class MockApplicationRepository implements ApplicationRepository {
  MockApplicationRepository(this._store);

  final MockDataStore _store;

  @override
  Future<MechanicApplication?> byUser(String userId) async {
    await _store.simulate();
    return _store.applications[userId];
  }

  @override
  Future<void> save(MechanicApplication application) async {
    await _store.simulate();
    _store.applications[application.userId] = application;
  }

  @override
  Future<List<MechanicApplication>> all() async {
    await _store.simulate();
    return _store.applications.values.toList();
  }

  @override
  Future<void> remove(String userId) async {
    await _store.simulate();
    _store.applications.remove(userId);
  }
}
