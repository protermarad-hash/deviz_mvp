import 'hr_payroll_rule_models.dart';

class HrLegalRuleResolver {
  const HrLegalRuleResolver();

  HrPayrollRuleVersion? resolveActiveRule({
    required List<HrPayrollRuleVersion> rules,
    required String jurisdiction,
    required String scope,
    required String ruleType,
    required DateTime date,
  }) {
    final matches = rules.where((item) {
      return item.jurisdiction.trim().toUpperCase() ==
              jurisdiction.trim().toUpperCase() &&
          item.ruleType.trim().toLowerCase() == ruleType.trim().toLowerCase() &&
          item.appliesTo(date) &&
          _scopeMatches(item, scope);
    }).toList(growable: false);

    if (matches.isEmpty) return null;

    matches.sort((a, b) {
      final byFrom = b.effectiveFrom.compareTo(a.effectiveFrom);
      if (byFrom != 0) return byFrom;
      if (a.isDefault != b.isDefault) {
        return a.isDefault ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return matches.first;
  }

  HrPayrollRuleVersion? resolveActiveRuleForPayrollMonth({
    required List<HrPayrollRuleVersion> rules,
    required String jurisdiction,
    required String scope,
    required String ruleType,
    required DateTime payrollMonth,
  }) {
    final anchorDate = DateTime(payrollMonth.year, payrollMonth.month, 1);
    return resolveActiveRule(
      rules: rules,
      jurisdiction: jurisdiction,
      scope: scope,
      ruleType: ruleType,
      date: anchorDate,
    );
  }

  bool _scopeMatches(HrPayrollRuleVersion item, String scope) {
    final value = scope.trim().toLowerCase();
    if (value.isEmpty) return true;
    return item.ruleSetId.trim().toLowerCase().contains(value) ||
        value == _scopeFromRuleSetId(item.ruleSetId);
  }

  String _scopeFromRuleSetId(String ruleSetId) {
    final value = ruleSetId.trim().toLowerCase();
    if (value == 'ro-payroll') return 'payroll';
    if (value == 'ro-leave') return 'leave';
    if (value == 'ro-medical-leave') return 'medical_leave';
    if (value == 'ro-overtime') return 'overtime';
    if (value == 'ro-garnishment') return 'garnishment';
    return value;
  }
}
