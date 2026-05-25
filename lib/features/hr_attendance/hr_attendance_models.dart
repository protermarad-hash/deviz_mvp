class HrAttendanceEntry {
  const HrAttendanceEntry({
    required this.id,
    required this.employeeId,
    required this.hrEmployeeProfileId,
    required this.date,
    required this.sourceType,
    required this.sourceRefId,
    required this.workedHours,
    required this.overtimeHours,
    required this.nightHours,
    required this.leaveHours,
    required this.jobId,
    required this.appointmentId,
    required this.teamId,
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
  final DateTime date;
  final String sourceType;
  final String sourceRefId;
  final double workedHours;
  final double overtimeHours;
  final double nightHours;
  final double leaveHours;
  final String jobId;
  final String appointmentId;
  final String teamId;
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

  HrAttendanceEntry copyWith({
    String? id,
    String? employeeId,
    String? hrEmployeeProfileId,
    DateTime? date,
    String? sourceType,
    String? sourceRefId,
    double? workedHours,
    double? overtimeHours,
    double? nightHours,
    double? leaveHours,
    String? jobId,
    String? appointmentId,
    String? teamId,
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
    return HrAttendanceEntry(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      hrEmployeeProfileId: hrEmployeeProfileId ?? this.hrEmployeeProfileId,
      date: date ?? this.date,
      sourceType: sourceType ?? this.sourceType,
      sourceRefId: sourceRefId ?? this.sourceRefId,
      workedHours: workedHours ?? this.workedHours,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      nightHours: nightHours ?? this.nightHours,
      leaveHours: leaveHours ?? this.leaveHours,
      jobId: jobId ?? this.jobId,
      appointmentId: appointmentId ?? this.appointmentId,
      teamId: teamId ?? this.teamId,
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

  bool get isCounted {
    final normalized = status.trim().toLowerCase();
    return normalized != 'deleted' &&
        normalized != 'void' &&
        normalized != 'cancelled';
  }

  bool get isApproved {
    return status.trim().toLowerCase() == 'approved';
  }

  DateTime get dateOnly => DateTime(date.year, date.month, date.day);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'employee_id': employeeId,
      'hr_employee_profile_id': hrEmployeeProfileId,
      'date': date.toIso8601String(),
      'source_type': sourceType,
      'source_ref_id': sourceRefId,
      'worked_hours': workedHours,
      'overtime_hours': overtimeHours,
      'night_hours': nightHours,
      'leave_hours': leaveHours,
      'job_id': jobId,
      'appointment_id': appointmentId,
      'team_id': teamId,
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

  factory HrAttendanceEntry.fromMap(Map<String, dynamic> map) {
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

    return HrAttendanceEntry(
      id: (map['id'] ?? '').toString(),
      employeeId: (map['employee_id'] ?? map['employeeId'] ?? '').toString(),
      hrEmployeeProfileId:
          (map['hr_employee_profile_id'] ?? map['hrEmployeeProfileId'] ?? '')
              .toString(),
      date: parseDate(map['date']),
      sourceType: (map['source_type'] ?? map['sourceType'] ?? '').toString(),
      sourceRefId:
          (map['source_ref_id'] ?? map['sourceRefId'] ?? '').toString(),
      workedHours: parseDouble(map['worked_hours'] ?? map['workedHours']),
      overtimeHours: parseDouble(map['overtime_hours'] ?? map['overtimeHours']),
      nightHours: parseDouble(map['night_hours'] ?? map['nightHours']),
      leaveHours: parseDouble(map['leave_hours'] ?? map['leaveHours']),
      jobId: (map['job_id'] ?? map['jobId'] ?? '').toString(),
      appointmentId:
          (map['appointment_id'] ?? map['appointmentId'] ?? '').toString(),
      teamId: (map['team_id'] ?? map['teamId'] ?? '').toString(),
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

class HrAttendanceDaySummary {
  const HrAttendanceDaySummary({
    required this.employeeId,
    required this.date,
    required this.entries,
    required this.workedHours,
    required this.overtimeHours,
    required this.nightHours,
    required this.leaveHours,
  });

  final String employeeId;
  final DateTime date;
  final List<HrAttendanceEntry> entries;
  final double workedHours;
  final double overtimeHours;
  final double nightHours;
  final double leaveHours;
}

class HrAttendanceIntervalSummary {
  const HrAttendanceIntervalSummary({
    required this.employeeId,
    required this.dateFrom,
    required this.dateTo,
    required this.entryCount,
    required this.workedHours,
    required this.overtimeHours,
    required this.nightHours,
    required this.leaveHours,
  });

  final String employeeId;
  final DateTime dateFrom;
  final DateTime dateTo;
  final int entryCount;
  final double workedHours;
  final double overtimeHours;
  final double nightHours;
  final double leaveHours;
}

class HrAttendanceMonthlySummary {
  const HrAttendanceMonthlySummary({
    required this.employeeId,
    required this.month,
    required this.daySummaries,
    required this.workedHours,
    required this.overtimeHours,
    required this.nightHours,
    required this.leaveHours,
  });

  final String employeeId;
  final DateTime month;
  final List<HrAttendanceDaySummary> daySummaries;
  final double workedHours;
  final double overtimeHours;
  final double nightHours;
  final double leaveHours;
}
