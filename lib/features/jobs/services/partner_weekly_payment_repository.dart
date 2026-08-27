import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/cloud/cloud_sync_models.dart';
import '../../../core/cloud/firebase_bootstrap.dart';
import '../../../core/cloud/firebase_collections.dart';
import '../../../core/cloud/offline_sync_runtime.dart';

/// Statusul derivat al plății săptămânale per partener.
/// Există document în colecție → platit; altfel → neplatit.
/// NU reutilizează PartnerPaymentStatus din appointment_models.dart.
enum PartnerWeeklyPaymentStatus {
  neplatit,
  platit;

  String get value => name;

  static PartnerWeeklyPaymentStatus fromValue(String? raw) {
    for (final s in PartnerWeeklyPaymentStatus.values) {
      if (s.value == raw) return s;
    }
    return PartnerWeeklyPaymentStatus.neplatit;
  }
}

/// Înregistrare izolată a unei plăți globale per partener + săptămână.
/// Complet independentă de appointment_models.dart și de partner_financial/*.
class PartnerWeeklyPayment {
  const PartnerWeeklyPayment({
    required this.id,
    required this.partnerId,
    required this.weekStart,
    required this.amountPaid,
    required this.calculatedAmountAtMarking,
    required this.paidAt,
    this.notes,
  });

  /// ID determinist: 'pwp_{partnerId}_{weekStartYYYYMMDD}'.
  final String id;
  final String partnerId;

  /// Lunea săptămânii (ora ignorată — se compară doar data).
  final DateTime weekStart;

  /// Suma efectiv plătită, editabilă de utilizator.
  final double amountPaid;

  /// Totalul calculat de pontaj LA MOMENTUL marcării — folosit strict
  /// pentru detecția avertismentului de pontaj modificat ulterior.
  /// NU este suma plătită.
  final double calculatedAmountAtMarking;

  final DateTime paidAt;
  final String? notes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'partner_id': partnerId,
        'week_start': weekStart.toIso8601String(),
        'amount_paid': amountPaid,
        'calculated_amount_at_marking': calculatedAmountAtMarking,
        'paid_at': paidAt.toIso8601String(),
        'notes': notes,
      };

  factory PartnerWeeklyPayment.fromMap(Map<String, dynamic> map) =>
      PartnerWeeklyPayment(
        id: (map['id'] ?? '').toString(),
        partnerId: (map['partner_id'] ?? '').toString(),
        weekStart: DateTime.tryParse(map['week_start'] ?? '') ?? DateTime(2024),
        amountPaid: (map['amount_paid'] as num? ?? 0).toDouble(),
        calculatedAmountAtMarking:
            (map['calculated_amount_at_marking'] as num? ?? 0).toDouble(),
        paidAt: DateTime.tryParse(map['paid_at'] ?? '') ?? DateTime.now(),
        notes: map['notes'] as String?,
      );

  PartnerWeeklyPayment copyWith({
    double? amountPaid,
    double? calculatedAmountAtMarking,
    DateTime? paidAt,
    String? notes,
  }) =>
      PartnerWeeklyPayment(
        id: id,
        partnerId: partnerId,
        weekStart: weekStart,
        amountPaid: amountPaid ?? this.amountPaid,
        calculatedAmountAtMarking:
            calculatedAmountAtMarking ?? this.calculatedAmountAtMarking,
        paidAt: paidAt ?? this.paidAt,
        notes: notes ?? this.notes,
      );
}

/// Repository izolat pentru plăți săptămânale per partener (pontaj-partener).
/// NU are nicio dependință de PartnerFinancialRepository sau de
/// appointment_models.dart. Respectă pattern-ul offline-first al proiectului:
/// SharedPreferences (cache local) + OfflineSyncRuntime (queue) +
/// Firestore fire-and-forget.
class PartnerWeeklyPaymentRepository {
  static const String _localKey = 'partner_weekly_payments_v1';

  static String? lastFirestoreError;
  static int lastFirestoreCount = -1;
  static int lastLocalCount = 0;

  bool get _isCloudAvailable => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance
          .collection(FirebaseCollections.partnerWeeklyPayments);

  /// ID determinist pentru o combinație (partnerId, weekStart).
  static String paymentId(String partnerId, DateTime weekStart) {
    final d = weekStart;
    final date =
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    return 'pwp_${partnerId}_$date';
  }

  // ---------------------------------------------------------------------------
  // READ
  // ---------------------------------------------------------------------------

  /// Citire locală pură (fără Firestore) — pentru teste și UI debug.
  Future<PartnerWeeklyPayment?> getPaymentLocal(
      String partnerId, DateTime weekStart) async {
    final id = paymentId(partnerId, weekStart);
    final all = await _readLocal();
    return all.where((p) => p.id == id).firstOrNull;
  }

  /// Lista locală completă — pentru teste și forceSyncLocalToCloud.
  Future<List<PartnerWeeklyPayment>> listLocalPayments() async =>
      _readLocal();

