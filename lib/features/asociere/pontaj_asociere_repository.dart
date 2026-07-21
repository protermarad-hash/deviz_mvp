import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/cloud_sync_models.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'pontaj_asociere_models.dart';

/// Repository pentru pontaje pe asociere. Costul de manoperă NU se stochează —
/// se calculează la decont (ore × tarif), doar pentru pontaje confirmate
/// integral (vezi PontajAsociereRecord.dataRecunoastereCost).
class PontajAsociereRepository {
  PontajAsociereRepository._();
  static final PontajAsociereRepository instance = PontajAsociereRepository._();

  static const String _localKey = 'pontaje_asociere_v1';

  static String? lastFirestoreError;
  static int lastLocalCount = 0;
  static DateTime? lastSyncAt;

  bool get _isCloud => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection(FirebaseCollections.pontajeAsociere);

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> upsertPontaj(PontajAsociereRecord r) async {
    final existing = await listLocal();
    if (existing.any(
        (item) => item.id != r.id && item.idempotencyKey == r.idempotencyKey)) {
      throw StateError(
          'Pontaj duplicat pentru aceeași persoană și activitate.');
    }
    await _writeLocal(r);
    await OfflineSyncRuntime.instance.queuePontajAsociere(r);
  }

  Future<void> deletePontaj(String id) async {
    await _deleteLocal(id);
    await OfflineSyncRuntime.instance.queuePontajAsociereDelete(id);
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
          .map(
              (e) => PontajAsociereRecord.fromMap(Map<String, dynamic>.from(e)))
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
      final pendingIds = await OfflineSyncRuntime.instance
          .pendingUpsertEntityIds(CloudEntityType.pontajeAsociere);
      final localById = {for (final item in locals) item.id: item};
      final merged = <String, PontajAsociereRecord>{};
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
          await OfflineSyncRuntime.instance.queuePontajAsociere(local);
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

  Future<List<PontajAsociereRecord>> listByProject(String projectId) async {
    final all = await listMerged();
    return _sort(all.where((r) => r.projectId == projectId).toList());
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

  Future<void> _writeAll(List<PontajAsociereRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localKey,
      jsonEncode(records.map((record) => record.toMap()).toList()),
    );
  }

  List<PontajAsociereRecord> _sort(List<PontajAsociereRecord> list) {
    return list..sort((a, b) => b.data.compareTo(a.data));
  }
}
