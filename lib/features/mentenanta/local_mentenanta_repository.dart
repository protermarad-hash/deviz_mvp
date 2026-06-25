import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mentenanta_models.dart';
import 'mentenanta_repository.dart';

/// Implementare locală (SharedPreferences) a [MentenantaRepository].
///
/// Pattern identic cu restul repository-urilor locale din proiect:
/// citire/scriere JSON sub o cheie versionată, sortare în Dart.
class LocalMentenantaRepository implements MentenantaRepository {
  LocalMentenantaRepository._();

  static final LocalMentenantaRepository instance =
      LocalMentenantaRepository._();

  static const String _prefKey = 'mentenanta_contracte_v1';

  final StreamController<List<ContractMentenanta>> _controller =
      StreamController<List<ContractMentenanta>>.broadcast();

  // ── Citire / scriere brută ──────────────────────────────────────────────────

  Future<List<ContractMentenanta>> _readAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) =>
              ContractMentenanta.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('[MentenantaLocal] ❌ Eroare citire cache: $e');
      return [];
    }
  }

  Future<void> _writeAll(List<ContractMentenanta> items) async {
    final prefs = await SharedPreferences.getInstance();
    final data = items.map((c) => c.toMap()).toList();
    await prefs.setString(_prefKey, jsonEncode(data));
    _controller.add(_sorted(items));
  }

  List<ContractMentenanta> _sorted(List<ContractMentenanta> items) {
    final copy = [...items];
    copy.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return copy;
  }

  // ── API public ────────────────────────────────────────────────────────────────

  @override
  Future<List<ContractMentenanta>> listContracte() async {
    return _sorted(await _readAll());
  }

  @override
  Future<ContractMentenanta> saveContract(ContractMentenanta contract) async {
    final items = await _readAll();
    final idx = items.indexWhere((c) => c.id == contract.id);
    if (idx >= 0) {
      items[idx] = contract;
    } else {
      items.insert(0, contract);
    }
    await _writeAll(items);
    return contract;
  }

  @override
  Future<void> deleteContract(String id) async {
    final items = await _readAll();
    items.removeWhere((c) => c.id == id);
    await _writeAll(items);
  }

  @override
  Stream<List<ContractMentenanta>> watchContracte() {
    // Emite imediat starea curentă pentru noii subscriberi.
    listContracte().then((items) {
      if (!_controller.isClosed) _controller.add(items);
    });
    return _controller.stream;
  }

  /// Înlocuiește complet cache-ul local (folosit de implementarea Firebase la
  /// merge cloud + local). Notifică subscriberii o singură dată.
  Future<void> replaceCache(List<ContractMentenanta> items) => _writeAll(items);
}
