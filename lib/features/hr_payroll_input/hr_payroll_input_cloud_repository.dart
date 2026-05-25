import 'hr_payroll_input_snapshot_models.dart';

abstract class HrPayrollInputCloudRepository {
  Future<List<HrPayrollInputSnapshot>> listSnapshots();
  Future<void> upsertSnapshot(HrPayrollInputSnapshot item);
}
