class HrPayrollRun {
  const HrPayrollRun({
    required this.id,
    required this.payrollMonth,
    required this.jurisdiction,
    required this.status,
    required this.employeeIds,
    required this.calculationResultIds,
    required this.generatedAt,
    required this.generatedByUserId,
    required this.notes,
    required this.lockedAt,
    required this.lockedByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime payrollMonth;
  final String jurisdiction;
  final String status;
  final List<String> employeeIds;
  final List<String> calculationResultIds;
  final DateTime generatedAt;
  final String generatedByUserId;
  final String notes;
  final DateTime? lockedAt;
  final String lockedByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLocked => status.trim().toLowerCase() == 'locked';

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'payroll_month':
          DateTime(payrollMonth.year, payrollMonth.month, 1).toIso8601String(),
      'jurisdiction': jurisdiction,
      'status': status,
      'employee_ids': employeeIds,
      'calculation_result_ids': calculationResultIds,
      'generated_at': generatedAt.toIso8601String(),
      'generated_by_user_id': generatedByUserId,
      'notes': notes,
      'locked_at': lockedAt?.toIso8601String() ?? '',
      'locked_by_user_id': lockedByUserId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HrPayrollRun.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      return DateTime.tryParse(text) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    DateTime? parseNullableDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    List<String> parseStringList(dynamic raw) {
      if (raw is! List) return const <String>[];
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    return HrPayrollRun(
      id: (map['id'] ?? '').toString(),
      payrollMonth: parseDate(map['payroll_month'] ?? map['payrollMonth']),
      jurisdiction: (map['jurisdiction'] ?? 'RO').toString(),
      status: (map['status'] ?? 'generated').toString(),
      employeeIds: parseStringList(map['employee_ids'] ?? map['employeeIds']),
      calculationResultIds: parseStringList(
        map['calculation_result_ids'] ?? map['calculationResultIds'],
      ),
      generatedAt: parseDate(map['generated_at'] ?? map['generatedAt']),
      generatedByUserId:
          (map['generated_by_user_id'] ?? map['generatedByUserId'] ?? '')
              .toString(),
      notes: (map['notes'] ?? '').toString(),
      lockedAt: parseNullableDate(map['locked_at'] ?? map['lockedAt']),
      lockedByUserId:
          (map['locked_by_user_id'] ?? map['lockedByUserId'] ?? '').toString(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}

class HrPayslip {
  const HrPayslip({
    required this.id,
    required this.employeeId,
    required this.hrEmployeeProfileId,
    required this.contractId,
    required this.payrollMonth,
    required this.payrollRunId,
    required this.calculationResultId,
    required this.currency,
    required this.grossTotal,
    required this.casAmount,
    required this.cassAmount,
    required this.incomeTaxAmount,
    required this.deductionTotal,
    required this.advanceRecoveryTotal,
    required this.garnishmentReservedTotal,
    required this.netFinal,
    required this.breakdown,
    required this.sourceRefs,
    required this.status,
    required this.generatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String employeeId;
  final String hrEmployeeProfileId;
  final String contractId;
  final DateTime payrollMonth;
  final String payrollRunId;
  final String calculationResultId;
  final String currency;
  final double grossTotal;
  final double casAmount;
  final double cassAmount;
  final double incomeTaxAmount;
  final double deductionTotal;
  final double advanceRecoveryTotal;
  final double garnishmentReservedTotal;
  final double netFinal;
  final Map<String, dynamic> breakdown;
  final Map<String, dynamic> sourceRefs;
  final String status;
  final DateTime generatedAt;
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
      'payroll_run_id': payrollRunId,
      'calculation_result_id': calculationResultId,
      'currency': currency,
      'gross_total': grossTotal,
      'cas_amount': casAmount,
      'cass_amount': cassAmount,
      'income_tax_amount': incomeTaxAmount,
      'deduction_total': deductionTotal,
      'advance_recovery_total': advanceRecoveryTotal,
      'garnishment_reserved_total': garnishmentReservedTotal,
      'net_final': netFinal,
      'breakdown': breakdown,
      'source_refs': sourceRefs,
      'status': status,
      'generated_at': generatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HrPayslip.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      return DateTime.tryParse(text) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
    }

    Map<String, dynamic> parseMap(dynamic raw) {
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return const <String, dynamic>{};
    }

    return HrPayslip(
      id: (map['id'] ?? '').toString(),
      employeeId: (map['employee_id'] ?? map['employeeId'] ?? '').toString(),
      hrEmployeeProfileId:
          (map['hr_employee_profile_id'] ?? map['hrEmployeeProfileId'] ?? '')
              .toString(),
      contractId: (map['contract_id'] ?? map['contractId'] ?? '').toString(),
      payrollMonth: parseDate(map['payroll_month'] ?? map['payrollMonth']),
      payrollRunId:
          (map['payroll_run_id'] ?? map['payrollRunId'] ?? '').toString(),
      calculationResultId:
          (map['calculation_result_id'] ?? map['calculationResultId'] ?? '')
              .toString(),
      currency: (map['currency'] ?? 'RON').toString(),
      grossTotal: parseDouble(map['gross_total'] ?? map['grossTotal']),
      casAmount: parseDouble(map['cas_amount'] ?? map['casAmount']),
      cassAmount: parseDouble(map['cass_amount'] ?? map['cassAmount']),
      incomeTaxAmount:
          parseDouble(map['income_tax_amount'] ?? map['incomeTaxAmount']),
      deductionTotal:
          parseDouble(map['deduction_total'] ?? map['deductionTotal']),
      advanceRecoveryTotal: parseDouble(
        map['advance_recovery_total'] ?? map['advanceRecoveryTotal'],
      ),
      garnishmentReservedTotal: parseDouble(
        map['garnishment_reserved_total'] ?? map['garnishmentReservedTotal'],
      ),
      netFinal: parseDouble(map['net_final'] ?? map['netFinal']),
      breakdown: parseMap(map['breakdown']),
      sourceRefs: parseMap(map['source_refs'] ?? map['sourceRefs']),
      status: (map['status'] ?? 'generated').toString(),
      generatedAt: parseDate(map['generated_at'] ?? map['generatedAt']),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}
