import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'hr_variable_payroll_models.dart';

class LocalHrVariablePayrollStore {
  static const String _bonusesKey = 'ultra_hr_bonuses_v1';
  static const String _deductionsKey = 'ultra_hr_deductions_v1';
  static const String _advancesKey = 'ultra_hr_advances_v1';
  static const String _garnishmentsKey = 'ultra_hr_garnishments_v1';

  Future<List<HrBonus>> listBonuses() async {
    return _decodeList(
      key: _bonusesKey,
      mapper: HrBonus.fromMap,
      sorter: (a, b) => b.effectiveMonth.compareTo(a.effectiveMonth),
    );
  }

  Future<void> saveBonuses(List<HrBonus> rows) async {
    await _saveList(
      _bonusesKey,
      rows.map((item) => item.toMap()).toList(growable: false),
    );
  }

  Future<List<HrDeduction>> listDeductions() async {
    return _decodeList(
      key: _deductionsKey,
      mapper: HrDeduction.fromMap,
      sorter: (a, b) => a.legalPriority.compareTo(b.legalPriority),
    );
  }

  Future<void> saveDeductions(List<HrDeduction> rows) async {
    await _saveList(
      _deductionsKey,
      rows.map((item) => item.toMap()).toList(growable: false),
    );
  }

  Future<List<HrAdvance>> listAdvances() async {
    return _decodeList(
      key: _advancesKey,
      mapper: HrAdvance.fromMap,
      sorter: (a, b) => b.effectiveMonth.compareTo(a.effectiveMonth),
    );
  }

  Future<void> saveAdvances(List<HrAdvance> rows) async {
    await _saveList(
      _advancesKey,
      rows.map((item) => item.toMap()).toList(growable: false),
    );
  }

  Future<List<HrGarnishment>> listGarnishments() async {
    return _decodeList(
      key: _garnishmentsKey,
      mapper: HrGarnishment.fromMap,
      sorter: (a, b) => a.legalPriority.compareTo(b.legalPriority),
    );
  }

  Future<void> saveGarnishments(List<HrGarnishment> rows) async {
    await _saveList(
      _garnishmentsKey,
      rows.map((item) => item.toMap()).toList(growable: false),
    );
  }

  Future<List<T>> _decodeList<T>({
    required String key,
    required T Function(Map<String, dynamic>) mapper,
    required int Function(T a, T b) sorter,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return <T>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <T>[];
    final rows = decoded
        .whereType<Map>()
        .map((row) => mapper(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    rows.sort(sorter);
    return rows;
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(payload));
  }
}
