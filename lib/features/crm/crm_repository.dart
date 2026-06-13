import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'crm_models.dart';

class CrmRepository {
  CrmRepository._();
  static final CrmRepository instance = CrmRepository._();

  static const String _localKey = 'crm_records_v1';

  static String? lastFirestoreError;
  static int lastLocalCount = 0;

  final Uuid _uuid = const Uuid();
  bool get _isCloud => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(FirebaseCollections.crmRecords);

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> upsertCrmRecord(CrmRecord r) async {
    await _writeLocal(r);
    await OfflineSyncRuntime.instance.queueCrmRecordUpsert(r.toMap());
    if (_isCloud) {
      _col.doc(r.id).set(r.toMap(), SetOptions(merge: true)).catchError((e) {
        lastFirestoreError = e.toString();
      });
    }
  }

  Future<void> deleteCrmRecord(String id) async {
    await _deleteLocal(id);
    await OfflineSyncRuntime.instance.queueCrmRecordDelete(id);
    if (_isCloud) {
      _col.doc(id).delete().catchError((_) {});
    }
  }

  Future<CrmRecord> addInteractiune(
      String recordId, CrmInteractiune interactiune) async {
    final all = await listLocal();
    final idx = all.indexWhere((r) => r.id == recordId);
    if (idx < 0) throw StateError('CrmRecord $recordId not found');
    final updated = all[idx].copyWith(
      interactiuni: [...all[idx].interactiuni, interactiune],
      updatedAt: DateTime.now(),
    );
    await upsertCrmRecord(updated);
    return updated;
  }

  // ── Citire ───────────────────────────────────────────────────────────────

  Future<List<CrmRecord>> listLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey) ?? '[]';
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final items = decoded
          .whereType<Map>()
          .map((e) =>
              CrmRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      lastLocalCount = items.length;
      return items;
    } catch (e) {
      debugPrint('[CRM] ❌ listLocal: $e');
      return [];
    }
  }

  Future<List<CrmRecord>> listMerged() async {
    final locals = await listLocal();
    if (!_isCloud) return _sort(locals);
    try {
      final snap = await _col.get();
      final cloud = snap.docs
          .map((d) => CrmRecord.fromMap({...d.data(), 'id': d.id}))
          .toList();
      final cloudIds = cloud.map((c) => c.id).toSet();
      final localOnly =
          locals.where((l) => !cloudIds.contains(l.id)).toList();
      for (final r in localOnly) {
        await OfflineSyncRuntime.instance.queueCrmRecordUpsert(r.toMap());
      }
      lastFirestoreError = null;
      return _sort([...cloud, ...localOnly]);
    } catch (e) {
      lastFirestoreError = e.toString();
      return _sort(locals);
    }
  }

  Future<List<CrmRecord>> listByStadiu(CrmStadiu stadiu) async {
    final all = await listLocal();
    return _sort(all.where((r) => r.stadiu == stadiu).toList());
  }

  Future<List<CrmRecord>> listNecesitaActiune() async {
    final all = await listLocal();
    return all
        .where((r) => r.necesitaActiune && r.esteActiv)
        .toList()
      ..sort((a, b) {
        final da = a.dataUrmatoareActiune ?? DateTime(2099);
        final db = b.dataUrmatoareActiune ?? DateTime(2099);
        return da.compareTo(db);
      });
  }

  Future<CrmStats> getStats() async {
    final all = await listLocal();
    final castigate = all.where((r) => r.stadiu == CrmStadiu.castigat).toList();
    final pierdute = all.where((r) => r.stadiu == CrmStadiu.pierdut).toList();
    final total = castigate.length + pierdute.length;
    final rataConversie =
        total > 0 ? castigate.length / total * 100 : 0.0;

    final activePipeline = all.where((r) =>
        r.stadiu == CrmStadiu.lead ||
        r.stadiu == CrmStadiu.calificat ||
        r.stadiu == CrmStadiu.ofertaTrimisa ||
        r.stadiu == CrmStadiu.negociere);

    double valCastigata = 0;
    for (final r in castigate) {
      valCastigata += r.valoareFinala ?? r.valoareEstimata;
    }
    double valPipeline = 0;
    for (final r in activePipeline) {
      valPipeline += r.valoareEstimata;
    }

    final perSursa = <String, int>{};
    final perTip = <String, double>{};
    for (final r in all) {
      perSursa[r.sursa] = (perSursa[r.sursa] ?? 0) + 1;
      if (r.tipLucrare.isNotEmpty) {
        perTip[r.tipLucrare] =
            (perTip[r.tipLucrare] ?? 0) + r.valoareEstimata;
      }
    }

    return CrmStats(
      totalLeaduri: all.length,
      castigate: castigate.length,
      pierdute: pierdute.length,
      rataConversie: rataConversie,
      valoareTotalaCastigata: valCastigata,
      valoareTotalaPipeline: valPipeline,
      perSursa: perSursa,
      perTipLucrare: perTip,
    );
  }

  // ── Factory ───────────────────────────────────────────────────────────────

  CrmRecord createNew({
    required String titlu,
    required String clientName,
    String clientId = '',
    CrmStadiu stadiu = CrmStadiu.lead,
    double valoareEstimata = 0,
    String tipLucrare = '',
    String sursa = 'Direct',
    String contactPerson = '',
    List<String> phoneNumbers = const [],
  }) {
    final now = DateTime.now();
    return CrmRecord(
      id: _uuid.v4(),
      titlu: titlu,
      clientId: clientId.isEmpty ? _uuid.v4() : clientId,
      clientName: clientName,
      contactPerson: contactPerson,
      phoneNumbers: phoneNumbers,
      stadiu: stadiu,
      tipLucrare: tipLucrare,
      valoareEstimata: valoareEstimata,
      sursa: sursa,
      dataContact: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ── Persistență ───────────────────────────────────────────────────────────

  Future<void> _writeLocal(CrmRecord r) async {
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

  List<CrmRecord> _sort(List<CrmRecord> list) {
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}
