class LookupItem {
  const LookupItem({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class EmployeeLookup {
  const EmployeeLookup({
    required this.id,
    required this.name,
    required this.role,
    required this.perDiemPerDay,
    required this.lodgingPerDay,
    this.laborCostType = 'orar',
    this.costLunar = 0.0,
    this.tarifOrar = 0.0,
    this.oreLunareStandard = 168.0,
    this.requiresLodgingByDefault = false,
    this.active = true,
  });

  final String id;
  final String name;
  final String role;
  final double perDiemPerDay;
  final double lodgingPerDay;
  final String laborCostType;
  final double costLunar;
  final double tarifOrar;
  final double oreLunareStandard;
  final bool requiresLodgingByDefault;
  final bool active;

  double get effectiveTarifOrar {
    final type = laborCostType.trim().toLowerCase();
    if (type == 'lunar') {
      final ore = oreLunareStandard > 0 ? oreLunareStandard : 168;
      if (costLunar <= 0 || ore <= 0) {
        return 0;
      }
      return costLunar / ore;
    }
    if (tarifOrar <= 0) {
      return 0;
    }
    return tarifOrar;
  }

  double get hourlyRate => effectiveTarifOrar;
  double get monthlyCost => costLunar;
  double get standardMonthlyHours => oreLunareStandard;
  double get dailyAllowance => perDiemPerDay;
  double get defaultLodgingCost => lodgingPerDay;
}
