import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'hr_self_service_attendance_models.dart';

class LocalHrSelfServiceAttendanceStore {
  static const String _sessionsKey =
      'ultra_hr_self_service_attendance_sessions_v1';

  Future<List<HrSelfServiceAttendanceSession>> listSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <HrSelfServiceAttendanceSession>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <HrSelfServiceAttendanceSession>[];
    }
    final rows = decoded
        .whereType<Map>()
        .map((row) => HrSelfServiceAttendanceSession.fromMap(
              Map<String, dynamic>.from(row),
            ))
        .where((row) => row.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rows;
  }

  Future<void> saveSessions(List<HrSelfServiceAttendanceSession> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionsKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }
}
