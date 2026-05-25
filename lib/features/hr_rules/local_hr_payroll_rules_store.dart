import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'hr_payroll_rule_models.dart';

class LocalHrPayrollRulesStore {
  static const String _ruleSetsKey = 'ultra_hr_rule_sets_v1';
  static const String _ruleVersionsKey = 'ultra_hr_rule_versions_v1';

  Future<List<HrPayrollRuleSet>> listRuleSets() async {
    await _ensureSeeded();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ruleSetsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <HrPayrollRuleSet>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <HrPayrollRuleSet>[];
    }
    var rows = decoded
        .whereType<Map>()
        .map((row) => HrPayrollRuleSet.fromMap(Map<String, dynamic>.from(row)))
        .where((row) => row.id.trim().isNotEmpty)
        .toList(growable: false);
    rows = HrPayrollRuleSeed.mergeRuleSetsWithRoDefaults(rows);
    return rows;
  }

  Future<void> saveRuleSets(List<HrPayrollRuleSet> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _ruleSetsKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  Future<List<HrPayrollRuleVersion>> listRuleVersions() async {
    await _ensureSeeded();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ruleVersionsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <HrPayrollRuleVersion>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <HrPayrollRuleVersion>[];
    }
    var rows = decoded
        .whereType<Map>()
        .map(
          (row) => HrPayrollRuleVersion.fromMap(Map<String, dynamic>.from(row)),
        )
        .where((row) => row.id.trim().isNotEmpty)
        .toList(growable: false);
    rows = HrPayrollRuleSeed.mergeWithRoDefaults(rows);
    return rows;
  }

  Future<void> saveRuleVersions(List<HrPayrollRuleVersion> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _ruleVersionsKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  Future<void> _ensureSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSets = (prefs.getString(_ruleSetsKey) ?? '').trim().isNotEmpty;
    final hasVersions =
        (prefs.getString(_ruleVersionsKey) ?? '').trim().isNotEmpty;
    if (hasSets && hasVersions) return;
    await saveRuleSets(HrPayrollRuleSeed.roRuleSets());
    await saveRuleVersions(HrPayrollRuleSeed.roRuleVersions());
  }
}
