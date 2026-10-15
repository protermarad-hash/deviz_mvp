import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/cloud/cloud_push.dart';
import '../../../core/cloud/offline_sync_runtime.dart';
import '../../../core/repositories/app_data_repository.dart';
import '../job_models.dart';
import '../lucrari_cloud_repository.dart';
import '../../../core/cloud/cloud_sync_models.dart';
import '../../../core/cloud/revision_sync.dart';

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

/// Salvează un job LOCAL întâi, apoi în cloud fără a bloca UI-ul.
///
/// 1. `repository.saveJob` — sursa locală e actualizată imediat (UI-ul poate
///    reflecta modificarea fără să aștepte rețeaua);
/// 2. scrierea cloud este lansată prin [pushToCloudWithoutBlocking]: offline,
///    Firestore o păstrează ca scriere în așteptare (cache-ul local rămâne
///    coerent cu `mergeJobsFromCloud`); online, e așteptată cu timeout;
/// 3. job-ul intră în coada offline ÎNAINTE de scrierea cloud (durabil la
///    crash, protejat la merge); coada păstrează un singur item nesincronizat
///    per `entityId`, iar scrierea cloud e condiționată de revizie (idempotentă).
///
/// [online] permite testarea; implicit `FirebaseBootstrap.isOnline`.
Future<JobRecord> lucrareSaveJobWithSync({
  required JobRecord job,
  required AppDataRepository repository,
  required LucrariCloudRepository? cloud,
  bool? online,
  Duration cloudTimeout = const Duration(seconds: 10),
}) async {
  // Coada ÎNAINTE de cloud (RC 120): editarea e durabilă la crash și protejată
  // la merge din momentul salvării. Dacă scrierea cloud de mai jos reușește,
  // elementul e confirmat la următoarea sincronizare fără a scrie din nou
  // (scriere condiționată de revizie: conținut identic = aplicat).
  final saved = await runEntitySyncLocked(CloudEntityType.jobs, () async {
    final saved = await repository.saveJob(job);
    await OfflineSyncRuntime.instance.queueJob(saved);
    return saved;
  });
  if (cloud == null) {
    return saved;
  }
  await pushToCloudWithoutBlocking(
    () => cloud.upsertJob(saved),
    online: online,
    timeout: cloudTimeout,
  );
  return saved;
}
