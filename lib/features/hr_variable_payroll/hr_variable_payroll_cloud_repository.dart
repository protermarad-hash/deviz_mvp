import 'hr_variable_payroll_models.dart';

abstract class HrVariablePayrollCloudRepository {
  Future<List<HrBonus>> listBonuses();
  Future<List<HrDeduction>> listDeductions();
  Future<List<HrAdvance>> listAdvances();
  Future<List<HrGarnishment>> listGarnishments();
  Future<void> upsertBonus(HrBonus item);
  Future<void> upsertDeduction(HrDeduction item);
  Future<void> upsertAdvance(HrAdvance item);
  Future<void> upsertGarnishment(HrGarnishment item);
}
