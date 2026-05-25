import 'hr_payroll_calculation_models.dart';

abstract class HrPayrollCalculationCloudRepository {
  Future<List<HrPayrollCalculationResult>> listResults();
  Future<void> upsertResult(HrPayrollCalculationResult item);
}
