import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'echipament_instalat_models.dart';

class EchipamenteRepository {
  EchipamenteRepository._();
  static final EchipamenteRepository instance = EchipamenteRepository._();

  static const String _localKey = 'echipamente_instalate_v1';

  static String? lastFirestoreError;
  static int lastLocalCount = 0;

  final Uuid _uuid = const Uuid();
  bool get _isCloud => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection(FirebaseCollections.echipamenteInstalate);

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> upsertEchipament(EchipamentInstalat e) async {
    await _writeLocal(e);
    await OfflineSyncRuntime.instance.queueEchipamentInstalat(e.toMap());
    if (_isCloud) {
      _col.doc(e.id).set(e.toMap(), SetOptions(merge: true)).catchError((err) {
        lastFirestoreError = err.toString();
      });
    }
  }

  Future<void> deleteEchipament(String id) async {
    await _deleteLocal(id);
    await OfflineSyncRuntime.instance.queueEchipamentInstalatDelete(id);
    if (_isCloud) {
      _col.doc(id).delete().catchError((_) {});
    }
  }

  // ── Citire ───────────────────────────────────────────────────────────────

  Future<List<EchipamentInstalat>> listLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey) ?? '[]';
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final items = decoded
          .whereType<Map>()
          .map((e) =>
              EchipamentInstalat.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      lastLocalCount = items.length;
      return items;
    } catch (e) {
      debugPrint('[Echipamente] ❌ listLocal: $e');
      return [];
    }
  }

  Future<List<EchipamentInstalat>> listMerged() async {
    final locals = await listLocal();
    if (!_isCloud) return _sort(locals);
    try {
      final snap = await _col.get();
      final cloud = snap.docs
          .map((d) => EchipamentInstalat.fromMap({...d.data(), 'id': d.id}))
          .toList();
      final cloudIds = cloud.map((c) => c.id).toSet();
      final localOnly =
          locals.where((l) => !cloudIds.contains(l.id)).toList();
      for (final e in localOnly) {
        await OfflineSyncRuntime.instance.queueEchipamentInstalat(e.toMap());
      }
      lastFirestoreError = null;
      return _sort([...cloud, ...localOnly]);
    } catch (e) {
      lastFirestoreError = e.toString();
      return _sort(locals);
    }
  }

  Future<List<EchipamentInstalat>> listForClient(String clientId) async {
    final all = await listLocal();
    return _sort(all.where((e) => e.clientId == clientId).toList());
  }

  Future<List<EchipamentInstalat>> listGarantiiExpirandCurand(
      {int inZile = 30}) async {
    final all = await listLocal();
    final limita = DateTime.now().add(Duration(days: inZile));
    return all
        .where((e) =>
            e.garantieLuni > 0 && e.dataExpirariiGarantiei.isBefore(limita))
        .toList()
      ..sort((a, b) =>
          a.dataExpirariiGarantiei.compareTo(b.dataExpirariiGarantiei));
  }

  Future<List<EchipamentInstalat>> listNecesitaService() async {
    final all = await listLocal();
    return all.where((e) => e.necesitaService).toList();
  }

  Future<void> inregistreazaInterventiePeEchipament({
    required String echipamentId,
    required String interventieId,
    required DateTime data,
  }) async {
    final all = await listLocal();
    final idx = all.indexWhere((e) => e.id == echipamentId);
    if (idx < 0) return;
    final updated = all[idx].copyWith(
      ultimaInterventieData: data,
      ultimaInterventieId: interventieId,
      updatedAt: DateTime.now(),
    );
    await upsertEchipament(updated);
  }

  // ── Creare rapidă din PV ─────────────────────────────────────────────────

  EchipamentInstalat creeazaDinPV({
    required String clientId,
    required String clientName,
    required String adresa,
    required String marca,
    required String model,
    required String serie,
    required String technician,
    required String numarPV,
    required String jobId,
    int garantieLuni = 24,
    String tipEchipament = 'AC Split',
    String agentFrigorific = '',
  }) {
    final now = DateTime.now();
    return EchipamentInstalat(
      id: _uuid.v4(),
      clientId: clientId,
      clientName: clientName,
      adresaInstalare: adresa,
      tipEchipament: tipEchipament,
      marca: marca,
      model: model,
      serieUnitateExterna: serie,
      agentFrigorific: agentFrigorific,
      dataInstalare: now,
      numarPVMontaj: numarPV,
      jobId: jobId,
      technicianInstalare: technician,
      garantieLuni: garantieLuni,
      stare: 'functional',
      createdAt: now,
      updatedAt: now,
    );
  }

  // ── Sync forțat ──────────────────────────────────────────────────────────

  Future<int> forceSyncToCloud() async {
    if (!_isCloud) return 0;
    final items = await listLocal();
    int count = 0;
    for (final e in items) {
      try {
        await _col.doc(e.id).set(e.toMap(), SetOptions(merge: true));
        count++;
      } catch (err) {
        debugPrint('[Echipamente] ❌ forceSyncToCloud: $err');
      }
    }
    return count;
  }

  // ── Persistență locală ───────────────────────────────────────────────────

  Future<void> _writeLocal(EchipamentInstalat e) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await listLocal();
    final idx = all.indexWhere((item) => item.id == e.id);
    if (idx >= 0) {
      all[idx] = e;
    } else {
      all.add(e);
    }
    await prefs.setString(
        _localKey, jsonEncode(all.map((item) => item.toMap()).toList()));
  }

  Future<void> _deleteLocal(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await listLocal();
    all.removeWhere((e) => e.id == id);
    await prefs.setString(
        _localKey, jsonEncode(all.map((e) => e.toMap()).toList()));
  }

  List<EchipamentInstalat> _sort(List<EchipamentInstalat> list) {
    return list
      ..sort((a, b) => b.dataInstalare.compareTo(a.dataInstalare));
  }
}
