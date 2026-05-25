class CompanyCostProfile {
  const CompanyCostProfile({
    this.id = 'default',
    this.administrativeMonthlyCosts = 0,
    this.rent = 0,
    this.utilities = 0,
    this.generalFuel = 0,
    this.telecomInternet = 0,
    this.accounting = 0,
    this.softwareLicenses = 0,
    this.operationalLeasing = 0,
    this.insurance = 0,
    this.otherIndirectCosts = 0,
    this.productiveEmployeeCount = 0,
    this.productiveHoursPerMonth = 168,
    this.productivityCoefficient = 1,
    this.employerContributionPercent = 2.25,
    this.updatedAt,
  });

  final String id;
  final double administrativeMonthlyCosts;
  final double rent;
  final double utilities;
  final double generalFuel;
  final double telecomInternet;
  final double accounting;
  final double softwareLicenses;
  final double operationalLeasing;
  final double insurance;
  final double otherIndirectCosts;
  final int productiveEmployeeCount;
  final double productiveHoursPerMonth;
  final double productivityCoefficient;
  final double employerContributionPercent;
  final DateTime? updatedAt;

  double get totalIndirectMonthlyCost =>
      administrativeMonthlyCosts +
      rent +
      utilities +
      generalFuel +
      telecomInternet +
      accounting +
      softwareLicenses +
      operationalLeasing +
      insurance +
      otherIndirectCosts;

  double get effectiveProductiveHoursPerMonth {
    final double base =
        productiveHoursPerMonth > 0 ? productiveHoursPerMonth : 168.0;
    final double coefficient =
        productivityCoefficient > 0 ? productivityCoefficient : 1.0;
    return base * coefficient;
  }

  CompanyCostProfile copyWith({
    String? id,
    double? administrativeMonthlyCosts,
    double? rent,
    double? utilities,
    double? generalFuel,
    double? telecomInternet,
    double? accounting,
    double? softwareLicenses,
    double? operationalLeasing,
    double? insurance,
    double? otherIndirectCosts,
    int? productiveEmployeeCount,
    double? productiveHoursPerMonth,
    double? productivityCoefficient,
    double? employerContributionPercent,
    DateTime? updatedAt,
  }) {
    return CompanyCostProfile(
      id: id ?? this.id,
      administrativeMonthlyCosts:
          administrativeMonthlyCosts ?? this.administrativeMonthlyCosts,
      rent: rent ?? this.rent,
      utilities: utilities ?? this.utilities,
      generalFuel: generalFuel ?? this.generalFuel,
      telecomInternet: telecomInternet ?? this.telecomInternet,
      accounting: accounting ?? this.accounting,
      softwareLicenses: softwareLicenses ?? this.softwareLicenses,
      operationalLeasing: operationalLeasing ?? this.operationalLeasing,
      insurance: insurance ?? this.insurance,
      otherIndirectCosts: otherIndirectCosts ?? this.otherIndirectCosts,
      productiveEmployeeCount:
          productiveEmployeeCount ?? this.productiveEmployeeCount,
      productiveHoursPerMonth:
          productiveHoursPerMonth ?? this.productiveHoursPerMonth,
      productivityCoefficient:
          productivityCoefficient ?? this.productivityCoefficient,
      employerContributionPercent:
          employerContributionPercent ?? this.employerContributionPercent,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'administrative_monthly_costs': administrativeMonthlyCosts,
      'rent': rent,
      'utilities': utilities,
      'general_fuel': generalFuel,
      'telecom_internet': telecomInternet,
      'accounting': accounting,
      'software_licenses': softwareLicenses,
      'operational_leasing': operationalLeasing,
      'insurance': insurance,
      'other_indirect_costs': otherIndirectCosts,
      'productive_employee_count': productiveEmployeeCount,
      'productive_hours_per_month': productiveHoursPerMonth,
      'productivity_coefficient': productivityCoefficient,
      'employer_contribution_percent': employerContributionPercent,
      'updated_at': updatedAt?.toIso8601String() ?? '',
    };
  }

  factory CompanyCostProfile.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic raw) {
      if (raw == null) {
        return 0;
      }
      if (raw is num) {
        return raw.toDouble();
      }
      return double.tryParse(raw.toString().replaceAll(',', '.').trim()) ?? 0;
    }

    int asInt(dynamic raw) {
      if (raw == null) {
        return 0;
      }
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.toInt();
      }
      return int.tryParse(raw.toString().trim()) ?? 0;
    }

    DateTime? parseDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      if (text.isEmpty) {
        return null;
      }
      return DateTime.tryParse(text);
    }

    return CompanyCostProfile(
      id: (map['id'] ?? 'default').toString(),
      administrativeMonthlyCosts: asDouble(
        map['administrative_monthly_costs'] ??
            map['administrativeMonthlyCosts'],
      ),
      rent: asDouble(map['rent']),
      utilities: asDouble(map['utilities']),
      generalFuel: asDouble(map['general_fuel'] ?? map['generalFuel']),
      telecomInternet:
          asDouble(map['telecom_internet'] ?? map['telecomInternet']),
      accounting: asDouble(map['accounting']),
      softwareLicenses:
          asDouble(map['software_licenses'] ?? map['softwareLicenses']),
      operationalLeasing:
          asDouble(map['operational_leasing'] ?? map['operationalLeasing']),
      insurance: asDouble(map['insurance']),
      otherIndirectCosts:
          asDouble(map['other_indirect_costs'] ?? map['otherIndirectCosts']),
      productiveEmployeeCount: asInt(
        map['productive_employee_count'] ?? map['productiveEmployeeCount'],
      ),
      productiveHoursPerMonth: asDouble(
        map['productive_hours_per_month'] ?? map['productiveHoursPerMonth'],
      ),
      productivityCoefficient: asDouble(
        map['productivity_coefficient'] ?? map['productivityCoefficient'],
      ),
      employerContributionPercent: asDouble(
        map['employer_contribution_percent'] ??
            map['employerContributionPercent'],
      ),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}

class ResolvedEmployeeRealCost {
  const ResolvedEmployeeRealCost({
    required this.employeeId,
    required this.hourlyInternalCost,
    required this.monthlyDirectCost,
    required this.monthlyIndirectAllocation,
    required this.productiveHours,
    required this.sourceLabel,
    required this.isRealCostBased,
  });

  final String employeeId;
  final double hourlyInternalCost;
  final double monthlyDirectCost;
  final double monthlyIndirectAllocation;
  final double productiveHours;
  final String sourceLabel;
  final bool isRealCostBased;
}
