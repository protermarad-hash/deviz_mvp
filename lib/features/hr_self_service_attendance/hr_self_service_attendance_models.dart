class HrSelfServiceAttendanceSession {
  const HrSelfServiceAttendanceSession({
    required this.id,
    required this.employeeId,
    required this.hrEmployeeProfileId,
    required this.userId,
    required this.date,
    required this.checkInAt,
    this.checkOutAt,
    this.breakStartAt,
    this.breakEndAt,
    required this.locationType,
    required this.jobId,
    required this.appointmentId,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String employeeId;
  final String hrEmployeeProfileId;
  final String userId;
  final DateTime date;
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final DateTime? breakStartAt;
  final DateTime? breakEndAt;
  final String locationType;
  final String jobId;
  final String appointmentId;
  final String notes;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpen => status.trim().toLowerCase() == 'open' || checkOutAt == null;
  bool get hasOpenBreak => breakStartAt != null && breakEndAt == null;

  HrSelfServiceAttendanceSession copyWith({
    String? id,
    String? employeeId,
    String? hrEmployeeProfileId,
    String? userId,
    DateTime? date,
    DateTime? checkInAt,
    DateTime? checkOutAt,
    bool clearCheckOutAt = false,
    DateTime? breakStartAt,
    bool clearBreakStartAt = false,
    DateTime? breakEndAt,
    bool clearBreakEndAt = false,
    String? locationType,
    String? jobId,
    String? appointmentId,
    String? notes,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HrSelfServiceAttendanceSession(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      hrEmployeeProfileId: hrEmployeeProfileId ?? this.hrEmployeeProfileId,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      checkInAt: checkInAt ?? this.checkInAt,
      checkOutAt: clearCheckOutAt ? null : (checkOutAt ?? this.checkOutAt),
      breakStartAt:
          clearBreakStartAt ? null : (breakStartAt ?? this.breakStartAt),
      breakEndAt: clearBreakEndAt ? null : (breakEndAt ?? this.breakEndAt),
      locationType: locationType ?? this.locationType,
      jobId: jobId ?? this.jobId,
      appointmentId: appointmentId ?? this.appointmentId,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'employee_id': employeeId,
      'hr_employee_profile_id': hrEmployeeProfileId,
      'user_id': userId,
      'date': date.toIso8601String(),
      'check_in_at': checkInAt.toIso8601String(),
      'check_out_at': checkOutAt?.toIso8601String() ?? '',
      'break_start_at': breakStartAt?.toIso8601String() ?? '',
      'break_end_at': breakEndAt?.toIso8601String() ?? '',
      'location_type': locationType,
      'job_id': jobId,
      'appointment_id': appointmentId,
      'notes': notes,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HrSelfServiceAttendanceSession.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      return DateTime.tryParse(text) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    DateTime? parseNullableDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    return HrSelfServiceAttendanceSession(
      id: (map['id'] ?? '').toString(),
      employeeId: (map['employee_id'] ?? map['employeeId'] ?? '').toString(),
      hrEmployeeProfileId:
          (map['hr_employee_profile_id'] ?? map['hrEmployeeProfileId'] ?? '')
              .toString(),
      userId: (map['user_id'] ?? map['userId'] ?? '').toString(),
      date: parseDate(map['date']),
      checkInAt: parseDate(map['check_in_at'] ?? map['checkInAt']),
      checkOutAt: parseNullableDate(map['check_out_at'] ?? map['checkOutAt']),
      breakStartAt:
          parseNullableDate(map['break_start_at'] ?? map['breakStartAt']),
      breakEndAt: parseNullableDate(map['break_end_at'] ?? map['breakEndAt']),
      locationType:
          (map['location_type'] ?? map['locationType'] ?? '').toString(),
      jobId: (map['job_id'] ?? map['jobId'] ?? '').toString(),
      appointmentId:
          (map['appointment_id'] ?? map['appointmentId'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
      status: (map['status'] ?? 'open').toString(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}
