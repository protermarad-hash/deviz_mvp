class HrBonus {
  const HrBonus({
    required this.id,
    required this.employeeId,
    required this.hrEmployeeProfileId,
    required this.bonusType,
    required this.taxableMode,
    required this.amount,
    required this.currency,
    required this.effectiveMonth,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String employeeId;
  final String hrEmployeeProfileId;
  final String bonusType;
  final String taxableMode;
  final double amount;
  final String currency;
  final DateTime effectiveMonth;
  final String status;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive {
    final value = status.trim().toLowerCase();
    return value != 'cancelled' && value != 'deleted' && value != 'rejected';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'employee_id': employeeId,
      'hr_employee_profile_id': hrEmployeeProfileId,
      'bonus_type': bonusType,
      'taxable_mode': taxableMode,
      'amount': amount,
      'currency': currency,
      'effective_month':
          DateTime(effectiveMonth.year, effectiveMonth.month, 1).toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HrBonus.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      return DateTime.tryParse(text) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
    }

    return HrBonus(
      id: (map['id'] ?? '').toString(),
      employeeId: (map['employee_id'] ?? map['employeeId'] ?? '').toString(),
      hrEmployeeProfileId: (map['hr_employee_profile_id'] ??
              map['hrEmployeeProfileId'] ??
              '')
          .toString(),
      bonusType: (map['bonus_type'] ?? map['bonusType'] ?? '').toString(),
      taxableMode:
          (map['taxable_mode'] ?? map['taxableMode'] ?? '').toString(),
      amount: parseDouble(map['amount']),
      currency: (map['currency'] ?? 'RON').toString(),
      effectiveMonth:
          parseDate(map['effective_month'] ?? map['effectiveMonth']),
      status: (map['status'] ?? 'active').toString(),
      notes: (map['notes'] ?? '').toString(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}

class HrDeduction {
  const HrDeduction({
    required this.id,
    required this.employeeId,
    required this.hrEmployeeProfileId,
    required this.deductionType,
    required this.legalPriority,
    required this.amountType,
    required this.amountValue,
    required this.currency,
    required this.capMode,
    required this.sourceDoc,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String employeeId;
  final String hrEmployeeProfileId;
  final String deductionType;
  final int legalPriority;
  final String amountType;
  final double amountValue;
  final String currency;
  final String capMode;
  final String sourceDoc;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String status;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool appliesToMonth(DateTime month) {
    final target = DateTime(month.year, month.month, 1);
    final from = DateTime(effectiveFrom.year, effectiveFrom.month, 1);
    final to = effectiveTo == null
        ? null
        : DateTime(effectiveTo!.year, effectiveTo!.month, 1);
    if (target.isBefore(from)) return false;
    if (to != null && target.isAfter(to)) return false;
    final value = status.trim().toLowerCase();
    return value != 'cancelled' && value != 'deleted' && value != 'closed';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'employee_id': employeeId,
      'hr_employee_profile_id': hrEmployeeProfileId,
      'deduction_type': deductionType,
      'legal_priority': legalPriority,
      'amount_type': amountType,
      'amount_value': amountValue,
      'currency': currency,
      'cap_mode': capMode,
      'source_doc': sourceDoc,
      'effective_from': effectiveFrom.toIso8601String(),
      'effective_to': effectiveTo?.toIso8601String() ?? '',
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HrDeduction.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      return DateTime.tryParse(text) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    DateTime? parseNullableDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
    }

    int parseInt(dynamic raw) {
      if (raw is num) return raw.toInt();
      return int.tryParse((raw ?? '').toString()) ?? 0;
    }

    return HrDeduction(
      id: (map['id'] ?? '').toString(),
      employeeId: (map['employee_id'] ?? map['employeeId'] ?? '').toString(),
      hrEmployeeProfileId: (map['hr_employee_profile_id'] ??
              map['hrEmployeeProfileId'] ??
              '')
          .toString(),
      deductionType:
          (map['deduction_type'] ?? map['deductionType'] ?? '').toString(),
      legalPriority:
          parseInt(map['legal_priority'] ?? map['legalPriority']),
      amountType: (map['amount_type'] ?? map['amountType'] ?? '').toString(),
      amountValue: parseDouble(map['amount_value'] ?? map['amountValue']),
      currency: (map['currency'] ?? 'RON').toString(),
      capMode: (map['cap_mode'] ?? map['capMode'] ?? '').toString(),
      sourceDoc: (map['source_doc'] ?? map['sourceDoc'] ?? '').toString(),
      effectiveFrom: parseDate(map['effective_from'] ?? map['effectiveFrom']),
      effectiveTo:
          parseNullableDate(map['effective_to'] ?? map['effectiveTo']),
      status: (map['status'] ?? 'active').toString(),
      notes: (map['notes'] ?? '').toString(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}

class HrAdvance {
  const HrAdvance({
    required this.id,
    required this.employeeId,
    required this.hrEmployeeProfileId,
    required this.amount,
    required this.currency,
    required this.grantedAt,
    required this.recoveryMode,
    required this.effectiveMonth,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String employeeId;
  final String hrEmployeeProfileId;
  final double amount;
  final String currency;
  final DateTime grantedAt;
  final String recoveryMode;
  final DateTime effectiveMonth;
  final String status;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool appliesToMonth(DateTime month) {
    final target = DateTime(month.year, month.month, 1);
    final effective = DateTime(effectiveMonth.year, effectiveMonth.month, 1);
    if (target.isBefore(effective)) return false;
    final value = status.trim().toLowerCase();
    return value != 'cancelled' && value != 'deleted' && value != 'recovered';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'employee_id': employeeId,
      'hr_employee_profile_id': hrEmployeeProfileId,
      'amount': amount,
      'currency': currency,
      'granted_at': grantedAt.toIso8601String(),
      'recovery_mode': recoveryMode,
      'effective_month':
          DateTime(effectiveMonth.year, effectiveMonth.month, 1).toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HrAdvance.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      return DateTime.tryParse(text) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
    }

    return HrAdvance(
      id: (map['id'] ?? '').toString(),
      employeeId: (map['employee_id'] ?? map['employeeId'] ?? '').toString(),
      hrEmployeeProfileId: (map['hr_employee_profile_id'] ??
              map['hrEmployeeProfileId'] ??
              '')
          .toString(),
      amount: parseDouble(map['amount']),
      currency: (map['currency'] ?? 'RON').toString(),
      grantedAt: parseDate(map['granted_at'] ?? map['grantedAt']),
      recoveryMode:
          (map['recovery_mode'] ?? map['recoveryMode'] ?? '').toString(),
      effectiveMonth:
          parseDate(map['effective_month'] ?? map['effectiveMonth']),
      status: (map['status'] ?? 'active').toString(),
      notes: (map['notes'] ?? '').toString(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}

class HrGarnishment {
  const HrGarnishment({
    required this.id,
    required this.employeeId,
    required this.hrEmployeeProfileId,
    required this.garnishmentType,
    required this.legalPriority,
    required this.amountType,
    required this.amountValue,
    required this.currency,
    required this.legalCapMode,
    required this.sourceDoc,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String employeeId;
  final String hrEmployeeProfileId;
  final String garnishmentType;
  final int legalPriority;
  final String amountType;
  final double amountValue;
  final String currency;
  final String legalCapMode;
  final String sourceDoc;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String status;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool appliesToMonth(DateTime month) {
    final target = DateTime(month.year, month.month, 1);
    final from = DateTime(effectiveFrom.year, effectiveFrom.month, 1);
    final to = effectiveTo == null
        ? null
        : DateTime(effectiveTo!.year, effectiveTo!.month, 1);
    if (target.isBefore(from)) return false;
    if (to != null && target.isAfter(to)) return false;
    final value = status.trim().toLowerCase();
    return value != 'cancelled' && value != 'deleted' && value != 'closed';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'employee_id': employeeId,
      'hr_employee_profile_id': hrEmployeeProfileId,
      'garnishment_type': garnishmentType,
      'legal_priority': legalPriority,
      'amount_type': amountType,
      'amount_value': amountValue,
      'currency': currency,
      'legal_cap_mode': legalCapMode,
      'source_doc': sourceDoc,
      'effective_from': effectiveFrom.toIso8601String(),
      'effective_to': effectiveTo?.toIso8601String() ?? '',
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HrGarnishment.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      return DateTime.tryParse(text) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    DateTime? parseNullableDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
    }

    int parseInt(dynamic raw) {
      if (raw is num) return raw.toInt();
      return int.tryParse((raw ?? '').toString()) ?? 0;
    }

    return HrGarnishment(
      id: (map['id'] ?? '').toString(),
      employeeId: (map['employee_id'] ?? map['employeeId'] ?? '').toString(),
      hrEmployeeProfileId: (map['hr_employee_profile_id'] ??
              map['hrEmployeeProfileId'] ??
              '')
          .toString(),
      garnishmentType: (map['garnishment_type'] ?? map['garnishmentType'] ?? '')
          .toString(),
      legalPriority:
          parseInt(map['legal_priority'] ?? map['legalPriority']),
      amountType: (map['amount_type'] ?? map['amountType'] ?? '').toString(),
      amountValue: parseDouble(map['amount_value'] ?? map['amountValue']),
      currency: (map['currency'] ?? 'RON').toString(),
      legalCapMode:
          (map['legal_cap_mode'] ?? map['legalCapMode'] ?? '').toString(),
      sourceDoc: (map['source_doc'] ?? map['sourceDoc'] ?? '').toString(),
      effectiveFrom: parseDate(map['effective_from'] ?? map['effectiveFrom']),
      effectiveTo:
          parseNullableDate(map['effective_to'] ?? map['effectiveTo']),
      status: (map['status'] ?? 'active').toString(),
      notes: (map['notes'] ?? '').toString(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}

class HrVariablePayrollMonthlyBundle {
  const HrVariablePayrollMonthlyBundle({
    required this.employeeId,
    required this.month,
    required this.bonuses,
    required this.deductions,
    required this.advances,
    required this.garnishments,
  });

  final String employeeId;
  final DateTime month;
  final List<HrBonus> bonuses;
  final List<HrDeduction> deductions;
  final List<HrAdvance> advances;
  final List<HrGarnishment> garnishments;

  List<Map<String, dynamic>> get bonusEntries => bonuses
      .map(
        (item) => <String, dynamic>{
          'id': item.id,
          'type': item.bonusType,
          'taxable_mode': item.taxableMode,
          'amount': item.amount,
          'currency': item.currency,
          'effective_month': item.effectiveMonth.toIso8601String(),
        },
      )
      .toList(growable: false);

  List<Map<String, dynamic>> get deductionEntries => <Map<String, dynamic>>[
        ...deductions.map(
          (item) => <String, dynamic>{
            'id': item.id,
            'type': item.deductionType,
            'legal_priority': item.legalPriority,
            'amount_type': item.amountType,
            'amount_value': item.amountValue,
            'currency': item.currency,
            'cap_mode': item.capMode,
            'source_doc': item.sourceDoc,
          },
        ),
        ...garnishments.map(
          (item) => <String, dynamic>{
            'id': item.id,
            'type': 'garnishment',
            'garnishment_type': item.garnishmentType,
            'legal_priority': item.legalPriority,
            'amount_type': item.amountType,
            'amount_value': item.amountValue,
            'currency': item.currency,
            'legal_cap_mode': item.legalCapMode,
            'source_doc': item.sourceDoc,
          },
        ),
      ];

  List<Map<String, dynamic>> get allowanceEntries => advances
      .map(
        (item) => <String, dynamic>{
          'id': item.id,
          'type': 'advance',
          'amount': item.amount,
          'currency': item.currency,
          'granted_at': item.grantedAt.toIso8601String(),
          'recovery_mode': item.recoveryMode,
          'effective_month': item.effectiveMonth.toIso8601String(),
        },
      )
      .toList(growable: false);
}
