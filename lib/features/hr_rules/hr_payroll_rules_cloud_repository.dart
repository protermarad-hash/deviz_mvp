import 'hr_payroll_rule_models.dart';

abstract class HrPayrollRulesCloudRepository {
  Future<List<HrPayrollRuleSet>> listRuleSets();
  Future<List<HrPayrollRuleVersion>> listRuleVersions();
  Future<void> upsertRuleSet(HrPayrollRuleSet item);
  Future<void> upsertRuleVersion(HrPayrollRuleVersion item);
}
