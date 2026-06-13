import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/cloud_sync_models.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'hr_payroll_payment_models.dart';

class HrPayrollPaymentRepository {
  static final HrPayrollPaymentRepository instance =
      HrPayrollPaymentRepository._();
  HrPayrollPaymentRepository._();

  static const String _localKey = 'hr_payroll_payments_v1';

  static String? lastFirestoreError;
  static int lastFirestoreCount = -1;
  static int lastLocalCount = 0;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(FirebaseCollections.hrPayrollPayments);

  // ── Local cache ──────────────────────────────────────────────────────────

  Future<List<HrPayrollPayment>> _readLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => HrPayrollPayment.fromMap(Map<String, dynamic>.from(m)))
          .toList(growable: true);
    } catch (e) {
      debugPrint('[HrPayrollPayment] _readLocal error: $e');
      return [];
    }
  }

  Future<void> _writeLocal(List<HrPayrollPayment> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(items.map((e) => e.toMap()).toList());
      await prefs.setString(_localKey, json);
    } catch (e) {
      debugPrint('[HrPayrollPayment] _writeLocal error: $e');
    }
  }

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> savePayment(HrPayrollPayment payment) async {
    final locals = await _readLocal();
    final idx = locals.indexWhere((p) => p.id == payment.id);
    if (idx >= 0) {
      locals[idx] = payment;
    } else {
      locals.add(payment);
    }
    await _writeLocal(locals);
    await OfflineSyncRuntime.instance
        .queueHrPayrollPaymentUpsert(payment.toMap());
    _col
        .doc(payment.id)
        .set(payment.toMap(), SetOptions(merge: true))
        .catchError((_) {});
  }

  Future<void> deletePayment(String paymentId) async {
    final locals = await _readLocal();
    locals.removeWhere((p) => p.id == paymentId);
    await _writeLocal(locals);
    await OfflineSyncRuntime.instance
        .queueHrPayrollPaymentDelete(paymentId);
    _col.doc(paymentId).delete().catchError((_) {});
  }

  // ── Query ────────────────────────────────────────────────────────────────

  /// Plăți locale pentru angajat + lună (fără query Firestore).
  Future<List<HrPayrollPayment>> listPaymentsForEmployeeMonth({
    required String employeeId,
    required DateTime payrollMonth,
  }) async {
    final locals = await _readLocal();
    final month = DateTime(payrollMonth.year, payrollMonth.month, 1);
    return locals
        .where((p) =>
            p.employeeId.trim() == employeeId.trim() &&
            p.payrollMonth.year == month.year &&
            p.payrollMonth.month == month.month)
        .toList(growable: false);
  }

  /// Toate plățile locale pentru o lună (toate angajații) — fără Firestore.
  Future<Map<String, List<HrPayrollPayment>>> listPaymentsForMonth(
    DateTime payrollMonth,
  ) async {
    final locals = await _readLocal();
    final month = DateTime(payrollMonth.year, payrollMonth.month, 1);
    final result = <String, List<HrPayrollPayment>>{};
    for (final p in locals) {
      if (p.payrollMonth.year == month.year &&
          p.payrollMonth.month == month.month) {
        result.putIfAbsent(p.employeeId, () => []).add(p);
      }
    }
    return result;
  }

  /// Toate plățile unui angajat (local + Firestore merge).
  Future<List<HrPayrollPayment>> listPaymentsForEmployee(
    String employeeId,
  ) async {
    final locals = await _readLocal();
    final localFiltered = locals
        .where((p) => p.employeeId.trim() == employeeId.trim())
        .toList(growable: true);
    lastLocalCount = localFiltered.length;

    try {
      final snap = await _col
          .where('employee_id', isEqualTo: employeeId.trim())
          .get();
      final cloud = snap.docs
          .map((d) => HrPayrollPayment.fromMap(d.data()))
          .toList(growable: true);
      lastFirestoreCount = cloud.length;
      lastFirestoreError = null;

      final cloudIds = cloud.map((p) => p.id).toSet();
      final pendingIds = await OfflineSyncRuntime.instance
          .pendingUpsertEntityIds(CloudEntityType.hrPayrollPayments);
      final localById = {for (var p in localFiltered) p.id: p};

      final resolved = cloud.map((c) {
        if (pendingIds.contains(c.id) && localById.containsKey(c.id)) {
          return localById[c.id]!;
        }
        return c;
      }).toList(growable: true);

      final localOnly =
          localFiltered.where((p) => !cloudIds.contains(p.id)).toList();
      for (final p in localOnly) {
        await OfflineSyncRuntime.instance.queueHrPayrollPaymentUpsert(p.toMap());
      }

      final merged = [...resolved, ...localOnly]
        ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
      return merged;
    } catch (e) {
      lastFirestoreError = e.toString();
      lastFirestoreCount = -1;
      debugPrint('[HrPayrollPayment] Firestore error: $e');
      return localFiltered
        ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    }
  }

  /// Calcul rest de plată pentru angajat + lună.
  /// rest = netFinal - totalAvansuri - totalSalariu
  Future<double> calculateRestDePlata({
    required String employeeId,
    required DateTime payrollMonth,
    required double netFinal,
  }) async {
    final payments = await listPaymentsForEmployeeMonth(
      employeeId: employeeId,
      payrollMonth: payrollMonth,
    );
    final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
    return netFinal - totalPaid;
  }

  Future<int> forceSyncLocalToCloud() async {
    final locals = await _readLocal();
    if (locals.isEmpty) return 0;
    int synced = 0;
    for (final p in locals) {
      try {
        await _col.doc(p.id).set(p.toMap(), SetOptions(merge: true));
        await OfflineSyncRuntime.instance.queueHrPayrollPaymentUpsert(p.toMap());
        synced++;
      } catch (e) {
        debugPrint('[HrPayrollPayment] forceSyncLocalToCloud error ${p.id}: $e');
      }
    }
    return synced;
  }
}
