import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'hr_payroll_input_snapshot_models.dart';

class LocalHrPayrollInputStore {
  static const String _snapshotsKey = 'ultra_hr_payroll_input_snapshots_v1';

  Future<List<HrPayrollInputSnapshot>> listSnapshots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_snapshotsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <HrPayrollInputSnapshot>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <HrPayrollInputSnapshot>[];
    }
    final rows = decoded
        .whereType<Map>()
        .map(
          (row) => HrPayrollInputSnapshot.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((row) => row.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) {
      final byMonth = b.payrollMonth.compareTo(a.payrollMonth);
      if (byMonth != 0) return byMonth;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return rows;
  }

  Future<void> saveSnapshots(List<HrPayrollInputSnapshot> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _snapshotsKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }
}
