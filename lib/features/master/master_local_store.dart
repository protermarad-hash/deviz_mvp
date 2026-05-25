import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MasterEmployee {
  const MasterEmployee({
    required this.id,
    required this.name,
    required this.role,
    required this.active,
    this.teamId = '',
    this.laborCostType = 'orar',
    this.costLunar = 0.0,
    this.tarifOrar = 0.0,
    this.oreLunareStandard = 168.0,
    this.dailyAllowance = 0.0,
    this.defaultLodgingCost = 0.0,
    this.requiresLodgingByDefault = false,
  });

  final String id;
  final String name;
  final String role;
  final bool active;
  final String teamId;
  final String laborCostType;
  final double costLunar;
  final double tarifOrar;
  final double oreLunareStandard;
  final double dailyAllowance;
  final double defaultLodgingCost;
  final bool requiresLodgingByDefault;

  // English aliases used by newer modules.
  double get monthlyCost => costLunar;
  double get hourlyRate => effectiveTarifOrar;
  double get standardMonthlyHours => oreLunareStandard;

  double get effectiveTarifOrar {
    final type = laborCostType.trim().toLowerCase();
    if (type == 'lunar') {
      final ore = oreLunareStandard > 0 ? oreLunareStandard : 168.0;
      if (costLunar <= 0 || ore <= 0) {
        return 0.0;
      }
      return costLunar / ore;
    }
    if (tarifOrar <= 0) {
      return 0.0;
    }
    return tarifOrar;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role,
        'active': active,
        'team_id': teamId,
        'laborCostType': laborCostType,
        'costLunar': costLunar,
        'tarifOrar': tarifOrar,
        'oreLunareStandard': oreLunareStandard,
        'dailyAllowance': dailyAllowance,
        'defaultLodgingCost': defaultLodgingCost,
        'requiresLodgingByDefault': requiresLodgingByDefault,
      };

  factory MasterEmployee.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw is num) {
        return raw.toDouble();
      }
      return double.tryParse((raw ?? '0').toString().replaceAll(',', '.')) ??
          0.0;
    }

    bool parseBool(dynamic raw, {bool fallback = false}) {
      if (raw is bool) {
        return raw;
      }
      final text = (raw ?? '').toString().trim().toLowerCase();
      if (text.isEmpty) return fallback;
      if (text == 'true' || text == '1' || text == 'da' || text == 'yes') {
        return true;
      }
      if (text == 'false' || text == '0' || text == 'nu' || text == 'no') {
        return false;
      }
      return fallback;
    }

    return MasterEmployee(
      id: (map['id'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString().trim(),
      role: (map['role'] ?? '').toString().trim(),
      active: parseBool(map['active'], fallback: true),
      teamId: (map['team_id'] ?? map['teamId'] ?? '').toString().trim(),
      laborCostType: (() {
        final raw = (map['laborCostType'] ??
                map['labor_cost_type'] ??
                map['tipCostManopera'] ??
                map['tip_cost_manopera'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();
        if (raw == 'lunar' || raw == 'orar') {
          return raw;
        }
        final tarif = parseDouble(
          map['tarifOrar'] ??
              map['tarif_orar'] ??
              map['hourlyRate'] ??
              map['hourly_rate'],
        );
        final lunar = parseDouble(
          map['costLunar'] ??
              map['cost_lunar'] ??
              map['monthly_salary_optional'],
        );
        if (tarif > 0) return 'orar';
        if (lunar > 0) return 'lunar';
        return 'orar';
      })(),
      costLunar: parseDouble(map['costLunar'] ??
          map['cost_lunar'] ??
          map['monthly_salary_optional']),
      tarifOrar: parseDouble(
        map['tarifOrar'] ??
            map['tarif_orar'] ??
            map['hourlyRate'] ??
            map['hourly_rate'] ??
            map['internal_hourly_cost'],
      ),
      oreLunareStandard: (() {
        final value = parseDouble(
          map['oreLunareStandard'] ??
              map['ore_lunare_standard'] ??
              map['monthly_hours_standard'],
        );
        return value > 0 ? value : 168.0;
      })(),
      dailyAllowance: parseDouble(
        map['dailyAllowance'] ??
            map['daily_allowance'] ??
            map['per_diem_per_day'] ??
            map['per_diem'] ??
            map['diurna'] ??
            map['diurna_per_day'],
      ),
      defaultLodgingCost: parseDouble(
        map['defaultLodgingCost'] ??
            map['default_lodging_cost'] ??
            map['lodging_per_day'] ??
            map['lodging'] ??
            map['cazare'] ??
            map['cazare_per_day'],
      ),
      requiresLodgingByDefault: parseBool(
        map['requiresLodgingByDefault'] ?? map['requires_lodging_by_default'],
        fallback: false,
      ),
    );
  }
}

class MasterTeam {
  const MasterTeam({
    required this.id,
    required this.name,
    required this.notes,
    required this.memberIds,
    this.colorValue = 0,
  });

  final String id;
  final String name;
  final String notes;
  final List<String> memberIds;

  /// ARGB color value, 0 means no custom color set.
  final int colorValue;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'notes': notes,
        'memberIds': memberIds,
        'colorValue': colorValue,
      };

  factory MasterTeam.fromMap(Map<String, dynamic> map) {
    final rawMembers = map['memberIds'];
    final members = rawMembers is List
        ? rawMembers
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    return MasterTeam(
      id: (map['id'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString().trim(),
      notes: (map['notes'] ?? '').toString().trim(),
      memberIds: members,
      colorValue: _parseColorValue(
        map['colorValue'] ?? map['color_value'] ?? map['teamColor'],
      ),
    );
  }

  static int _parseColorValue(Object? raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final text = raw.toString().trim();
    if (text.isEmpty) return 0;
    return int.tryParse(text) ?? 0;
  }
}

class MasterMaterial {
  const MasterMaterial({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.notes,
    this.quantityInStock = 0,
    this.minQuantityAlert = 0,
    this.stockCategory = '',
  });

  final String id;
  final String name;
  final String unit;
  final double price;
  final String notes;

  /// Current stock level
  final double quantityInStock;

  /// Alert threshold — shows warning when quantity falls below this
  final double minQuantityAlert;

  /// Category: 'material', 'frigorant', 'consumabil', '' (any)
  final String stockCategory;

  bool get isLowStock =>
      minQuantityAlert > 0 && quantityInStock < minQuantityAlert;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'unit': unit,
        'price': price,
        'notes': notes,
        'quantity_in_stock': quantityInStock,
        'min_quantity_alert': minQuantityAlert,
        'stock_category': stockCategory,
      };

  factory MasterMaterial.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw == null) return 0;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString().replaceAll(',', '.')) ?? 0;
    }

    return MasterMaterial(
      id: (map['id'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString().trim(),
      unit: (map['unit'] ?? '').toString().trim(),
      price: parseDouble(map['price']),
      notes: (map['notes'] ?? '').toString().trim(),
      quantityInStock:
          parseDouble(map['quantity_in_stock'] ?? map['quantityInStock']),
      minQuantityAlert:
          parseDouble(map['min_quantity_alert'] ?? map['minQuantityAlert']),
      stockCategory: (map['stock_category'] ?? map['stockCategory'] ?? '')
          .toString()
          .trim(),
    );
  }
}

