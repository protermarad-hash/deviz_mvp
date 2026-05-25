import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../app_models.dart';
import '../../features/clients/client_models.dart';
import '../../features/clients/firebase_clienti_repository.dart';
import '../../features/jobs/firebase_job_site_documents_repository.dart';
import '../../features/jobs/firebase_lucrari_repository.dart';
import '../../features/jobs/job_models.dart';
import '../../features/jobs/job_site_document_models.dart';
import '../../features/hr_attendance/firebase_hr_attendance_repository.dart';
import '../../features/hr_attendance/hr_attendance_models.dart';
import '../../features/agfr/agfr_models.dart';
import '../../features/tool_packages/firebase_pachete_scule_repository.dart';
import '../../features/tool_packages/pachete_scule_models.dart';
import '../../features/tools/firebase_scule_repository.dart';
import '../../features/tools/scule_models.dart';
import '../../features/master/master_local_store.dart';
import '../../features/materials/firebase_materiale_repository.dart';
import '../../features/oferte/deviz_articol_template_models.dart';
import '../../features/oferte/deviz_articol_template_repository.dart';
import '../../features/oferte/firebase_oferte_repository.dart';
import '../../features/oferte/offer_models.dart';
import '../../features/programari/appointment_models.dart';
import '../../features/programari/firebase_programari_repository.dart';
import '../../features/programari/firebase_programare_kit_repository.dart';
import '../../features/programari/programare_kit_models.dart';
import '../../features/reclamatii/complaint_models.dart';
import '../../features/teams/firebase_echipe_repository.dart';
import 'cloud_sync_bridge.dart';
import 'firebase_collections.dart';
import 'cloud_sync_models.dart';
import 'cloud_sync_service.dart';
import 'firebase_bootstrap.dart';
import 'local_cloud_sync_repository.dart';

class OfflineSyncRuntime {
  OfflineSyncRuntime._();

  static final OfflineSyncRuntime instance = OfflineSyncRuntime._();

  final LocalCloudSyncRepository _queueRepository = LocalCloudSyncRepository();

  late final CloudSyncBridge _bridge =
      CloudSyncBridge(CloudSyncService(_queueRepository));

  bool _isSyncing = false;
  static const int _maxRetryAttempts = 10;
  static const Duration _minSyncGap = Duration(seconds: 5);
  DateTime? _lastSyncStartedAt;
  DateTime? _lastSyncFinishedAt;
  DateTime? _lastSyncSkipLoggedAt;

  bool get isSyncing => _isSyncing;

  Future<int> pendingItemsCount() async {
    try {
      return (await _queueRepository.listPendingItems()).length;
    } catch (_) {
      return -1;
    }
  }

