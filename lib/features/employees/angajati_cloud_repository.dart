import '../master/master_local_store.dart';

abstract class AngajatiCloudRepository {
  Future<List<MasterEmployee>> listEmployees();
  Stream<List<MasterEmployee>> watchEmployees();
  Future<void> upsertEmployee(MasterEmployee employee);
  Future<void> deleteEmployee(String employeeId);
}

