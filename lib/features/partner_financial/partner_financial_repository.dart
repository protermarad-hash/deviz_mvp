import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/cloud_sync_models.dart';
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
      // BUG 7 fix: preferă versiunea locală pentru items cu queue pending
      // (modificări offline nu au ajuns încă în Firestore — cloud are versiunea veche)
      final pendingIds = await OfflineSyncRuntime.instance
          .pendingUpsertEntityIds(CloudEntityType.partnerTransactions);
      final localById = <String, PartnerTransaction>{
        for (final t in filtered) t.id: t
      };
      final resolvedCloud = cloud.map((c) {
        if (pendingIds.contains(c.id) && localById.containsKey(c.id)) {
          return localById[c.id]!;
        }
        return c;
      }).toList(growable: false);
      // Merge: cloud (rezolvat) + local-only (create offline, neajunse în Firestore)
      final knownIds = resolvedCloud.map((t) => t.id).toSet();
      final localOnly = filtered
          .where((t) => !knownIds.contains(t.id))
          .toList(growable: false);
      // Queue local-only pentru sync
      for (final txn in localOnly) {
        await OfflineSyncRuntime.instance
            .queuePartnerTransactionUpsert(txn.toMap());
      }

      // ── DEDUP: elimină tranzacțiile vechi cu ID UUID care au un echivalent
      // ptxn_* (creat de _syncFromAppointments cu ID deterministic).
      // Cauza dublei numărări: versiunea anterioară a codului crea tranzacții
      // consumMateriale / incasareProgramare / plataProgramare cu UUID-uri
      // aleatorii; noua versiune creează ptxn_{appointmentId}_{tip}.
      // La merge cloud + local, ambele versiuni apar → totaluri x2.
      // Soluție: dacă există ptxn_* pentru (referenceId, type), eliminăm UUID-ul.
      final allMerged = [...resolvedCloud, ...localOnly];
      final ptxnKeys = <String>{}; // 'refId|typeValue'
      for (final t in allMerged) {
        if (t.id.startsWith('ptxn_') &&
            t.referenceType == 'programare' &&
            t.referenceId.isNotEmpty) {
          ptxnKeys.add('${t.referenceId}|${t.type.value}');
        }
      }
      final toDeleteOldIds = <String>[];
      final deduped = allMerged.where((t) {
        if (!t.id.startsWith('ptxn_') &&
            t.referenceType == 'programare' &&
            t.referenceId.isNotEmpty) {
          final key = '${t.referenceId}|${t.type.value}';
          if (ptxnKeys.contains(key)) {
            toDeleteOldIds.add(t.id);
            return false; // exclude din rezultat
          }
        }
        return true;
      }).toList(growable: false);

      // Șterge din Firestore tranzacțiile UUID orfane (fire-and-forget)
      if (toDeleteOldIds.isNotEmpty) {
        debugPrint(
          '[FinanciarPartner $partnerId] Șterg ${toDeleteOldIds.length} '
          'tranzacții orfane (ID UUID + echivalent ptxn_* există)',
        );
        await Future.wait(
          toDeleteOldIds.map(
            (id) => OfflineSyncRuntime.instance.queuePartnerTransactionDelete(id),
          ),
        );
        if (_isCloudAvailable) {
          for (final id in toDeleteOldIds) {
            _transactionsCollection.doc(id).delete().catchError((_) {});
          }
        }
      }

      await _writeLocalTransactions([
        ...local.where((t) => t.partnerId != partnerId),
        ...deduped,
      ]);
      // Returnăm lista deduplicată (nu doar cloud ca înainte)
      return _sortTransactions(deduped);
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

    await rebuildSummary(transaction.partnerId, transaction.partnerName);
  }

  /// Upsert în lot — O(1) citire + scriere indiferent de numărul tranzacțiilor.
  /// FOLOSIȚI ASTA în loc de upsertTransaction() apelat în buclă.
  /// Evită O(n²) de citiri/scrieri SharedPreferences.
  ///
  /// [preserveExistingStatus] = true → dacă tranzacția există deja local,
  /// păstrează statusul existent (nu suprascrie modificările manuale de status
  /// cu valorile recalculate din programări). Folosiți pentru _syncFromAppointments().
  Future<void> upsertTransactionsBatch(
    List<PartnerTransaction> newOrUpdated, {
    bool preserveExistingStatus = false,
  }) async {
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
        if (preserveExistingStatus) {
          // Păstrează statusul editat manual — nu suprascrie cu statusul din programare
          existing[idx] = t.copyWith(status: existing[idx].status);
        } else {
          existing[idx] = t;
        }
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
      await rebuildSummary(entry.key, entry.value);
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
      await rebuildSummary(existing.partnerId, existing.partnerName);
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
      // Preferă LOCAL (proaspăt calculat de rebuildSummary) față de Firestore (stale).
      // Adaugă din cloud DOAR partenerii care nu există în local.
      final localIds = local.map((s) => s.partnerId).toSet();
      final cloudOnly = cloud.where((s) => !localIds.contains(s.partnerId)).toList();
      final merged = [...local, ...cloudOnly];
      await _writeLocalSummaries(merged);
      return merged;
    } catch (_) {
      return local;
    }
  }

  // ---------------------------------------------------------------------------
  // REBUILD SUMAR (calculat din tranzacții locale)
  // ---------------------------------------------------------------------------

  Future<PartnerFinancialSummary> rebuildSummary(
    String partnerId,
    String partnerName,
  ) async {
    final allTransactions = await _readLocalTransactions();
    // Deduplică după ID — protecție împotriva eventualelor duplicate în cache
    final seenIds = <String>{};
    final partnerTransactions = allTransactions
        .where((t) => t.partnerId == partnerId && seenIds.add(t.id))
        .toList();

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

    // Formula definitivă — bazată pe financialDirection (getter robust în model):
    //
    //   credit_neincasat         → crediteNeincasate   (de primit de la partener)
    //   credit_incasat           → ignorat             (credit marcat plătit direct)
    //   plata_primita            → platiPrimite        (MEREU reduce De încasat)
    //   plata_efectuata          → debiteNeachitate    (de plătit partenerului)
    //   plata_efectuata_achitata → ignorat             (achitat deja)
    //
    // consumMateriale → MEREU 'credit_neincasat' (recuperat de la partener)
    // incasareManuala = MEREU 'plata_primita' indiferent de câmpul status
    //
    // Etapa 2 — alocare încasări pe categorii:
    //   collectionCategory=work      → reduce workCredits
    //   collectionCategory=materials → reduce materialsCredits
    //   collectionCategory=products  → reduce productsCredits
    //   collectionCategory=mixed     → split pe allocated*Amount
    //   collectionCategory=general   → reduce totalul general (legacy)
    double workCredits = 0;        // lucrări / manoperă brute
    double materialsCredits = 0;   // materiale / kituri brute
    double productsCredits = 0;    // produse brute
    double crediteNeincasate = 0;  // = workCredits + materialsCredits + productsCredits
    // Plăți alocate pe categorii (Etapa 2):
    double collectedWork = 0;
    double collectedMaterials = 0;
    double collectedProducts = 0;
    double collectedGeneral = 0;   // legacy / nealocate
    double platiPrimite = 0;       // = Σ toate plata_primita
    double debiteNeachitate = 0;
    DateTime? lastDate;

    // ── AUDIT LOG temporar pentru parteneri cheie ─────────────────────────────
    final auditMode = partnerName.toUpperCase().contains('BOGDINSTAL') ||
        partnerName.toUpperCase().contains('E.ON') ||
        partnerName.toUpperCase().contains('AIR SISTEM');
    if (auditMode) {
      debugPrint('[AUDIT $partnerName] ══════════════════════════════════════');
      debugPrint('[AUDIT $partnerName] Total tranzacții: ${partnerTransactions.length}');
      for (final t in partnerTransactions) {
        debugPrint('[AUDIT $partnerName]  id=${t.id.length > 16 ? t.id.substring(0, 16) : t.id}'
            ' | type=${t.type.value}'
            ' | status=${t.status.value}'
            ' | dir=${t.financialDirection}'
            ' | refact=${t.isRefacturable}'
            ' | amount=${t.amount}');
      }
    }
    // ─────────────────────────────────────────────────────────────────────────

    for (final t in partnerTransactions) {
      if (lastDate == null || t.date.isAfter(lastDate)) lastDate = t.date;
      final amount = t.amount.abs();
      switch (t.financialDirection) {
        case 'credit_neincasat':
          crediteNeincasate += amount;
          // Sub-tracking per categorie pentru sumar detaliat
          if (t.type == PartnerTransactionType.consumMateriale) {
            materialsCredits += amount;
          } else if (t.type == PartnerTransactionType.vanzareProdus) {
            productsCredits += amount;
          } else {
            workCredits += amount;
          }
          break;
        case 'plata_primita':
          platiPrimite += amount;
          // Etapa 2 — alocare pe categorii
          switch (t.collectionCategory) {
            case PartnerCollectionCategory.work:
              collectedWork += amount;
              break;
            case PartnerCollectionCategory.materials:
              collectedMaterials += amount;
              break;
            case PartnerCollectionCategory.products:
              collectedProducts += amount;
              break;
            case PartnerCollectionCategory.mixed:
              collectedWork += t.allocatedWorkAmount;
              collectedMaterials += t.allocatedMaterialsAmount;
              collectedProducts += t.allocatedProductsAmount;
              break;
            case PartnerCollectionCategory.general:
              collectedGeneral += amount;
              break;
          }
          break;
        case 'plata_efectuata':
          debiteNeachitate += amount;
          break;
        case 'credit_incasat':
        case 'plata_efectuata_achitata':
          break; // ignorat în sold
      }
    }

    final deIncasat = (crediteNeincasate - platiPrimite).clamp(0.0, double.infinity);
    final soldNet = deIncasat - debiteNeachitate;

    if (auditMode) {
      debugPrint('[AUDIT $partnerName] crediteNeincasate=$crediteNeincasate'
          ' (work=$workCredits mat=$materialsCredits prod=$productsCredits)');
      debugPrint('[AUDIT $partnerName] platiPrimite=$platiPrimite'
          ' (work=$collectedWork mat=$collectedMaterials prod=$collectedProducts gen=$collectedGeneral)');
      debugPrint('[AUDIT $partnerName] deIncasat=$deIncasat debiteNeachitate=$debiteNeachitate soldNet=$soldNet');
      debugPrint('[AUDIT $partnerName] ══════════════════════════════════════');
    }
    debugPrint('[Financiar $partnerId] lucrari=$workCredits mat=$materialsCredits prod=$productsCredits platiPrimite=$platiPrimite deIncasat=$deIncasat soldNet=$soldNet');

    final summary = PartnerFinancialSummary(
      partnerId: partnerId,
      partnerName: partnerName,
      totalDeIncasat: deIncasat,
      totalDePlata: debiteNeachitate,
      totalIncasat: platiPrimite,
      totalPlatit: 0,
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

  /// Migrare date vechi: re-salvează toate tranzacțiile locale scriind
  /// câmpul 'financial_direction' în JSON (din getter-ul computed al modelului).
  /// Tranzacțiile vechi din SharedPreferences nu aveau acest câmp.
  /// Returnează numărul de tranzacții migrate.
  Future<int> migrateTransactions() async {
    final all = await _readLocalTransactions();
    if (all.isEmpty) return 0;
    // Re-salvare: toMap() include acum 'financial_direction' → scrie în cache
    await _writeLocalTransactions(all);
    // Sync fire-and-forget în Firestore pentru câmpul nou
    if (_isCloudAvailable) {
      for (final t in all) {
        _transactionsCollection
            .doc(t.id)
            .set({'financial_direction': t.financialDirection}, SetOptions(merge: true))
            .catchError((_) {});
      }
    }
    debugPrint('[FinanciarMigration] Migrat ${all.length} tranzacții cu financial_direction');
    return all.length;
  }

  /// Reconstruiește sumarele pentru TOȚI partenerii care au tranzacții locale.
  /// Apelat din dashboard pentru a corecta valorile stale din Firestore.
  Future<int> rebuildAllSummaries() async {
    await migrateTransactions();
    final allTransactions = await _readLocalTransactions();
    final partners = <String, String>{};
    for (final t in allTransactions) {
      if (t.partnerId.isNotEmpty) {
        partners[t.partnerId] = t.partnerName;
      }
    }
    for (final entry in partners.entries) {
      await rebuildSummary(entry.key, entry.value);
    }
    return partners.length;
  }

  // ---------------------------------------------------------------------------
  // LOCAL STORAGE
  // ---------------------------------------------------------------------------

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  /// Citire rapidă — NUMAI din SharedPreferences, fără atingerea Firestore.
  /// Folosit de dashboard pentru încărcarea fazei 1 (non-blocking).
  Future<List<PartnerFinancialSummary>> listLocalOnlySummaries() async {
    return _readLocalSummaries();
  }

  /// Citire rapidă — NUMAI din SharedPreferences, fără atingerea Firestore.
  /// Folosit de dashboard pentru calculul alertelor (offline-first).
  Future<List<PartnerTransaction>> listLocalOnlyTransactions() async {
    return _readLocalTransactions();
  }

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
      await rebuildSummary(entry.key, entry.value);
    }
    return synced;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECONCILIERE PERIOADE (Etapa 4)
  // ─────────────────────────────────────────────────────────────────────────

  static const String _settlementsLocalKey = 'partner_settlements_v1';

  CollectionReference<Map<String, dynamic>> get _settlementsCollection =>
      FirebaseFirestore.instance
          .collection(FirebaseCollections.partnerSettlements);

  Future<List<PartnerSettlementPeriod>> _readLocalSettlements() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settlementsLocalKey) ?? '[]';
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(PartnerSettlementPeriod.fromMap)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeLocalSettlements(
      List<PartnerSettlementPeriod> settlements) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _settlementsLocalKey,
      jsonEncode(settlements.map((s) => s.toMap()).toList()),
    );
  }

  /// Returnează perioadele de reconciliere pentru un partener (local + cloud).
  Future<List<PartnerSettlementPeriod>> listSettlementsForPartner(
      String partnerId) async {
    final all = await _readLocalSettlements();
    final local = all.where((s) => s.partnerId == partnerId).toList();

    if (!_isCloudAvailable) return local;

    try {
      final snapshot = await _settlementsCollection
          .where('partner_id', isEqualTo: partnerId)
          .get();
      final cloud = snapshot.docs
          .map((d) => PartnerSettlementPeriod.fromMap(d.data()))
          .toList();

      // Merge: preferă versiunea locală dacă există (BUG 7 pattern)
      final cloudIds = cloud.map((s) => s.id).toSet();
      final localOnly =
          local.where((s) => !cloudIds.contains(s.id)).toList();
      final merged = [...cloud, ...localOnly];
      merged.sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
      return merged;
    } catch (e) {
      debugPrint('[PartnerSettlements] listSettlements error: $e');
      return local;
    }
  }

  /// Salvează o perioadă (local + queue + Firebase fire-and-forget).
  Future<void> upsertSettlement(PartnerSettlementPeriod settlement) async {
    // 1. Local
    final all = await _readLocalSettlements();
    final idx = all.indexWhere((s) => s.id == settlement.id);
    if (idx >= 0) {
      all[idx] = settlement;
    } else {
      all.add(settlement);
    }
    await _writeLocalSettlements(all);

    // 2. Queue
    await OfflineSyncRuntime.instance
        .queuePartnerSettlementUpsert(settlement.toMap());

    // 3. Firebase fire-and-forget (BUG 8)
    _settlementsCollection
        .doc(settlement.id)
        .set(settlement.toMap(), SetOptions(merge: true))
        .catchError((_) {});
  }

  /// Marchează o perioadă ca anulată (nu șterge datele).
  Future<void> cancelSettlement(String settlementId) async {
    final all = await _readLocalSettlements();
    final idx = all.indexWhere((s) => s.id == settlementId);
    if (idx < 0) return;

    final updated = PartnerSettlementPeriod(
      id: all[idx].id,
      partnerId: all[idx].partnerId,
      partnerName: all[idx].partnerName,
      periodStart: all[idx].periodStart,
      periodEnd: all[idx].periodEnd,
      status: PartnerSettlementStatus.cancelled,
      totalDatorat: all[idx].totalDatorat,
      totalIncasat: all[idx].totalIncasat,
      restDeIncasat: all[idx].restDeIncasat,
      totalDePlata: all[idx].totalDePlata,
      soldNet: all[idx].soldNet,
      adjustmentAmount: all[idx].adjustmentAmount,
      adjustmentNote: all[idx].adjustmentNote,
      lockedTransactionIds: all[idx].lockedTransactionIds,
      closedBy: all[idx].closedBy,
      closedByName: all[idx].closedByName,
      closedAt: all[idx].closedAt,
      notes: all[idx].notes,
      createdAt: all[idx].createdAt,
      updatedAt: DateTime.now(),
    );
    await upsertSettlement(updated);

    // Deblochează tranzacțiile care aparțineau acestei perioade
    await _unlockTransactions(
        all[idx].lockedTransactionIds, settlementId);
  }

  /// Închide o perioadă: calculează sumarul, blochează tranzacțiile.
  Future<PartnerSettlementPeriod> closeSettlementPeriod({
    required String partnerId,
    required String partnerName,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<PartnerTransaction> allTransactions,
    double adjustmentAmount = 0,
    String adjustmentNote = '',
    String closedBy = '',
    String closedByName = '',
    String notes = '',
  }) async {
    final now = DateTime.now();

    // Tranzacțiile din perioadă (exclusiv deja locked în altă reconciliere)
    final inPeriod = allTransactions.where((t) {
      if (t.isLocked && t.settlementId.isNotEmpty) return false;
      return !t.date.isBefore(periodStart) &&
          !t.date.isAfter(periodEnd.add(const Duration(days: 1)));
    }).toList();

    // Calcul sumar
    double totalDatorat = 0;
    double totalIncasat = 0;
    double totalDePlata = 0;
    for (final t in inPeriod) {
      switch (t.financialDirection) {
        case 'credit_neincasat':
          totalDatorat += t.amount;
          break;
        case 'plata_primita':
          totalIncasat += t.amount;
          break;
        case 'plata_efectuata':
          totalDePlata += t.amount;
          break;
        default:
          break;
      }
    }
    final restDeIncasat =
        (totalDatorat - totalIncasat + adjustmentAmount)
            .clamp(0.0, double.infinity);
    final soldNet = restDeIncasat - totalDePlata;

    final settlementId = PartnerSettlementPeriod.generateId();
    final lockedIds = inPeriod.map((t) => t.id).toList(growable: false);

    final settlement = PartnerSettlementPeriod(
      id: settlementId,
      partnerId: partnerId,
      partnerName: partnerName,
      periodStart: periodStart,
      periodEnd: periodEnd,
      status: PartnerSettlementStatus.closed,
      totalDatorat: totalDatorat,
      totalIncasat: totalIncasat,
      restDeIncasat: restDeIncasat,
      totalDePlata: totalDePlata,
      soldNet: soldNet,
      adjustmentAmount: adjustmentAmount,
      adjustmentNote: adjustmentNote,
      lockedTransactionIds: lockedIds,
      closedBy: closedBy,
      closedByName: closedByName,
      closedAt: now,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );

    // Salvează settlement
    await upsertSettlement(settlement);

    // Blochează tranzacțiile
    await _lockTransactions(lockedIds, settlementId);

    // Dacă există ajustare, adaugă tranzacție specială de ajustare
    if (adjustmentAmount.abs() > 0.001 && adjustmentNote.trim().isNotEmpty) {
      final adjTx = PartnerTransaction(
        id: PartnerTransaction.generateId(),
        partnerId: partnerId,
        partnerName: partnerName,
        type: adjustmentAmount >= 0
            ? PartnerTransactionType.incasareManuala
            : PartnerTransactionType.plataManuala,
        direction: adjustmentAmount >= 0
            ? PartnerTransactionDirection.intrare
            : PartnerTransactionDirection.iesire,
        amount: adjustmentAmount.abs(),
        date: periodEnd,
        description: 'Ajustare reconciliere: $adjustmentNote',
        paymentMethod: PartnerTransactionPaymentMethod.transfer,
        status: PartnerTransactionStatus.platit,
        notes:
            'Creat automat la închiderea reconcilierii $settlementId',
        settlementId: settlementId,
        isLocked: true,
        createdAt: now,
        updatedAt: now,
      );
      await upsertTransaction(adjTx);
    }

    return settlement;
  }

  /// Blochează tranzacțiile specificate (setează isLocked=true + settlementId).
  Future<void> _lockTransactions(
      List<String> ids, String settlementId) async {
    if (ids.isEmpty) return;
    final all = await _readLocalTransactions();
    final updated = all.map((t) {
      if (ids.contains(t.id)) {
        return t.copyWith(
          isLocked: true,
          settlementId: settlementId,
          updatedAt: DateTime.now(),
        );
      }
      return t;
    }).toList();
    await _writeLocalTransactions(updated);

    // Queue fiecare tranzacție actualizată
    for (final t in updated.where((t) => ids.contains(t.id))) {
      await OfflineSyncRuntime.instance
          .queuePartnerTransactionUpsert(t.toMap());
      _transactionsCollection
          .doc(t.id)
          .set(t.toMap(), SetOptions(merge: true))
          .catchError((_) {});
    }
  }

  /// Deblochează tranzacțiile aparținând unui settlement anulat.
  Future<void> _unlockTransactions(
      List<String> ids, String settlementId) async {
    if (ids.isEmpty) return;
    final all = await _readLocalTransactions();
    final updated = all.map((t) {
      if (ids.contains(t.id) && t.settlementId == settlementId) {
        return t.copyWith(
          isLocked: false,
          settlementId: '',
          updatedAt: DateTime.now(),
        );
      }
      return t;
    }).toList();
    await _writeLocalTransactions(updated);

    for (final t in updated.where((t) => ids.contains(t.id))) {
      await OfflineSyncRuntime.instance
          .queuePartnerTransactionUpsert(t.toMap());
      _transactionsCollection
          .doc(t.id)
          .set(t.toMap(), SetOptions(merge: true))
          .catchError((_) {});
    }
  }

}
