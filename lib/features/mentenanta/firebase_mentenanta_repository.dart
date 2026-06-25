import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import 'local_mentenanta_repository.dart';
import 'mentenanta_models.dart';
import 'mentenanta_repository.dart';

/// Implementare Firestore a [MentenantaRepository], offline-first.
///
/// Strategie (conform pattern-ului din proiect):
///  1. Scriere locală (funcționează și offline) — sursa de adevăr pentru UI.
///  2. Firebase direct best-effort (fire-and-forget — nu blochează UI).
///  3. La citire: merge cloud + local-only, fallback complet pe local la eroare.
class FirebaseMentenantaRepository implements MentenantaRepository {
  FirebaseMentenantaRepository({
    FirebaseFirestore? firestore,
    LocalMentenantaRepository? local,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _local = local ?? LocalMentenantaRepository.instance;

  final FirebaseFirestore _firestore;
  final LocalMentenantaRepository _local;

  bool get _isCloudAvailable => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirebaseCollections.mentenantaContracte);

  // ── Diagnostics (vizibile în UI pentru depanare cross-device) ────────────────
  static String? lastFirestoreError;
  static int lastFirestoreCount = -1;
  static int lastLocalCount = 0;

  // ── List (cloud + local merge) ───────────────────────────────────────────────

  @override
  Future<List<ContractMentenanta>> listContracte() async {
    final localItems = await _local.listContracte();
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
          .map((d) => ContractMentenanta.fromMap({...d.data(), 'id': d.id}))
          .toList();
      lastFirestoreCount = cloudItems.length;

      // Merge: cloud + local-only (create offline, încă nesincronizate).
      final cloudIds = cloudItems.map((c) => c.id).toSet();
      final localOnly =
          localItems.where((c) => !cloudIds.contains(c.id)).toList();

      // Re-publică local-only în cloud (best-effort), ca să nu se piardă.
      for (final c in localOnly) {
        _col.doc(c.id).set(c.toMap(), SetOptions(merge: true)).catchError((_) {});
      }

      final merged = [...cloudItems, ...localOnly];
      // Actualizează cache-ul local cu starea consolidată.
      await _local.replaceCache(merged);
      merged.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return merged;
    } catch (e) {
      lastFirestoreCount = -1;
      lastFirestoreError = e.toString();
      debugPrint('[MentenantaCloud] ❌ Eroare Firestore listContracte(): $e');
      return localItems; // fallback complet pe local
    }
  }

  // ── Save (upsert) ─────────────────────────────────────────────────────────────

  @override
  Future<ContractMentenanta> saveContract(ContractMentenanta contract) async {
    // Asigură un ID stabil pentru documentele noi (doc ID = id model).
    final toSave = contract.id.trim().isEmpty
        ? contract.copyWith(id: const Uuid().v4())
        : contract;

    // 1. Scriere locală (offline-first).
    await _local.saveContract(toSave);

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
  Future<void> deleteContract(String id) async {
    // 1. Ștergere locală.
    await _local.deleteContract(id);

    // 2. Firebase direct (best-effort, fire-and-forget).
    if (_isCloudAvailable) {
      _col.doc(id).delete().catchError((_) {});
    }
  }

  // ── Watch ────────────────────────────────────────────────────────────────────

  @override
  Stream<List<ContractMentenanta>> watchContracte() {
    if (!_isCloudAvailable) {
      return _local.watchContracte();
    }
    return _col.snapshots().map((snap) {
      final items = snap.docs
          .map((d) => ContractMentenanta.fromMap({...d.data(), 'id': d.id}))
          .toList();
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items;
    });
  }

  // ── Numerotare automată CM-YYYY-NNNN ─────────────────────────────────────────

  Future<String> nextNumber() async {
    final year = DateTime.now().year;
    final prefix = 'CM-$year-';
    final nums = <int>[];

    // Local (funcționează offline).
    final localItems = await _local.listContracte();
    nums.addAll(localItems
        .where((c) => c.numar.startsWith(prefix))
        .map((c) => _seqOf(c.numar)));

    // Cloud (best-effort).
    if (_isCloudAvailable) {
      try {
        final snap = await _col
            .where('numar', isGreaterThanOrEqualTo: prefix)
            .where('numar', isLessThan: 'CM-${year + 1}-')
            .get();
        nums.addAll(snap.docs.map((d) => _seqOf((d.data()['numar'] ?? '').toString())));
      } catch (e) {
        debugPrint('[MentenantaCloud] citire numere cloud eșuată, folosesc local: $e');
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
