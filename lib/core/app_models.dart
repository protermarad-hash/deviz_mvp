import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

const String localUserId = 'local-user';
const String overheadModePercent = 'percent';
const String overheadModeCalculated = 'calculated';

double parseDouble(Object? value, {double fallback = 0}) {
  if (value == null) {
    return fallback;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? fallback;
}

double convertFromRon(
  double ronAmount, {
  required String currency,
  required double eurRate,
}) {
  final normalizedCurrency = currency.trim().toUpperCase();
  if (normalizedCurrency == 'EUR' && eurRate > 0) {
    return ronAmount / eurRate;
  }
  return ronAmount;
}

String formatMoney(
  double ronAmount, {
  required String currency,
  required double eurRate,
}) {
  final converted = convertFromRon(
    ronAmount,
    currency: currency,
    eurRate: eurRate,
  );
  return '${converted.toStringAsFixed(2)} ${currency.trim().isEmpty ? 'RON' : currency.trim().toUpperCase()}';
}

bool parseBool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value == null) {
    return fallback;
  }
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') {
    return true;
  }
  if (normalized == 'false' || normalized == '0') {
    return false;
  }
  return fallback;
}

String valueText(Object? value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

class AppDefaults {
  static const companyName = 'ProVentaris';
  static const issuerName = 'Operator local';
  static const defaultVatPercent = 21.0;
  static const defaultProfitPercent = 15.0;
}

class CompanySettings {
  final String companyName;
  final String companyAddress;
  final String companyPhone;
  final String companyEmail;
  final String companyCui;
  final String companyTradeRegister;
  final String companyBank;
  final String companyIban;
  final String companyContactName;
  final String? companyLogoBase64;
  final String defaultCurrency;
  final double defaultEurRate;
  final double defaultVatPercent;
  final double defaultProfitPercent;
  final double defaultOverheadPercent;

  const CompanySettings({
    this.companyName = '',
    this.companyAddress = '',
    this.companyPhone = '',
    this.companyEmail = '',
    this.companyCui = '',
    this.companyTradeRegister = '',
    this.companyBank = '',
    this.companyIban = '',
    this.companyContactName = '',
    this.companyLogoBase64,
    this.defaultCurrency = 'RON',
    this.defaultEurRate = 5,
    this.defaultVatPercent = AppDefaults.defaultVatPercent,
    this.defaultProfitPercent = AppDefaults.defaultProfitPercent,
    this.defaultOverheadPercent = 0,
  });

  factory CompanySettings.fromMap(Map<String, dynamic> map) {
    return CompanySettings(
      companyName: valueText(map['company_name']),
      companyAddress: valueText(map['company_address']),
      companyPhone: valueText(map['company_phone']),
      companyEmail: valueText(map['company_email']),
      companyCui: valueText(map['company_cui']),
      companyTradeRegister: valueText(map['company_trade_register']),
      companyBank: valueText(map['company_bank']),
      companyIban: valueText(map['company_iban']),
      companyContactName: valueText(map['company_contact_name']),
      companyLogoBase64: map['company_logo_base64'] as String?,
      defaultCurrency: valueText(map['default_currency'], fallback: 'RON'),
      defaultEurRate: parseDouble(map['default_eur_rate'], fallback: 5),
      defaultVatPercent: parseDouble(
        map['default_vat_percent'],
        fallback: AppDefaults.defaultVatPercent,
      ),
      defaultProfitPercent: parseDouble(
        map['default_profit_percent'],
        fallback: AppDefaults.defaultProfitPercent,
      ),
      defaultOverheadPercent: parseDouble(map['default_overhead_percent']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'company_name': companyName,
      'company_address': companyAddress,
      'company_phone': companyPhone,
      'company_email': companyEmail,
      'company_cui': companyCui,
      'company_trade_register': companyTradeRegister,
      'company_bank': companyBank,
      'company_iban': companyIban,
      'company_contact_name': companyContactName,
      'company_logo_base64': companyLogoBase64,
      'default_currency': defaultCurrency,
      'default_eur_rate': defaultEurRate,
      'default_vat_percent': defaultVatPercent,
      'default_profit_percent': defaultProfitPercent,
      'default_overhead_percent': defaultOverheadPercent,
    };
  }

  String get companyNameOrFallback =>
      companyName.trim().isEmpty ? AppDefaults.companyName : companyName;

  Uint8List? get logoBytes {
    final raw = companyLogoBase64;
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }
}

class OverheadSettings {
  final String defaultOverheadMode;
  final double defaultOverheadPercent;
  final double accountingMonthly;
  final double psiSsmMonthly;
  final double insuranceMonthly;
  final double phoneMonthly;
  final double adminMonthly;
  final double consumablesMonthly;
  final double otherMonthly;

  const OverheadSettings({
    this.defaultOverheadMode = overheadModePercent,
    this.defaultOverheadPercent = 0,
    this.accountingMonthly = 0,
    this.psiSsmMonthly = 0,
    this.insuranceMonthly = 0,
    this.phoneMonthly = 0,
    this.adminMonthly = 0,
    this.consumablesMonthly = 0,
    this.otherMonthly = 0,
  });

  factory OverheadSettings.fromMap(Map<String, dynamic> map) {
    return OverheadSettings(
      defaultOverheadMode: valueText(map['default_overhead_mode'],
          fallback: overheadModePercent),
      defaultOverheadPercent: parseDouble(map['default_overhead_percent']),
      accountingMonthly: parseDouble(map['accounting_monthly']),
      psiSsmMonthly: parseDouble(map['psi_ssm_monthly']),
      insuranceMonthly: parseDouble(map['insurance_monthly']),
      phoneMonthly: parseDouble(map['phone_monthly']),
      adminMonthly: parseDouble(map['admin_monthly']),
      consumablesMonthly: parseDouble(map['consumables_monthly']),
      otherMonthly: parseDouble(map['other_monthly']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'default_overhead_mode': defaultOverheadMode,
      'default_overhead_percent': defaultOverheadPercent,
      'accounting_monthly': accountingMonthly,
      'psi_ssm_monthly': psiSsmMonthly,
      'insurance_monthly': insuranceMonthly,
      'phone_monthly': phoneMonthly,
      'admin_monthly': adminMonthly,
      'consumables_monthly': consumablesMonthly,
      'other_monthly': otherMonthly,
    };
  }

  double get monthlyTotal =>
      accountingMonthly +
      psiSsmMonthly +
      insuranceMonthly +
      phoneMonthly +
      adminMonthly +
      consumablesMonthly +
      otherMonthly;
}

class EmployeeRecord {
  final String id;
  final String name;
  final String role;
  final double hourlyRate;
  final double internalHourlyCost;
  final double monthlySalaryOptional;
  final double perDiemPerDay;
  final double lodgingPerDay;
  final bool active;
  final String notes;

  const EmployeeRecord({
    required this.id,
    required this.name,
    required this.role,
    required this.hourlyRate,
    required this.internalHourlyCost,
    required this.monthlySalaryOptional,
    required this.perDiemPerDay,
    required this.lodgingPerDay,
    required this.active,
    this.notes = '',
  });

  factory EmployeeRecord.fromMap(Map<String, dynamic> map) {
    return EmployeeRecord(
      id: valueText(map['id']),
      name: valueText(map['name']),
      role: valueText(map['role']),
      hourlyRate: parseDouble(map['hourly_rate']),
      internalHourlyCost: parseDouble(map['internal_hourly_cost']),
      monthlySalaryOptional: parseDouble(map['monthly_salary_optional']),
      perDiemPerDay: parseDouble(map['per_diem_per_day']),
      lodgingPerDay: parseDouble(map['lodging_per_day']),
      active: parseBool(map['active'], fallback: true),
      notes: valueText(map['notes']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'hourly_rate': hourlyRate,
      'internal_hourly_cost': internalHourlyCost,
      'monthly_salary_optional': monthlySalaryOptional,
      'per_diem_per_day': perDiemPerDay,
      'lodging_per_day': lodgingPerDay,
      'active': active,
      'notes': notes,
    };
  }
}

class VehicleRecord {
  final String id;
  final String plateNumber;
  final String name;
  final String fuelType;
  final double fuelConsumptionLPer100Km;
  final double fuelPricePerLiter;
  final double costPerKmOptional;
  final double fixedDailyCost;
  final String acquisitionType;
  final double purchasePrice;
  final double monthlyLeasingCost;
  final double insuranceCostOptional;
  final double maintenanceCostOptional;
  final int depreciationMonths;
  final double annualInsuranceCost;
  final double annualTaxCost;
  final double annualRovinietaCost;
  final double annualItpCost;
  final double annualMaintenanceBudget;
  final double annualRepairBudget;
  final double tireSetCost;
  final int tireReplacementMonths;
  final double productiveHoursPerMonth;
  final double expectedAnnualKm;
  final double otherPerKmCost;
  final bool active;
  final String notes;

  const VehicleRecord({
    required this.id,
    required this.plateNumber,
    required this.name,
    required this.fuelType,
    required this.fuelConsumptionLPer100Km,
    required this.fuelPricePerLiter,
    required this.costPerKmOptional,
    required this.fixedDailyCost,
    this.acquisitionType = 'purchase',
    this.purchasePrice = 0,
    double monthlyLeasingCost = 0,
    double? leasingCostOptional,
    required this.insuranceCostOptional,
    required this.maintenanceCostOptional,
    this.depreciationMonths = 60,
    double? annualInsuranceCost,
    this.annualTaxCost = 0,
    this.annualRovinietaCost = 0,
    this.annualItpCost = 0,
    double? annualMaintenanceBudget,
    this.annualRepairBudget = 0,
    this.tireSetCost = 0,
    this.tireReplacementMonths = 48,
    this.productiveHoursPerMonth = 168,
    this.expectedAnnualKm = 0,
    this.otherPerKmCost = 0,
    required this.active,
    this.notes = '',
  })  : monthlyLeasingCost = leasingCostOptional ?? monthlyLeasingCost,
        annualInsuranceCost = annualInsuranceCost ?? insuranceCostOptional,
        annualMaintenanceBudget =
            annualMaintenanceBudget ?? maintenanceCostOptional;

  factory VehicleRecord.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic raw, {int fallback = 0}) {
      if (raw == null) return fallback;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString().trim()) ?? fallback;
    }

    final monthlyLeasingCost = parseDouble(
      map['monthly_leasing_cost'] ?? map['leasing_cost_optional'],
    );
    final rawAcquisitionType = valueText(
      map['acquisition_type'],
      fallback: monthlyLeasingCost > 0 ? 'leasing' : 'purchase',
    ).toLowerCase();
    final normalizedAcquisitionType =
        rawAcquisitionType == 'leasing' ? 'leasing' : 'purchase';
    return VehicleRecord(
      id: valueText(map['id']),
      plateNumber: valueText(map['plate_number']),
      name: valueText(map['name']),
      fuelType: valueText(map['fuel_type']),
      fuelConsumptionLPer100Km:
          parseDouble(map['fuel_consumption_l_per_100km']),
      fuelPricePerLiter: parseDouble(map['fuel_price_per_liter']),
      costPerKmOptional: parseDouble(map['cost_per_km_optional']),
      fixedDailyCost: parseDouble(map['fixed_daily_cost']),
      acquisitionType: normalizedAcquisitionType,
      purchasePrice: parseDouble(map['purchase_price']),
      monthlyLeasingCost: monthlyLeasingCost,
      insuranceCostOptional: parseDouble(map['insurance_cost_optional']),
      maintenanceCostOptional: parseDouble(map['maintenance_cost_optional']),
      depreciationMonths: asInt(
        map['depreciation_months'],
        fallback: 60,
      ),
      annualInsuranceCost: parseDouble(
        map['annual_insurance_cost'],
        fallback: parseDouble(map['insurance_cost_optional']),
      ),
      annualTaxCost: parseDouble(map['annual_tax_cost']),
      annualRovinietaCost: parseDouble(map['annual_rovinieta_cost']),
      annualItpCost: parseDouble(map['annual_itp_cost']),
      annualMaintenanceBudget: parseDouble(
        map['annual_maintenance_budget'],
        fallback: parseDouble(map['maintenance_cost_optional']),
      ),
      annualRepairBudget: parseDouble(map['annual_repair_budget']),
      tireSetCost: parseDouble(map['tire_set_cost']),
      tireReplacementMonths: asInt(
        map['tire_replacement_months'],
        fallback: 48,
      ),
      productiveHoursPerMonth: parseDouble(
        map['productive_hours_per_month'],
        fallback: 168,
      ),
      expectedAnnualKm: parseDouble(map['expected_annual_km']),
      otherPerKmCost: parseDouble(map['other_per_km_cost']),
      active: parseBool(map['active'], fallback: true),
      notes: valueText(map['notes']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plate_number': plateNumber,
      'name': name,
      'fuel_type': fuelType,
      'fuel_consumption_l_per_100km': fuelConsumptionLPer100Km,
      'fuel_price_per_liter': fuelPricePerLiter,
      'cost_per_km_optional': costPerKmOptional,
      'fixed_daily_cost': fixedDailyCost,
      'acquisition_type': normalizedAcquisitionType,
      'purchase_price': purchasePrice,
      'monthly_leasing_cost': monthlyLeasingCost,
      'leasing_cost_optional': monthlyLeasingCost,
      'insurance_cost_optional': insuranceCostOptional,
      'maintenance_cost_optional': maintenanceCostOptional,
      'depreciation_months': depreciationMonths,
      'annual_insurance_cost': annualInsuranceCost,
      'annual_tax_cost': annualTaxCost,
      'annual_rovinieta_cost': annualRovinietaCost,
      'annual_itp_cost': annualItpCost,
      'annual_maintenance_budget': annualMaintenanceBudget,
      'annual_repair_budget': annualRepairBudget,
      'tire_set_cost': tireSetCost,
      'tire_replacement_months': tireReplacementMonths,
      'productive_hours_per_month': productiveHoursPerMonth,
      'expected_annual_km': expectedAnnualKm,
      'other_per_km_cost': otherPerKmCost,
      'active': active,
      'notes': notes,
    };
  }

  String get normalizedAcquisitionType =>
      acquisitionType.trim().toLowerCase() == 'leasing'
          ? 'leasing'
          : 'purchase';

  int get effectiveDepreciationMonths =>
      depreciationMonths > 0 ? depreciationMonths : 60;

  int get effectiveTireReplacementMonths =>
      tireReplacementMonths > 0 ? tireReplacementMonths : 48;

  double get effectiveProductiveHoursPerMonth =>
      productiveHoursPerMonth > 0 ? productiveHoursPerMonth : 168.0;

  double get leasingCostOptional => monthlyLeasingCost;

  bool get isLeasing => normalizedAcquisitionType == 'leasing';

  double get monthlyDepreciationCost {
    if (purchasePrice <= 0) return 0.0;
    return purchasePrice / effectiveDepreciationMonths;
  }

  double get monthlyAcquisitionCost =>
      isLeasing ? monthlyLeasingCost : monthlyDepreciationCost;

  double get monthlyTireCost {
    if (tireSetCost <= 0) return 0.0;
    return tireSetCost / effectiveTireReplacementMonths;
  }

  double get estimatedMonthlyFixedCost =>
      monthlyAcquisitionCost +
      (annualInsuranceCost > 0 ? annualInsuranceCost / 12.0 : 0.0) +
      (annualTaxCost > 0 ? annualTaxCost / 12.0 : 0.0) +
      (annualRovinietaCost > 0 ? annualRovinietaCost / 12.0 : 0.0) +
      (annualItpCost > 0 ? annualItpCost / 12.0 : 0.0) +
      (annualMaintenanceBudget > 0 ? annualMaintenanceBudget / 12.0 : 0.0) +
      (annualRepairBudget > 0 ? annualRepairBudget / 12.0 : 0.0) +
      monthlyTireCost;

  double get estimatedFuelCostPerKm =>
      (fuelConsumptionLPer100Km > 0 ? fuelConsumptionLPer100Km : 0.0) /
      100.0 *
      (fuelPricePerLiter > 0 ? fuelPricePerLiter : 0.0);

  double get estimatedInternalCostPerKm =>
      estimatedFuelCostPerKm + (otherPerKmCost > 0 ? otherPerKmCost : 0.0);

  double get estimatedInternalCostPerHour => estimatedMonthlyFixedCost > 0
      ? estimatedMonthlyFixedCost / effectiveProductiveHoursPerMonth
      : 0.0;

  double get effectiveCostPerKm {
    if (costPerKmOptional > 0) {
      return costPerKmOptional;
    }
    return (fuelConsumptionLPer100Km / 100) * fuelPricePerLiter;
  }
}

class DraftMaterialLine {
  final String materialId;
  final String materialName;
  final String unit;
  final double quantity;
  final double unitPrice;

  const DraftMaterialLine({
    required this.materialId,
    required this.materialName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
  });

  factory DraftMaterialLine.fromMap(Map<String, dynamic> map) {
    return DraftMaterialLine(
      materialId: valueText(map['material_id']),
      materialName: valueText(map['material_name']),
      unit: valueText(map['unit']),
      quantity: parseDouble(map['quantity']),
      unitPrice: parseDouble(map['unit_price']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'material_id': materialId,
      'material_name': materialName,
      'unit': unit,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }

  double get total => quantity * unitPrice;
}

class OfferEmployeeAssignment {
  final String employeeId;
  final String name;
  final String role;
  final double hourlyRate;
  final double internalHourlyCost;
  final double perDiemPerDay;
  final double lodgingPerDay;
  final double workedHours;
  final double workedDays;

  const OfferEmployeeAssignment({
    required this.employeeId,
    required this.name,
    required this.role,
    required this.hourlyRate,
    required this.internalHourlyCost,
    required this.perDiemPerDay,
    required this.lodgingPerDay,
    required this.workedHours,
    required this.workedDays,
  });

  factory OfferEmployeeAssignment.fromMap(Map<String, dynamic> map) {
    return OfferEmployeeAssignment(
      employeeId: valueText(map['employee_id']),
      name: valueText(map['name']),
      role: valueText(map['role']),
      hourlyRate: parseDouble(map['hourly_rate']),
      internalHourlyCost: parseDouble(map['internal_hourly_cost']),
      perDiemPerDay: parseDouble(map['per_diem_per_day']),
      lodgingPerDay: parseDouble(map['lodging_per_day']),
      workedHours: parseDouble(map['worked_hours']),
      workedDays: parseDouble(map['worked_days']),
    );
  }

  factory OfferEmployeeAssignment.fromEmployee(EmployeeRecord employee) {
    return OfferEmployeeAssignment(
      employeeId: employee.id,
      name: employee.name,
      role: employee.role,
      hourlyRate: employee.hourlyRate,
      internalHourlyCost: employee.internalHourlyCost,
      perDiemPerDay: employee.perDiemPerDay,
      lodgingPerDay: employee.lodgingPerDay,
      workedHours: 0,
      workedDays: 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employee_id': employeeId,
      'name': name,
      'role': role,
      'hourly_rate': hourlyRate,
      'internal_hourly_cost': internalHourlyCost,
      'per_diem_per_day': perDiemPerDay,
      'lodging_per_day': lodgingPerDay,
      'worked_hours': workedHours,
      'worked_days': workedDays,
    };
  }

  OfferEmployeeAssignment copyWith({
    double? hourlyRate,
    double? internalHourlyCost,
    double? perDiemPerDay,
    double? lodgingPerDay,
    double? workedHours,
    double? workedDays,
  }) {
    return OfferEmployeeAssignment(
      employeeId: employeeId,
      name: name,
      role: role,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      internalHourlyCost: internalHourlyCost ?? this.internalHourlyCost,
      perDiemPerDay: perDiemPerDay ?? this.perDiemPerDay,
      lodgingPerDay: lodgingPerDay ?? this.lodgingPerDay,
      workedHours: workedHours ?? this.workedHours,
      workedDays: workedDays ?? this.workedDays,
    );
  }

  double get laborCost =>
      (workedHours * hourlyRate) +
      (workedDays * hourlyRate * 8) +
      (workedDays * perDiemPerDay) +
      (workedDays * lodgingPerDay);

  double get internalCost =>
      (workedHours * internalHourlyCost) +
      (workedDays * internalHourlyCost * 8) +
      (workedDays * perDiemPerDay) +
      (workedDays * lodgingPerDay);

  double get dayEquivalent => math.max(workedDays, workedHours / 8);
}

class OfferVehicleAssignment {
  final String vehicleId;
  final String plateNumber;
  final String name;
  final String fuelType;
  final double costPerKm;
  final double fixedDailyCost;
  final double kilometers;
  final double workedDays;

  const OfferVehicleAssignment({
    required this.vehicleId,
    required this.plateNumber,
    required this.name,
    required this.fuelType,
    required this.costPerKm,
    required this.fixedDailyCost,
    required this.kilometers,
    required this.workedDays,
  });

  factory OfferVehicleAssignment.fromMap(Map<String, dynamic> map) {
    return OfferVehicleAssignment(
      vehicleId: valueText(map['vehicle_id']),
      plateNumber: valueText(map['plate_number']),
      name: valueText(map['name']),
      fuelType: valueText(map['fuel_type']),
      costPerKm: parseDouble(map['cost_per_km']),
      fixedDailyCost: parseDouble(map['fixed_daily_cost']),
      kilometers: parseDouble(map['kilometers']),
      workedDays: parseDouble(map['worked_days']),
    );
  }

  factory OfferVehicleAssignment.fromVehicle(VehicleRecord vehicle) {
    return OfferVehicleAssignment(
      vehicleId: vehicle.id,
      plateNumber: vehicle.plateNumber,
      name: vehicle.name,
      fuelType: vehicle.fuelType,
      costPerKm: vehicle.effectiveCostPerKm,
      fixedDailyCost: vehicle.fixedDailyCost,
      kilometers: 0,
      workedDays: 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicle_id': vehicleId,
      'plate_number': plateNumber,
      'name': name,
      'fuel_type': fuelType,
      'cost_per_km': costPerKm,
      'fixed_daily_cost': fixedDailyCost,
      'kilometers': kilometers,
      'worked_days': workedDays,
    };
  }

  OfferVehicleAssignment copyWith({
    double? costPerKm,
    double? fixedDailyCost,
    double? kilometers,
    double? workedDays,
  }) {
    return OfferVehicleAssignment(
      vehicleId: vehicleId,
      plateNumber: plateNumber,
      name: name,
      fuelType: fuelType,
      costPerKm: costPerKm ?? this.costPerKm,
      fixedDailyCost: fixedDailyCost ?? this.fixedDailyCost,
      kilometers: kilometers ?? this.kilometers,
      workedDays: workedDays ?? this.workedDays,
    );
  }

  double get totalCost =>
      (kilometers * costPerKm) + (workedDays * fixedDailyCost);
}

class OfferCalculations {
  final double materialsTotal;
  final double laborTotal;
  final double laborInternalCost;
  final double vehicleTotal;
  final double directTotal;
  final double overheadTotal;
  final double profitTotal;
  final double totalWithoutVat;
  final double vatTotal;
  final double grandTotal;
  final double projectDays;

  const OfferCalculations({
    required this.materialsTotal,
    required this.laborTotal,
    required this.laborInternalCost,
    required this.vehicleTotal,
    required this.directTotal,
    required this.overheadTotal,
    required this.profitTotal,
    required this.totalWithoutVat,
    required this.vatTotal,
    required this.grandTotal,
    required this.projectDays,
  });

  factory OfferCalculations.compute({
    required List<DraftMaterialLine> lines,
    required List<OfferEmployeeAssignment> employees,
    required List<OfferVehicleAssignment> vehicles,
    required String overheadMode,
    required double overheadPercent,
    required OverheadSettings overheadSettings,
    required double profitPercent,
    required double vatPercent,
  }) {
    final materialsTotal =
        lines.fold<double>(0, (sum, item) => sum + item.total);
    final laborTotal =
        employees.fold<double>(0, (sum, item) => sum + item.laborCost);
    final laborInternalCost =
        employees.fold<double>(0, (sum, item) => sum + item.internalCost);
    final vehicleTotal =
        vehicles.fold<double>(0, (sum, item) => sum + item.totalCost);
    final projectDays = _projectDays(employees, vehicles);
    final directTotal = materialsTotal + laborTotal + vehicleTotal;
    final overheadTotal = overheadMode == overheadModeCalculated
        ? (overheadSettings.monthlyTotal / 22) * projectDays
        : directTotal * (overheadPercent / 100);
    final profitTotal = (directTotal + overheadTotal) * (profitPercent / 100);
    final totalWithoutVat = directTotal + overheadTotal + profitTotal;
    final vatTotal = totalWithoutVat * (vatPercent / 100);
    final grandTotal = totalWithoutVat + vatTotal;
    return OfferCalculations(
      materialsTotal: materialsTotal,
      laborTotal: laborTotal,
      laborInternalCost: laborInternalCost,
      vehicleTotal: vehicleTotal,
      directTotal: directTotal,
      overheadTotal: overheadTotal,
      profitTotal: profitTotal,
      totalWithoutVat: totalWithoutVat,
      vatTotal: vatTotal,
      grandTotal: grandTotal,
      projectDays: projectDays,
    );
  }

  static double _projectDays(
    List<OfferEmployeeAssignment> employees,
    List<OfferVehicleAssignment> vehicles,
  ) {
    var maxDays = 0.0;
    for (final employee in employees) {
      maxDays = math.max(maxDays, employee.dayEquivalent);
    }
    for (final vehicle in vehicles) {
      maxDays = math.max(maxDays, vehicle.workedDays);
    }
    if (maxDays == 0 && (employees.isNotEmpty || vehicles.isNotEmpty)) {
      return 1;
    }
    return maxDays;
  }
}

class OfferBundle {
  final Map<String, dynamic> offer;
  final List<DraftMaterialLine> lines;
  final List<OfferEmployeeAssignment> employeeAssignments;
  final List<OfferVehicleAssignment> vehicleAssignments;

  const OfferBundle({
    required this.offer,
    required this.lines,
    required this.employeeAssignments,
    required this.vehicleAssignments,
  });
}
