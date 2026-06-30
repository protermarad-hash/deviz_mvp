import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'serviciu_prestat_models.dart';
import 'serviciu_prestat_repository.dart';

/// Implementare locală (SharedPreferences) a [ServiciuPrestatRepository].
///
/// Pattern identic cu [LocalMentenantaRepository]: citire/scriere JSON sub o
/// cheie versionată, sortare în Dart, offline-first.
class LocalServiciuPrestatRepository implements ServiciuPrestatRepository {
  LocalServiciuPrestatRepository._();

  static final LocalServiciuPrestatRepository instance =
      LocalServiciuPrestatRepository._();

  static const String _prefKey = 'servicii_prestate_v1';

  Future<List<ServiciuPrestat>> _readAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) =>
              ServiciuPrestat.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('[ServiciiLocal] ❌ Eroare citire cache: $e');
      return [];
    }
  }

  Future<void> _writeAll(List<ServiciuPrestat> items) async {
    final prefs = await SharedPreferences.getInstance();
    final data = items.map((s) => s.toMap()).toList();
    await prefs.setString(_prefKey, jsonEncode(data));
  }

  List<ServiciuPrestat> _sorted(List<ServiciuPrestat> items) {
    final copy = [...items];
    copy.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return copy;
  }

  @override
  Future<List<ServiciuPrestat>> listServicii() async {
    return _sorted(await _readAll());
  }

  @override
  Future<ServiciuPrestat> saveServiciu(ServiciuPrestat s) async {
    final items = await _readAll();
    final idx = items.indexWhere((e) => e.id == s.id);
    if (idx >= 0) {
      items[idx] = s;
    } else {
      items.insert(0, s);
    }
    await _writeAll(items);
    return s;
  }

  @override
  Future<void> deleteServiciu(String id) async {
    final items = await _readAll();
    items.removeWhere((e) => e.id == id);
    await _writeAll(items);
  }

  /// Înlocuiește complet cache-ul local (folosit de implementarea Firebase la
  /// merge cloud + local).
  Future<void> replaceCache(List<ServiciuPrestat> items) => _writeAll(items);
}
