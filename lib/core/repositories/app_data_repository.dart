import '../auth_models.dart';
import '../company_profile.dart';
import '../lookup_models.dart';
import '../team_models.dart';
import '../../features/clients/client_models.dart';
import '../../features/agfr/agfr_models.dart';
import '../../features/hr_deplasari/trip_models.dart';
import '../../features/jobs/job_models.dart';
import '../../features/partners/partner_models.dart';
import '../../features/programari/appointment_models.dart';
import '../../features/reclamatii/complaint_models.dart';
import '../../features/reclamatii/complaint_document_models.dart';
import '../../features/field_photos/field_photo_models.dart';
import '../../features/hr_monthly_timesheet/monthly_timesheet_models.dart';
import '../../features/reclamatii/repair_report_models.dart';
import '../../features/reclamatii/warranty_intervention_report_models.dart';
import '../../features/refrigerant_reporting/refrigerant_reporting_models.dart';
import '../../features/registratura/registry_models.dart';

abstract class AppDataRepository {
  Future<AppUser?> loadCurrentUser();
  Future<void> saveCurrentUser(AppUser? user);

  Future<List<Appointment>> listAppointments();
  // Încarcă TOT istoricul (fără filtru de dată) — pentru rapoarte sau "Arată tot"
  Future<List<Appointment>> listAllAppointments() => listAppointments();
  Future<void> saveAppointment(Appointment appointment);
  Future<void> deleteAppointment(String appointmentId);
  Future<void> logAppointmentHistory({
    required String appointmentId,
    required String clientId,
    required String action,
    required String changedBy,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {}

  Future<List<AgfrEquipmentRecord>> listAgfrEquipments() async => const [];
  Future<void> saveAgfrEquipment(AgfrEquipmentRecord equipment) async {}
  Future<void> deleteAgfrEquipment(String equipmentId) async {}

  Future<List<AgfrInterventionRecord>> listAgfrInterventions() async =>
      const [];
  Future<void> saveAgfrIntervention(
      AgfrInterventionRecord intervention) async {}
  Future<void> deleteAgfrIntervention(String interventionId) async {}

  Future<List<AgfrReportRecord>> listAgfrReports() async => const [];
  Future<void> saveAgfrReport(AgfrReportRecord report) async {}
  Future<void> deleteAgfrReport(String reportId) async {}
  Future<String> nextAgfrReportNumber({DateTime? issueDate}) async =>
      'AGFR-${DateTime.now().year}-0001';

  Future<List<AgfrWeighingReportRecord>> listAgfrWeighingReports() async =>
      const [];
  Future<void> saveAgfrWeighingReport(
    AgfrWeighingReportRecord report,
  ) async {}
  Future<void> deleteAgfrWeighingReport(String reportId) async {}

  Future<List<RefrigerantReportingRecord>>
      listRefrigerantReportingRecords() async => const [];
  Future<void> saveRefrigerantReportingRecord(
    RefrigerantReportingRecord record,
  ) async {}
  Future<void> deleteRefrigerantReportingRecord(String recordId) async {}

  Future<List<Team>> listTeams();
  Future<void> saveTeam(Team team);
  Future<void> deleteTeam(String teamId);

  Future<List<Trip>> listTrips();
  Future<void> saveTrip(Trip trip);
  Future<void> deleteTrip(String tripId);

  Future<List<TravelOrder>> listTravelOrders();
  Future<void> saveTravelOrder(TravelOrder order);
  Future<void> deleteTravelOrder(String orderId);
  Future<String> nextTravelOrderNumber({DateTime? issueDate}) async =>
      'ORD-${DateTime.now().year}-0001';

  Future<List<ComplaintRecord>> listComplaints() async => const [];
  Future<void> saveComplaint(ComplaintRecord complaint) async {}
  Future<void> deleteComplaint(String complaintId) async {}
  Future<String> nextComplaintNumber() async => 'REC-0001';
  Future<String> nextOfferNumber() async => 'OFR-0001';

  Future<List<RepairReportRecord>> listRepairReports() async => const [];
  Future<void> saveRepairReport(RepairReportRecord report) async {}
  Future<void> deleteRepairReport(String reportId) async {}
  Future<String> nextRepairReportNumber() async => 'PVR-0001';

  Future<List<WarrantyInterventionReportRecord>>
      listWarrantyInterventionReports() async =>
          const <WarrantyInterventionReportRecord>[];
  Future<void> saveWarrantyInterventionReport(
    WarrantyInterventionReportRecord report,
  ) async {}
  Future<void> deleteWarrantyInterventionReport(String reportId) async {}
  Future<String> nextWarrantyInterventionReportNumber() async => 'PVG-0001';

  Future<List<ComplaintClientCentralizerRecord>>
      listComplaintClientCentralizers() async =>
          const <ComplaintClientCentralizerRecord>[];
  Future<void> saveComplaintClientCentralizer(
    ComplaintClientCentralizerRecord record,
  ) async {}
  Future<void> deleteComplaintClientCentralizer(String documentId) async {}
  Future<String> nextComplaintClientCentralizerNumber() async => 'CTR-0001';

  Future<List<ComplaintWorkOrderRecord>> listComplaintWorkOrders() async =>
      const <ComplaintWorkOrderRecord>[];
  Future<void> saveComplaintWorkOrder(ComplaintWorkOrderRecord record) async {}
  Future<void> deleteComplaintWorkOrder(String documentId) async {}
  Future<String> nextComplaintWorkOrderNumber() async => 'CMD-0001';

  Future<List<FieldPhotoRecord>> listFieldPhotos({
    String sourceModule = '',
    String sourceEntityId = '',
    String documentId = '',
  }) async =>
      const <FieldPhotoRecord>[];

  /// Versiune rapidă: returnează DOAR din cache local, fără query Firestore.
  /// Folosită pentru badge-uri/contoare unde nu e nevoie de date cross-device.
  Future<List<FieldPhotoRecord>> listFieldPhotosLocalOnly({
    String sourceModule = '',
    String sourceEntityId = '',
    String documentId = '',
  }) async =>
      const <FieldPhotoRecord>[];
  Future<void> saveFieldPhoto(FieldPhotoRecord photo) async {}
  Future<void> deleteFieldPhoto(String photoId) async {}
  /// Returnează câte poze sunt în cache-ul LOCAL pentru o entitate (fără Firestore).
  Future<int> countLocalFieldPhotos({
    String sourceModule = '',
    String sourceEntityId = '',
  }) async => 0;

  Future<List<MonthlyTimesheetRecord>> listMonthlyTimesheets() async =>
      const <MonthlyTimesheetRecord>[];
  Future<void> saveMonthlyTimesheet(MonthlyTimesheetRecord record) async {}
  Future<void> deleteMonthlyTimesheet(String recordId) async {}

  Future<List<ClientRecord>> listClients();
  Future<ClientRecord> saveClient(ClientRecord client);
  Future<void> deleteClient(String clientId);
  Future<String> nextClientCode();
  Future<List<PartnerRecord>> listPartners() async => const [];
  Future<PartnerRecord> savePartner(PartnerRecord partner) async => partner;
  Future<void> deletePartner(String partnerId) async {}
  Future<List<PartnerWorkerRecord>> listPartnerWorkers() async => const [];
  Future<PartnerWorkerRecord> savePartnerWorker(
    PartnerWorkerRecord worker,
  ) async =>
      worker;
  Future<void> deletePartnerWorker(String workerId) async {}
  Future<List<PartnerVehicleRecord>> listPartnerVehicles() async => const [];
  Future<PartnerVehicleRecord> savePartnerVehicle(
    PartnerVehicleRecord vehicle,
  ) async =>
      vehicle;
  Future<void> deletePartnerVehicle(String vehicleId) async {}

  Future<List<JobRecord>> listJobs() async => const [];
  Future<JobRecord> saveJob(JobRecord job) async => job;
  Future<void> deleteJob(String jobId) async {}
  Future<String> nextJobCode() async => 'JOB-0001';
  Future<List<LookupItem>> listJobsLookup() async => const [];

  Future<List<LookupItem>> listClientsLookup();
  Future<List<EmployeeLookup>> listEmployeesLookup();
  Future<List<LookupItem>> listVehiclesLookup();

  Future<CompanyProfile> loadCompanyProfile();
  Future<void> saveCompanyProfile(CompanyProfile profile);

  Future<List<RegistryEntry>> listRegistryEntries();
  Future<void> saveRegistryEntry(RegistryEntry entry);
  Future<void> deleteRegistryEntry(String entryId);
  Future<RegistrySettings> loadRegistrySettings();
  Future<void> saveRegistrySettings(RegistrySettings settings);
  Future<RegistryEntry> registerGeneratedDocument({
    required RegistryType registryType,
    required String documentCategory,
    required String documentTitle,
    required String documentNumber,
    DateTime? documentDate,
    String issuerName,
    String recipientName,
    String clientId,
    String jobId,
    String offerId,
    String estimateId,
    String contractId,
    String ticketId,
    String filePath,
    String fileName,
    String notes,
    String status,
  });
}
