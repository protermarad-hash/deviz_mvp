import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/cloud/firebase_bootstrap.dart';
import '../../../core/cloud/firebase_collections.dart';
import 'local_serviciu_prestat_repository.dart';
import 'serviciu_prestat_models.dart';
import 'serviciu_prestat_repository.dart';

/// Implementare Firestore a [ServiciuPrestatRepository], offline-first.
///
/// Strategie (conform pattern-ului din [FirebaseMentenantaRepository]):
///  1. Scriere locală (funcționează și offline) — sursa de adevăr pentru UI.
///  2. Firebase direct best-effort (fire-and-forget — nu blochează UI).
///  3. La citire: merge cloud + local-only, fallback complet pe local la eroare.
class FirebaseServiciuPrestatRepository implements ServiciuPrestatRepository {
  FirebaseServiciuPrestatRepository({
    FirebaseFirestore? firestore,
    LocalServiciuPrestatRepository? local,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _local = local ?? LocalServiciuPrestatRepository.instance;

  final FirebaseFirestore _firestore;
  final LocalServiciuPrestatRepository _local;

  bool get _isCloudAvailable => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirebaseCollections.serviciiPrestate);

  // ── Diagnostics (vizibile în UI pentru depanare cross-device) ────────────────
  static String? lastFirestoreError;
  static int lastFirestoreCount = -1;
  static int lastLocalCount = 0;

  @override
  Future<List<ServiciuPrestat>> listServicii() async {
    final localItems = await _local.listServicii();
    lastLocalCount = localItems.length;

    if (!_isCloudAvailable) {
      return localItems;
    }

    lastFirestoreCount = -1;
    lastFirestoreError = null;

    try {
      // NU folosim .orderBy() — sortare în Dart (evită index compus Firestore).
      final snap = await _col.get();
      final cloudItems = snap.docs
          .map((d) => ServiciuPrestat.fromMap({...d.data(), 'id': d.id}))
          .toList();
      lastFirestoreCount = cloudItems.length;

      // Merge: cloud + local-only (create offline, încă nesincronizate).
      final cloudIds = cloudItems.map((c) => c.id).toSet();
      final localOnly =
          localItems.where((c) => !cloudIds.contains(c.id)).toList();

      // Re-publică local-only în cloud (best-effort), ca să nu se piardă.
      for (final s in localOnly) {
        _col.doc(s.id).set(s.toMap(), SetOptions(merge: true)).catchError((_) {});
      }

      final merged = [...cloudItems, ...localOnly];
      await _local.replaceCache(merged);
      merged.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return merged;
    } catch (e) {
      lastFirestoreCount = -1;
      lastFirestoreError = e.toString();
      debugPrint('[ServiciiCloud] ❌ Eroare Firestore listServicii(): $e');
      return localItems; // fallback complet pe local
    }
  }

  @override
  Future<ServiciuPrestat> saveServiciu(ServiciuPrestat s) async {
    // 1. Scriere locală (offline-first).
    await _local.saveServiciu(s);

    // 2. Firebase direct (best-effort, fire-and-forget — nu blochează UI).
    if (_isCloudAvailable) {
      _col.doc(s.id).set(s.toMap(), SetOptions(merge: true)).catchError((_) {});
    }
    return s;
  }

  @override
  Future<void> deleteServiciu(String id) async {
    // 1. Ștergere locală.
    await _local.deleteServiciu(id);

    // 2. Firebase direct (best-effort, fire-and-forget).
    if (_isCloudAvailable) {
      _col.doc(id).delete().catchError((_) {});
    }
  }
}
