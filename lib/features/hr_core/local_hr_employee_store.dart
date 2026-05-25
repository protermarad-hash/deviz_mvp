import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'hr_employee_models.dart';

class LocalHrEmployeeStore {
  static const String _profilesKey = 'ultra_hr_employee_profiles_v1';
  static const String _contractsKey = 'ultra_hr_contracts_v1';

  Future<List<HrEmployeeProfile>> listProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <HrEmployeeProfile>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <HrEmployeeProfile>[];
    }
    final rows = decoded
        .whereType<Map>()
        .map((row) => HrEmployeeProfile.fromMap(Map<String, dynamic>.from(row)))
        .where((row) => row.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return rows;
  }

  Future<void> saveProfiles(List<HrEmployeeProfile> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profilesKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  Future<List<HrContract>> listContracts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contractsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <HrContract>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <HrContract>[];
    }
    final rows = decoded
        .whereType<Map>()
        .map((row) => HrContract.fromMap(Map<String, dynamic>.from(row)))
        .where((row) => row.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.startDate.compareTo(a.startDate));
    return rows;
  }

  Future<void> saveContracts(List<HrContract> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _contractsKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }
}
