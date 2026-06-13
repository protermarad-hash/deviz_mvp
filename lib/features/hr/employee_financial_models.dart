import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmployeePayEntry — suma datorată unui angajat pentru O programare
// ─────────────────────────────────────────────────────────────────────────────

class EmployeePayEntry {
  EmployeePayEntry({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.appointmentId,
    required this.appointmentTitle,
    required this.appointmentDate,
    required this.jobId,
    required this.jobTitle,
    required this.amountDue,
    required this.currency,
    required this.notes,
    required this.createdAt,
    required this.createdBy,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String appointmentId;
  final String appointmentTitle;
  final String appointmentDate;
  final String jobId;
  final String jobTitle;
  final double amountDue;
  final String currency;
  final String notes;
  final DateTime createdAt;
  final String createdBy;

  static EmployeePayEntry create({
    required String employeeId,
    required String employeeName,
    required String appointmentId,
    required String appointmentTitle,
    required String appointmentDate,
    String jobId = '',
    String jobTitle = '',
    required double amountDue,
    String currency = 'RON',
    String notes = '',
    String createdBy = '',
  }) {
    return EmployeePayEntry(
      id: const Uuid().v4(),
      employeeId: employeeId,
      employeeName: employeeName,
      appointmentId: appointmentId,
      appointmentTitle: appointmentTitle,
      appointmentDate: appointmentDate,
      jobId: jobId,
      jobTitle: jobTitle,
      amountDue: amountDue,
      currency: currency,
      notes: notes,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
  }

  EmployeePayEntry copyWith({
    double? amountDue,
    String? currency,
    String? notes,
    String? employeeName,
  }) {
    return EmployeePayEntry(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName ?? this.employeeName,
      appointmentId: appointmentId,
      appointmentTitle: appointmentTitle,
      appointmentDate: appointmentDate,
      jobId: jobId,
      jobTitle: jobTitle,
      amountDue: amountDue ?? this.amountDue,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'appointment_id': appointmentId,
        'appointment_title': appointmentTitle,
        'appointment_date': appointmentDate,
        'job_id': jobId,
        'job_title': jobTitle,
        'amount_due': amountDue,
        'currency': currency,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'created_by': createdBy,
      };

  factory EmployeePayEntry.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    return EmployeePayEntry(
      id: (map['id'] ?? '').toString(),
      employeeId: (map['employee_id'] ?? '').toString(),
      employeeName: (map['employee_name'] ?? '').toString(),
      appointmentId: (map['appointment_id'] ?? '').toString(),
      appointmentTitle: (map['appointment_title'] ?? '').toString(),
      appointmentDate: (map['appointment_date'] ?? '').toString(),
      jobId: (map['job_id'] ?? '').toString(),
      jobTitle: (map['job_title'] ?? '').toString(),
      amountDue: parseDouble(map['amount_due']),
      currency: (map['currency'] ?? 'RON').toString(),
      notes: (map['notes'] ?? '').toString(),
      createdAt: DateTime.tryParse(
            (map['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
      createdBy: (map['created_by'] ?? '').toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EmployeePayment — o plată efectivă făcută unui angajat
// ─────────────────────────────────────────────────────────────────────────────

class EmployeePayment {
  EmployeePayment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.amount,
    required this.currency,
    required this.paymentDate,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final double amount;
  final String currency;
  final DateTime paymentDate;
  final String notes;
  final String createdBy;
  final DateTime createdAt;

  static EmployeePayment create({
    required String employeeId,
    required String employeeName,
    required double amount,
    String currency = 'RON',
    DateTime? paymentDate,
    String notes = '',
    String createdBy = '',
  }) {
    return EmployeePayment(
      id: const Uuid().v4(),
      employeeId: employeeId,
      employeeName: employeeName,
      amount: amount,
      currency: currency,
      paymentDate: paymentDate ?? DateTime.now(),
      notes: notes,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'amount': amount,
        'currency': currency,
        'payment_date': paymentDate.toIso8601String(),
        'notes': notes,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  factory EmployeePayment.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    return EmployeePayment(
      id: (map['id'] ?? '').toString(),
      employeeId: (map['employee_id'] ?? '').toString(),
      employeeName: (map['employee_name'] ?? '').toString(),
      amount: parseDouble(map['amount']),
      currency: (map['currency'] ?? 'RON').toString(),
      paymentDate: DateTime.tryParse(
            (map['payment_date'] ?? '').toString(),
          ) ??
          DateTime.now(),
      notes: (map['notes'] ?? '').toString(),
      createdBy: (map['created_by'] ?? '').toString(),
      createdAt: DateTime.tryParse(
            (map['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EmployeeSettings — tarif prestabilit per angajat
// ─────────────────────────────────────────────────────────────────────────────

class EmployeeSettings {
  const EmployeeSettings({
    required this.employeeId,
    required this.employeeName,
    required this.defaultPayPerAppointment,
    required this.updatedAt,
  });

  final String employeeId;
  final String employeeName;
  final double defaultPayPerAppointment;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'employee_id': employeeId,
        'employee_name': employeeName,
        'default_pay_per_appointment': defaultPayPerAppointment,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory EmployeeSettings.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    return EmployeeSettings(
      employeeId: (map['employee_id'] ?? '').toString(),
      employeeName: (map['employee_name'] ?? '').toString(),
      defaultPayPerAppointment:
          parseDouble(map['default_pay_per_appointment']),
      updatedAt: DateTime.tryParse(
            (map['updated_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }

  EmployeeSettings copyWith({double? defaultPayPerAppointment}) {
    return EmployeeSettings(
      employeeId: employeeId,
      employeeName: employeeName,
      defaultPayPerAppointment:
          defaultPayPerAppointment ?? this.defaultPayPerAppointment,
      updatedAt: DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EmployeeFinancialSummary — sumar per angajat (calculat automat)
// ─────────────────────────────────────────────────────────────────────────────

class EmployeeFinancialSummary {
  const EmployeeFinancialSummary({
    required this.employeeId,
    required this.employeeName,
    required this.totalDue,
    required this.totalPaid,
    required this.updatedAt,
  });

  final String employeeId;
  final String employeeName;
  final double totalDue;
  final double totalPaid;
  final DateTime updatedAt;

  double get balance => totalDue - totalPaid;

  Map<String, dynamic> toMap() => {
        'employee_id': employeeId,
        'employee_name': employeeName,
        'total_due': totalDue,
        'total_paid': totalPaid,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory EmployeeFinancialSummary.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    return EmployeeFinancialSummary(
      employeeId: (map['employee_id'] ?? '').toString(),
      employeeName: (map['employee_name'] ?? '').toString(),
      totalDue: parseDouble(map['total_due']),
      totalPaid: parseDouble(map['total_paid']),
      updatedAt: DateTime.tryParse(
            (map['updated_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }
}
