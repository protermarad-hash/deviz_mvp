import 'hr_employee_models.dart';

class HrContractResolver {
  const HrContractResolver();

  HrContract? resolveActiveContract({
    required List<HrContract> contracts,
    required String employeeId,
    required DateTime date,
  }) {
    final targetEmployeeId = employeeId.trim();
    if (targetEmployeeId.isEmpty) return null;
    final matches = contracts.where((item) {
      return item.employeeId.trim() == targetEmployeeId && item.appliesTo(date);
    }).toList(growable: false);
    if (matches.isEmpty) return null;
    matches.sort((a, b) {
      final byStart = b.startDate.compareTo(a.startDate);
      if (byStart != 0) return byStart;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return matches.first;
  }
}