class MasterLocalStore {
  static const List<String> _employeesAliasKeys = <String>[
    'employees_v1',
    'app_employees_v1',
    'deviz_employees_v1',
    'master_employees_v1',
  ];
  static const List<String> _teamsAliasKeys = <String>[
    'ultra_teams_v1',
    'teams_v1',
    'app_teams_v1',
    'deviz_teams_v1',
    'master_teams_v1',
  ];
  static const _employeesKey = 'ultra_master_employees_v1';
  static const _teamsKey = 'ultra_master_teams_v1';
  static const _materialsKey = 'ultra_master_materials_v1';

  static Future<List<MasterEmployee>> readEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in <String>[_employeesKey, ..._employeesAliasKeys]) {
      final rows = _decodeList(prefs.getString(key))
          .map(MasterEmployee.fromMap)
          .where((e) => e.id.isNotEmpty)
          .toList(growable: false);
      if (rows.isNotEmpty) {
        if (key != _employeesKey) {
          await writeEmployees(rows);
        }
        return rows;
      }
    }
    return const <MasterEmployee>[];
  }

  static Future<void> writeEmployees(List<MasterEmployee> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _employeesKey,
      jsonEncode(rows.map((e) => e.toMap()).toList(growable: false)),
    );
  }

  static Future<List<MasterTeam>> readTeams() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in <String>[_teamsKey, ..._teamsAliasKeys]) {
      final rows = _decodeList(prefs.getString(key))
          .map(MasterTeam.fromMap)
          .where((e) => e.id.isNotEmpty)
          .toList(growable: false);
      if (rows.isNotEmpty) {
        if (key != _teamsKey) {
          await writeTeams(rows);
        }
        return rows;
      }
    }
    return const <MasterTeam>[];
  }

  static Future<void> writeTeams(List<MasterTeam> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _teamsKey,
      jsonEncode(rows.map((e) => e.toMap()).toList(growable: false)),
    );
  }

  static Future<List<MasterMaterial>> readMaterials() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeList(prefs.getString(_materialsKey))
        .map(MasterMaterial.fromMap)
        .where((e) => e.id.isNotEmpty)
        .toList(growable: false);
  }

  static Future<void> writeMaterials(List<MasterMaterial> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _materialsKey,
      jsonEncode(rows.map((e) => e.toMap()).toList(growable: false)),
    );
  }

  static List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
    } catch (_) {}
    return const [];
  }
}
