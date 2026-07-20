import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'asociere_models.dart';

/// Repository pentru asocieri (partajare profit/pierdere pe Lucrare).
/// Pattern standard (mirror crm_repository.dart): local → queue → Firestore
/// fire-and-forget. Query Firestore fără .orderBy() — sortare în Dart.
class AsociereRepository {
  AsociereRepository._();
  static final AsociereRepository instance = AsociereRepository._();

  static const String _localKey = 'asocieri_v1';

  static String? lastFirestoreError;
  static int lastLocalCount = 0;

  bool get _isCloud => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(FirebaseCollections.asocieri);

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> upsertAsociere(AsociereRecord r) async {
    await _writeLocal(r);
    await OfflineSyncRuntime.instance.queueAsociere(r);
    if (_isCloud) {
      _col.doc(r.id).set(r.toMap(), SetOptions(merge: true)).catchError((e) {
        lastFirestoreError = e.toString();
      });
    }
  }

  Future<void> deleteAsociere(String id) async {
    await _deleteLocal(id);
    await OfflineSyncRuntime.instance.queueAsociereDelete(id);
    if (_isCloud) {
      _col.doc(id).delete().catchError((_) {});
    }
  }

  // ── Citire ───────────────────────────────────────────────────────────────

  Future<List<AsociereRecord>> listLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey) ?? '[]';
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final items = decoded
          .whereType<Map>()
          .map((e) => AsociereRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      lastLocalCount = items.length;
      return items;
    } catch (e) {
      debugPrint('[Asociere] ❌ listLocal: $e');
      return [];
    }
  }

  Future<List<AsociereRecord>> listMerged() async {
    final locals = await listLocal();
    if (!_isCloud) return _sort(locals);
    try {
      final snap = await _col.get();
      final cloud = snap.docs
          .map((d) => AsociereRecord.fromMap({...d.data(), 'id': d.id}))
          .toList();
      final cloudIds = cloud.map((c) => c.id).toSet();
      final localOnly = locals.where((l) => !cloudIds.contains(l.id)).toList();
      for (final r in localOnly) {
        await OfflineSyncRuntime.instance.queueAsociere(r);
      }
      lastFirestoreError = null;
      return _sort([...cloud, ...localOnly]);
    } catch (e) {
      lastFirestoreError = e.toString();
      return _sort(locals);
    }
  }

  Future<List<AsociereRecord>> listByLucrare(String lucrareId) async {
    final all = await listLocal();
    return _sort(all.where((r) => r.lucrareId == lucrareId).toList());
  }

  Future<AsociereRecord?> getById(String id) async {
    final all = await listLocal();
    for (final r in all) {
      if (r.id == id) return r;
    }
    return null;
  }

  // ── Persistență ───────────────────────────────────────────────────────────

  Future<void> _writeLocal(AsociereRecord r) async {
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

  List<AsociereRecord> _sort(List<AsociereRecord> list) {
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}