  /// Citire cu fallback cloud, pentru un singur document.
  Future<PartnerWeeklyPayment?> getPayment(
      String partnerId, DateTime weekStart) async {
    final id = paymentId(partnerId, weekStart);
    final all = await _readLocal();
    final localItem = all.where((p) => p.id == id).firstOrNull;
    lastLocalCount = localItem != null ? 1 : 0;

    if (!_isCloudAvailable) return localItem;

    try {
      final doc = await _collection.doc(id).get();
      if (doc.exists && doc.data() != null) {
        final cloud = PartnerWeeklyPayment.fromMap(doc.data()!);
        await _upsertLocal(cloud);
        lastFirestoreCount = 1;
        lastFirestoreError = null;
        return cloud;
      }
      lastFirestoreCount = 0;
      lastFirestoreError = null;
    } catch (e) {
      lastFirestoreError = e.toString();
      debugPrint('[PartnerWeeklyPayment] getPayment cloud eroare: $e');
    }
    return localItem;
  }

  /// Listare cu merge cloud+local pentru un interval de date.
  Future<List<PartnerWeeklyPayment>> listPaymentsForPeriod(
      DateTime start, DateTime end) async {
    final all = await _readLocal();
    final filtered = all
        .where((p) =>
            !p.weekStart.isBefore(start) && !p.weekStart.isAfter(end))
        .toList(growable: false);
    lastLocalCount = filtered.length;

    if (!_isCloudAvailable) return filtered;

    try {
      final snapshot = await _collection.get();
      final cloud = snapshot.docs
          .map((doc) => PartnerWeeklyPayment.fromMap(doc.data()))
          .where((p) =>
              !p.weekStart.isBefore(start) && !p.weekStart.isAfter(end))
          .toList(growable: false);
      lastFirestoreCount = cloud.length;
      lastFirestoreError = null;

      final pendingIds = await OfflineSyncRuntime.instance
          .pendingUpsertEntityIds(CloudEntityType.partnerWeeklyPayments);
      final localById = <String, PartnerWeeklyPayment>{
        for (final p in filtered) p.id: p
      };
      final resolved = cloud.map((c) {
        if (pendingIds.contains(c.id) && localById.containsKey(c.id)) {
          return localById[c.id]!;
        }
        return c;
      }).toList(growable: false);

      final knownIds = resolved.map((p) => p.id).toSet();
      final localOnly =
          filtered.where((p) => !knownIds.contains(p.id)).toList(growable: false);
      for (final p in localOnly) {
        await OfflineSyncRuntime.instance
            .queuePartnerWeeklyPaymentUpsert(p.toMap());
      }

      final merged = [...resolved, ...localOnly];
      // Actualizează cache-ul local cu datele cloud (fără a pierde items
      // din afara intervalului curent).
      final others = all.where((p) {
        final inRange =
            !p.weekStart.isBefore(start) && !p.weekStart.isAfter(end);
        return !inRange;
      }).toList(growable: false);
      await _writeLocal([...others, ...merged]);
      return merged;
    } catch (e) {
      lastFirestoreError = e.toString();
      debugPrint('[PartnerWeeklyPayment] listPaymentsForPeriod cloud eroare: $e');
      return filtered;
    }
  }

  // ---------------------------------------------------------------------------
  // WRITE
  // ---------------------------------------------------------------------------

  Future<void> upsertPayment(PartnerWeeklyPayment payment) async {
    await _upsertLocal(payment);
    await OfflineSyncRuntime.instance
        .queuePartnerWeeklyPaymentUpsert(payment.toMap());
    if (_isCloudAvailable) {
      _collection
          .doc(payment.id)
          .set(payment.toMap(), SetOptions(merge: true))
          .catchError((_) {});
    }
  }

  Future<void> deletePayment(String id) async {
    final all = await _readLocal();
    await _writeLocal(all.where((p) => p.id != id).toList(growable: false));
    await OfflineSyncRuntime.instance.queuePartnerWeeklyPaymentDelete(id);
    if (_isCloudAvailable) {
      _collection.doc(id).delete().catchError((_) {});
    }
  }

  /// Re-publică toate înregistrările locale în Firestore.
  Future<int> forceSyncLocalToCloud() async {
    if (!_isCloudAvailable) return 0;
    final locals = await _readLocal();
    int synced = 0;
    for (final p in locals) {
      try {
        await _collection
            .doc(p.id)
            .set(p.toMap(), SetOptions(merge: true));
        await OfflineSyncRuntime.instance
            .queuePartnerWeeklyPaymentUpsert(p.toMap());
        synced++;
      } catch (e) {
        lastFirestoreError = e.toString();
        debugPrint('[PartnerWeeklyPayment] forceSyncLocalToCloud eroare: $e');
      }
    }
    return synced;
  }

  // ---------------------------------------------------------------------------
  // LOCAL STORAGE
  // ---------------------------------------------------------------------------

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<List<PartnerWeeklyPayment>> _readLocal() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_localKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) =>
            PartnerWeeklyPayment.fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<void> _writeLocal(List<PartnerWeeklyPayment> items) async {
    final prefs = await _prefs();
    await prefs.setString(
      _localKey,
      jsonEncode(items.map((p) => p.toMap()).toList(growable: false)),
    );
  }

  Future<void> _upsertLocal(PartnerWeeklyPayment item) async {
    final all = [...await _readLocal()];
    final idx = all.indexWhere((p) => p.id == item.id);
    if (idx >= 0) {
      all[idx] = item;
    } else {
      all.add(item);
    }
    await _writeLocal(all);
  }
}
