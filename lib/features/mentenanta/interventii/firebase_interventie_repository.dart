import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/cloud/firebase_bootstrap.dart';
import '../../../core/cloud/firebase_collections.dart';
import 'interventie_models.dart';
import 'interventie_repository.dart';
import 'local_interventie_repository.dart';

/// Implementare Firestore a [InterventieRepository], offline-first.
///
/// Strategie (pattern din proiect, identic cu [FirebaseMentenantaRepository]):
///  1. Scriere locală (funcționează și offline) — sursa de adevăr pentru UI.
///  2. Firebase direct best-effort (fire-and-forget — nu blochează UI).
///  3. La citire: merge cloud + local-only, fallback complet pe local la eroare.
class FirebaseInterventieRepository implements InterventieRepository {
  FirebaseInterventieRepository({
    FirebaseFirestore? firestore,
    LocalInterventieRepository? local,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _local = local ?? LocalInterventieRepository.instance;

  final FirebaseFirestore _firestore;
  final LocalInterventieRepository _local;

  bool get _isCloudAvailable => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirebaseCollections.mentenantaInterventii);

  // ── Diagnostics ──────────────────────────────────────────────────────────────
  static String? lastFirestoreError;
  static int lastFirestoreCount = -1;
  static int lastLocalCount = 0;

  // ── List (cloud + local merge) ───────────────────────────────────────────────

  @override
  Future<List<InterventieService>> listInterventii(String contractId) async {
    final localItems = await _local.listInterventii(contractId);
    lastLocalCount = localItems.length;

    if (!_isCloudAvailable) {
      return localItems;
    }

    lastFirestoreCount = -1;
    lastFirestoreError = null;

    try {
      // .where() simplu pe contract_id — fără .orderBy() (sortare în Dart).
      final snap =
          await _col.where('contract_id', isEqualTo: contractId).get();
      final cloudItems = snap.docs
          .map((d) => InterventieService.fromMap({...d.data(), 'id': d.id}))
          .toList();
      lastFirestoreCount = cloudItems.length;

      // Merge: cloud + local-only (create offline, încă nesincronizate).
      final cloudIds = cloudItems.map((c) => c.id).toSet();
      final localOnly =
          localItems.where((i) => !cloudIds.contains(i.id)).toList();

      // Re-publică local-only în cloud (best-effort), ca să nu se piardă.
      for (final i in localOnly) {
        _col.doc(i.id).set(i.toMap(), SetOptions(merge: true)).catchError((_) {});
      }

      final merged = [...cloudItems, ...localOnly];
      await _local.upsertMany(merged); // actualizează cache-ul consolidat
      merged.sort((a, b) => b.dataInterventie.compareTo(a.dataInterventie));
      return merged;
    } catch (e) {
      lastFirestoreCount = -1;
      lastFirestoreError = e.toString();
      debugPrint('[InterventieCloud] ❌ Eroare Firestore listInterventii(): $e');
      return localItems; // fallback complet pe local
    }
  }

  // ── Save (upsert) ─────────────────────────────────────────────────────────────

  @override
  Future<InterventieService> saveInterventie(
      InterventieService interventie) async {
    final toSave = interventie.id.trim().isEmpty
        ? interventie.copyWith(id: const Uuid().v4())
        : interventie;

    // 1. Scriere locală (offline-first).
    await _local.saveInterventie(toSave);

    // 2. Firebase direct (best-effort, fire-and-forget — nu blochează UI).
    if (_isCloudAvailable) {
      _col
          .doc(toSave.id)
          .set(toSave.toMap(), SetOptions(merge: true))
          .catchError((_) {});
    }

    return toSave;
  }

  // ── Delete ─────────────────────────────────────────────────────────────────────

  @override
  Future<void> deleteInterventie(String id) async {
    await _local.deleteInterventie(id);
    if (_isCloudAvailable) {
      _col.doc(id).delete().catchError((_) {});
    }
  }

  // ── Numerotare automată IS-YYYY-NNNN ─────────────────────────────────────────

  Future<String> nextNumber(int year) async {
    final prefix = 'IS-$year-';
    final nums = <int>[];

    // Local (toate intervențiile, funcționează offline).
    final localItems = await _local.listAll();
    nums.addAll(localItems
        .where((i) => i.numar.startsWith(prefix))
        .map((i) => _seqOf(i.numar)));

    // Cloud (best-effort).
    if (_isCloudAvailable) {
      try {
        final snap = await _col
            .where('numar', isGreaterThanOrEqualTo: prefix)
            .where('numar', isLessThan: 'IS-${year + 1}-')
            .get();
        nums.addAll(snap.docs
            .map((d) => _seqOf((d.data()['numar'] ?? '').toString())));
      } catch (e) {
        debugPrint('[InterventieCloud] citire numere cloud eșuată, '
            'folosesc local: $e');
      }
    }

    final maxNum = nums.isEmpty ? 0 : nums.reduce((a, b) => a > b ? a : b);
    return '$prefix${(maxNum + 1).toString().padLeft(4, '0')}';
  }

  static int _seqOf(String numar) {
    final parts = numar.split('-');
    return parts.length >= 3 ? int.tryParse(parts.last) ?? 0 : 0;
  }
}
