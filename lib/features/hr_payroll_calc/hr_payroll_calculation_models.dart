class HrPayrollCalculationResult {
  const HrPayrollCalculationResult({
    required this.id,
    required this.employeeId,
    required this.hrEmployeeProfileId,
    required this.contractId,
    required this.payrollMonth,
    required this.snapshotId,
    required this.ruleVersionIds,
    required this.grossBaseSalary,
    required this.grossBonusesTaxable,
    required this.grossAllowancesTaxable,
    required this.grossTotalTaxable,
    required this.employeeCasAmount,
    required this.employeeCassAmount,
    required this.taxableBaseAfterContributions,
    required this.incomeTaxAmount,
    required this.grossNonTaxableAllowances,
    required this.deductionTotal,
    required this.advanceRecoveryTotal,
    required this.garnishmentReservedTotal,
    required this.mealTicketsTotalValue,
    required this.mealTicketIncomeTaxAmount,
    required this.mealTicketCassAmount,
    required this.nightWorkSupplementAmount,
    required this.overtimeSupplementAmount,
    required this.netBeforeDeductions,
    required this.netFinal,
    required this.currency,
    required this.calculatedAt,
    required this.notes,
    required this.breakdown,
    required this.sourceRefs,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String employeeId;
  final String hrEmployeeProfileId;
  final String contractId;
  final DateTime payrollMonth;
  final String snapshotId;
  final List<String> ruleVersionIds;
  final double grossBaseSalary;
  final double grossBonusesTaxable;
  final double grossAllowancesTaxable;
  final double grossTotalTaxable;
  final double employeeCasAmount;
  final double employeeCassAmount;
  final double taxableBaseAfterContributions;
  final double incomeTaxAmount;
  final double grossNonTaxableAllowances;
  final double deductionTotal;
  final double advanceRecoveryTotal;
  final double garnishmentReservedTotal;
  final double mealTicketsTotalValue;
  final double mealTicketIncomeTaxAmount;
  final double mealTicketCassAmount;
  final double nightWorkSupplementAmount;
  final double overtimeSupplementAmount;
  final double netBeforeDeductions;
  final double netFinal;
  final String currency;
  final DateTime calculatedAt;
  final String notes;
  final Map<String, dynamic> breakdown;
  final Map<String, dynamic> sourceRefs;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'employee_id': employeeId,
      'hr_employee_profile_id': hrEmployeeProfileId,
      'contract_id': contractId,
      'payroll_month':
          DateTime(payrollMonth.year, payrollMonth.month, 1).toIso8601String(),
      'snapshot_id': snapshotId,
      'rule_version_ids': ruleVersionIds,
      'gross_base_salary': grossBaseSalary,
      'gross_bonuses_taxable': grossBonusesTaxable,
      'gross_allowances_taxable': grossAllowancesTaxable,
      'gross_total_taxable': grossTotalTaxable,
      'employee_cas_amount': employeeCasAmount,
      'employee_cass_amount': employeeCassAmount,
      'taxable_base_after_contributions': taxableBaseAfterContributions,
      'income_tax_amount': incomeTaxAmount,
      'gross_non_taxable_allowances': grossNonTaxableAllowances,
      'deduction_total': deductionTotal,
      'advance_recovery_total': advanceRecoveryTotal,
      'garnishment_reserved_total': garnishmentReservedTotal,
      'meal_tickets_total_value': mealTicketsTotalValue,
      'meal_ticket_income_tax_amount': mealTicketIncomeTaxAmount,
      'meal_ticket_cass_amount': mealTicketCassAmount,
      'night_work_supplement_amount': nightWorkSupplementAmount,
      'overtime_supplement_amount': overtimeSupplementAmount,
      'net_before_deductions': netBeforeDeductions,
      'net_final': netFinal,
      'currency': currency,
      'calculated_at': calculatedAt.toIso8601String(),
      'notes': notes,
      'breakdown': breakdown,
      'source_refs': sourceRefs,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HrPayrollCalculationResult.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      return DateTime.tryParse(text) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
    }

    List<String> parseStringList(dynamic raw) {
      if (raw is! List) return const <String>[];
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    Map<String, dynamic> parseMap(dynamic raw) {
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return const <String, dynamic>{};
    }

    return HrPayrollCalculationResult(
      id: (map['id'] ?? '').toString(),
      employeeId: (map['employee_id'] ?? map['employeeId'] ?? '').toString(),
      hrEmployeeProfileId:
          (map['hr_employee_profile_id'] ?? map['hrEmployeeProfileId'] ?? '')
              .toString(),
      contractId: (map['contract_id'] ?? map['contractId'] ?? '').toString(),
      payrollMonth: parseDate(map['payroll_month'] ?? map['payrollMonth']),
      snapshotId: (map['snapshot_id'] ?? map['snapshotId'] ?? '').toString(),
      ruleVersionIds:
          parseStringList(map['rule_version_ids'] ?? map['ruleVersionIds']),
      grossBaseSalary:
          parseDouble(map['gross_base_salary'] ?? map['grossBaseSalary']),
      grossBonusesTaxable: parseDouble(
        map['gross_bonuses_taxable'] ?? map['grossBonusesTaxable'],
      ),
      grossAllowancesTaxable: parseDouble(
        map['gross_allowances_taxable'] ?? map['grossAllowancesTaxable'],
      ),
      grossTotalTaxable: parseDouble(
        map['gross_total_taxable'] ?? map['grossTotalTaxable'],
      ),
      employeeCasAmount: parseDouble(
        map['employee_cas_amount'] ?? map['employeeCasAmount'],
      ),
      employeeCassAmount: parseDouble(
        map['employee_cass_amount'] ?? map['employeeCassAmount'],
      ),
      taxableBaseAfterContributions: parseDouble(
        map['taxable_base_after_contributions'] ??
            map['taxableBaseAfterContributions'],
      ),
      incomeTaxAmount:
          parseDouble(map['income_tax_amount'] ?? map['incomeTaxAmount']),
      grossNonTaxableAllowances: parseDouble(
        map['gross_non_taxable_allowances'] ?? map['grossNonTaxableAllowances'],
      ),
      deductionTotal:
          parseDouble(map['deduction_total'] ?? map['deductionTotal']),
      advanceRecoveryTotal: parseDouble(
        map['advance_recovery_total'] ?? map['advanceRecoveryTotal'],
      ),
      garnishmentReservedTotal: parseDouble(
        map['garnishment_reserved_total'] ?? map['garnishmentReservedTotal'],
      ),
      mealTicketsTotalValue: parseDouble(
        map['meal_tickets_total_value'] ?? map['mealTicketsTotalValue'],
      ),
      mealTicketIncomeTaxAmount: parseDouble(
        map['meal_ticket_income_tax_amount'] ??
            map['mealTicketIncomeTaxAmount'],
      ),
      mealTicketCassAmount: parseDouble(
        map['meal_ticket_cass_amount'] ?? map['mealTicketCassAmount'],
      ),
      nightWorkSupplementAmount: parseDouble(
        map['night_work_supplement_amount'] ?? map['nightWorkSupplementAmount'],
      ),
      overtimeSupplementAmount: parseDouble(
        map['overtime_supplement_amount'] ?? map['overtimeSupplementAmount'],
      ),
      netBeforeDeductions: parseDouble(
        map['net_before_deductions'] ?? map['netBeforeDeductions'],
      ),
      netFinal: parseDouble(map['net_final'] ?? map['netFinal']),
      currency: (map['currency'] ?? 'RON').toString(),
      calculatedAt: parseDate(map['calculated_at'] ?? map['calculatedAt']),
      notes: (map['notes'] ?? '').toString(),
      breakdown: parseMap(map['breakdown']),
      sourceRefs: parseMap(map['source_refs'] ?? map['sourceRefs']),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}
