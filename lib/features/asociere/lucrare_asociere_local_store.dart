import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'lucrare_asociere_models.dart';

class LucrareAsociereLocalStore {
  const LucrareAsociereLocalStore();

  static const key = 'lucrari_asociere_v1';
  static const filtersKey = 'lucrari_asociere_filters_v1';
  static const defaultsKey = 'lucrari_asociere_defaults_v1';

  Future<List<LucrareAsociereRecord>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key) ?? '[]';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((row) => LucrareAsociereRecord.fromMap(
                Map<String, dynamic>.from(row),
              ))
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: true);
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsert(LucrareAsociereRecord record) async {
    final items = await list();
    final index = items.indexWhere((item) => item.id == record.id);
    if (index < 0) {
      items.add(record);
    } else {
      items[index] = record;
    }
    await _write(items);
  }

  Future<void> writeAll(List<LucrareAsociereRecord> items) => _write(items);

  Future<void> _write(List<LucrareAsociereRecord> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(items.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  Future<Map<String, dynamic>> loadFilters() => _loadMap(filtersKey);
  Future<void> saveFilters(Map<String, dynamic> filters) =>
      _saveMap(filtersKey, filters);
  Future<Map<String, dynamic>> loadDefaults() => _loadMap(defaultsKey);
  Future<void> saveDefaults(Map<String, dynamic> defaults) =>
      _saveMap(defaultsKey, defaults);

  Future<Map<String, dynamic>> _loadMap(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final decoded = jsonDecode(prefs.getString(storageKey) ?? '{}');
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _saveMap(String storageKey, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(value));
  }
}
