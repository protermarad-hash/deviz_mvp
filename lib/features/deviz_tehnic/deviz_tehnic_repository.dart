import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'deviz_tehnic_models.dart';

/// Repository pentru devize tehnice — Firebase + cache local + offline queue.
///
/// Pattern obligatoriu (CLAUDE.md):
/// 1. Scriere locală (funcționează offline)
/// 2. Queue OBLIGATORIU (sincronizare automată la revenirea internetului)
/// 3. Firebase direct (best-effort)
class DevizTehnicRepository {
  static const _prefKey = 'devize_tehnice_cache';

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(FirebaseCollections.devizeTehnice);

  bool get _isCloudAvailable => FirebaseBootstrap.isInitialized;

  // ── Diagnostics (vizibile în UI pentru depanare cross-device) ────────────────
  /// Eroarea din ultima interogare Firestore (null = OK, '' = nu s-a interogat)
  static String? lastFirestoreError;
  /// Câte documente a returnat Firestore la ultima interogare (-1 = eroare/neterminat)
  static int lastFirestoreCount = -1;
  /// Câte documente sunt în cache-ul local
  static int lastLocalCount = 0;

  // ── Local cache ─────────────────────────────────────────────────────────────

  Future<List<DevizTehnicRecord>> listLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) =>
              DevizTehnicRecord.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocal(List<DevizTehnicRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final data = records.map((r) => r.toMap()).toList();
    await prefs.setString(_prefKey, jsonEncode(data));
  }

  Future<void> _updateLocalCache(DevizTehnicRecord record) async {
    final locals = await listLocal();
    final idx = locals.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      locals[idx] = record;
    } else {
      locals.insert(0, record);
    }
    await _saveLocal(locals);
  }

  // ── List (cloud + local merge) ───────────────────────────────────────────────

  Future<List<DevizTehnicRecord>> list() async {
    final localItems = await listLocal();

    if (!_isCloudAvailable) {
      return _sorted(localItems);
    }

    lastLocalCount = localItems.length;
    lastFirestoreCount = -1;
    lastFirestoreError = null;

    debugPrint('[DevizTehnic] list(): isInit=${FirebaseBootstrap.isInitialized} '
        'isOnline=${FirebaseBootstrap.isOnline} '
        'localCache=${localItems.length} docs');

    try {
      // NU folosim .orderBy() — sortare în Dart (evită index compus Firestore)
      final snap = await _col.get();
      final cloudItems = snap.docs
          .map((d) => DevizTehnicRecord.fromMap({...d.data(), 'id': d.id}))
          .toList();

      lastFirestoreCount = cloudItems.length;
      lastFirestoreError = null;
      debugPrint('[DevizTehnic] Firestore returned ${cloudItems.length} docs');

      // Merge cloud + local-only (create offline, nesincronizate încă)
      final cloudIds = cloudItems.map((r) => r.id).toSet();
      // Numerele din cloud — pentru deduplicare (cazul local- promovat la ID real)
      final cloudNumere =
          cloudItems.map((r) => r.numar).where((n) => n.isNotEmpty).toSet();

      final localOnly = localItems.where((r) {
        if (cloudIds.contains(r.id)) return false;
        // Dacă un item local- are același numar cu un cloud item → deja sincronizat
        if (r.id.startsWith('local-') &&
            r.numar.isNotEmpty &&
            cloudNumere.contains(r.numar)) {
          return false;
        }
        return true;
      }).toList();

      // Queue local-only ca să ajungă în cloud
      for (final r in localOnly) {
        await OfflineSyncRuntime.instance.queueDevizTehnicUpsert(r.toMap());
      }

      final merged = [...cloudItems, ...localOnly];
      await _saveLocal(merged);
      return _sorted(merged);
    } catch (e, stack) {
      lastFirestoreCount = -1;
      lastFirestoreError = e.toString();
      debugPrint('[DevizTehnic] ❌ Eroare Firestore list(): $e');
      debugPrint('[DevizTehnic] Stack: $stack');
      return _sorted(localItems);
    }
  }

  List<DevizTehnicRecord> _sorted(List<DevizTehnicRecord> items) {
    final copy = [...items];
    copy.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return copy;
  }

  // ── Save (upsert) ────────────────────────────────────────────────────────────

  Future<DevizTehnicRecord> save(DevizTehnicRecord record) async {
    DevizTehnicRecord toSave;

    if (record.id.isEmpty || record.id.startsWith('local-')) {
      // Document nou — generăm ID în Firestore dacă online, altfel UUID local
      if (_isCloudAvailable) {
        try {
          final map = record.toMap()..remove('id');
          final ref = await _col.add(map);
          toSave = DevizTehnicRecord.fromMap({
            ...record.toMap(),
            'id': ref.id,
          });
        } catch (e) {
          debugPrint('[DevizTehnic] ❌ Eroare add la Firestore: $e');
          // Fallback: ID local temporar
          toSave = DevizTehnicRecord.fromMap({
            ...record.toMap(),
            'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
          });
        }
      } else {
        toSave = DevizTehnicRecord.fromMap({
          ...record.toMap(),
          'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
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
    await OfflineSyncRuntime.instance.queueDevizTehnicUpsert(toSave.toMap());

    // 3. Firebase direct (best-effort, fire-and-forget — nu blochează UI)
    if (_isCloudAvailable && !toSave.id.startsWith('local-')) {
      final map = toSave.toMap()..remove('id');
      _col.doc(toSave.id).set(map, SetOptions(merge: true)).catchError((_) {});
    }

    return toSave;
  }

  // ── Delete ───────────────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    // 1. Ștergere locală
    final locals = await listLocal();
    await _saveLocal(locals.where((r) => r.id != id).toList());

    // 2. Queue delete OBLIGATORIU
    await OfflineSyncRuntime.instance.queueDevizTehnicDelete(id);

    // 3. Firebase direct (best-effort, fire-and-forget — nu blochează UI)
    if (_isCloudAvailable && !id.startsWith('local-')) {
      _col.doc(id).delete().catchError((_) {});
    }
  }

  // ── Sync forțat: publică toate documentele locale în Firestore ───────────────

  /// Re-scrie direct în Firestore toate documentele din cache-ul local.
  /// Folosit pentru diagnosticare și recuperare după eșecuri de sync.
  Future<int> forceSyncLocalToCloud() async {
    if (!_isCloudAvailable) return 0;
    final locals = await listLocal();
    if (locals.isEmpty) return 0;

    // Lucrăm pe o copie mutabilă — înlocuim local- IDs cu cele reale in-place
    final result = List<DevizTehnicRecord>.from(locals);
    int synced = 0;

    for (int i = 0; i < result.length; i++) {
      final r = result[i];
      try {
        // Documente cu ID local (nesincronizate) — le adăugăm în Firestore
        if (r.id.startsWith('local-') || r.id.isEmpty) {
          final map = r.toMap()..remove('id');
          final ref = await _col.add(map);
          // Înlocuiește in-place — elimină local- ID, adaugă ID real
          result[i] = DevizTehnicRecord.fromMap({...r.toMap(), 'id': ref.id});
          await OfflineSyncRuntime.instance
              .queueDevizTehnicUpsert(result[i].toMap());
        } else {
          // Documente cu ID valid — le scriem direct
          final map = r.toMap()..remove('id');
          await _col.doc(r.id).set(map, SetOptions(merge: true));
          await OfflineSyncRuntime.instance.queueDevizTehnicUpsert(r.toMap());
        }
        synced++;
      } catch (e) {
        debugPrint('[DevizTehnic] ❌ forceSyncLocalToCloud error for ${r.id}: $e');
      }
    }

    // Salvează lista actualizată (ID-uri reale în locul celor local-)
    // Deduplicare după ID — elimină eventualele duplicate din sync-uri anterioare
    final seen = <String>{};
    final deduplicated = result.where((r) => seen.add(r.id)).toList();
    await _saveLocal(deduplicated);
    return synced;
  }

  // ── Numerotare automată per tip document ─────────────────────────────────────
  //
  // Prefixe:
  //   devizTehnic     → DVZ-YYYY-NNNN
  //   ofertaLucrari   → OFR-YYYY-NNNN
  //   situatieLucrari → STL-YYYY-NNNN

  Future<String> nextNumber(DevizTehnicTipDocument tip) async {
    final year = DateTime.now().year;
    final prefix = _prefixFor(tip);
    final prefixYear = '$prefix-$year-';
    final prefixYearNext = '$prefix-${year + 1}-';

    try {
      // Căutăm în cache local mai întâi (funcționează și offline)
      final localItems = await listLocal();
      final localNums = localItems
          .where((r) =>
              r.tipDocument == tip &&
              r.numar.startsWith(prefixYear))
          .map((r) {
            final parts = r.numar.split('-');
            return parts.length >= 3 ? int.tryParse(parts.last) ?? 0 : 0;
          })
          .toList();

      // Dacă suntem online, completăm cu datele din Firestore
      if (_isCloudAvailable) {
        try {
          final snap = await _col
              .where('numar', isGreaterThanOrEqualTo: prefixYear)
              .where('numar', isLessThan: prefixYearNext)
              .get();
          final cloudNums = snap.docs.map((d) {
            final n = (d.data()['numar'] ?? '').toString();
            final parts = n.split('-');
            return parts.length >= 3 ? int.tryParse(parts.last) ?? 0 : 0;
          }).toList();
          localNums.addAll(cloudNums);
        } catch (e) {
          debugPrint('[DevizTehnicRepo] citire numere cloud eșuată, folosesc local: $e');
        }
      }

      final maxNum =
          localNums.isEmpty ? 0 : localNums.reduce((a, b) => a > b ? a : b);
      final next = (maxNum + 1).toString().padLeft(4, '0');
      return '$prefixYear$next';
    } catch (_) {
      return '${prefixYear}0001';
    }
  }

  static String _prefixFor(DevizTehnicTipDocument tip) {
    switch (tip) {
      case DevizTehnicTipDocument.ofertaLucrari:
        return 'OFR';
      case DevizTehnicTipDocument.situatieLucrari:
        return 'STL';
      case DevizTehnicTipDocument.devizTehnic:
        return 'DVZ';
    }
  }

  // ── Setare tip document implicit (cross-device) ──────────────────────────────

  static const _prefKeyDefaultTip = 'deviz_tehnic_default_tip';
  static const _firestoreSettingsDoc = 'deviz_tehnic_settings';
  static const _firestoreSettingsColl = 'app_settings';

  /// Salvează tipul implicit local (SharedPreferences) + Firestore (cross-device).
  Future<void> saveDefaultTipDocument(DevizTehnicTipDocument tip) async {
    // Local
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyDefaultTip, tip.value);

    // Firestore (best-effort, cross-device)
    if (_isCloudAvailable) {
      try {
        await FirebaseFirestore.instance
            .collection(_firestoreSettingsColl)
            .doc(_firestoreSettingsDoc)
            .set({'default_tip_document': tip.value}, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[DevizTehnicRepo] salvare tip implicit cloud best-effort eșuată (local persistă): $e');
      }
    }
  }

  /// Citește tipul implicit: Firestore (cross-device) > local > devizTehnic.
  Future<DevizTehnicTipDocument> loadDefaultTipDocument() async {
    // Încearcă Firestore mai întâi (cross-device)
    if (_isCloudAvailable) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(_firestoreSettingsColl)
            .doc(_firestoreSettingsDoc)
            .get();
        if (doc.exists) {
          final raw = doc.data()?['default_tip_document']?.toString();
          final tip = DevizTehnicTipDocument.fromValue(raw);
          // Sincronizează și local
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKeyDefaultTip, tip.value);
          return tip;
        }
      } catch (e) {
        debugPrint('[DevizTehnicRepo] citire tip implicit cloud eșuată, folosesc local: $e');
      }
    }

    // Fallback: local
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKeyDefaultTip);
      return DevizTehnicTipDocument.fromValue(raw);
    } catch (_) {
      return DevizTehnicTipDocument.devizTehnic;
    }
  }
}
