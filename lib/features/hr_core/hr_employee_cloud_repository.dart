import 'hr_employee_models.dart';

abstract class HrEmployeeCloudRepository {
  Future<List<HrEmployeeProfile>> listProfiles();
  Future<List<HrContract>> listContracts();
  Future<void> upsertProfile(HrEmployeeProfile item);
  Future<void> upsertContract(HrContract item);
}
