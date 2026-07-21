import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/cloud_sync_models.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'asociere_operational_common.dart';
import 'tarif_asociere_models.dart';

/// Repository pentru tarife per calificare, negociate per-asociere.
/// Folosite la calculul manoperei din pontaje (ore × tarifRonOra).
class TarifAsociereRepository {
  TarifAsociereRepository._();
  static final TarifAsociereRepository instance = TarifAsociereRepository._();

  static const String _localKey = 'tarife_asociere_v1';

  static String? lastFirestoreError;
  static int lastLocalCount = 0;
  static DateTime? lastSyncAt;

  bool get _isCloud => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(FirebaseCollections.tarifeAsociere);

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> upsertTarif(TarifAsociereRecord r) async {
    final existing = await listLocal();
    final persoana = r.persoanaId.trim().toLowerCase();
    if (existing.any((item) {
      if (item.id == r.id || item.projectId != r.projectId) return false;
      if (item.valabilDeLa != r.valabilDeLa) return false;
      if (persoana.isNotEmpty) {
        // Tarif individual: unic pe (persoană, perioadă).
        return item.persoanaId.trim().toLowerCase() == persoana;
      }
      // Tarif pe calificare: unic pe (calificare, asociat, perioadă).
      return !item.esteIndividual &&
          item.calificare.trim().toLowerCase() ==
              r.calificare.trim().toLowerCase() &&
          item.asociat == r.asociat;
    })) {
      throw StateError(persoana.isNotEmpty
          ? 'Tarif individual duplicat pentru aceeași persoană și perioadă.'
          : 'Tarif duplicat pentru aceeași calificare și perioadă.');
    }
    await _writeLocal(r);
    await OfflineSyncRuntime.instance.queueTarifAsociere(r);
  }

  Future<void> deleteTarif(String id) async {
    await _deleteLocal(id);
    await OfflineSyncRuntime.instance.queueTarifAsociereDelete(id);
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
      final pendingIds = await OfflineSyncRuntime.instance
          .pendingUpsertEntityIds(CloudEntityType.tarifeAsociere);
      final localById = {for (final item in locals) item.id: item};
      final merged = <String, TarifAsociereRecord>{};
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
          await OfflineSyncRuntime.instance.queueTarifAsociere(local);
        }
      }
      lastFirestoreError = null;
      lastSyncAt = DateTime.now();
      final result = merged.values.toList();
      await _writeAll(result);
      return result;
    } catch (e) {
      lastFirestoreError = e.toString();
      return locals;
    }
  }

  Future<List<TarifAsociereRecord>> listByProject(String projectId) async {
    final all = await listMerged();
    return all.where((r) => r.projectId == projectId).toList()
      ..sort((a, b) => a.calificare.compareTo(b.calificare));
  }

  /// Tariful RON/oră pentru o calificare pe o asociere (0 dacă lipsește).
  /// Păstrat pentru compatibilitate — folosește fallback-ul pe calificare.
  Future<double> tarifOraPentru(
      String projectId, String calificare, DateTime data) async {
    final rez = await rezolva(
      projectId: projectId,
      persoanaId: '',
      calificare: calificare,
      angajator: AsociereParte.proTerm,
      data: data,
    );
    return rez.tarifOra;
  }

  /// Rezolvă tariful pentru o persoană cu fallback pe calificare (vezi
  /// [rezolvaTarifAsociere]). Returnează și sursa tarifului, pentru mesaje UX.
  Future<TarifAsociereRezolutie> rezolva({
    required String projectId,
    required String persoanaId,
    required String calificare,
    required AsociereParte angajator,
    required DateTime data,
  }) async {
    final tarife = await listByProject(projectId);
    return rezolvaTarifAsociere(
      tarife: tarife,
      persoanaId: persoanaId,
      calificare: calificare,
      angajator: angajator,
      data: data,
    );
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

  Future<void> _writeAll(List<TarifAsociereRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localKey,
      jsonEncode(records.map((record) => record.toMap()).toList()),
    );
  }
}
