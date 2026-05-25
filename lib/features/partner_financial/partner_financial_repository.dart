import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'partner_financial_models.dart';

class PartnerFinancialRepository {
  static const String _transactionsLocalKey = 'partner_transactions_v1';
  static const String _summariesLocalKey = 'partner_financial_summaries_v1';

  // ── Statics diagnostice (CLAUDE.md CHECKLIST) ─────────────────────────────
  static String? lastFirestoreError;
  static int lastFirestoreCount = -1;
  static int lastLocalCount = 0;

  bool get _isCloudAvailable => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _transactionsCollection =>
      FirebaseFirestore.instance
          .collection(FirebaseCollections.partnerTransactions);

  CollectionReference<Map<String, dynamic>> get _summariesCollection =>
      FirebaseFirestore.instance
          .collection(FirebaseCollections.partnerFinancialSummary);

  // ---------------------------------------------------------------------------
  // TRANZACȚII
  // ---------------------------------------------------------------------------

  Future<List<PartnerTransaction>> listTransactionsForPartner(
    String partnerId,
  ) async {
    final local = await _readLocalTransactions();
    final filtered =
        local.where((t) => t.partnerId == partnerId).toList(growable: false);
    lastLocalCount = filtered.length;
    if (!_isCloudAvailable) return _sortTransactions(filtered);

    try {
      // FĂRĂ .orderBy() — evită necesitatea unui index compus Firestore
      // (where + orderBy necesită index explicit; sortăm în Dart oricum).
      final snapshot = await _transactionsCollection
          .where('partner_id', isEqualTo: partnerId)
          .get();
      final cloud = snapshot.docs
          .map((doc) => PartnerTransaction.fromMap(doc.data()))
          .toList(growable: false);
      lastFirestoreCount = cloud.length;
      lastFirestoreError = null;
      // Merge: cloud + local-only (create offline, neajunse în Firestore)
      final knownIds = cloud.map((t) => t.id).toSet();
      final localOnly = filtered
          .where((t) => !knownIds.contains(t.id))
          .toList(growable: false);
      // Queue local-only pentru sync
      for (final txn in localOnly) {
        await OfflineSyncRuntime.instance
            .queuePartnerTransactionUpsert(txn.toMap());
      }
      await _writeLocalTransactions([
        ...local.where((t) => t.partnerId != partnerId),
        ...cloud,
        ...localOnly,
      ]);
      // Returnăm cloud + local-only (nu doar cloud ca înainte)
      return _sortTransactions([...cloud, ...localOnly]);
    } catch (e) {
      lastFirestoreError = e.toString();
      lastFirestoreCount = -1;
      return _sortTransactions(filtered);
    }
  }

  Future<List<PartnerTransaction>> listAllTransactions() async {
    final local = await _readLocalTransactions();
    if (!_isCloudAvailable) return _sortTransactions(local);

    try {
      // Fără limită — descarcă TOATE tranzacțiile pentru istoricul complet
      // (10 ani de date trebuie să fie disponibile, indiferent de numărul de tranzacții).
      // Dacă cache-ul local e gol (instalare nouă), ia tot din Firestore.
      // Dacă există cache local, combină: cloud + locale-only (create offline).
      // Fără .orderBy() — evită indexul compus Firestore; sortăm în Dart
      final snapshot = await _transactionsCollection.get();
      final cloud = snapshot.docs
          .map((doc) => PartnerTransaction.fromMap(doc.data()))
          .toList(growable: false);
      final all = [...cloud];
      final knownIds = cloud.map((t) => t.id).toSet();
      for (final local in local) {
        if (!knownIds.contains(local.id)) all.add(local);
      }
      await _writeLocalTransactions(all);
      return _sortTransactions(all);
    } catch (_) {
      return _sortTransactions(local);
    }
  }

  Future<void> upsertTransaction(PartnerTransaction transaction) async {
    final items = [...await _readLocalTransactions()];
    final index = items.indexWhere((t) => t.id == transaction.id);
    if (index >= 0) {
      items[index] = transaction;
    } else {
      items.add(transaction);
    }
    await _writeLocalTransactions(items);

    // Queue pentru sync offline — garantează că ajunge în Firebase
    await OfflineSyncRuntime.instance
        .queuePartnerTransactionUpsert(transaction.toMap());

    // Firebase direct — fire-and-forget (BUG 8: nu await → nu blochează UI)
    if (_isCloudAvailable) {
      _transactionsCollection
          .doc(transaction.id)
          .set(transaction.toMap(), SetOptions(merge: true))
          .catchError((_) {});
    }

    await _rebuildSummary(transaction.partnerId, transaction.partnerName);
  }

