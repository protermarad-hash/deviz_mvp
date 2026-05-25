import 'hr_payroll_run_models.dart';

abstract class HrPayrollRunCloudRepository {
  Future<List<HrPayrollRun>> listRuns();
  Future<List<HrPayslip>> listPayslips();
  Future<void> upsertRun(HrPayrollRun item);
  Future<void> upsertPayslip(HrPayslip item);
}
