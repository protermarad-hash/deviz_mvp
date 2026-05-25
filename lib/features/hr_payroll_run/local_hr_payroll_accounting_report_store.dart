import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'hr_payroll_accounting_report_models.dart';

class LocalHrPayrollAccountingReportStore {
  static const String _reportsKey = 'ultra_hr_payroll_accounting_reports_v1';

  Future<List<HrPayrollAccountingReport>> listReports() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_reportsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <HrPayrollAccountingReport>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <HrPayrollAccountingReport>[];
    }
    final rows = decoded
        .whereType<Map>()
        .map(
          (row) => HrPayrollAccountingReport.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((row) => row.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) {
      final byMonth = b.payrollMonth.compareTo(a.payrollMonth);
      if (byMonth != 0) return byMonth;
      return b.generatedAt.compareTo(a.generatedAt);
    });
    return rows;
  }

  Future<void> saveReports(List<HrPayrollAccountingReport> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _reportsKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }
}
