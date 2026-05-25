import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'hr_payroll_run_models.dart';

class LocalHrPayrollRunStore {
  static const String _runsKey = 'ultra_hr_payroll_runs_v1';
  static const String _payslipsKey = 'ultra_hr_payslips_v1';

  Future<List<HrPayrollRun>> listRuns() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_runsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <HrPayrollRun>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <HrPayrollRun>[];
    }
    final rows = decoded
        .whereType<Map>()
        .map((row) => HrPayrollRun.fromMap(Map<String, dynamic>.from(row)))
        .where((row) => row.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) {
      final byMonth = b.payrollMonth.compareTo(a.payrollMonth);
      if (byMonth != 0) return byMonth;
      return b.generatedAt.compareTo(a.generatedAt);
    });
    return rows;
  }

  Future<void> saveRuns(List<HrPayrollRun> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _runsKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  Future<List<HrPayslip>> listPayslips() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_payslipsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <HrPayslip>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <HrPayslip>[];
    }
    final rows = decoded
        .whereType<Map>()
        .map((row) => HrPayslip.fromMap(Map<String, dynamic>.from(row)))
        .where((row) => row.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) {
      final byMonth = b.payrollMonth.compareTo(a.payrollMonth);
      if (byMonth != 0) return byMonth;
      return b.generatedAt.compareTo(a.generatedAt);
    });
    return rows;
  }

  Future<void> savePayslips(List<HrPayslip> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _payslipsKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }
}
