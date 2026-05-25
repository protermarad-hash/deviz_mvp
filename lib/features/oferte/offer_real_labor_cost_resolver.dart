import '../../core/lookup_models.dart';
import '../hr_core/hr_employee_models.dart';
import 'company_cost_profile_models.dart';

class OfferRealLaborCostResolver {
  const OfferRealLaborCostResolver();

  static const double _fallbackMonthlyHours = 168;
  static const double _weeksPerMonth = 4.33;

  ResolvedEmployeeRealCost resolve({
    required EmployeeLookup employee,
    required HrContract? activeContract,
    required CompanyCostProfile companyCostProfile,
    required int resolvedProductiveEmployeeCount,
  }) {
    final productiveEmployees = resolvedProductiveEmployeeCount > 0
        ? resolvedProductiveEmployeeCount
        : 1;
    final indirectAllocation =
        companyCostProfile.totalIndirectMonthlyCost / productiveEmployees;

    final contractHours = _monthlyHoursFromContract(activeContract);
    final employeeHours = employee.standardMonthlyHours > 0
        ? employee.standardMonthlyHours
        : _fallbackMonthlyHours;
    final productiveHoursBase = contractHours > 0 ? contractHours : employeeHours;
    final productivityCoefficient =
        companyCostProfile.productivityCoefficient > 0
            ? companyCostProfile.productivityCoefficient
            : 1;
    final configuredHours = companyCostProfile.productiveHoursPerMonth > 0
        ? companyCostProfile.productiveHoursPerMonth
        : productiveHoursBase;
    final productiveHours = (contractHours > 0 ? productiveHoursBase : configuredHours) *
        productivityCoefficient;

    final directCost = _resolveMonthlyDirectCost(
      employee: employee,
      activeContract: activeContract,
      productiveHoursBase: productiveHoursBase,
      employerContributionPercent: companyCostProfile.employerContributionPercent,
    );

    if (directCost <= 0 || productiveHours <= 0) {
      final fallback = employee.effectiveTarifOrar;
      return ResolvedEmployeeRealCost(
        employeeId: employee.id,
        hourlyInternalCost: fallback,
        monthlyDirectCost: 0,
        monthlyIndirectAllocation: 0,
        productiveHours: productiveHours > 0 ? productiveHours : employeeHours,
        sourceLabel: fallback > 0
            ? 'fallback tarif existent angajat'
            : 'fara cost complet disponibil',
        isRealCostBased: false,
      );
    }

    final hourlyInternalCost = (directCost + indirectAllocation) / productiveHours;
    return ResolvedEmployeeRealCost(
      employeeId: employee.id,
      hourlyInternalCost: hourlyInternalCost,
      monthlyDirectCost: directCost,
      monthlyIndirectAllocation: indirectAllocation,
      productiveHours: productiveHours,
      sourceLabel: 'cost real intern (salariu + indirecte)',
      isRealCostBased: true,
    );
  }

  double _monthlyHoursFromContract(HrContract? contract) {
    if (contract == null) {
      return 0;
    }
    if (contract.employmentNormHoursPerWeek > 0) {
      return contract.employmentNormHoursPerWeek * _weeksPerMonth;
    }
    if (contract.employmentNormHoursPerDay > 0) {
      return contract.employmentNormHoursPerDay * 21;
    }
    return 0;
  }

  double _resolveMonthlyDirectCost({
    required EmployeeLookup employee,
    required HrContract? activeContract,
    required double productiveHoursBase,
    required double employerContributionPercent,
  }) {
    if (employee.monthlyCost > 0) {
      return employee.monthlyCost;
    }
    if (activeContract != null &&
        activeContract.baseSalaryGross > 0 &&
        (activeContract.currency.trim().isEmpty ||
            activeContract.currency.trim().toUpperCase() == 'RON')) {
      final load = employerContributionPercent > 0
          ? employerContributionPercent / 100
          : 0;
      return activeContract.baseSalaryGross * (1 + load);
    }
    if (employee.tarifOrar > 0) {
      final hours = productiveHoursBase > 0 ? productiveHoursBase : _fallbackMonthlyHours;
      return employee.tarifOrar * hours;
    }
    return 0;
  }
}
