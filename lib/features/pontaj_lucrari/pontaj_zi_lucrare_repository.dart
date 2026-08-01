import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/firestore_auth_warning_service.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'pontaj_zi_lucrare_models.dart';

/// Repository pentru pontajul zilnic pe lucrări — Firebase + cache local
/// + offline queue. Șablon: deviz_tehnic_repository.dart.
///
/// Pattern obligatoriu (CLAUDE.md):
/// 1. Scriere locală (funcționează offline)
/// 2. Queue OBLIGATORIU (sincronizare automată la revenirea internetului)
/// 3. Firebase direct (best-effort, fire-and-forget)
class PontajZiLucrareRepository {
  static const _prefKey = 'pontaj_zile_lucrari_cache_v1';

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection(FirebaseCollections.pontajZileLucrari);

  bool get _isCloudAvailable => FirebaseBootstrap.isInitialized;

  // ── Diagnostics (vizibile în UI pentru depanare cross-device) ──────────────
  static String? lastFirestoreError;
  static int lastFirestoreCount = -1;
  static int lastLocalCount = 0;

  // ── Local cache ────────────────────────────────────────────────────────────

  Future<List<PontajZiLucrare>> listLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) =>
              PontajZiLucrare.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocal(List<PontajZiLucrare> records) async {
    final prefs = await SharedPreferences.getInstance();
    final data = records.map((r) => r.toMap()).toList();
    await prefs.setString(_prefKey, jsonEncode(data));
  }

  Future<void> _updateLocalCache(PontajZiLucrare record) async {
    final locals = await listLocal();
    final idx = locals.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      locals[idx] = record;
    } else {
      locals.insert(0, record);
    }
    await _saveLocal(locals);
  }

  // ── List (cloud + local merge, filtrat per lucrare) ────────────────────────

  Future<List<PontajZiLucrare>> listForLucrare(String lucrareId) async {
    final all = await _listAll();
    return all.where((r) => r.lucrareId == lucrareId).toList();
  }

  Future<List<PontajZiLucrare>> _listAll() async {
    final localItems = await listLocal();

    if (!_isCloudAvailable) {
      return _sorted(localItems);
    }

    lastLocalCount = localItems.length;
    lastFirestoreCount = -1;
    lastFirestoreError = null;

    debugPrint(
        '[PontajLucrari] list(): isInit=${FirebaseBootstrap.isInitialized} '
        'isOnline=${FirebaseBootstrap.isOnline} '
        'localCache=${localItems.length} docs');

    try {
      // NU folosim .orderBy() — sortare în Dart (evită index compus Firestore)
      final snap = await _col.get();
      final cloudItems = snap.docs
          .map((d) => PontajZiLucrare.fromMap({...d.data(), 'id': d.id}))
          .toList();

      lastFirestoreCount = cloudItems.length;
      lastFirestoreError = null;
      debugPrint(
          '[PontajLucrari] Firestore returned ${cloudItems.length} docs');

      // Merge cloud + local-only (create offline, nesincronizate încă)
      final cloudIds = cloudItems.map((r) => r.id).toSet();
      final localOnly =
          localItems.where((r) => !cloudIds.contains(r.id)).toList();

      // Queue local-only ca să ajungă în cloud
      for (final r in localOnly) {
        await OfflineSyncRuntime.instance.queuePontajZiLucrareUpsert(r.toMap());
      }

      final merged = [...cloudItems, ...localOnly];
      await _saveLocal(merged);
      return _sorted(merged);
    } catch (e, stack) {
      lastFirestoreCount = -1;
      lastFirestoreError = e.toString();
      FirestoreAuthWarningService.instance.reportCloudError(e);
      debugPrint('[PontajLucrari] ❌ Eroare Firestore list(): $e');
      debugPrint('[PontajLucrari] Stack: $stack');
      return _sorted(localItems);
    }
  }

  List<PontajZiLucrare> _sorted(List<PontajZiLucrare> items) {
    final copy = [...items];
    // Cea mai recentă zi sus; în cadrul aceleiași zile, după nume.
    copy.sort((a, b) {
      final byDate = b.ziCalendaristica.compareTo(a.ziCalendaristica);
      if (byDate != 0) return byDate;
      return a.persoanaNume.toLowerCase().compareTo(b.persoanaNume.toLowerCase());
    });
    return copy;
  }

  // ── Save (upsert) ──────────────────────────────────────────────────────────

  Future<PontajZiLucrare> save(PontajZiLucrare record) async {
    PontajZiLucrare toSave;

    if (record.id.isEmpty || record.id.startsWith('local-')) {
      // Document nou — generăm ID în Firestore dacă online, altfel ID local
      if (_isCloudAvailable) {
        try {
          final map = record.toMap()..remove('id');
          final ref = await _col.add(map);
          toSave = PontajZiLucrare.fromMap({
            ...record.toMap(),
            'id': ref.id,
          });
        } catch (e) {
          debugPrint('[PontajLucrari] ❌ Eroare add la Firestore: $e');
          toSave = record.id.startsWith('local-')
              ? record
              : PontajZiLucrare.fromMap({
                  ...record.toMap(),
                  'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
                });
        }
      } else {
        toSave = record.id.startsWith('local-')
            ? record
            : PontajZiLucrare.fromMap({
                ...record.toMap(),
                'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
              });
      }
    } else {
      toSave = record;
    }

    // 1. Salvare locală
    // Dacă ID-ul s-a schimbat (local- → real), elimină intrarea veche din cache
    if (record.id != toSave.id && record.id.startsWith('local-')) {
      final locals = await listLocal();
      await _saveLocal(locals.where((r) => r.id != record.id).toList());
    }
    await _updateLocalCache(toSave);

    // 2. Queue OBLIGATORIU (funcționează și offline)
    await OfflineSyncRuntime.instance.queuePontajZiLucrareUpsert(toSave.toMap());

    // 3. Firebase direct (best-effort, fire-and-forget — nu blochează UI)
    if (_isCloudAvailable && !toSave.id.startsWith('local-')) {
      final map = toSave.toMap()..remove('id');
      _col.doc(toSave.id).set(map, SetOptions(merge: true)).catchError((_) {});
    }

    return toSave;
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    // 1. Ștergere locală
    final locals = await listLocal();
    await _saveLocal(locals.where((r) => r.id != id).toList());

    // 2. Queue delete OBLIGATORIU
    await OfflineSyncRuntime.instance.queuePontajZiLucrareDelete(id);

    // 3. Firebase direct (best-effort, fire-and-forget — nu blochează UI)
    if (_isCloudAvailable && !id.startsWith('local-')) {
      _col.doc(id).delete().catchError((_) {});
    }
  }

  // ── Sync forțat: publică toate documentele locale în Firestore ─────────────

  /// Re-scrie direct în Firestore toate documentele din cache-ul local.
  /// Folosit pentru diagnosticare și recuperare după eșecuri de sync.
  Future<int> forceSyncLocalToCloud() async {
    if (!_isCloudAvailable) return 0;
    final locals = await listLocal();
    if (locals.isEmpty) return 0;

    final result = List<PontajZiLucrare>.from(locals);
    int synced = 0;

    for (int i = 0; i < result.length; i++) {
      final r = result[i];
      try {
        if (r.id.startsWith('local-') || r.id.isEmpty) {
          final map = r.toMap()..remove('id');
          final ref = await _col.add(map);
          result[i] = PontajZiLucrare.fromMap({...r.toMap(), 'id': ref.id});
          await OfflineSyncRuntime.instance
              .queuePontajZiLucrareUpsert(result[i].toMap());
        } else {
          final map = r.toMap()..remove('id');
          await _col.doc(r.id).set(map, SetOptions(merge: true));
          await OfflineSyncRuntime.instance
              .queuePontajZiLucrareUpsert(r.toMap());
        }
        synced++;
      } catch (e) {
        debugPrint(
            '[PontajLucrari] ❌ forceSyncLocalToCloud error for ${r.id}: $e');
      }
    }

    // Deduplicare după ID
    final seen = <String>{};
    final deduplicated = result.where((r) => seen.add(r.id)).toList();
    await _saveLocal(deduplicated);
    return synced;
  }
}
