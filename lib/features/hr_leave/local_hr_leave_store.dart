import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'hr_leave_models.dart';

class LocalHrLeaveStore {
  static const String _leaveTypesKey = 'ultra_hr_leave_types_v1';
  static const String _leaveRequestsKey = 'ultra_hr_leave_requests_v1';

  Future<List<HrLeaveType>> listLeaveTypes() async {
    await _ensureSeeded();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_leaveTypesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <HrLeaveType>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <HrLeaveType>[];
    }
    final rows = decoded
        .whereType<Map>()
        .map((row) => HrLeaveType.fromMap(Map<String, dynamic>.from(row)))
        .where((row) => row.id.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return rows;
  }

  Future<void> saveLeaveTypes(List<HrLeaveType> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _leaveTypesKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  Future<List<HrLeaveRequest>> listLeaveRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_leaveRequestsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <HrLeaveRequest>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <HrLeaveRequest>[];
    }
    final rows = decoded
        .whereType<Map>()
        .map((row) => HrLeaveRequest.fromMap(Map<String, dynamic>.from(row)))
        .where((row) => row.id.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return rows;
  }

  Future<void> saveLeaveRequests(List<HrLeaveRequest> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _leaveRequestsKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  Future<void> _ensureSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final hasTypes =
        (prefs.getString(_leaveTypesKey) ?? '').trim().isNotEmpty;
    if (hasTypes) return;
    await saveLeaveTypes(HrLeaveSeed.leaveTypes());
  }
}
