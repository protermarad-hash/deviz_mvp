import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'tarif_asociere_models.dart';

/// Repository pentru tarife per calificare, negociate per-asociere.
/// Folosite la calculul manoperei din pontaje (ore × tarifRonOra).
class TarifAsociereRepository {
  TarifAsociereRepository._();
  static final TarifAsociereRepository instance = TarifAsociereRepository._();

  static const String _localKey = 'tarife_asociere_v1';

  static String? lastFirestoreError;
  static int lastLocalCount = 0;

  bool get _isCloud => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(FirebaseCollections.tarifeAsociere);

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> upsertTarif(TarifAsociereRecord r) async {
    await _writeLocal(r);
    await OfflineSyncRuntime.instance.queueTarifAsociere(r);
    if (_isCloud) {
      _col.doc(r.id).set(r.toMap(), SetOptions(merge: true)).catchError((e) {
        lastFirestoreError = e.toString();
      });
    }
  }

  Future<void> deleteTarif(String id) async {
    await _deleteLocal(id);
    await OfflineSyncRuntime.instance.queueTarifAsociereDelete(id);
    if (_isCloud) {
      _col.doc(id).delete().catchError((_) {});
    }
  }

  // ── Citire ───────────────────────────────────────────────────────────────

  Future<List<TarifAsociereRecord>> listLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey) ?? '[]';
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final items = decoded
          .whereType<Map>()
          .map((e) => TarifAsociereRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      lastLocalCount = items.length;
      return items;
    } catch (e) {
      debugPrint('[TarifAsociere] ❌ listLocal: $e');
      return [];
    }
  }

  Future<List<TarifAsociereRecord>> listMerged() async {
    final locals = await listLocal();
    if (!_isCloud) return locals;
    try {
      final snap = await _col.get();
      final cloud = snap.docs
          .map((d) => TarifAsociereRecord.fromMap({...d.data(), 'id': d.id}))
          .toList();
      final cloudIds = cloud.map((c) => c.id).toSet();
      final localOnly = locals.where((l) => !cloudIds.contains(l.id)).toList();
      for (final r in localOnly) {
        await OfflineSyncRuntime.instance.queueTarifAsociere(r);
      }
      lastFirestoreError = null;
      return [...cloud, ...localOnly];
    } catch (e) {
      lastFirestoreError = e.toString();
      return locals;
    }
  }

  Future<List<TarifAsociereRecord>> listByAsociere(String asociereId) async {
    final all = await listLocal();
    return all.where((r) => r.asociereId == asociereId).toList()
      ..sort((a, b) => a.calificare.compareTo(b.calificare));
  }

  /// Tariful RON/oră pentru o calificare pe o asociere (0 dacă lipsește).
  /// Folosit la calculul manoperei din pontaje.
  Future<double> tarifRonOraPentru(String asociereId, String calificare) async {
    final tarife = await listByAsociere(asociereId);
    final key = calificare.trim().toLowerCase();
    for (final t in tarife) {
      if (t.calificare.trim().toLowerCase() == key) return t.tarifRonOra;
    }
    return 0;
  }

  // ── Persistență ───────────────────────────────────────────────────────────

  Future<void> _writeLocal(TarifAsociereRecord r) async {
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
}
