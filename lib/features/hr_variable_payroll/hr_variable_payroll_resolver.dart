import 'hr_variable_payroll_models.dart';

class HrVariablePayrollResolver {
  const HrVariablePayrollResolver();

  List<HrBonus> activeBonusesForMonth(
    List<HrBonus> rows, {
    required String employeeId,
    required DateTime month,
  }) {
    final target = DateTime(month.year, month.month, 1);
    return rows
        .where((item) => item.employeeId.trim() == employeeId.trim())
        .where((item) => item.isActive)
        .where((item) =>
            item.effectiveMonth.year == target.year &&
            item.effectiveMonth.month == target.month)
        .toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<HrDeduction> activeDeductionsForMonth(
    List<HrDeduction> rows, {
    required String employeeId,
    required DateTime month,
  }) {
    return rows
        .where((item) => item.employeeId.trim() == employeeId.trim())
        .where((item) => item.appliesToMonth(month))
        .toList(growable: false)
      ..sort((a, b) {
        final byPriority = a.legalPriority.compareTo(b.legalPriority);
        if (byPriority != 0) return byPriority;
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  List<HrAdvance> activeAdvancesForMonth(
    List<HrAdvance> rows, {
    required String employeeId,
    required DateTime month,
  }) {
    return rows
        .where((item) => item.employeeId.trim() == employeeId.trim())
        .where((item) => item.appliesToMonth(month))
        .toList(growable: false)
      ..sort((a, b) => a.grantedAt.compareTo(b.grantedAt));
  }

  List<HrGarnishment> activeGarnishmentsForMonth(
    List<HrGarnishment> rows, {
    required String employeeId,
    required DateTime month,
  }) {
    return rows
        .where((item) => item.employeeId.trim() == employeeId.trim())
        .where((item) => item.appliesToMonth(month))
        .toList(growable: false)
      ..sort((a, b) {
        final byPriority = a.legalPriority.compareTo(b.legalPriority);
        if (byPriority != 0) return byPriority;
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  HrVariablePayrollMonthlyBundle buildMonthlyBundle({
    required String employeeId,
    required DateTime month,
    required List<HrBonus> bonuses,
    required List<HrDeduction> deductions,
    required List<HrAdvance> advances,
    required List<HrGarnishment> garnishments,
  }) {
    final target = DateTime(month.year, month.month, 1);
    return HrVariablePayrollMonthlyBundle(
      employeeId: employeeId.trim(),
      month: target,
      bonuses: activeBonusesForMonth(
        bonuses,
        employeeId: employeeId,
        month: target,
      ),
      deductions: activeDeductionsForMonth(
        deductions,
        employeeId: employeeId,
        month: target,
      ),
      advances: activeAdvancesForMonth(
        advances,
        employeeId: employeeId,
        month: target,
      ),
      garnishments: activeGarnishmentsForMonth(
        garnishments,
        employeeId: employeeId,
        month: target,
      ),
    );
  }
}
