class HrPayrollAccountingReport {
  const HrPayrollAccountingReport({
    required this.id,
    required this.payrollMonth,
    required this.payrollRunId,
    required this.jurisdiction,
    required this.status,
    required this.generatedAt,
    required this.generatedByUserId,
    required this.employeeCount,
    required this.currency,
    required this.lineItems,
    required this.totals,
    required this.notes,
    required this.approvedAt,
    required this.approvedByUserId,
    required this.reviewedAt,
    required this.reviewedByUserId,
    required this.reviewNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime payrollMonth;
  final String payrollRunId;
  final String jurisdiction;
  final String status;
  final DateTime generatedAt;
  final String generatedByUserId;
  final int employeeCount;
  final String currency;
  final List<Map<String, dynamic>> lineItems;
  final Map<String, dynamic> totals;
  final String notes;
  final DateTime? approvedAt;
  final String approvedByUserId;
  final DateTime? reviewedAt;
  final String reviewedByUserId;
  final String reviewNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'payroll_month':
          DateTime(payrollMonth.year, payrollMonth.month, 1).toIso8601String(),
      'payroll_run_id': payrollRunId,
      'jurisdiction': jurisdiction,
      'status': status,
      'generated_at': generatedAt.toIso8601String(),
      'generated_by_user_id': generatedByUserId,
      'employee_count': employeeCount,
      'currency': currency,
      'line_items': lineItems,
      'totals': totals,
      'notes': notes,
      'approved_at': approvedAt?.toIso8601String() ?? '',
      'approved_by_user_id': approvedByUserId,
      'reviewed_at': reviewedAt?.toIso8601String() ?? '',
      'reviewed_by_user_id': reviewedByUserId,
      'review_notes': reviewNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HrPayrollAccountingReport.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      return DateTime.tryParse(text) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    DateTime? parseNullableDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    int parseInt(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse((raw ?? '').toString()) ?? 0;
    }

    List<Map<String, dynamic>> parseMapList(dynamic raw) {
      if (raw is! List) return const <Map<String, dynamic>>[];
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    Map<String, dynamic> parseMap(dynamic raw) {
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return const <String, dynamic>{};
    }

    return HrPayrollAccountingReport(
      id: (map['id'] ?? '').toString(),
      payrollMonth: parseDate(map['payroll_month'] ?? map['payrollMonth']),
      payrollRunId:
          (map['payroll_run_id'] ?? map['payrollRunId'] ?? '').toString(),
      jurisdiction: (map['jurisdiction'] ?? 'RO').toString(),
      status: (map['status'] ?? 'ready_for_accounting').toString(),
      generatedAt: parseDate(map['generated_at'] ?? map['generatedAt']),
      generatedByUserId:
          (map['generated_by_user_id'] ?? map['generatedByUserId'] ?? '')
              .toString(),
      employeeCount: parseInt(map['employee_count'] ?? map['employeeCount']),
      currency: (map['currency'] ?? 'RON').toString(),
      lineItems: parseMapList(map['line_items'] ?? map['lineItems']),
      totals: parseMap(map['totals']),
      notes: (map['notes'] ?? '').toString(),
      approvedAt: parseNullableDate(map['approved_at'] ?? map['approvedAt']),
      approvedByUserId:
          (map['approved_by_user_id'] ?? map['approvedByUserId'] ?? '')
              .toString(),
      reviewedAt: parseNullableDate(map['reviewed_at'] ?? map['reviewedAt']),
      reviewedByUserId:
          (map['reviewed_by_user_id'] ?? map['reviewedByUserId'] ?? '')
              .toString(),
      reviewNotes: (map['review_notes'] ?? map['reviewNotes'] ?? '').toString(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}
