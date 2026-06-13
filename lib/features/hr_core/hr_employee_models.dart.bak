import '../../core/app_models.dart';
import '../../core/auth/field_auth_models.dart';

class HrEmployeeProfile {
  const HrEmployeeProfile({
    required this.id,
    required this.employeeId,
    required this.userId,
    required this.fullName,
    required this.teamId,
    required this.isActive,
    required this.personalNumericCode,
    required this.taxResidenceCountry,
    required this.bankAccount,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String employeeId;
  final String userId;
  final String fullName;
  final String teamId;
  final bool isActive;
  final String personalNumericCode;
  final String taxResidenceCountry;
  final String bankAccount;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  HrEmployeeProfile copyWith({
    String? id,
    String? employeeId,
    String? userId,
    String? fullName,
    String? teamId,
    bool? isActive,
    String? personalNumericCode,
    String? taxResidenceCountry,
    String? bankAccount,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HrEmployeeProfile(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      teamId: teamId ?? this.teamId,
      isActive: isActive ?? this.isActive,
      personalNumericCode: personalNumericCode ?? this.personalNumericCode,
      taxResidenceCountry: taxResidenceCountry ?? this.taxResidenceCountry,
      bankAccount: bankAccount ?? this.bankAccount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory HrEmployeeProfile.fromEmployeeRecord(
    EmployeeRecord employee, {
    FieldAuthUser? user,
    String teamId = '',
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final linkedUser = user;
    return HrEmployeeProfile(
      id: 'hr-profile-${employee.id}',
      employeeId: employee.id,
      userId: linkedUser?.id ?? '',
      fullName: employee.name.trim(),
      teamId: teamId.isNotEmpty ? teamId : (linkedUser?.teamId ?? ''),
      isActive: employee.active,
      personalNumericCode: '',
      taxResidenceCountry: 'RO',
      bankAccount: '',
      notes: employee.notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'employee_id': employeeId,
      'user_id': userId,
      'full_name': fullName,
      'team_id': teamId,
      'is_active': isActive,
      'personal_numeric_code': personalNumericCode,
      'tax_residence_country': taxResidenceCountry,
      'bank_account': bankAccount,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HrEmployeeProfile.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      return DateTime.tryParse(text) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    bool parseBool(dynamic raw, {bool fallback = false}) {
      if (raw is bool) return raw;
      final text = (raw ?? '').toString().trim().toLowerCase();
      if (text == 'true' || text == '1') return true;
      if (text == 'false' || text == '0') return false;
      return fallback;
    }

    return HrEmployeeProfile(
      id: (map['id'] ?? '').toString(),
      employeeId: (map['employee_id'] ?? map['employeeId'] ?? '').toString(),
      userId: (map['user_id'] ?? map['userId'] ?? '').toString(),
      fullName: (map['full_name'] ?? map['fullName'] ?? '').toString(),
      teamId: (map['team_id'] ?? map['teamId'] ?? '').toString(),
      isActive: parseBool(map['is_active'] ?? map['isActive'], fallback: true),
      personalNumericCode:
          (map['personal_numeric_code'] ?? map['personalNumericCode'] ?? '')
              .toString(),
      taxResidenceCountry:
          (map['tax_residence_country'] ?? map['taxResidenceCountry'] ?? 'RO')
              .toString(),
      bankAccount: (map['bank_account'] ?? map['bankAccount'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}

class HrContract {
  const HrContract({
    required this.id,
    required this.hrEmployeeProfileId,
    required this.employeeId,
    required this.contractType,
    required this.jobTitle,
    required this.employmentNormHoursPerDay,
    required this.employmentNormHoursPerWeek,
    required this.baseSalaryGross,
    required this.currency,
    required this.startDate,
    this.endDate,
    required this.isChildcareLeave,
    this.childcareLeaveStartDate,
    this.childcareLeaveEndDate,
    required this.status,
    required this.payrollRuleJurisdiction,
    required this.payrollRuleScopeDefaults,
    required this.registryEntryId,
    required this.registryNumber,
    required this.registeredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String hrEmployeeProfileId;
  final String employeeId;
  final String contractType;
  final String jobTitle;
  final double employmentNormHoursPerDay;
  final double employmentNormHoursPerWeek;
  final double baseSalaryGross;
  final String currency;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isChildcareLeave;
  final DateTime? childcareLeaveStartDate;
  final DateTime? childcareLeaveEndDate;
  final String status;
  final String payrollRuleJurisdiction;
  final List<String> payrollRuleScopeDefaults;
  final String registryEntryId;
  final String registryNumber;
  final DateTime? registeredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  HrContract copyWith({
    String? id,
    String? hrEmployeeProfileId,
    String? employeeId,
    String? contractType,
    String? jobTitle,
    double? employmentNormHoursPerDay,
    double? employmentNormHoursPerWeek,
    double? baseSalaryGross,
    String? currency,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? isChildcareLeave,
    DateTime? childcareLeaveStartDate,
    bool clearChildcareLeaveStartDate = false,
    DateTime? childcareLeaveEndDate,
    bool clearChildcareLeaveEndDate = false,
    String? status,
    String? payrollRuleJurisdiction,
    List<String>? payrollRuleScopeDefaults,
    String? registryEntryId,
    String? registryNumber,
    DateTime? registeredAt,
    bool clearRegisteredAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HrContract(
      id: id ?? this.id,
      hrEmployeeProfileId: hrEmployeeProfileId ?? this.hrEmployeeProfileId,
      employeeId: employeeId ?? this.employeeId,
      contractType: contractType ?? this.contractType,
      jobTitle: jobTitle ?? this.jobTitle,
      employmentNormHoursPerDay:
          employmentNormHoursPerDay ?? this.employmentNormHoursPerDay,
      employmentNormHoursPerWeek:
          employmentNormHoursPerWeek ?? this.employmentNormHoursPerWeek,
      baseSalaryGross: baseSalaryGross ?? this.baseSalaryGross,
      currency: currency ?? this.currency,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      isChildcareLeave: isChildcareLeave ?? this.isChildcareLeave,
      childcareLeaveStartDate: clearChildcareLeaveStartDate
          ? null
          : (childcareLeaveStartDate ?? this.childcareLeaveStartDate),
      childcareLeaveEndDate: clearChildcareLeaveEndDate
          ? null
          : (childcareLeaveEndDate ?? this.childcareLeaveEndDate),
      status: status ?? this.status,
      payrollRuleJurisdiction:
          payrollRuleJurisdiction ?? this.payrollRuleJurisdiction,
      payrollRuleScopeDefaults:
          payrollRuleScopeDefaults ?? this.payrollRuleScopeDefaults,
      registryEntryId: registryEntryId ?? this.registryEntryId,
      registryNumber: registryNumber ?? this.registryNumber,
      registeredAt:
          clearRegisteredAt ? null : (registeredAt ?? this.registeredAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool appliesTo(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    final from = DateTime(startDate.year, startDate.month, startDate.day);
    final to = endDate == null
        ? null
        : DateTime(endDate!.year, endDate!.month, endDate!.day);
    if (target.isBefore(from)) return false;
    if (to != null && target.isAfter(to)) return false;
    final normalizedStatus = status.trim().toLowerCase();
    return normalizedStatus != 'closed' &&
        normalizedStatus != 'inactive' &&
        normalizedStatus != 'terminated';
  }

  bool isChildcareLeaveActiveOn(DateTime date) {
    if (!isChildcareLeave) return false;
    final start = childcareLeaveStartDate;
    if (start == null) return false;
    final target = DateTime(date.year, date.month, date.day);
    final from = DateTime(start.year, start.month, start.day);
    final to = childcareLeaveEndDate == null
        ? null
        : DateTime(
            childcareLeaveEndDate!.year,
            childcareLeaveEndDate!.month,
            childcareLeaveEndDate!.day,
          );
    if (target.isBefore(from)) return false;
    if (to != null && target.isAfter(to)) return false;
    return true;
  }

  bool hasChildcareLeaveOverlapInMonth(DateTime payrollMonth) {
    final monthStart = DateTime(payrollMonth.year, payrollMonth.month, 1);
    final monthEnd = DateTime(payrollMonth.year, payrollMonth.month + 1, 0);
    return childcareLeaveStartDate != null &&
        !DateTime(
          childcareLeaveStartDate!.year,
          childcareLeaveStartDate!.month,
          childcareLeaveStartDate!.day,
        ).isAfter(monthEnd) &&
        !(childcareLeaveEndDate != null &&
            DateTime(
              childcareLeaveEndDate!.year,
              childcareLeaveEndDate!.month,
              childcareLeaveEndDate!.day,
            ).isBefore(monthStart)) &&
        isChildcareLeave;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'hr_employee_profile_id': hrEmployeeProfileId,
      'employee_id': employeeId,
      'contract_type': contractType,
      'job_title': jobTitle,
      'employment_norm_hours_per_day': employmentNormHoursPerDay,
      'employment_norm_hours_per_week': employmentNormHoursPerWeek,
      'base_salary_gross': baseSalaryGross,
      'currency': currency,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String() ?? '',
      'is_childcare_leave': isChildcareLeave,
      'childcare_leave_start_date':
          childcareLeaveStartDate?.toIso8601String() ?? '',
      'childcare_leave_end_date':
          childcareLeaveEndDate?.toIso8601String() ?? '',
      'status': status,
      'payroll_rule_jurisdiction': payrollRuleJurisdiction,
      'payroll_rule_scope_defaults': payrollRuleScopeDefaults,
      'registry_entry_id': registryEntryId,
      'registry_number': registryNumber,
      'registered_at': registeredAt?.toIso8601String() ?? '',
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HrContract.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      return DateTime.tryParse(text) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    DateTime? parseNullableDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    bool parseBool(dynamic raw, {bool fallback = false}) {
      if (raw is bool) return raw;
      final text = (raw ?? '').toString().trim().toLowerCase();
      if (text == 'true' || text == '1') return true;
      if (text == 'false' || text == '0') return false;
      return fallback;
    }

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
    }

    final rawScopes = map['payroll_rule_scope_defaults'] ??
        map['payrollRuleScopeDefaults'] ??
        const <dynamic>[];
    final scopes = rawScopes is List
        ? rawScopes
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    return HrContract(
      id: (map['id'] ?? '').toString(),
      hrEmployeeProfileId:
          (map['hr_employee_profile_id'] ?? map['hrEmployeeProfileId'] ?? '')
              .toString(),
      employeeId: (map['employee_id'] ?? map['employeeId'] ?? '').toString(),
      contractType:
          (map['contract_type'] ?? map['contractType'] ?? '').toString(),
      jobTitle: (map['job_title'] ?? map['jobTitle'] ?? '').toString(),
      employmentNormHoursPerDay: parseDouble(
        map['employment_norm_hours_per_day'] ??
            map['employmentNormHoursPerDay'],
      ),
      employmentNormHoursPerWeek: parseDouble(
        map['employment_norm_hours_per_week'] ??
            map['employmentNormHoursPerWeek'],
      ),
      baseSalaryGross:
          parseDouble(map['base_salary_gross'] ?? map['baseSalaryGross']),
      currency: (map['currency'] ?? 'RON').toString(),
      startDate: parseDate(map['start_date'] ?? map['startDate']),
      endDate: parseNullableDate(map['end_date'] ?? map['endDate']),
      isChildcareLeave: parseBool(
        map['is_childcare_leave'] ?? map['isChildcareLeave'],
      ),
      childcareLeaveStartDate: parseNullableDate(
        map['childcare_leave_start_date'] ?? map['childcareLeaveStartDate'],
      ),
      childcareLeaveEndDate: parseNullableDate(
        map['childcare_leave_end_date'] ?? map['childcareLeaveEndDate'],
      ),
      status: (map['status'] ?? 'active').toString(),
      payrollRuleJurisdiction: (map['payroll_rule_jurisdiction'] ??
              map['payrollRuleJurisdiction'] ??
              'RO')
          .toString(),
      payrollRuleScopeDefaults: scopes,
      registryEntryId:
          (map['registry_entry_id'] ?? map['registryEntryId'] ?? '').toString(),
      registryNumber:
          (map['registry_number'] ?? map['registryNumber'] ?? '').toString(),
      registeredAt:
          parseNullableDate(map['registered_at'] ?? map['registeredAt']),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}
