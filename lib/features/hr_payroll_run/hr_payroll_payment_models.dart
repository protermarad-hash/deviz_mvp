import 'package:uuid/uuid.dart';

class HrPayrollPayment {
  const HrPayrollPayment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.payrollMonth,
    required this.paymentType,
    required this.amount,
    required this.paymentDate,
    required this.metodaPlata,
    required this.note,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime payrollMonth;

  /// 'avans' sau 'salariu'
  final String paymentType;

  final double amount;
  final DateTime paymentDate;

  /// 'numerar' | 'virament' | 'card'
  final String metodaPlata;

  final String note;
  final String createdBy;
  final DateTime createdAt;

  static String newId() => const Uuid().v4();

  HrPayrollPayment copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    DateTime? payrollMonth,
    String? paymentType,
    double? amount,
    DateTime? paymentDate,
    String? metodaPlata,
    String? note,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return HrPayrollPayment(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      payrollMonth: payrollMonth ?? this.payrollMonth,
      paymentType: paymentType ?? this.paymentType,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      metodaPlata: metodaPlata ?? this.metodaPlata,
      note: note ?? this.note,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'payroll_month':
          DateTime(payrollMonth.year, payrollMonth.month, 1).toIso8601String(),
      'payment_type': paymentType,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'metoda_plata': metodaPlata,
      'note': note,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory HrPayrollPayment.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      return DateTime.tryParse(text) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse(
              (raw ?? '').toString().replaceAll(',', '.')) ??
          0.0;
    }

    return HrPayrollPayment(
      id: (map['id'] ?? '').toString(),
      employeeId:
          (map['employee_id'] ?? map['employeeId'] ?? '').toString(),
      employeeName:
          (map['employee_name'] ?? map['employeeName'] ?? '').toString(),
      payrollMonth:
          parseDate(map['payroll_month'] ?? map['payrollMonth']),
      paymentType:
          (map['payment_type'] ?? map['paymentType'] ?? 'salariu').toString(),
      amount: parseDouble(map['amount']),
      paymentDate: parseDate(map['payment_date'] ?? map['paymentDate']),
      metodaPlata:
          (map['metoda_plata'] ?? map['metodaPlata'] ?? 'numerar').toString(),
      note: (map['note'] ?? '').toString(),
      createdBy:
          (map['created_by'] ?? map['createdBy'] ?? '').toString(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
    );
  }
}
