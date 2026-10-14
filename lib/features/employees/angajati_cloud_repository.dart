import '../master/master_local_store.dart';

abstract class AngajatiCloudRepository {
  Future<List<MasterEmployee>> listEmployees();

  /// `true` dacă ultimul [listEmployees] a venit din cache-ul local (offline),
  /// nu de la server.
  bool get lastListFromCache;
  Stream<List<MasterEmployee>> watchEmployees();
  Future<void> upsertEmployee(MasterEmployee employee);
  Future<void> deleteEmployee(String employeeId);
}

