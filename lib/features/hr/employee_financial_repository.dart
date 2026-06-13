import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'employee_financial_models.dart';

class EmployeeFinancialRepository {
  EmployeeFinancialRepository._();
  static final EmployeeFinancialRepository instance =
      EmployeeFinancialRepository._();

  static const String _payEntriesKey = 'employee_pay_entries_v1';
  static const String _paymentsKey = 'employee_payments_v1';
  static const String _summariesKey = 'employee_financial_summaries_v1';
  static const String _settingsKey = 'employee_settings_v1';

  // ── Statics diagnostice (CLAUDE.md CHECKLIST) ─────────────────────────────
  static String? lastFirestoreError;
  static int lastFirestoreCount = -1;
  static int lastLocalCount = 0;

  bool get _isCloudAvailable => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _payEntriesCol =>
      FirebaseFirestore.instance
          .collection(FirebaseCollections.employeePayEntries);

  CollectionReference<Map<String, dynamic>> get _paymentsCol =>
      FirebaseFirestore.instance
          .collection(FirebaseCollections.employeePayments);

  CollectionReference<Map<String, dynamic>> get _summariesCol =>
      FirebaseFirestore.instance
          .collection(FirebaseCollections.employeeFinancialSummary);

  CollectionReference<Map<String, dynamic>> get _settingsCol =>
      FirebaseFirestore.instance
          .collection(FirebaseCollections.employeeSettings);

  // ─────────────────────────────────────────────────────────────────────────
  // PAY ENTRIES
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> savePayEntry(EmployeePayEntry entry) async {
    final items = [...await _readLocalPayEntries()];
    final index = items.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      items[index] = entry;
    } else {
      items.add(entry);
    }
    await _writeLocalPayEntries(items);

    await OfflineSyncRuntime.instance
        .queueEmployeePayEntryUpsert(entry.toMap());

    if (_isCloudAvailable) {
      _payEntriesCol
          .doc(entry.id)
          .set(entry.toMap(), SetOptions(merge: true))
          .catchError((_) {});
    }

