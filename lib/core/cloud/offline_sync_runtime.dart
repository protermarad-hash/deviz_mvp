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
import '../../features/partners/partner_models.dart';
import '../../features/asociere/asociere_models.dart';
import '../../features/asociere/lucrare_asociere_models.dart';
import '../../features/asociere/lucrare_asociere_cloud_projection.dart';
import '../../features/asociere/tarif_asociere_models.dart';
import '../../features/asociere/pontaj_asociere_models.dart';
import '../../features/asociere/cost_asociere_models.dart';
import '../../features/asociere/venit_asociere_models.dart';
import '../../features/asociere/decont_lunar_asociere_models.dart';
import '../../features/asociere/deplasare_asociere_models.dart';
import '../../features/asociere/cazare_asociere_models.dart';
import '../../features/asociere/diurna_asociere_models.dart';
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
  String? _lastSyncError;
  int _lastSyncFailedItems = 0;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncFinishedAt => _lastSyncFinishedAt;
  String? get lastSyncError => _lastSyncError;
  int get lastSyncFailedItems => _lastSyncFailedItems;

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
    final items = appointments
        .map((a) {
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
        })
        .whereType<CloudSyncItem>()
        .toList(growable: false);
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

  Future<void> queueAgfrIntervention(
      AgfrInterventionRecord intervention) async {
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

  Future<void> queuePartnerSettlementUpsert(
    Map<String, dynamic> settlement,
  ) async {
    await _bridge.queuePartnerSettlementUpsert(settlement);
  }

  Future<void> queuePartnerSettlementDelete(String settlementId) async {
    await _bridge.queuePartnerSettlementDelete(settlementId);
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

  Future<void> queueEmployeePayEntryUpsert(Map<String, dynamic> entry) async {
    await _bridge.queueEmployeePayEntryUpsert(entry);
  }

  Future<void> queueEmployeePayEntryDelete(String entryId) async {
    await _bridge.queueEmployeePayEntryDelete(entryId);
  }

  Future<void> queueEmployeePaymentUpsert(Map<String, dynamic> payment) async {
    await _bridge.queueEmployeePaymentUpsert(payment);
  }

  Future<void> queueEmployeePaymentDelete(String paymentId) async {
    await _bridge.queueEmployeePaymentDelete(paymentId);
  }

  Future<void> queueEmployeeFinancialSummaryUpsert(
    Map<String, dynamic> summary,
  ) async {
    await _bridge.queueEmployeeFinancialSummaryUpsert(summary);
  }

  Future<void> queueEmployeeSettingsUpsert(
    Map<String, dynamic> settings,
  ) async {
    await _bridge.queueEmployeeSettingsUpsert(settings);
  }

  Future<void> queueEmployeeSettingsDelete(String employeeId) async {
    await _bridge.queueEmployeeSettingsDelete(employeeId);
  }

  Future<void> queueHrPayrollPaymentUpsert(
    Map<String, dynamic> payment,
  ) async {
    await _bridge.queueHrPayrollPaymentUpsert(payment);
  }

  Future<void> queueHrPayrollPaymentDelete(String paymentId) async {
    await _bridge.queueHrPayrollPaymentDelete(paymentId);
  }

  Future<void> queueStocItemUpsert(Map<String, dynamic> item) async {
    await _bridge.queueStocItemUpsert(item);
  }

  Future<void> queueStocItemDelete(String itemId) async {
    await _bridge.queueStocItemDelete(itemId);
  }

  Future<void> queueStocMiscareUpsert(Map<String, dynamic> miscare) async {
    await _bridge.queueStocMiscareUpsert(miscare);
  }

  Future<void> queueGpsCheckinUpsert(Map<String, dynamic> checkin) async {
    await _bridge.queueGpsCheckinUpsert(checkin);
  }

  Future<void> queueEchipamentInstalat(Map<String, dynamic> echipament) async {
    await _bridge.queueEchipamentInstalat(echipament);
  }

  Future<void> queueEchipamentInstalatDelete(String echipamentId) async {
    await _bridge.queueEchipamentInstalatDelete(echipamentId);
  }

  Future<void> queueCrmRecordUpsert(Map<String, dynamic> record) async {
    await _bridge.queueCrmRecordUpsert(record);
  }

  Future<void> queueCrmRecordDelete(String id) async {
    await _bridge.queueCrmRecordDelete(id);
  }

  Future<void> queueObiectivLunarUpsert(Map<String, dynamic> o) async {
    await _bridge.queueObiectivLunarUpsert(o);
  }

  Future<void> queuePartner(PartnerRecord partner) async {
    await _bridge.queuePartnerUpsert(partner.toMap());
  }

  Future<void> queuePartnerDelete(String partnerId) async {
    await _bridge.queuePartnerDelete(partnerId);
  }

  Future<void> queuePartnerWorker(PartnerWorkerRecord worker) async {
    await _bridge.queuePartnerWorkerUpsert(worker.toMap());
  }

  Future<void> queuePartnerWorkerDelete(String workerId) async {
    await _bridge.queuePartnerWorkerDelete(workerId);
  }

  Future<void> queuePartnerVehicle(PartnerVehicleRecord vehicle) async {
    await _bridge.queuePartnerVehicleUpsert(vehicle.toMap());
  }

  Future<void> queuePartnerVehicleDelete(String vehicleId) async {
    await _bridge.queuePartnerVehicleDelete(vehicleId);
  }

  // --- Modul Asociere (partajare profit/pierdere pe Lucrare) — iul 2026 ---

  Future<void> queueLucrareAsociere(LucrareAsociereRecord project) async {
    await _bridge.queueLucrareAsociereUpsert(project.toCloudMap());
  }

  Future<void> queueLucrareAsociereDelete(String projectId) async {
    await _bridge.queueLucrareAsociereDelete(projectId);
  }

  Future<void> queueAsociere(AsociereRecord asociere) async {
    await _bridge.queueAsociereUpsert(asociere.toMap());
  }

  Future<void> queueAsociereDelete(String asociereId) async {
    await _bridge.queueAsociereDelete(asociereId);
  }

  Future<void> queueTarifAsociere(TarifAsociereRecord tarif) async {
    await _bridge.queueTarifAsociereUpsert(tarif.toMap());
  }

  Future<void> queueTarifAsociereDelete(String tarifId) async {
    await _bridge.queueTarifAsociereDelete(tarifId);
  }

  Future<void> queuePontajAsociere(PontajAsociereRecord pontaj) async {
    await _bridge.queuePontajAsociereUpsert(pontaj.toMap());
  }

  Future<void> queuePontajAsociereDelete(String pontajId) async {
    await _bridge.queuePontajAsociereDelete(pontajId);
  }

  Future<void> queueCostAsociere(CostAsociereRecord cost) async {
    await _bridge.queueCostAsociereUpsert(cost.toMap());
  }

  Future<void> queueCostAsociereDelete(String costId) async {
    await _bridge.queueCostAsociereDelete(costId);
  }

  Future<void> queueVenitAsociere(VenitAsociereRecord venit) async {
    await _bridge.queueVenitAsociereUpsert(venit.toMap());
  }

  Future<void> queueVenitAsociereDelete(String venitId) async {
    await _bridge.queueVenitAsociereDelete(venitId);
  }

  Future<void> queueDecontLunarAsociere(
      DecontLunarAsociereRecord decont) async {
    await _bridge.queueDecontLunarAsociereUpsert(decont.toMap());
  }

  Future<void> queueDecontLunarAsociereDelete(String decontId) async {
    await _bridge.queueDecontLunarAsociereDelete(decontId);
  }

  Future<void> queueDeplasareAsociere(DeplasareAsociereRecord value) async {
    await _bridge.queueDeplasareAsociereUpsert(value.toMap());
  }

  Future<void> queueDeplasareAsociereDelete(String id) async {
    await _bridge.queueDeplasareAsociereDelete(id);
  }

  Future<void> queueCazareAsociere(CazareAsociereRecord value) async {
    await _bridge.queueCazareAsociereUpsert(value.toMap());
  }

  Future<void> queueCazareAsociereDelete(String id) async {
    await _bridge.queueCazareAsociereDelete(id);
  }

  Future<void> queueDiurnaAsociere(DiurnaAsociereRecord value) async {
    await _bridge.queueDiurnaAsociereUpsert(value.toMap());
  }

  Future<void> queueDiurnaAsociereDelete(String id) async {
    await _bridge.queueDiurnaAsociereDelete(id);
  }

  /// Curăță imediat coada: elimină itemele deja sincronizate și cele moarte.
  /// Se apelează la startup pentru a elibera rapid JSON-ul acumulat.
  Future<void> cleanupQueue() async {
    await _queueRepository.clearStale(maxRetries: _maxRetryAttempts);
  }

  Future<bool> syncPending({bool force = false}) async {
    final now = DateTime.now();
    if (_isSyncing) {
      if (_lastSyncSkipLoggedAt == null ||
          now.difference(_lastSyncSkipLoggedAt!) > const Duration(seconds: 2)) {
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
    if (!force &&
        lastSyncActivityAt != null &&
        now.difference(lastSyncActivityAt) < _minSyncGap) {
      if (_lastSyncSkipLoggedAt == null ||
          now.difference(_lastSyncSkipLoggedAt!) > const Duration(seconds: 2)) {
        debugPrint('[Programari] cloud sync skip reason=cooldown');
        _lastSyncSkipLoggedAt = now;
      }
      return false;
    }
    final stopwatch = Stopwatch()..start();
    _isSyncing = true;
    _lastSyncStartedAt = now;
    _lastSyncError = null;
    _lastSyncFailedItems = 0;
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
      final appointmentMaterialKitRepository =
          FirebaseProgramareKitRepository();
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
            case CloudEntityType.partnerSettlements:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.partnerSettlements)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.partnerSettlements)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.devizArticoleTemplate:
              final templateRepo = DevizArticolTemplateRepository();
              if (item.deleted) {
                await templateRepo.deleteFromFirebase(item.entityId);
              } else {
                final template = DevizArticolTemplate.fromMap(item.payload);
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
            case CloudEntityType.employeePayEntries:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.employeePayEntries)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.employeePayEntries)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.employeePayments:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.employeePayments)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.employeePayments)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.employeeFinancialSummary:
              if (!item.deleted) {
                final empId =
                    (item.payload['employee_id'] ?? item.entityId).toString();
                if (empId.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection(FirebaseCollections.employeeFinancialSummary)
                      .doc(empId)
                      .set(item.payload, SetOptions(merge: true));
                }
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.employeeSettings:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.employeeSettings)
                    .doc(item.entityId)
                    .delete();
              } else {
                final empId =
                    (item.payload['employee_id'] ?? item.entityId).toString();
                if (empId.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection(FirebaseCollections.employeeSettings)
                      .doc(empId)
                      .set(item.payload, SetOptions(merge: true));
                }
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.hrPayrollPayments:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.hrPayrollPayments)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.hrPayrollPayments)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.stocItems:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.stocItems)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.stocItems)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.stocMiscari:
              if (!item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.stocMiscari)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.gpsCheckins:
              if (!item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.gpsCheckins)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.echipamenteInstalate:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.echipamenteInstalate)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.echipamenteInstalate)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.crmRecords:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.crmRecords)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.crmRecords)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.obiectiveLunare:
              if (!item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.obiectiveLunare)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.partners:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.partners)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.partners)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.partnerWorkers:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.partnerWorkers)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.partnerWorkers)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.partnerVehicles:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.partnerVehicles)
                    .doc(item.entityId)
                    .delete();
              } else {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.partnerVehicles)
                    .doc(item.entityId)
                    .set(item.payload, SetOptions(merge: true));
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.lucrariAsociere:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.lucrariAsociere)
                    .doc(item.entityId)
                    .delete();
              } else {
                await _syncVersionedAsociereItem(
                  item,
                  FirebaseCollections.lucrariAsociere,
                );
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.asocieri:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.asocieri)
                    .doc(item.entityId)
                    .delete();
              } else {
                await _syncVersionedAsociereItem(
                  item,
                  FirebaseCollections.asocieri,
                );
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.tarifeAsociere:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.tarifeAsociere)
                    .doc(item.entityId)
                    .delete();
              } else {
                await _syncVersionedAsociereItem(
                  item,
                  FirebaseCollections.tarifeAsociere,
                );
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.pontajeAsociere:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.pontajeAsociere)
                    .doc(item.entityId)
                    .delete();
              } else {
                await _syncVersionedAsociereItem(
                  item,
                  FirebaseCollections.pontajeAsociere,
                );
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.costuriAsociere:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.costuriAsociere)
                    .doc(item.entityId)
                    .delete();
              } else {
                await _syncVersionedAsociereItem(
                  item,
                  FirebaseCollections.costuriAsociere,
                );
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.venituriAsociere:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.venituriAsociere)
                    .doc(item.entityId)
                    .delete();
              } else {
                await _syncVersionedAsociereItem(
                  item,
                  FirebaseCollections.venituriAsociere,
                );
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.deconturiLunareAsociere:
              if (item.deleted) {
                await FirebaseFirestore.instance
                    .collection(FirebaseCollections.deconturiLunareAsociere)
                    .doc(item.entityId)
                    .delete();
              } else {
                await _syncVersionedAsociereItem(
                  item,
                  FirebaseCollections.deconturiLunareAsociere,
                );
              }
              await _queueRepository.markItemSynced(item.id, DateTime.now());
              break;
            case CloudEntityType.deplasariAsociere:
            case CloudEntityType.cazariAsociere:
            case CloudEntityType.diurneAsociere:
              final collection = switch (item.entityType) {
                CloudEntityType.deplasariAsociere =>
                  FirebaseCollections.deplasariAsociere,
                CloudEntityType.cazariAsociere =>
                  FirebaseCollections.cazariAsociere,
                CloudEntityType.diurneAsociere =>
                  FirebaseCollections.diurneAsociere,
                _ => throw StateError('Tip logistic Asociere necunoscut'),
              };
              final reference = FirebaseFirestore.instance
                  .collection(collection)
                  .doc(item.entityId);
              if (item.deleted) {
                await reference.delete();
              } else {
                await _syncVersionedAsociereItem(item, collection);
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
          if (_isAsociereEntity(item.entityType)) {
            _lastSyncFailedItems++;
            _lastSyncError = error is StateError
                ? error.message.toString()
                : 'O operație Asociere nu s-a putut sincroniza.';
          }
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

  Future<void> _syncVersionedAsociereItem(
    CloudSyncItem item,
    String collection,
  ) async {
    final revision = (item.payload['revision'] as num?)?.toInt();
    if (revision == null || revision < 1) {
      throw StateError('Operație respinsă: revizie locală invalidă.');
    }
    final reference =
        FirebaseFirestore.instance.collection(collection).doc(item.entityId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        if (revision != 1) {
          throw StateError(
            'Conflict de sincronizare: documentul remote lipsește pentru revizia $revision.',
          );
        }
        transaction.set(reference, item.payload);
        return;
      }

      final remote = snapshot.data() ?? const <String, dynamic>{};
      final remoteRevision = (remote['revision'] as num?)?.toInt();
      if (remoteRevision == revision && _deepEquals(remote, item.payload)) {
        return;
      }
      if (remoteRevision == null || remoteRevision + 1 != revision) {
        throw StateError(
          'Conflict de sincronizare: revizia remote nu corespunde reviziei locale.',
        );
      }
      transaction.set(reference, item.payload);
    });
  }

  bool _deepEquals(Object? left, Object? right) {
    if (identical(left, right) || left == right) return true;
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final key in left.keys) {
        if (!right.containsKey(key) || !_deepEquals(left[key], right[key])) {
          return false;
        }
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (!_deepEquals(left[index], right[index])) return false;
      }
      return true;
    }
    return false;
  }

  bool _isAsociereEntity(CloudEntityType type) => switch (type) {
        CloudEntityType.lucrariAsociere ||
        CloudEntityType.asocieri ||
        CloudEntityType.tarifeAsociere ||
        CloudEntityType.pontajeAsociere ||
        CloudEntityType.costuriAsociere ||
        CloudEntityType.venituriAsociere ||
        CloudEntityType.deconturiLunareAsociere ||
        CloudEntityType.deplasariAsociere ||
        CloudEntityType.cazariAsociere ||
        CloudEntityType.diurneAsociere =>
          true,
        _ => false,
      };

  DateTime _computeNextRetryAt({
    required DateTime attemptedAt,
    required int retryCount,
  }) {
    // Exponential backoff capped at 30 minutes.
    final seconds = (30 * (1 << (retryCount - 1))).clamp(30, 1800);
    return attemptedAt.add(Duration(seconds: seconds));
  }
}
