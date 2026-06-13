import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import '../../features/notifications/notification_runtime_service.dart';
import 'stoc_models.dart';

class StocRepository {
  StocRepository._();
  static final StocRepository instance = StocRepository._();

  static const String _itemsKey = 'stoc_items_v1';
  static const String _miscariKey = 'stoc_miscari_v1';
  static const int _maxMiscariLocale = 500;

  static String? lastFirestoreError;
  static int lastLocalCount = 0;

  final Uuid _uuid = const Uuid();
  bool get _isCloudAvailable => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _itemsCol =>
      FirebaseFirestore.instance.collection(FirebaseCollections.stocItems);
  CollectionReference<Map<String, dynamic>> get _miscariCol =>
      FirebaseFirestore.instance.collection(FirebaseCollections.stocMiscari);

  // ── Citire locală ────────────────────────────────────────────────────────────

  Future<List<StocItem>> listLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_itemsKey) ?? '[]';
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final items = decoded
          .map((e) => StocItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      lastLocalCount = items.length;
      return items;
    } catch (e) {
      debugPrint('[Stoc] ❌ listLocal: $e');
      return [];
    }
  }

  Future<List<StocMiscare>> listMiscariLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_miscariKey) ?? '[]';
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => StocMiscare.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── CRUD StocItem ────────────────────────────────────────────────────────────

  Future<void> upsertStocItem(StocItem item) async {
    // 1. Local
    await _writeItemLocal(item);
    // 2. Queue
    await OfflineSyncRuntime.instance.queueStocItemUpsert(item.toMap());
    // 3. Firebase fire-and-forget
    if (_isCloudAvailable) {
      _itemsCol
          .doc(item.id)
          .set(item.toMap(), SetOptions(merge: true))
          .catchError((e) {
        lastFirestoreError = e.toString();
      });
    }
  }

  Future<void> deleteStocItem(String id) async {
    await _deleteItemLocal(id);
    await OfflineSyncRuntime.instance.queueStocItemDelete(id);
    if (_isCloudAvailable) {
      _itemsCol.doc(id).delete().catchError((e) {
        lastFirestoreError = e.toString();
      });
    }
  }

  // ── Merge cloud + local ──────────────────────────────────────────────────────

  Future<List<StocItem>> listMerged() async {
    final locals = await listLocal();
    lastLocalCount = locals.length;
    if (!_isCloudAvailable) return _sortItems(locals);

    try {
      final snapshot = await _itemsCol.get();
      final cloudItems = snapshot.docs
          .map((d) => StocItem.fromMap({...d.data(), 'id': d.id}))
          .toList();
      final cloudIds = cloudItems.map((c) => c.id).toSet();
      final localOnly = locals.where((l) => !cloudIds.contains(l.id)).toList();
      for (final item in localOnly) {
        await OfflineSyncRuntime.instance.queueStocItemUpsert(item.toMap());
      }
      lastFirestoreError = null;
      return _sortItems([...cloudItems, ...localOnly]);
    } catch (e) {
      lastFirestoreError = e.toString();
      return _sortItems(locals);
    }
  }

  // ── Consum materiale ─────────────────────────────────────────────────────────

  Future<void> inregistreazaConsum({
    required String productId,
    required double cantitate,
    required String referintaId,
    required String referintaTip,
    required String referintaNume,
  }) async {
    if (cantitate <= 0) return;
    final items = await listLocal();
    final idx = items.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;
    final item = items[idx];
    final nouaCantitate = (item.cantitate - cantitate).clamp(0.0, double.infinity);
    final updated = item.copyWith(
      cantitate: nouaCantitate,
      ultimaActualizare: DateTime.now(),
    );
    await upsertStocItem(updated);
    final miscare = StocMiscare(
      id: _uuid.v4(),
      stocItemId: item.id,
      productId: productId,
      productName: item.productName,
      tip: 'consum',
      cantitate: -cantitate,
      cantitateInainte: item.cantitate,
      cantitateAfter: nouaCantitate,
      referintaId: referintaId,
      referintaTip: referintaTip,
      referintaNume: referintaNume,
      unitate: item.unitate,
      createdBy: FirebaseAuth.instance.currentUser?.uid ?? '',
      createdAt: DateTime.now(),
    );
    await _saveMiscareLocal(miscare);
    await OfflineSyncRuntime.instance.queueStocMiscareUpsert(miscare.toMap());
    if (_isCloudAvailable) {
      _miscariCol
          .doc(miscare.id)
          .set(miscare.toMap())
          .catchError((_) {});
    }
    // Alertă stoc minim
    if (nouaCantitate <= item.pragMinim && item.pragMinim > 0) {
      NotificationRuntimeService.instance.showAlertaStocMinim(
        produsNume: item.productName,
        cantitateRamasa: nouaCantitate,
        unitate: item.unitate,
        pragMinim: item.pragMinim,
      ).catchError((_) {});
    }
  }

  Future<void> inregistreazaAchizitie({
    required String productId,
    required double cantitate,
    double pretUnitar = 0,
    String furnizor = '',
  }) async {
    if (cantitate <= 0) return;
    final items = await listLocal();
    final idx = items.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;
    final item = items[idx];
    final nouaCantitate = item.cantitate + cantitate;
    final updated = item.copyWith(
      cantitate: nouaCantitate,
      ultimaActualizare: DateTime.now(),
      ultimaComanda: DateTime.now(),
      pretUnitarAchizitie: pretUnitar > 0 ? pretUnitar : item.pretUnitarAchizitie,
      furnizor: furnizor.isNotEmpty ? furnizor : item.furnizor,
    );
    await upsertStocItem(updated);
    final miscare = StocMiscare(
      id: _uuid.v4(),
      stocItemId: item.id,
      productId: productId,
      productName: item.productName,
      tip: 'achizitie',
      cantitate: cantitate,
      cantitateInainte: item.cantitate,
      cantitateAfter: nouaCantitate,
      unitate: item.unitate,
      createdBy: FirebaseAuth.instance.currentUser?.uid ?? '',
      createdAt: DateTime.now(),
    );
    await _saveMiscareLocal(miscare);
    await OfflineSyncRuntime.instance.queueStocMiscareUpsert(miscare.toMap());
    if (_isCloudAvailable) {
      _miscariCol
          .doc(miscare.id)
          .set(miscare.toMap())
          .catchError((_) {});
    }
  }

  Future<void> ajusteazaStoc({
    required String stocItemId,
    required double nouaCantitate,
    String motiv = '',
  }) async {
    final items = await listLocal();
    final idx = items.indexWhere((i) => i.id == stocItemId);
    if (idx < 0) return;
    final item = items[idx];
    final updated = item.copyWith(
      cantitate: nouaCantitate.clamp(0, double.infinity),
      ultimaActualizare: DateTime.now(),
    );
    await upsertStocItem(updated);
    final delta = nouaCantitate - item.cantitate;
    final miscare = StocMiscare(
      id: _uuid.v4(),
      stocItemId: item.id,
      productId: item.productId,
      productName: item.productName,
      tip: 'ajustare',
      cantitate: delta,
      cantitateInainte: item.cantitate,
      cantitateAfter: nouaCantitate,
      referintaNume: motiv,
      unitate: item.unitate,
      createdBy: FirebaseAuth.instance.currentUser?.uid ?? '',
      createdAt: DateTime.now(),
    );
    await _saveMiscareLocal(miscare);
    await OfflineSyncRuntime.instance.queueStocMiscareUpsert(miscare.toMap());
    if (_isCloudAvailable) {
      _miscariCol.doc(miscare.id).set(miscare.toMap()).catchError((_) {});
    }
  }

  // ── Filtre ───────────────────────────────────────────────────────────────────

  Future<List<StocItem>> listStocCritic() async {
    final all = await listLocal();
    return all.where((i) => i.esteStocCritic).toList();
  }

  Future<List<StocItem>> listNecesitaComanda() async {
    final all = await listLocal();
    return all.where((i) => i.necesitaComanda && !i.esteStocCritic).toList();
  }

  // ── Creare din catalog ───────────────────────────────────────────────────────

  Future<int> importaFromCatalog(List<Map<String, dynamic>> products) async {
    int count = 0;
    final existing = await listLocal();
    final existingProductIds = existing.map((e) => e.productId).toSet();
    for (final p in products) {
      final pid = (p['id'] ?? '').toString();
      if (pid.isEmpty || existingProductIds.contains(pid)) continue;
      final item = StocItem(
        id: _uuid.v4(),
        productId: pid,
        productName: (p['name'] ?? p['denumire'] ?? '').toString(),
        sku: (p['sku'] ?? p['code'] ?? '').toString(),
        categorie: (p['category'] ?? p['categorie'] ?? '').toString(),
        unitate: (p['unit'] ?? p['unitate'] ?? 'buc').toString(),
      );
      await upsertStocItem(item);
      count++;
    }
    return count;
  }

  // ── Sync forțat ──────────────────────────────────────────────────────────────

  Future<int> forceSyncLocalToCloud() async {
    if (!_isCloudAvailable) return 0;
    final items = await listLocal();
    int count = 0;
    for (final item in items) {
      try {
        await _itemsCol.doc(item.id).set(item.toMap(), SetOptions(merge: true));
        await OfflineSyncRuntime.instance.queueStocItemUpsert(item.toMap());
        count++;
      } catch (e) {
        debugPrint('[Stoc] ❌ forceSyncLocalToCloud: $e');
      }
    }
    return count;
  }

  // ── Persistență locală ───────────────────────────────────────────────────────

  Future<void> _writeItemLocal(StocItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await listLocal();
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      items[idx] = item;
    } else {
      items.add(item);
    }
    await prefs.setString(
        _itemsKey, jsonEncode(items.map((i) => i.toMap()).toList()));
  }

  Future<void> _deleteItemLocal(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await listLocal();
    items.removeWhere((i) => i.id == id);
    await prefs.setString(
        _itemsKey, jsonEncode(items.map((i) => i.toMap()).toList()));
  }

  Future<void> _saveMiscareLocal(StocMiscare miscare) async {
    final prefs = await SharedPreferences.getInstance();
    final miscari = await listMiscariLocal();
    miscari.insert(0, miscare);
    final trimmed = miscari.length > _maxMiscariLocale
        ? miscari.sublist(0, _maxMiscariLocale)
        : miscari;
    await prefs.setString(
        _miscariKey, jsonEncode(trimmed.map((m) => m.toMap()).toList()));
  }

  List<StocItem> _sortItems(List<StocItem> items) {
    return items
      ..sort((a, b) {
        // Critice primele, apoi în ordine alfabetică
        if (a.esteStocCritic && !b.esteStocCritic) return -1;
        if (!a.esteStocCritic && b.esteStocCritic) return 1;
        return a.productName.compareTo(b.productName);
      });
  }
}
