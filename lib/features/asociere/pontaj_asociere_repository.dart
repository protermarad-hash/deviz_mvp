import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'pontaj_asociere_models.dart';

/// Repository pentru pontaje pe asociere. Costul de manoperă NU se stochează —
/// se calculează la decont (ore × tarif), doar pentru pontaje confirmate
/// integral (vezi PontajAsociereRecord.dataRecunoastereCost).
class PontajAsociereRepository {
  PontajAsociereRepository._();
  static final PontajAsociereRepository instance =
      PontajAsociereRepository._();

  static const String _localKey = 'pontaje_asociere_v1';

  static String? lastFirestoreError;
  static int lastLocalCount = 0;

  bool get _isCloud => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(FirebaseCollections.pontajeAsociere);

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> upsertPontaj(PontajAsociereRecord r) async {
    await _writeLocal(r);
    await OfflineSyncRuntime.instance.queuePontajAsociere(r);
    if (_isCloud) {
      _col.doc(r.id).set(r.toMap(), SetOptions(merge: true)).catchError((e) {
        lastFirestoreError = e.toString();
      });
    }
  }

  Future<void> deletePontaj(String id) async {
    await _deleteLocal(id);
    await OfflineSyncRuntime.instance.queuePontajAsociereDelete(id);
    if (_isCloud) {
      _col.doc(id).delete().catchError((_) {});
    }
  }

  // ── Citire ───────────────────────────────────────────────────────────────

  Future<List<PontajAsociereRecord>> listLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey) ?? '[]';
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final items = decoded
          .whereType<Map>()
          .map((e) =>
              PontajAsociereRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      lastLocalCount = items.length;
      return items;
    } catch (e) {
      debugPrint('[PontajAsociere] ❌ listLocal: $e');
      return [];
    }
  }

  Future<List<PontajAsociereRecord>> listMerged() async {
    final locals = await listLocal();
    if (!_isCloud) return _sort(locals);
    try {
      final snap = await _col.get();
      final cloud = snap.docs
          .map((d) => PontajAsociereRecord.fromMap({...d.data(), 'id': d.id}))
          .toList();
      final cloudIds = cloud.map((c) => c.id).toSet();
      final localOnly = locals.where((l) => !cloudIds.contains(l.id)).toList();
      for (final r in localOnly) {
        await OfflineSyncRuntime.instance.queuePontajAsociere(r);
      }
      lastFirestoreError = null;
      return _sort([...cloud, ...localOnly]);
    } catch (e) {
      lastFirestoreError = e.toString();
      return _sort(locals);
    }
  }

  Future<List<PontajAsociereRecord>> listByAsociere(String asociereId) async {
    final all = await listLocal();
    return _sort(all.where((r) => r.asociereId == asociereId).toList());
  }

  // ── Persistență ───────────────────────────────────────────────────────────

  Future<void> _writeLocal(PontajAsociereRecord r) async {
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

  List<PontajAsociereRecord> _sort(List<PontajAsociereRecord> list) {
    return list..sort((a, b) => b.data.compareTo(a.data));
  }
}