  /// Upsert în lot — O(1) citire + scriere indiferent de numărul tranzacțiilor.
  /// FOLOSIȚI ASTA în loc de upsertTransaction() apelat în buclă.
  /// Evită O(n²) de citiri/scrieri SharedPreferences.
  Future<void> upsertTransactionsBatch(
    List<PartnerTransaction> newOrUpdated,
  ) async {
    if (newOrUpdated.isEmpty) return;

    // Citire o singură dată
    final existing = [...await _readLocalTransactions()];
    final existingById = <String, int>{};
    for (var i = 0; i < existing.length; i++) {
      existingById[existing[i].id] = i;
    }

    // Aplică toate modificările în memorie
    for (final t in newOrUpdated) {
      final idx = existingById[t.id];
      if (idx != null) {
        existing[idx] = t;
      } else {
        existing.add(t);
        existingById[t.id] = existing.length - 1;
      }
    }

    // Scriere o singură dată
    await _writeLocalTransactions(existing);

    // Queue toate în paralel
    await Future.wait(
      newOrUpdated.map(
        (t) => OfflineSyncRuntime.instance.queuePartnerTransactionUpsert(
          t.toMap(),
        ),
      ),
    );

    // Firebase în paralel — fire-and-forget (BUG 8)
    if (_isCloudAvailable) {
      for (final t in newOrUpdated) {
        _transactionsCollection
            .doc(t.id)
            .set(t.toMap(), SetOptions(merge: true))
            .catchError((_) {});
      }
    }

    // Reconstruiește sumarele pentru toți partenerii afectați (fără duplicate)
    final affectedPartners = <String, String>{};
    for (final t in newOrUpdated) {
      affectedPartners[t.partnerId] = t.partnerName;
    }
    for (final entry in affectedPartners.entries) {
      await _rebuildSummary(entry.key, entry.value);
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    final items = [...await _readLocalTransactions()];
    final existing = items.firstWhere(
      (t) => t.id == transactionId,
      orElse: () => PartnerTransaction(
        id: '',
        partnerId: '',
        partnerName: '',
        type: PartnerTransactionType.incasareManuala,
        direction: PartnerTransactionDirection.intrare,
        amount: 0,
        date: DateTime.now(),
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    items.removeWhere((t) => t.id == transactionId);
    await _writeLocalTransactions(items);

    // Queue pentru ștergere offline — garantează că se șterge și din Firebase
    await OfflineSyncRuntime.instance
        .queuePartnerTransactionDelete(transactionId);

    // Firebase direct — fire-and-forget (BUG 8)
    if (_isCloudAvailable) {
      _transactionsCollection
          .doc(transactionId)
          .delete()
          .catchError((_) {});
    }

    if (existing.partnerId.isNotEmpty) {
      await _rebuildSummary(existing.partnerId, existing.partnerName);
    }
  }

  // ---------------------------------------------------------------------------
  // SUMAR FINANCIAR
  // ---------------------------------------------------------------------------

  Future<PartnerFinancialSummary?> getSummaryForPartner(
    String partnerId,
  ) async {
    final local = await _readLocalSummaries();
    final localSummary = local.where((s) => s.partnerId == partnerId).firstOrNull;

    if (!_isCloudAvailable) return localSummary;

    try {
      final doc = await _summariesCollection.doc(partnerId).get();
      if (doc.exists && doc.data() != null) {
        final summary = PartnerFinancialSummary.fromMap(doc.data()!);
        await _upsertLocalSummary(summary);
        return summary;
      }
    } catch (_) {}

    return localSummary;
  }

  Future<List<PartnerFinancialSummary>> listAllSummaries() async {
    final local = await _readLocalSummaries();
    if (!_isCloudAvailable) return local;

    try {
      final snapshot = await _summariesCollection.get();
      final cloud = snapshot.docs
          .map((doc) => PartnerFinancialSummary.fromMap(doc.data()))
          .toList(growable: false);
      final all = [...cloud];
      final knownIds = cloud.map((s) => s.partnerId).toSet();
      for (final s in local) {
        if (!knownIds.contains(s.partnerId)) all.add(s);
      }
      await _writeLocalSummaries(all);
      return all;
    } catch (_) {
      return local;
    }
  }

  // ---------------------------------------------------------------------------
  // REBUILD SUMAR (calculat din tranzacții locale)
  // ---------------------------------------------------------------------------

  Future<PartnerFinancialSummary> _rebuildSummary(
    String partnerId,
    String partnerName,
  ) async {
    final allTransactions = await _readLocalTransactions();
    final partnerTransactions =
        allTransactions.where((t) => t.partnerId == partnerId).toList();

    // Guard: dacă cache-ul local e gol, nu suprascriem sumarul din Firebase cu zero.
    // Poate că suntem pe un dispozitiv nou care nu a sincronizat încă datele.
    if (partnerTransactions.isEmpty && _isCloudAvailable) {
      try {
        final doc = await _summariesCollection.doc(partnerId).get();
        if (doc.exists && doc.data() != null) {
          final existingSummary =
              PartnerFinancialSummary.fromMap(doc.data()!);
          await _upsertLocalSummary(existingSummary);
          return existingSummary;
        }
      } catch (_) {}
    }

    double totalDeIncasat = 0;
    double totalDePlata = 0;
    DateTime? lastDate;
    for (final t in partnerTransactions) {
      // Tranzacțiile marcate ca "Plătit" sunt deja decontate — nu mai contribuie
      // la soldul restant (De încasat / De plătit).
      // Tranzacțiile "Parțial" sau "Neîncasat" rămân în sold.
      if (t.status == PartnerTransactionStatus.platit) {
        // Actualizăm totuși ultima dată de tranzacție
        if (lastDate == null || t.date.isAfter(lastDate)) {
          lastDate = t.date;
        }
        continue;
      }
      if (t.direction == PartnerTransactionDirection.intrare) {
        totalDeIncasat += t.amount;
      } else {
        totalDePlata += t.amount;
      }
      if (lastDate == null || t.date.isAfter(lastDate)) {
        lastDate = t.date;
      }
    }

    final summary = PartnerFinancialSummary(
      partnerId: partnerId,
      partnerName: partnerName,
      totalDeIncasat: totalDeIncasat,
      totalDePlata: totalDePlata,
      lastTransactionDate: lastDate,
      transactionCount: partnerTransactions.length,
      updatedAt: DateTime.now(),
    );

    await _upsertLocalSummary(summary);

    // Queue pentru sync offline — garantează că sumarul ajunge în Firebase
    await OfflineSyncRuntime.instance
        .queuePartnerFinancialSummaryUpsert(summary.toMap());

    // Firebase direct — fire-and-forget (BUG 8)
    if (_isCloudAvailable) {
      _summariesCollection
          .doc(partnerId)
          .set(summary.toMap(), SetOptions(merge: true))
          .catchError((_) {});
    }

    return summary;
  }

  // ---------------------------------------------------------------------------
  // LOCAL STORAGE
  // ---------------------------------------------------------------------------

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<List<PartnerTransaction>> _readLocalTransactions() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_transactionsLocalKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <PartnerTransaction>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <PartnerTransaction>[];
    return decoded
        .whereType<Map>()
        .map((item) => PartnerTransaction.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
  }

  Future<void> _writeLocalTransactions(
    List<PartnerTransaction> items,
  ) async {
    final prefs = await _prefs();
    await prefs.setString(
      _transactionsLocalKey,
      jsonEncode(items.map((t) => t.toMap()).toList(growable: false)),
    );
  }


  Future<List<PartnerFinancialSummary>> _readLocalSummaries() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_summariesLocalKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <PartnerFinancialSummary>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <PartnerFinancialSummary>[];
    return decoded
        .whereType<Map>()
        .map((item) => PartnerFinancialSummary.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
  }

  Future<void> _writeLocalSummaries(
    List<PartnerFinancialSummary> items,
  ) async {
    final prefs = await _prefs();
    await prefs.setString(
      _summariesLocalKey,
      jsonEncode(items.map((s) => s.toMap()).toList(growable: false)),
    );
  }

  Future<void> _upsertLocalSummary(PartnerFinancialSummary summary) async {
    final items = [...await _readLocalSummaries()];
    final index = items.indexWhere((s) => s.partnerId == summary.partnerId);
    if (index >= 0) {
      items[index] = summary;
    } else {
      items.add(summary);
    }
    await _writeLocalSummaries(items);
  }

  // ---------------------------------------------------------------------------
  // UTILITARE
  // ---------------------------------------------------------------------------

  List<PartnerTransaction> _sortTransactions(List<PartnerTransaction> items) {
    return [...items]..sort((a, b) => b.date.compareTo(a.date));
  }

  // ── Sync forțat: publică toate tranzacțiile locale în Firestore ──────────
  Future<int> forceSyncLocalToCloud() async {
    if (!_isCloudAvailable) return 0;
    final locals = await _readLocalTransactions();
    if (locals.isEmpty) return 0;
    int synced = 0;
    for (final t in locals) {
      try {
        await _transactionsCollection
            .doc(t.id)
            .set(t.toMap(), SetOptions(merge: true));
        await OfflineSyncRuntime.instance
            .queuePartnerTransactionUpsert(t.toMap());
        synced++;
      } catch (e) {
        lastFirestoreError = e.toString();
      }
    }
    // Re-publică și sumarele
    final affected = <String, String>{};
    for (final t in locals) {
      affected[t.partnerId] = t.partnerName;
    }
    for (final entry in affected.entries) {
      await _rebuildSummary(entry.key, entry.value);
    }
    return synced;
  }
}
