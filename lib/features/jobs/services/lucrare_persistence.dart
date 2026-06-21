import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/cloud/firebase_bootstrap.dart';
import '../../../core/cloud/offline_sync_runtime.dart';
import '../../../core/repositories/app_data_repository.dart';
import '../job_models.dart';
import '../lucrari_cloud_repository.dart';

/// Chei SharedPreferences pentru o lucrare, derivate din `jobId`.
///
/// Extras din `lucrare_detalii_page.dart` (Faza 2). Centralizează toate cheile
/// de stocare locală ale unei lucrări într-un singur loc, primind `jobId` ca
/// parametru — fără dependențe de state/UI.
class LucrareStorageKeys {
  const LucrareStorageKeys(this.jobId);

  final String jobId;

  String get team => 'job_team_v4_$jobId';
  String get appointments => 'job_appointments_v4_$jobId';
  String get materials => 'job_materials_v4_$jobId';
  String get labor => 'job_labor_v4_$jobId';
  String get timeEntries => 'job_time_entries_v1_$jobId';
  String get partners => 'job_partners_v1_$jobId';
  String get partnerWorkers => 'job_partner_workers_v1_$jobId';
  String get partnerVehicles => 'job_partner_vehicles_v1_$jobId';
  String get ownVehicles => 'job_own_vehicles_v1_$jobId';
  String get documents => 'job_documents_v1_$jobId';
  String get journal => 'job_journal_v1_$jobId';
  String get checklist => 'job_checklist_v1_$jobId';
  String get workTaskEntries => 'job_work_tasks_v1_$jobId';
  String get beneficiaryEquipment => 'job_beneficiary_equipment_v1_$jobId';
  String get beneficiaryMaterials => 'job_beneficiary_materials_v1_$jobId';

  /// Cheie globală (nu depinde de lucrare).
  static const String commercialSettings = 'commercial_settings_v1';
}

/// Decodează o listă de rânduri JSON dintr-un string SharedPreferences.
/// Returnează listă goală dacă input-ul e gol sau parsarea eșuează.
List<Map<String, dynamic>> lucrareReadRows(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
  } catch (e) {
    debugPrint('[LucrareDetalii] parsare rânduri JSON eșuată: $e');
  }
  return const [];
}

/// Clonează o listă de rânduri (copie defensivă a fiecărui map).
List<Map<String, dynamic>> lucrareCloneRows(List<Map<String, dynamic>> rows) {
  return rows
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

/// Scrie o listă de rânduri JSON în SharedPreferences sub cheia dată.
Future<void> lucrareSaveRows(
    String key, List<Map<String, dynamic>> rows) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, jsonEncode(rows));
}

/// Salvează un job în cloud (best-effort) + local + queue offline.
///
/// Centralizează blocul repetat de sincronizare: încearcă upsert în cloud
/// (dacă `cloud` e disponibil), salvează local prin `repository` și pune în
/// queue offline dacă cloud-ul lipsește sau a eșuat. Returnează job-ul salvat
/// (din `repository.saveJob`), pe care apelantul îl atribuie stării locale.
Future<JobRecord> lucrareSaveJobWithSync({
  required JobRecord job,
  required AppDataRepository repository,
  required LucrariCloudRepository? cloud,
}) async {
  var queuedOffline = cloud == null;
  if (cloud != null) {
    try {
      await cloud.upsertJob(job);
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      queuedOffline = true;
    }
  }
  final saved = await repository.saveJob(job);
  if (queuedOffline) {
    await OfflineSyncRuntime.instance.queueJob(saved);
  }
  return saved;
}
