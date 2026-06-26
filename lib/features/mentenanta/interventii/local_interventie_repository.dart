import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'interventie_models.dart';
import 'interventie_repository.dart';

/// Implementare locală (SharedPreferences) a [InterventieRepository].
///
/// Stochează TOATE intervențiile (din toate contractele) sub o singură cheie
/// versionată; [listInterventii] filtrează după `contractId`. Pattern identic cu
/// [LocalMentenantaRepository]: citire/scriere JSON, sortare în Dart.
class LocalInterventieRepository implements InterventieRepository {
  LocalInterventieRepository._();

  static final LocalInterventieRepository instance =
      LocalInterventieRepository._();

  static const String _prefKey = 'mentenanta_interventii_v1';

  // ── Citire / scriere brută ──────────────────────────────────────────────────

  Future<List<InterventieService>> _readAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) =>
              InterventieService.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('[InterventieLocal] ❌ Eroare citire cache: $e');
      return [];
    }
  }

  Future<void> _writeAll(List<InterventieService> items) async {
    final prefs = await SharedPreferences.getInstance();
    final data = items.map((i) => i.toMap()).toList();
    await prefs.setString(_prefKey, jsonEncode(data));
  }

  List<InterventieService> _sorted(List<InterventieService> items) {
    final copy = [...items];
    copy.sort((a, b) => b.dataInterventie.compareTo(a.dataInterventie));
    return copy;
  }

  // ── API public ────────────────────────────────────────────────────────────────

  /// Toate intervențiile din cache (orice contract), nesortate.
  Future<List<InterventieService>> listAll() => _readAll();

  @override
  Future<List<InterventieService>> listInterventii(String contractId) async {
    final all = await _readAll();
    return _sorted(all.where((i) => i.contractId == contractId).toList());
  }

  @override
  Future<InterventieService> saveInterventie(
      InterventieService interventie) async {
    final items = await _readAll();
    final idx = items.indexWhere((i) => i.id == interventie.id);
    if (idx >= 0) {
      items[idx] = interventie;
    } else {
      items.insert(0, interventie);
    }
    await _writeAll(items);
    return interventie;
  }

  @override
  Future<void> deleteInterventie(String id) async {
    final items = await _readAll();
    items.removeWhere((i) => i.id == id);
    await _writeAll(items);
  }

  /// Upsert în lot (folosit de implementarea Firebase la merge cloud + local).
  /// O singură scriere finală.
  Future<void> upsertMany(List<InterventieService> incoming) async {
    if (incoming.isEmpty) return;
    final items = await _readAll();
    final byId = {for (final i in items) i.id: i};
    for (final i in incoming) {
      byId[i.id] = i;
    }
    await _writeAll(byId.values.toList());
  }
}
