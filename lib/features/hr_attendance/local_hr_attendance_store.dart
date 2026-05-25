import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'hr_attendance_models.dart';

class LocalHrAttendanceStore {
  static const String _entriesKey = 'ultra_hr_attendance_entries_v1';

  Future<List<HrAttendanceEntry>> listEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_entriesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <HrAttendanceEntry>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <HrAttendanceEntry>[];
    }
    final rows = decoded
        .whereType<Map>()
        .map((row) => HrAttendanceEntry.fromMap(Map<String, dynamic>.from(row)))
        .where((row) => row.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return rows;
  }

  Future<void> saveEntries(List<HrAttendanceEntry> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _entriesKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }
}
