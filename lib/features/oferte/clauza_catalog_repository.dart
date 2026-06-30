import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import 'offer_acceptance_models.dart';

/// Catalog persistent de clauze CUSTOM (adăugate manual de utilizator),
/// reutilizabile la toate ofertele viitoare. NU conține cele 6 clauze default
/// (acelea se generează mereu din [OfferAcceptanceClause.defaults]).
///
/// Offline-first (pattern identic cu [FirebaseMentenantaRepository]):
///  1. Scriere locală (SharedPreferences) — sursa de adevăr pentru UI.
///  2. Firebase direct best-effort (fire-and-forget — nu blochează UI).
///  3. La citire: merge cloud + local-only, fallback complet pe local la eroare.
class ClauzaCatalogRepository {
  ClauzaCatalogRepository._();

  static final ClauzaCatalogRepository instance = ClauzaCatalogRepository._();

  static const String _prefKey = 'clauze_custom_catalog_v1';

  bool get _isCloudAvailable => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(FirebaseCollections.clauzeCustomCatalog);

  // ── Citire / scriere brută locală ───────────────────────────────────────────

  Future<List<OfferAcceptanceClause>> _readLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) =>
              OfferAcceptanceClause.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('[ClauzeCatalog] ❌ Eroare citire cache: $e');
      return [];
    }
  }

  Future<void> _writeLocal(List<OfferAcceptanceClause> items) async {
    final prefs = await SharedPreferences.getInstance();
    final data = items.map((c) => c.toMap()).toList();
    await prefs.setString(_prefKey, jsonEncode(data));
  }

  List<OfferAcceptanceClause> _sorted(List<OfferAcceptanceClause> items) {
    final copy = [...items];
    copy.sort((a, b) =>
        a.title.toLowerCase().trim().compareTo(b.title.toLowerCase().trim()));
    return copy;
  }

  // ── API public ────────────────────────────────────────────────────────────────

  /// Listă clauze custom (merge cloud + local-only, fallback pe local la eroare).
  Future<List<OfferAcceptanceClause>> listClauzeCustom() async {
    final localItems = await _readLocal();
    if (!_isCloudAvailable) return _sorted(localItems);

    try {
      // NU folosim .orderBy() — sortare în Dart (evită index compus Firestore).
      final snap = await _col.get();
      final cloudItems = snap.docs
          .map((d) => OfferAcceptanceClause.fromMap({...d.data(), 'id': d.id}))
          .toList();

      final cloudIds = cloudItems.map((c) => c.id).toSet();
      final localOnly =
          localItems.where((c) => !cloudIds.contains(c.id)).toList();

      // Re-publică local-only în cloud (best-effort).
      for (final c in localOnly) {
        _col.doc(c.id).set(c.toMap(), SetOptions(merge: true)).catchError((_) {});
      }

      final merged = [...cloudItems, ...localOnly];
      await _writeLocal(merged);
      return _sorted(merged);
    } catch (e) {
      debugPrint('[ClauzeCatalog] ❌ Eroare Firestore listClauzeCustom(): $e');
      return _sorted(localItems); // fallback complet pe local
    }
  }

  /// Upsert după titlu (case-insensitive): dacă există deja o clauză cu același
  /// titlu, o actualizează (păstrează id-ul existent) — NU duplică.
  Future<void> saveClauzaCustom(OfferAcceptanceClause c) async {
    final title = c.title.trim();
    if (title.isEmpty) return;

    final items = await _readLocal();
    final idx = items.indexWhere(
      (e) => e.title.toLowerCase().trim() == title.toLowerCase(),
    );

    OfferAcceptanceClause toSave;
    if (idx >= 0) {
      // Actualizează conținutul, păstrează id-ul existent.
      toSave = items[idx].copyWith(title: title, content: c.content);
      items[idx] = toSave;
    } else {
      toSave = c.copyWith(title: title);
      items.add(toSave);
    }

    await _writeLocal(items);

    // Firebase best-effort, fire-and-forget.
    if (_isCloudAvailable) {
      _col
          .doc(toSave.id)
          .set(toSave.toMap(), SetOptions(merge: true))
          .catchError((_) {});
    }
  }

  /// Șterge o clauză custom din catalog.
  Future<void> deleteClauzaCustom(String id) async {
    final items = await _readLocal();
    items.removeWhere((e) => e.id == id);
    await _writeLocal(items);

    if (_isCloudAvailable) {
      _col.doc(id).delete().catchError((_) {});
    }
  }
}
