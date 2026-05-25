import '../../core/app_models.dart';

class ResolvedVehicleRealCost {
  const ResolvedVehicleRealCost({
    required this.internalHourlyCost,
    required this.internalKmCost,
    required this.fixedMonthlyCost,
    required this.fuelCostPerKm,
    required this.sourceLabel,
    required this.isRealCostBased,
  });

  final double internalHourlyCost;
  final double internalKmCost;
  final double fixedMonthlyCost;
  final double fuelCostPerKm;
  final String sourceLabel;
  final bool isRealCostBased;
}

class OfferRealVehicleCostResolver {
  const OfferRealVehicleCostResolver();

  static const int _defaultDepreciationMonths = 60;
  static const int _defaultTireReplacementMonths = 48;
  static const double _defaultMonthlyHours = 168;

  ResolvedVehicleRealCost resolve(VehicleRecord vehicle) {
    final monthlyAcquisitionCost = vehicle.isLeasing
        ? _monthlyLeasingCost(vehicle)
        : _monthlyDepreciationCost(vehicle);
    final monthlyFixedCost = monthlyAcquisitionCost +
        (_positive(vehicle.annualInsuranceCost) / 12.0) +
        (_positive(vehicle.annualTaxCost) / 12.0) +
        (_positive(vehicle.annualRovinietaCost) / 12.0) +
        (_positive(vehicle.annualItpCost) / 12.0) +
        (_positive(vehicle.annualMaintenanceBudget) / 12.0) +
        (_positive(vehicle.annualRepairBudget) / 12.0) +
        _monthlyTireCost(vehicle);

    final productiveHours = vehicle.productiveHoursPerMonth > 0
        ? vehicle.productiveHoursPerMonth
        : _defaultMonthlyHours;
    final hourlyInternalCost =
        monthlyFixedCost > 0 ? monthlyFixedCost / productiveHours : 0.0;

    final fuelCostPerKm =
        (_positive(vehicle.fuelConsumptionLPer100Km) / 100.0) *
            _positive(vehicle.fuelPricePerLiter);
    final internalKmCost = fuelCostPerKm + _positive(vehicle.otherPerKmCost);

    if (hourlyInternalCost > 0 || internalKmCost > 0) {
      return ResolvedVehicleRealCost(
        internalHourlyCost: hourlyInternalCost,
        internalKmCost: internalKmCost,
        fixedMonthlyCost: monthlyFixedCost,
        fuelCostPerKm: fuelCostPerKm,
        sourceLabel: 'cost real intern autoturism',
        isRealCostBased: true,
      );
    }

    final fallbackHourly = vehicle.fixedDailyCost > 0
        ? vehicle.fixedDailyCost / 8.0
        : 0.0;
    final fallbackKm = vehicle.effectiveCostPerKm;
    return ResolvedVehicleRealCost(
      internalHourlyCost: fallbackHourly,
      internalKmCost: fallbackKm,
      fixedMonthlyCost: monthlyFixedCost,
      fuelCostPerKm: fuelCostPerKm,
      sourceLabel: 'fallback autoturism',
      isRealCostBased: false,
    );
  }

  double _monthlyLeasingCost(VehicleRecord vehicle) {
    return _positive(vehicle.monthlyLeasingCost);
  }

  double _monthlyDepreciationCost(VehicleRecord vehicle) {
    final price = _positive(vehicle.purchasePrice);
    if (price <= 0) return 0.0;
    final months = vehicle.depreciationMonths > 0
        ? vehicle.depreciationMonths
        : _defaultDepreciationMonths;
    return price / months;
  }

  double _monthlyTireCost(VehicleRecord vehicle) {
    final tireCost = _positive(vehicle.tireSetCost);
    if (tireCost <= 0) return 0.0;
    final months = vehicle.tireReplacementMonths > 0
        ? vehicle.tireReplacementMonths
        : _defaultTireReplacementMonths;
    return tireCost / months;
  }

  double _positive(double value) => value > 0 ? value : 0.0;
}