    await _rebuildSummary(entry.employeeId, entry.employeeName);
  }

  Future<void> deletePayEntry(String entryId) async {
    final items = [...await _readLocalPayEntries()];
    final existing = items.firstWhere(
      (e) => e.id == entryId,
      orElse: () => EmployeePayEntry(
        id: '',
        employeeId: '',
        employeeName: '',
        appointmentId: '',
        appointmentTitle: '',
        appointmentDate: '',
        jobId: '',
        jobTitle: '',
        amountDue: 0,
        currency: 'RON',
        notes: '',
        createdAt: DateTime.now(),
        createdBy: '',
      ),
    );
    items.removeWhere((e) => e.id == entryId);
    await _writeLocalPayEntries(items);

    await OfflineSyncRuntime.instance.queueEmployeePayEntryDelete(entryId);

    if (_isCloudAvailable) {
      _payEntriesCol.doc(entryId).delete().catchError((_) {});
    }

    if (existing.employeeId.isNotEmpty) {
      await _rebuildSummary(existing.employeeId, existing.employeeName);
    }
  }

  Future<List<EmployeePayEntry>> listPayEntriesForEmployee(
    String employeeId,
  ) async {
    final local = await _readLocalPayEntries();
    final filtered =
        local.where((e) => e.employeeId == employeeId).toList(growable: false);
    lastLocalCount = filtered.length;

    if (!_isCloudAvailable) return _sortPayEntries(filtered);

    try {
      final snapshot = await _payEntriesCol
          .where('employee_id', isEqualTo: employeeId)
          .get();
      final cloud = snapshot.docs
          .map((doc) => EmployeePayEntry.fromMap(doc.data()))
          .toList(growable: false);
      lastFirestoreCount = cloud.length;
      lastFirestoreError = null;

      final knownIds = cloud.map((e) => e.id).toSet();
      final localOnly =
          filtered.where((e) => !knownIds.contains(e.id)).toList();
      for (final e in localOnly) {
        await OfflineSyncRuntime.instance
            .queueEmployeePayEntryUpsert(e.toMap());
      }
      await _writeLocalPayEntries([
        ...local.where((e) => e.employeeId != employeeId),
        ...cloud,
        ...localOnly,
      ]);
      return _sortPayEntries([...cloud, ...localOnly]);
    } catch (err) {
      lastFirestoreError = err.toString();
      lastFirestoreCount = -1;
      return _sortPayEntries(filtered);
    }
  }

  Future<List<EmployeePayEntry>> listPayEntriesForAppointment(
    String appointmentId,
  ) async {
    final local = await _readLocalPayEntries();
    return _sortPayEntries(
      local.where((e) => e.appointmentId == appointmentId).toList(),
    );
  }

  Future<List<EmployeePayEntry>> listAllPayEntries({
    DateTime? from,
    DateTime? to,
  }) async {
    final local = await _readLocalPayEntries();
    if (!_isCloudAvailable) {
      return _sortPayEntries(_filterByPeriod(local, from, to));
    }

    try {
      final snapshot = await _payEntriesCol.get();
      final cloud = snapshot.docs
          .map((doc) => EmployeePayEntry.fromMap(doc.data()))
          .toList(growable: false);
      lastFirestoreCount = cloud.length;
      lastFirestoreError = null;

      final all = [...cloud];
      final knownIds = cloud.map((e) => e.id).toSet();
      for (final e in local) {
        if (!knownIds.contains(e.id)) all.add(e);
      }
      await _writeLocalPayEntries(all);
      return _sortPayEntries(_filterByPeriod(all, from, to));
    } catch (err) {
      lastFirestoreError = err.toString();
      lastFirestoreCount = -1;
      return _sortPayEntries(_filterByPeriod(local, from, to));
    }
  }

  List<EmployeePayEntry> _filterByPeriod(
    List<EmployeePayEntry> items,
    DateTime? from,
    DateTime? to,
  ) {
    if (from == null && to == null) return items;
    return items.where((e) {
      final dt = DateTime.tryParse(e.appointmentDate) ?? e.createdAt;
      if (from != null && dt.isBefore(from)) return false;
      if (to != null && dt.isAfter(to)) return false;
      return true;
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAYMENTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> savePayment(EmployeePayment payment) async {
    final items = [...await _readLocalPayments()];
    final index = items.indexWhere((p) => p.id == payment.id);
    if (index >= 0) {
      items[index] = payment;
    } else {
      items.add(payment);
    }
    await _writeLocalPayments(items);

    await OfflineSyncRuntime.instance
        .queueEmployeePaymentUpsert(payment.toMap());

    if (_isCloudAvailable) {
      _paymentsCol
          .doc(payment.id)
          .set(payment.toMap(), SetOptions(merge: true))
          .catchError((_) {});
    }

    await _rebuildSummary(payment.employeeId, payment.employeeName);
  }

  Future<void> deletePayment(String paymentId) async {
    final items = [...await _readLocalPayments()];
    final existing = items.firstWhere(
      (p) => p.id == paymentId,
      orElse: () => EmployeePayment(
        id: '',
        employeeId: '',
        employeeName: '',
        amount: 0,
        currency: 'RON',
        paymentDate: DateTime.now(),
        notes: '',
        createdBy: '',
        createdAt: DateTime.now(),
      ),
    );
    items.removeWhere((p) => p.id == paymentId);
    await _writeLocalPayments(items);

    await OfflineSyncRuntime.instance.queueEmployeePaymentDelete(paymentId);

    if (_isCloudAvailable) {
      _paymentsCol.doc(paymentId).delete().catchError((_) {});
    }

    if (existing.employeeId.isNotEmpty) {
      await _rebuildSummary(existing.employeeId, existing.employeeName);
    }
  }

  Future<List<EmployeePayment>> listPaymentsForEmployee(
    String employeeId,
  ) async {
    final local = await _readLocalPayments();
    final filtered =
        local.where((p) => p.employeeId == employeeId).toList(growable: false);

    if (!_isCloudAvailable) return _sortPayments(filtered);

    try {
      final snapshot = await _paymentsCol
          .where('employee_id', isEqualTo: employeeId)
          .get();
      final cloud = snapshot.docs
          .map((doc) => EmployeePayment.fromMap(doc.data()))
          .toList(growable: false);

      final knownIds = cloud.map((p) => p.id).toSet();
      final localOnly =
          filtered.where((p) => !knownIds.contains(p.id)).toList();
      for (final p in localOnly) {
        await OfflineSyncRuntime.instance
            .queueEmployeePaymentUpsert(p.toMap());
      }
      await _writeLocalPayments([
        ...local.where((p) => p.employeeId != employeeId),
        ...cloud,
        ...localOnly,
      ]);
      return _sortPayments([...cloud, ...localOnly]);
    } catch (_) {
      return _sortPayments(filtered);
    }
  }

  Future<List<EmployeePayment>> listAllPayments({
    DateTime? from,
    DateTime? to,
    String? employeeId,
  }) async {
    final local = await _readLocalPayments();
    if (!_isCloudAvailable) {
      return _sortPayments(_filterPayments(local, from, to, employeeId));
    }

    try {
      final snapshot = await _paymentsCol.get();
      final cloud = snapshot.docs
          .map((doc) => EmployeePayment.fromMap(doc.data()))
          .toList(growable: false);
      final all = [...cloud];
      final knownIds = cloud.map((p) => p.id).toSet();
      for (final p in local) {
        if (!knownIds.contains(p.id)) all.add(p);
      }
      await _writeLocalPayments(all);
      return _sortPayments(_filterPayments(all, from, to, employeeId));
    } catch (_) {
      return _sortPayments(_filterPayments(local, from, to, employeeId));
    }
  }

  List<EmployeePayment> _filterPayments(
    List<EmployeePayment> items,
    DateTime? from,
    DateTime? to,
    String? employeeId,
  ) {
    return items.where((p) {
      if (employeeId != null &&
          employeeId.isNotEmpty &&
          p.employeeId != employeeId) {
        return false;
      }
      if (from != null && p.paymentDate.isBefore(from)) return false;
      if (to != null && p.paymentDate.isAfter(to)) return false;
      return true;
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUMMARY
  // ─────────────────────────────────────────────────────────────────────────

  Future<EmployeeFinancialSummary?> getSummary(String employeeId) async {
    final local = await _readLocalSummaries();
    final localSummary =
        local.where((s) => s.employeeId == employeeId).firstOrNull;

    if (!_isCloudAvailable) return localSummary;

    try {
      final doc = await _summariesCol.doc(employeeId).get();
      if (doc.exists && doc.data() != null) {
        final summary = EmployeeFinancialSummary.fromMap(doc.data()!);
        await _upsertLocalSummary(summary);
        return summary;
      }
    } catch (_) {}

    return localSummary;
  }

  Future<List<EmployeeFinancialSummary>> listAllSummaries() async {
    final local = await _readLocalSummaries();
    if (!_isCloudAvailable) return local;

    try {
      final snapshot = await _summariesCol.get();
      final cloud = snapshot.docs
          .map((doc) => EmployeeFinancialSummary.fromMap(doc.data()))
          .toList(growable: false);
      final all = [...cloud];
      final knownIds = cloud.map((s) => s.employeeId).toSet();
      for (final s in local) {
        if (!knownIds.contains(s.employeeId)) all.add(s);
      }
      await _writeLocalSummaries(all);
      return all;
    } catch (_) {
      return local;
    }
  }

  Future<EmployeeFinancialSummary> _rebuildSummary(
    String employeeId,
    String employeeName,
  ) async {
    final allEntries = await _readLocalPayEntries();
    final empEntries =
        allEntries.where((e) => e.employeeId == employeeId).toList();

    // Guard BUG 2: dacă nu avem date locale, nu suprascriem sumarul din Firebase
    if (empEntries.isEmpty && _isCloudAvailable) {
      try {
        final doc = await _summariesCol.doc(employeeId).get();
        if (doc.exists && doc.data() != null) {
          final existing = EmployeeFinancialSummary.fromMap(doc.data()!);
          await _upsertLocalSummary(existing);
          return existing;
        }
      } catch (_) {}
    }

    final allPayments = await _readLocalPayments();
    final empPayments =
        allPayments.where((p) => p.employeeId == employeeId).toList();

    final totalDue =
        empEntries.fold<double>(0, (acc, e) => acc + e.amountDue);
    final totalPaid =
        empPayments.fold<double>(0, (acc, p) => acc + p.amount);

    final summary = EmployeeFinancialSummary(
      employeeId: employeeId,
      employeeName: employeeName,
      totalDue: totalDue,
      totalPaid: totalPaid,
      updatedAt: DateTime.now(),
    );

    await _upsertLocalSummary(summary);

    await OfflineSyncRuntime.instance
        .queueEmployeeFinancialSummaryUpsert(summary.toMap());

    if (_isCloudAvailable) {
      _summariesCol
          .doc(employeeId)
          .set(summary.toMap(), SetOptions(merge: true))
          .catchError((_) {});
    }

    return summary;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMPLOYEE SETTINGS (tarif prestabilit per angajat)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> saveEmployeeSettings(EmployeeSettings settings) async {
    final items = [...await _readLocalSettings()];
    final index =
        items.indexWhere((s) => s.employeeId == settings.employeeId);
    if (index >= 0) {
      items[index] = settings;
    } else {
      items.add(settings);
    }
    await _writeLocalSettings(items);

    await OfflineSyncRuntime.instance
        .queueEmployeeSettingsUpsert(settings.toMap());

    if (_isCloudAvailable) {
      _settingsCol
          .doc(settings.employeeId)
          .set(settings.toMap(), SetOptions(merge: true))
          .catchError((_) {});
    }
  }

  Future<EmployeeSettings?> loadEmployeeSettings(String employeeId) async {
    final local = await _readLocalSettings();
    final localSetting =
        local.where((s) => s.employeeId == employeeId).firstOrNull;

    if (!_isCloudAvailable) return localSetting;

    try {
      final doc = await _settingsCol.doc(employeeId).get();
      if (doc.exists && doc.data() != null) {
        final settings = EmployeeSettings.fromMap(doc.data()!);
        await _upsertLocalSettings(settings);
        return settings;
      }
    } catch (_) {}
    return localSetting;
  }

  Future<Map<String, EmployeeSettings>> loadAllEmployeeSettings() async {
    final local = await _readLocalSettings();
    if (!_isCloudAvailable) {
      return {for (final s in local) s.employeeId: s};
    }

    try {
      final snapshot = await _settingsCol.get();
      final cloud = snapshot.docs
          .map((doc) => EmployeeSettings.fromMap(doc.data()))
          .toList(growable: false);
      final all = [...cloud];
      final knownIds = cloud.map((s) => s.employeeId).toSet();
      for (final s in local) {
        if (!knownIds.contains(s.employeeId)) all.add(s);
      }
      await _writeLocalSettings(all);
      return {for (final s in all) s.employeeId: s};
    } catch (_) {
      return {for (final s in local) s.employeeId: s};
    }
  }

  Future<void> _upsertLocalSettings(EmployeeSettings settings) async {
    final items = [...await _readLocalSettings()];
    final index =
        items.indexWhere((s) => s.employeeId == settings.employeeId);
    if (index >= 0) {
      items[index] = settings;
    } else {
      items.add(settings);
    }
    await _writeLocalSettings(items);
  }

  Future<List<EmployeeSettings>> _readLocalSettings() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) =>
            EmployeeSettings.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<void> _writeLocalSettings(List<EmployeeSettings> items) async {
    final prefs = await _prefs();
    await prefs.setString(
      _settingsKey,
      jsonEncode(items.map((s) => s.toMap()).toList(growable: false)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FORCE SYNC
  // ─────────────────────────────────────────────────────────────────────────

  Future<int> forceSyncLocalToCloud() async {
    if (!_isCloudAvailable) return 0;
    int synced = 0;

    final entries = await _readLocalPayEntries();
    for (final e in entries) {
      try {
        await _payEntriesCol
            .doc(e.id)
            .set(e.toMap(), SetOptions(merge: true));
        await OfflineSyncRuntime.instance
            .queueEmployeePayEntryUpsert(e.toMap());
        synced++;
      } catch (_) {}
    }

    final payments = await _readLocalPayments();
    for (final p in payments) {
      try {
        await _paymentsCol
            .doc(p.id)
            .set(p.toMap(), SetOptions(merge: true));
        await OfflineSyncRuntime.instance
            .queueEmployeePaymentUpsert(p.toMap());
        synced++;
      } catch (_) {}
    }

    return synced;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOCAL STORAGE
  // ─────────────────────────────────────────────────────────────────────────

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<List<EmployeePayEntry>> _readLocalPayEntries() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_payEntriesKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => EmployeePayEntry.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<void> _writeLocalPayEntries(List<EmployeePayEntry> items) async {
    final prefs = await _prefs();
    await prefs.setString(
      _payEntriesKey,
      jsonEncode(items.map((e) => e.toMap()).toList(growable: false)),
    );
  }

  Future<List<EmployeePayment>> _readLocalPayments() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_paymentsKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => EmployeePayment.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<void> _writeLocalPayments(List<EmployeePayment> items) async {
    final prefs = await _prefs();
    await prefs.setString(
      _paymentsKey,
      jsonEncode(items.map((p) => p.toMap()).toList(growable: false)),
    );
  }

  Future<List<EmployeeFinancialSummary>> _readLocalSummaries() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_summariesKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) =>
            EmployeeFinancialSummary.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<void> _writeLocalSummaries(
    List<EmployeeFinancialSummary> items,
  ) async {
    final prefs = await _prefs();
    await prefs.setString(
      _summariesKey,
      jsonEncode(items.map((s) => s.toMap()).toList(growable: false)),
    );
  }

  Future<void> _upsertLocalSummary(EmployeeFinancialSummary summary) async {
    final items = [...await _readLocalSummaries()];
    final index =
        items.indexWhere((s) => s.employeeId == summary.employeeId);
    if (index >= 0) {
      items[index] = summary;
    } else {
      items.add(summary);
    }
    await _writeLocalSummaries(items);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SORTARE
  // ─────────────────────────────────────────────────────────────────────────

  List<EmployeePayEntry> _sortPayEntries(List<EmployeePayEntry> items) =>
      [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<EmployeePayment> _sortPayments(List<EmployeePayment> items) =>
      [...items]..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
}
