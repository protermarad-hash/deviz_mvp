import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/cloud_sync_models.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'venit_asociere_models.dart';

/// Repository pentru venituri (facturi emise) pe asociere. Un venit intră în
/// decontul lunii DOAR dacă are `dataIncasare` setată în luna respectivă
/// (vezi VenitAsociereRecord — "încasat", nu doar "facturat").
class VenitAsociereRepository {
  VenitAsociereRepository._();
  static final VenitAsociereRepository instance = VenitAsociereRepository._();

  static const String _localKey = 'venituri_asociere_v1';

  static String? lastFirestoreError;
  static int lastLocalCount = 0;
  static DateTime? lastSyncAt;

  bool get _isCloud => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection(FirebaseCollections.venituriAsociere);

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> upsertVenit(VenitAsociereRecord r) async {
    final existing = await listLocal();
    if (existing.any(
        (item) => item.id != r.id && item.idempotencyKey == r.idempotencyKey)) {
      throw StateError('Venit duplicat pentru aceeași factură și dată.');
    }
    await _writeLocal(r);
    await OfflineSyncRuntime.instance.queueVenitAsociere(r);
    if (_isCloud) {
      _col.doc(r.id).set(r.toMap(), SetOptions(merge: true)).catchError((e) {
        lastFirestoreError = e.toString();
      });
    }
  }

  Future<void> deleteVenit(String id) async {
    await _deleteLocal(id);
    await OfflineSyncRuntime.instance.queueVenitAsociereDelete(id);
    if (_isCloud) {
      _col.doc(id).delete().catchError((_) {});
    }
  }

  // ── Citire ───────────────────────────────────────────────────────────────

  Future<List<VenitAsociereRecord>> listLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey) ?? '[]';
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final items = decoded
          .whereType<Map>()
          .map((e) => VenitAsociereRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      lastLocalCount = items.length;
      return items;
    } catch (e) {
      debugPrint('[VenitAsociere] ❌ listLocal: $e');
      return [];
    }
  }

  Future<List<VenitAsociereRecord>> listMerged() async {
    final locals = await listLocal();
    if (!_isCloud) return _sort(locals);
    try {
      final snap = await _col.get();
      final cloud = snap.docs
          .map((d) => VenitAsociereRecord.fromMap({...d.data(), 'id': d.id}))
          .toList();
      final pendingIds = await OfflineSyncRuntime.instance
          .pendingUpsertEntityIds(CloudEntityType.venituriAsociere);
      final localById = {for (final item in locals) item.id: item};
      final merged = <String, VenitAsociereRecord>{};
      for (final remote in cloud) {
        final local = localById[remote.id];
        merged[remote.id] = local != null &&
                (pendingIds.contains(remote.id) ||
                    local.revision > remote.revision)
            ? local
            : remote;
      }
      for (final local in locals) {
        if (!merged.containsKey(local.id)) {
          merged[local.id] = local;
          await OfflineSyncRuntime.instance.queueVenitAsociere(local);
        }
      }
      lastFirestoreError = null;
      lastSyncAt = DateTime.now();
      final result = _sort(merged.values.toList());
      await _writeAll(result);
      return result;
    } catch (e) {
      lastFirestoreError = e.toString();
      return _sort(locals);
    }
  }

  Future<List<VenitAsociereRecord>> listByProject(String projectId) async {
    final all = await listMerged();
    return _sort(all.where((r) => r.projectId == projectId).toList());
  }

  // ── Persistență ───────────────────────────────────────────────────────────

  Future<void> _writeLocal(VenitAsociereRecord r) async {
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

  Future<void> _writeAll(List<VenitAsociereRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localKey,
      jsonEncode(records.map((record) => record.toMap()).toList()),
    );
  }

  List<VenitAsociereRecord> _sort(List<VenitAsociereRecord> list) {
    return list
      ..sort((a, b) => (b.dataFactura ?? b.createdAt)
          .compareTo(a.dataFactura ?? a.createdAt));
  }
}
