import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'cost_asociere_models.dart';

/// Repository pentru costuri pe asociere. `necesitaAprobare` se stabilește la
/// creare (vezi CostAsociereRecord.computeNecesitaAprobare) — nu se
/// recalculează retroactiv. Recunoașterea într-un decont se face după
/// `dataRecunoastereCost` (vezi model).
class CostAsociereRepository {
  CostAsociereRepository._();
  static final CostAsociereRepository instance = CostAsociereRepository._();

  static const String _localKey = 'costuri_asociere_v1';

  static String? lastFirestoreError;
  static int lastLocalCount = 0;

  bool get _isCloud => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(FirebaseCollections.costuriAsociere);

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> upsertCost(CostAsociereRecord r) async {
    await _writeLocal(r);
    await OfflineSyncRuntime.instance.queueCostAsociere(r);
    if (_isCloud) {
      _col.doc(r.id).set(r.toMap(), SetOptions(merge: true)).catchError((e) {
        lastFirestoreError = e.toString();
      });
    }
  }

  Future<void> deleteCost(String id) async {
    await _deleteLocal(id);
    await OfflineSyncRuntime.instance.queueCostAsociereDelete(id);
    if (_isCloud) {
      _col.doc(id).delete().catchError((_) {});
    }
  }

  // ── Citire ───────────────────────────────────────────────────────────────

  Future<List<CostAsociereRecord>> listLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey) ?? '[]';
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final items = decoded
          .whereType<Map>()
          .map((e) => CostAsociereRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      lastLocalCount = items.length;
      return items;
    } catch (e) {
      debugPrint('[CostAsociere] ❌ listLocal: $e');
      return [];
    }
  }

  Future<List<CostAsociereRecord>> listMerged() async {
    final locals = await listLocal();
    if (!_isCloud) return _sort(locals);
    try {
      final snap = await _col.get();
      final cloud = snap.docs
          .map((d) => CostAsociereRecord.fromMap({...d.data(), 'id': d.id}))
          .toList();
      final cloudIds = cloud.map((c) => c.id).toSet();
      final localOnly = locals.where((l) => !cloudIds.contains(l.id)).toList();
      for (final r in localOnly) {
        await OfflineSyncRuntime.instance.queueCostAsociere(r);
      }
      lastFirestoreError = null;
      return _sort([...cloud, ...localOnly]);
    } catch (e) {
      lastFirestoreError = e.toString();
      return _sort(locals);
    }
  }

  Future<List<CostAsociereRecord>> listByAsociere(String asociereId) async {
    final all = await listLocal();
    return _sort(all.where((r) => r.asociereId == asociereId).toList());
  }

  // ── Persistență ───────────────────────────────────────────────────────────

  Future<void> _writeLocal(CostAsociereRecord r) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await listLocal();
    final idx = all.indexWhere((item) => item.id == r.id);
    if (idx >= 0) {
      all[idx] = r;
    } else {
      all.add(r);
    }
    await prefs.setString(
        _localKey, jsonEncode(all.map((item) => item.toMap()).toList()));
  }

  Future<void> _deleteLocal(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await listLocal();
    all.removeWhere((r) => r.id == id);
    await prefs.setString(
        _localKey, jsonEncode(all.map((r) => r.toMap()).toList()));
  }

  List<CostAsociereRecord> _sort(List<CostAsociereRecord> list) {
    return list..sort((a, b) => b.data.compareTo(a.data));
  }
}
