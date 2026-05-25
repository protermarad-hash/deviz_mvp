class HrLeaveType {
  const HrLeaveType({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.isPaid,
    required this.isMedical,
    required this.formulaType,
    required this.requiresDocument,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String code;
  final String name;
  final String category;
  final bool isPaid;
  final bool isMedical;
  final String formulaType;
  final bool requiresDocument;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'code': code,
      'name': name,
      'category': category,
      'is_paid': isPaid,
      'is_medical': isMedical,
      'formula_type': formulaType,
      'requires_document': requiresDocument,
      'is_active': isActive,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HrLeaveType.fromMap(Map<String, dynamic> map) {
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

    int parseInt(dynamic raw) {
      if (raw is num) return raw.toInt();
      return int.tryParse((raw ?? '').toString()) ?? 0;
    }

    return HrLeaveType(
      id: (map['id'] ?? '').toString(),
      code: (map['code'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      isPaid: parseBool(map['is_paid'] ?? map['isPaid']),
      isMedical: parseBool(map['is_medical'] ?? map['isMedical']),
      formulaType: (map['formula_type'] ?? map['formulaType'] ?? '').toString(),
      requiresDocument: parseBool(
        map['requires_document'] ?? map['requiresDocument'],
      ),
      isActive: parseBool(map['is_active'] ?? map['isActive'], fallback: true),
      sortOrder: parseInt(map['sort_order'] ?? map['sortOrder']),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}

class HrLeaveRequest {
  const HrLeaveRequest({
    required this.id,
    required this.employeeId,
    required this.hrEmployeeProfileId,
    required this.leaveTypeCode,
    required this.startDate,
    required this.endDate,
    required this.calendarDays,
    required this.workingDays,
    required this.medicalCode,
    required this.documentRef,
    required this.status,
    required this.submittedAt,
    required this.submittedByUserId,
    required this.approvedAt,
    required this.approvedByUserId,
    required this.reviewedAt,
    required this.reviewedByUserId,
    required this.reviewNotes,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String employeeId;
  final String hrEmployeeProfileId;
  final String leaveTypeCode;
  final DateTime startDate;
  final DateTime endDate;
  final double calendarDays;
  final double workingDays;
  final String medicalCode;
  final String documentRef;
  final String status;
  final DateTime? submittedAt;
  final String submittedByUserId;
  final DateTime? approvedAt;
  final String approvedByUserId;
  final DateTime? reviewedAt;
  final String reviewedByUserId;
  final String reviewNotes;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive {
    final normalized = status.trim().toLowerCase();
    return normalized != 'cancelled' &&
        normalized != 'rejected' &&
        normalized != 'deleted';
  }

  bool get isApproved {
    return status.trim().toLowerCase() == 'approved';
  }

  HrLeaveRequest copyWith({
    String? id,
    String? employeeId,
    String? hrEmployeeProfileId,
    String? leaveTypeCode,
    DateTime? startDate,
    DateTime? endDate,
    double? calendarDays,
    double? workingDays,
    String? medicalCode,
    String? documentRef,
    String? status,
    DateTime? submittedAt,
    bool clearSubmittedAt = false,
    String? submittedByUserId,
    DateTime? approvedAt,
    bool clearApprovedAt = false,
    String? approvedByUserId,
    DateTime? reviewedAt,
    bool clearReviewedAt = false,
    String? reviewedByUserId,
    String? reviewNotes,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HrLeaveRequest(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      hrEmployeeProfileId: hrEmployeeProfileId ?? this.hrEmployeeProfileId,
      leaveTypeCode: leaveTypeCode ?? this.leaveTypeCode,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      calendarDays: calendarDays ?? this.calendarDays,
      workingDays: workingDays ?? this.workingDays,
      medicalCode: medicalCode ?? this.medicalCode,
      documentRef: documentRef ?? this.documentRef,
      status: status ?? this.status,
      submittedAt: clearSubmittedAt ? null : (submittedAt ?? this.submittedAt),
      submittedByUserId: submittedByUserId ?? this.submittedByUserId,
      approvedAt: clearApprovedAt ? null : (approvedAt ?? this.approvedAt),
      approvedByUserId: approvedByUserId ?? this.approvedByUserId,
      reviewedAt: clearReviewedAt ? null : (reviewedAt ?? this.reviewedAt),
      reviewedByUserId: reviewedByUserId ?? this.reviewedByUserId,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  DateTime get startDateOnly =>
      DateTime(startDate.year, startDate.month, startDate.day);
  DateTime get endDateOnly =>
      DateTime(endDate.year, endDate.month, endDate.day);

  bool overlaps(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    return !endDateOnly.isBefore(start) && !startDateOnly.isAfter(end);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'employee_id': employeeId,
      'hr_employee_profile_id': hrEmployeeProfileId,
      'leave_type_code': leaveTypeCode,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'calendar_days': calendarDays,
      'working_days': workingDays,
      'medical_code': medicalCode,
      'document_ref': documentRef,
      'status': status,
      'submitted_at': submittedAt?.toIso8601String() ?? '',
      'submitted_by_user_id': submittedByUserId,
      'approved_at': approvedAt?.toIso8601String() ?? '',
      'approved_by_user_id': approvedByUserId,
      'reviewed_at': reviewedAt?.toIso8601String() ?? '',
      'reviewed_by_user_id': reviewedByUserId,
      'review_notes': reviewNotes,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HrLeaveRequest.fromMap(Map<String, dynamic> map) {
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

    return HrLeaveRequest(
      id: (map['id'] ?? '').toString(),
      employeeId: (map['employee_id'] ?? map['employeeId'] ?? '').toString(),
      hrEmployeeProfileId:
          (map['hr_employee_profile_id'] ?? map['hrEmployeeProfileId'] ?? '')
              .toString(),
      leaveTypeCode:
          (map['leave_type_code'] ?? map['leaveTypeCode'] ?? '').toString(),
      startDate: parseDate(map['start_date'] ?? map['startDate']),
      endDate: parseDate(map['end_date'] ?? map['endDate']),
      calendarDays: parseDouble(map['calendar_days'] ?? map['calendarDays']),
      workingDays: parseDouble(map['working_days'] ?? map['workingDays']),
      medicalCode: (map['medical_code'] ?? map['medicalCode'] ?? '').toString(),
      documentRef: (map['document_ref'] ?? map['documentRef'] ?? '').toString(),
      status: (map['status'] ?? 'draft').toString(),
      submittedAt: parseNullableDate(map['submitted_at'] ?? map['submittedAt']),
      submittedByUserId:
          (map['submitted_by_user_id'] ?? map['submittedByUserId'] ?? '')
              .toString(),
      approvedAt: parseNullableDate(map['approved_at'] ?? map['approvedAt']),
      approvedByUserId:
          (map['approved_by_user_id'] ?? map['approvedByUserId'] ?? '')
              .toString(),
      reviewedAt: parseNullableDate(map['reviewed_at'] ?? map['reviewedAt']),
      reviewedByUserId:
          (map['reviewed_by_user_id'] ?? map['reviewedByUserId'] ?? '')
              .toString(),
      reviewNotes: (map['review_notes'] ?? map['reviewNotes'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}

class HrLeaveIntervalSummary {
  const HrLeaveIntervalSummary({
    required this.employeeId,
    required this.dateFrom,
    required this.dateTo,
    required this.requests,
    required this.totalCalendarDays,
    required this.totalWorkingDays,
    required this.calendarDaysByType,
    required this.workingDaysByType,
  });

  final String employeeId;
  final DateTime dateFrom;
  final DateTime dateTo;
  final List<HrLeaveRequest> requests;
  final double totalCalendarDays;
  final double totalWorkingDays;
  final Map<String, double> calendarDaysByType;
  final Map<String, double> workingDaysByType;
}

class HrLeaveSeed {
  const HrLeaveSeed._();

  static List<HrLeaveType> leaveTypes() {
    final now = DateTime.utc(2026, 4, 12);
    return <HrLeaveType>[
      HrLeaveType(
        id: 'leave-type-co',
        code: 'CO',
        name: 'Concediu de odihna',
        category: 'vacation',
        isPaid: true,
        isMedical: false,
        formulaType: 'vacation_leave',
        requiresDocument: false,
        isActive: true,
        sortOrder: 10,
        createdAt: now,
        updatedAt: now,
      ),
      HrLeaveType(
        id: 'leave-type-cm',
        code: 'CM',
        name: 'Concediu medical',
        category: 'medical',
        isPaid: true,
        isMedical: true,
        formulaType: 'medical_leave',
        requiresDocument: true,
        isActive: true,
        sortOrder: 20,
        createdAt: now,
        updatedAt: now,
      ),
      HrLeaveType(
        id: 'leave-type-cfp',
        code: 'CFP',
        name: 'Concediu fara plata',
        category: 'unpaid',
        isPaid: false,
        isMedical: false,
        formulaType: 'unpaid_leave',
        requiresDocument: false,
        isActive: true,
        sortOrder: 30,
        createdAt: now,
        updatedAt: now,
      ),
      HrLeaveType(
        id: 'leave-type-adm',
        code: 'ADM',
        name: 'Concediu administrativ',
        category: 'administrative',
        isPaid: false,
        isMedical: false,
        formulaType: 'administrative_leave',
        requiresDocument: false,
        isActive: true,
        sortOrder: 40,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
