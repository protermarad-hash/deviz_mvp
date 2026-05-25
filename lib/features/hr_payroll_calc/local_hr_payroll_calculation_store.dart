import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'hr_payroll_calculation_models.dart';

class LocalHrPayrollCalculationStore {
  static const String _resultsKey = 'ultra_hr_payroll_calculations_v1';

  Future<List<HrPayrollCalculationResult>> listResults() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_resultsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <HrPayrollCalculationResult>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <HrPayrollCalculationResult>[];
    }
    final rows = decoded
        .whereType<Map>()
        .map(
          (row) => HrPayrollCalculationResult.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((row) => row.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) {
      final byMonth = b.payrollMonth.compareTo(a.payrollMonth);
      if (byMonth != 0) return byMonth;
      return b.calculatedAt.compareTo(a.calculatedAt);
    });
    return rows;
  }

  Future<void> saveResults(List<HrPayrollCalculationResult> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _resultsKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }
}