  /// Returnează ID-urile entităților cu operații de upsert în așteptare (nesincronizate).
  /// Folosit de repository-uri pentru a prefera versiunea locală față de cea din cloud
  /// la merge, evitând suprascrierea modificărilor offline.
  Future<Set<String>> pendingUpsertEntityIds(CloudEntityType entityType) async {
    try {
      final pending = await _queueRepository.listPendingItems();
      return pending
          .where((item) => item.entityType == entityType && !item.deleted)
          .map((item) => item.entityId)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> queueJob(JobRecord job) async {
    await _bridge.queueJob(job.toMap());
  }

  Future<void> queueAppointment(Appointment appointment) async {
    await _bridge.queueAppointment(appointment.toMap());
  }

  /// Batch queue pentru o listă de programări — O(1) I/O SharedPreferences
  /// în loc de O(n). Folosit la re-queue local-only items la listare.
  Future<void> queueAppointmentsBatch(List<Appointment> appointments) async {
    if (appointments.isEmpty) return;
    final now = DateTime.now();
    final items = appointments.map((a) {
      final id = a.id;
      final entityId = id.trim().isEmpty ? null : id;
      if (entityId == null) return null;
      return CloudSyncItem(
        id: 'appointments_${entityId}_${now.millisecondsSinceEpoch}',
        entityType: CloudEntityType.appointments,
        entityId: entityId,
        payload: a.toMap(),
        updatedAt: now,
      );
    }).whereType<CloudSyncItem>().toList(growable: false);
    if (items.isNotEmpty) {
      await _queueRepository.upsertBatch(items);
    }
  }

  Future<void> queueAppointmentDelete(String appointmentId) async {
    await _bridge.queueAppointmentDelete(appointmentId);
  }

  Future<void> queueAppointmentMaterialKitUpsert(
    AppointmentMaterialKitTemplate template,
  ) async {
    await _bridge.queueAppointmentMaterialKitUpsert(template.toMap());
  }

  Future<void> queueAppointmentMaterialKitDelete(String templateId) async {
    await _bridge.queueAppointmentMaterialKitDelete(templateId);
  }

  Future<void> queueClient(ClientRecord client) async {
    await _bridge.queueClient(client.toMap());
  }

  Future<void> queueClientDelete(String clientId) async {
    await _bridge.queueClientDelete(clientId);
  }

  Future<void> queueOffer(OfferRecord offer) async {
    await _bridge.queueOffer(offer.toMap());
  }

  Future<void> queueOfferDelete(String offerId) async {
    await _bridge.queueOfferDelete(offerId);
  }

  Future<void> queueTeam(MasterTeam team) async {
    await _bridge.queueTeam(team.toMap());
  }

  Future<void> queueTeamDelete(String teamId) async {
    await _bridge.queueTeamDelete(teamId);
  }

  Future<void> queueComplaint(ComplaintRecord complaint) async {
    await _bridge.queueComplaint(complaint.toMap());
  }

  Future<void> queueComplaintDelete(String complaintId) async {
    await _bridge.queueComplaintDelete(complaintId);
  }

  Future<void> queueJobDelete(String jobId) async {
    await _bridge.queueJobDelete(jobId);
  }

  Future<void> queueDocument(JobSiteDocumentRecord document) async {
    await _bridge.queueDocument(document.toMap());
  }

  Future<void> queueDocumentDelete(String documentId) async {
    await _bridge.queueDocumentDelete(documentId);
  }

  Future<void> queueMaterial(MasterMaterial material) async {
    await _bridge.queueMaterial(material.toMap());
  }

  Future<void> queueMaterialDelete(String materialId) async {
    await _bridge.queueMaterialDelete(materialId);
  }

  Future<void> queueAttendanceEntry(HrAttendanceEntry entry) async {
    await _bridge.queueAttendanceEntry(entry.toMap());
  }

  Future<void> queueToolUpsert(ToolInventoryItem tool) async {
    await _bridge.queueToolUpsert(tool.toMap());
  }

  Future<void> queueToolDelete(String toolId) async {
    await _bridge.queueToolDelete(toolId);
  }

  Future<void> queueToolPackageUpsert(ToolPackageRecord package) async {
    await _bridge.queueToolPackageUpsert(package.toMap());
  }

  Future<void> queueToolPackageDelete(String packageId) async {
    await _bridge.queueToolPackageDelete(packageId);
  }

  Future<void> queueAgfrEquipment(AgfrEquipmentRecord equipment) async {
    await _bridge.queueAgfrEquipment(equipment.toMap());
  }

  Future<void> queueAgfrEquipmentDelete(String equipmentId) async {
    await _bridge.queueAgfrEquipmentDelete(equipmentId);
  }

  Future<void> queueAgfrIntervention(AgfrInterventionRecord intervention) async {
    await _bridge.queueAgfrIntervention(intervention.toMap());
  }

  Future<void> queueAgfrInterventionDelete(String interventionId) async {
    await _bridge.queueAgfrInterventionDelete(interventionId);
  }

  Future<void> queueAgfrReport(AgfrReportRecord report) async {
    await _bridge.queueAgfrReport(report.toMap());
  }

  Future<void> queueAgfrReportDelete(String reportId) async {
    await _bridge.queueAgfrReportDelete(reportId);
  }

  Future<void> queueAgfrWeighingReport(AgfrWeighingReportRecord report) async {
    await _bridge.queueAgfrWeighingReport(report.toMap());
  }

  Future<void> queueAgfrWeighingReportDelete(String reportId) async {
    await _bridge.queueAgfrWeighingReportDelete(reportId);
  }

  Future<void> queueVehicleUpsert(VehicleRecord vehicle) async {
    await _bridge.queueVehicleUpsert(vehicle.toMap());
  }

  Future<void> queueVehicleDelete(String vehicleId) async {
    await _bridge.queueVehicleDelete(vehicleId);
  }

  Future<void> queueRegistryEntryUpsert(Map<String, dynamic> cloudMap) async {
    await _bridge.queueRegistryEntryUpsert(cloudMap);
  }

  Future<void> queueRegistryEntryDelete(String entryId) async {
    await _bridge.queueRegistryEntryDelete(entryId);
  }

  Future<void> queuePartnerTransactionUpsert(
    Map<String, dynamic> transaction,
  ) async {
    await _bridge.queuePartnerTransactionUpsert(transaction);
  }

  Future<void> queuePartnerTransactionDelete(String transactionId) async {
    await _bridge.queuePartnerTransactionDelete(transactionId);
  }

  Future<void> queuePartnerFinancialSummaryUpsert(
    Map<String, dynamic> summary,
  ) async {
    await _bridge.queuePartnerFinancialSummaryUpsert(summary);
  }

  Future<void> queueDevizArticolTemplateUpsert(
    Map<String, dynamic> template,
  ) async {
    await _bridge.queueDevizArticolTemplateUpsert(template);
  }

  Future<void> queueDevizArticolTemplateDelete(String templateId) async {
    await _bridge.queueDevizArticolTemplateDelete(templateId);
  }

  Future<void> queueFieldPhotoUpsert(Map<String, dynamic> photo) async {
    await _bridge.queueFieldPhotoUpsert(photo);
  }

  Future<void> queueFieldPhotoDelete(String photoId) async {
    await _bridge.queueFieldPhotoDelete(photoId);
  }

  Future<void> queueDevizTehnicUpsert(Map<String, dynamic> deviz) async {
    await _bridge.queueDevizTehnicUpsert(deviz);
  }

  Future<void> queueDevizTehnicDelete(String devizId) async {
    await _bridge.queueDevizTehnicDelete(devizId);
  }

  Future<void> queueFiltreCtaUpsert(Map<String, dynamic> deviz) async {
    await _bridge.queueFiltreCtaUpsert(deviz);
  }

  Future<void> queueFiltreCtaDelete(String devizId) async {
    await _bridge.queueFiltreCtaDelete(devizId);
  }

  Future<void> queueAppTaskUpsert(Map<String, dynamic> task) async {
    await _bridge.queueAppTaskUpsert(task);
  }

  Future<void> queueAppTaskDelete(String taskId) async {
    await _bridge.queueAppTaskDelete(taskId);
  }

  /// Curăță imediat coada: elimină itemele deja sincronizate și cele moarte.
  /// Se apelează la startup pentru a elibera rapid JSON-ul acumulat.
  Future<void> cleanupQueue() async {
    await _queueRepository.clearStale(maxRetries: _maxRetryAttempts);
  }

  Future<bool> syncPending() async {
    final now = DateTime.now();
    if (_isSyncing) {
      if (_lastSyncSkipLoggedAt == null ||
          now.difference(_lastSyncSkipLoggedAt!) >
              const Duration(seconds: 2)) {
        debugPrint('[Programari] cloud sync skip reason=already_syncing');
        _lastSyncSkipLoggedAt = now;
      }
      return false;
    }
    final lastSyncActivityAt = _lastSyncFinishedAt != null &&
            (_lastSyncStartedAt == null ||
                _lastSyncFinishedAt!.isAfter(_lastSyncStartedAt!))
        ? _lastSyncFinishedAt
        : _lastSyncStartedAt;
    if (lastSyncActivityAt != null &&
        now.difference(lastSyncActivityAt) < _minSyncGap) {
      if (_lastSyncSkipLoggedAt == null ||
          now.difference(_lastSyncSkipLoggedAt!) >
              const Duration(seconds: 2)) {
        debugPrint('[Programari] cloud sync skip reason=cooldown');
        _lastSyncSkipLoggedAt = now;
      }
      return false;
    }
    final stopwatch = Stopwatch()..start();
    _isSyncing = true;
    _lastSyncStartedAt = now;
    debugPrint('[Programari] cloud sync start');
    try {
      if (!FirebaseBootstrap.isInitialized) {
        await FirebaseBootstrap.initializeSafe();
      }
      if (!FirebaseBootstrap.isInitialized) {
        debugPrint(
          '[Programari] cloud sync end duration_ms=${stopwatch.elapsedMilliseconds} result=false firebase_initialized=false',
        );
        return false;
      }

      // Curăță backlog-ul: elimină itemele deja sincronizate (rămase din versiuni
      // anterioare) și cele cu prea multe retry-uri (moarte). O singură citire+scriere.
      await _queueRepository.clearStale(maxRetries: _maxRetryAttempts);

      final pending = await _queueRepository.listPendingItems();
      if (pending.isEmpty) {
        debugPrint(
          '[Programari] cloud sync end duration_ms=${stopwatch.elapsedMilliseconds} pending=0 result=true',
        );
        return true;
      }

      final jobsRepository = FirebaseLucrariRepository();
      final offersRepository = FirebaseOferteRepository();
      final documentsRepository = FirebaseJobSiteDocumentsRepository();
      final teamsRepository = FirebaseEchipeRepository();
      final appointmentsRepository = FirebaseProgramariRepository();
      final appointmentMaterialKitRepository = FirebaseProgramareKitRepository();
      final clientsRepository = FirebaseClientiRepository();
      final materialsRepository = FirebaseMaterialeRepository();
      final complaintsCollection =
          FirebaseFirestore.instance.collection(FirebaseCollections.complaints);
      for (final item in pending) {
        if (item.retryCount >= _maxRetryAttempts) {
          continue;
        }
        try {
          switch (item.entityType) {
            case CloudEntityType.appointments:
              if (item.deleted) {
                await appointmentsRepository.deleteAppointment(item.entityId);
              } else {
                await appointmentsRepository
                    .upsertAppointment(Appointment.fromMap(item.payload));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.appointmentMaterialKitTemplates:
              if (item.deleted) {
                await appointmentMaterialKitRepository
                    .deleteTemplate(item.entityId);
              } else {
                await appointmentMaterialKitRepository.upsertTemplate(
                  AppointmentMaterialKitTemplate.fromMap(item.payload),
                );
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.clients:
              if (item.deleted) {
                await clientsRepository.deleteClient(item.entityId);
              } else {
                await clientsRepository
                    .upsertClient(ClientRecord.fromMap(item.payload));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.offers:
              if (item.deleted) {
                await offersRepository.deleteOffer(item.entityId);
              } else {
                await offersRepository.upsertOffer(
                  OfferRecord.fromMap(item.payload),
                );
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.jobs:
              if (item.deleted) {
                await jobsRepository.deleteJob(item.entityId);
              } else {
                await jobsRepository.upsertJob(JobRecord.fromMap(item.payload));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.complaints:
              if (item.deleted) {
                await complaintsCollection.doc(item.entityId).delete();
              } else {
                final complaint = ComplaintRecord.fromMap(item.payload);
                await complaintsCollection.doc(complaint.id).set(
                      complaint.toMap(),
                      SetOptions(merge: true),
                    );
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.documents:
              if (item.deleted) {
                await documentsRepository.deleteDocument(item.entityId);
              } else {
                await documentsRepository.upsertDocument(
                    JobSiteDocumentRecord.fromMap(item.payload));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.materials:
              if (item.deleted) {
                await materialsRepository.deleteMaterial(item.entityId);
              } else {
                await materialsRepository
                    .upsertMaterial(MasterMaterial.fromMap(item.payload));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.hrAttendanceEntries:
              final attendanceRepo = FirebaseHrAttendanceRepository();
              await attendanceRepo
                  .upsertEntry(HrAttendanceEntry.fromMap(item.payload));
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.agfrEquipments:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.agfrEquipments)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.agfrEquipments)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.agfrInterventions:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.agfrInterventions)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.agfrInterventions)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.agfrReports:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.agfrReports)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.agfrReports)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.agfrWeighingReports:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.agfrWeighingReports)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.agfrWeighingReports)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.toolInventoryItems:
              final sculesRepo = FirebaseSculeRepository();
              if (item.deleted) {
                await sculesRepo.deleteTool(item.entityId);
              } else {
                await sculesRepo
                    .upsertTool(ToolInventoryItem.fromMap(item.payload));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.toolPackages:
              final packagesRepo = FirebasePacheteSculeRepository();
              if (item.deleted) {
                await packagesRepo.deletePackage(item.entityId);
              } else {
                await packagesRepo
                    .upsertPackage(ToolPackageRecord.fromMap(item.payload));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.vehicles:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.vehicles)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.vehicles)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.registryEntries:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.registryEntries)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.registryEntries)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.partnerTransactions:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.partnerTransactions)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.partnerTransactions)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.partnerFinancialSummary:
              if (!item.deleted) {
                final partnerId =
                    (item.payload['partner_id'] ?? item.entityId).toString();
                if (partnerId.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection(FirebaseCollections.partnerFinancialSummary)
                      .doc(partnerId)
                      .set(item.payload, SetOptions(merge: true));
                }
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.devizArticoleTemplate:
              final templateRepo = DevizArticolTemplateRepository();
              if (item.deleted) {
                await templateRepo.deleteFromFirebase(item.entityId);
              } else {
                final template =
                    DevizArticolTemplate.fromMap(item.payload);
                await templateRepo.upsertToFirebase(template);
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.fieldPhotos:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.fieldPhotos)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.fieldPhotos)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.devizeTehnice:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.devizeTehnice)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.devizeTehnice)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.devizeFiltreCta:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.devizeFiltreCta)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.devizeFiltreCta)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.appTasks:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.appTasks)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.appTasks)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.unknown:
              // Tip necunoscut (din versiune mai nouă) — scoatem din queue
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.users:
            case CloudEntityType.teams:
              if (item.entityType == CloudEntityType.teams) {
                if (item.deleted) {
                  await teamsRepository.deleteTeam(item.entityId);
                } else {
                  await teamsRepository
                      .upsertTeam(MasterTeam.fromMap(item.payload));
                }
                await _queueRepository.markItemSynced(item.id, DateTime.now());
              }
              break;
          }
        } catch (error) {
          FirebaseBootstrap.registerRuntimeError(error);
          final attemptedAt = DateTime.now();
          await _queueRepository.markItemFailed(
            id: item.id,
            attemptedAt: attemptedAt,
            nextAttemptAt: _computeNextRetryAt(
              attemptedAt: attemptedAt,
              retryCount: item.retryCount + 1,
            ),
            errorMessage: error.toString(),
          );
        }
      }
      debugPrint(
        '[Programari] cloud sync end duration_ms=${stopwatch.elapsedMilliseconds} pending=${pending.length} result=true',
      );
      return true;
    } catch (error) {
      debugPrint(
        '[Programari] cloud sync end duration_ms=${stopwatch.elapsedMilliseconds} result=false error=$error',
      );
      rethrow;
    } finally {
      _isSyncing = false;
      _lastSyncFinishedAt = DateTime.now();
    }
  }

  DateTime _computeNextRetryAt({
    required DateTime attemptedAt,
    required int retryCount,
  }) {
    // Exponential backoff capped at 30 minutes.
    final seconds = (30 * (1 << (retryCount - 1))).clamp(30, 1800);
    return attemptedAt.add(Duration(seconds: seconds));
  }
}
