import '../auth_models.dart';
import '../company_profile.dart';
import '../lookup_models.dart';
import '../team_models.dart';
import '../../features/agfr/agfr_models.dart';
import '../../features/clients/client_models.dart';
import '../../features/field_photos/field_photo_models.dart';
import '../../features/hr_monthly_timesheet/monthly_timesheet_models.dart';
import '../../features/hr_deplasari/trip_models.dart';
import '../../features/partners/partner_models.dart';
import '../../features/programari/appointment_models.dart';
import '../../features/reclamatii/complaint_document_models.dart';
import '../../features/reclamatii/complaint_models.dart';
import '../../features/reclamatii/repair_report_models.dart';
import '../../features/reclamatii/warranty_intervention_report_models.dart';
import '../../features/refrigerant_reporting/refrigerant_reporting_models.dart';
import '../../features/registratura/registry_models.dart';
import 'app_data_repository.dart';
import 'local_app_data_repository.dart';
import '../../features/jobs/job_models.dart';

final AppDataRepository _fallback = LocalAppDataRepository();

class CloudAppDataRepository implements AppDataRepository {
  const CloudAppDataRepository();

  UnsupportedError _unsupported() {
    return UnsupportedError(
      'Cloud repository este doar fundatie in aceasta etapa. '
      'Integrarea Supabase se activeaza ulterior.',
    );
  }

  @override
  Future<AppUser?> loadCurrentUser() async => null;

  @override
  Future<void> saveCurrentUser(AppUser? user) async => throw _unsupported();

  @override
  Future<List<Appointment>> listAppointments() async =>
      _fallback.listAppointments();

  @override
  Future<List<Appointment>> listAllAppointments() async =>
      _fallback.listAllAppointments();

  @override
  Future<void> saveAppointment(Appointment appointment) async =>
      _fallback.saveAppointment(appointment);

  @override
  Future<void> deleteAppointment(String appointmentId) async =>
      _fallback.deleteAppointment(appointmentId);

  @override
  Future<void> logAppointmentHistory({
    required String appointmentId,
    required String clientId,
    required String action,
    required String changedBy,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async =>
      _fallback.logAppointmentHistory(
        appointmentId: appointmentId,
        clientId: clientId,
        action: action,
        changedBy: changedBy,
        before: before,
        after: after,
      );

  @override
  Future<List<AgfrEquipmentRecord>> listAgfrEquipments() async =>
      _fallback.listAgfrEquipments();

  @override
  Future<void> saveAgfrEquipment(AgfrEquipmentRecord equipment) async =>
      _fallback.saveAgfrEquipment(equipment);

  @override
  Future<void> deleteAgfrEquipment(String equipmentId) async =>
      _fallback.deleteAgfrEquipment(equipmentId);

  @override
  Future<List<AgfrInterventionRecord>> listAgfrInterventions() async =>
      _fallback.listAgfrInterventions();

  @override
  Future<void> saveAgfrIntervention(
    AgfrInterventionRecord intervention,
  ) async =>
      _fallback.saveAgfrIntervention(intervention);

  @override
  Future<void> deleteAgfrIntervention(String interventionId) async =>
      _fallback.deleteAgfrIntervention(interventionId);

  @override
  Future<List<AgfrReportRecord>> listAgfrReports() async =>
      _fallback.listAgfrReports();

  @override
  Future<void> saveAgfrReport(AgfrReportRecord report) async =>
      _fallback.saveAgfrReport(report);

  @override
  Future<String> nextAgfrReportNumber({DateTime? issueDate}) async =>
      _fallback.nextAgfrReportNumber(issueDate: issueDate);

  @override
  Future<void> deleteAgfrReport(String reportId) async =>
      _fallback.deleteAgfrReport(reportId);

  @override
  Future<List<AgfrWeighingReportRecord>> listAgfrWeighingReports() async =>
      _fallback.listAgfrWeighingReports();

  @override
  Future<void> saveAgfrWeighingReport(
    AgfrWeighingReportRecord report,
  ) async =>
      _fallback.saveAgfrWeighingReport(report);

  @override
  Future<void> deleteAgfrWeighingReport(String reportId) async =>
      _fallback.deleteAgfrWeighingReport(reportId);

  @override
  Future<List<RefrigerantReportingRecord>>
      listRefrigerantReportingRecords() async =>
          _fallback.listRefrigerantReportingRecords();

  @override
  Future<void> saveRefrigerantReportingRecord(
    RefrigerantReportingRecord record,
  ) async =>
      _fallback.saveRefrigerantReportingRecord(record);

  @override
  Future<void> deleteRefrigerantReportingRecord(String recordId) async =>
      _fallback.deleteRefrigerantReportingRecord(recordId);

  @override
  Future<List<Team>> listTeams() async => const <Team>[];

  @override
  Future<void> saveTeam(Team team) async => throw _unsupported();

  @override
  Future<void> deleteTeam(String teamId) async => throw _unsupported();

  @override
  Future<List<Trip>> listTrips() async => const <Trip>[];

  @override
  Future<void> saveTrip(Trip trip) async => throw _unsupported();

  @override
  Future<void> deleteTrip(String tripId) async => throw _unsupported();

  @override
  Future<List<TravelOrder>> listTravelOrders() async => const <TravelOrder>[];

  @override
  Future<void> saveTravelOrder(TravelOrder order) async => throw _unsupported();

  @override
  Future<void> deleteTravelOrder(String orderId) async => throw _unsupported();

  @override
  Future<String> nextTravelOrderNumber({DateTime? issueDate}) async =>
      _fallback.nextTravelOrderNumber(issueDate: issueDate);

  @override
  Future<List<ComplaintRecord>> listComplaints() async =>
      _fallback.listComplaints();

  @override
  Future<void> saveComplaint(ComplaintRecord complaint) async =>
      _fallback.saveComplaint(complaint);

  @override
  Future<void> deleteComplaint(String complaintId) async =>
      _fallback.deleteComplaint(complaintId);

  @override
  Future<String> nextComplaintNumber() async => _fallback.nextComplaintNumber();

  @override
  Future<String> nextOfferNumber() async => _fallback.nextOfferNumber();

  @override
  Future<List<RepairReportRecord>> listRepairReports() async =>
      _fallback.listRepairReports();

  @override
  Future<void> saveRepairReport(RepairReportRecord report) async =>
      _fallback.saveRepairReport(report);

  @override
  Future<void> deleteRepairReport(String reportId) async =>
      _fallback.deleteRepairReport(reportId);

  @override
  Future<String> nextRepairReportNumber() async =>
      _fallback.nextRepairReportNumber();

  @override
  Future<List<WarrantyInterventionReportRecord>>
      listWarrantyInterventionReports() async =>
          _fallback.listWarrantyInterventionReports();

  @override
  Future<void> saveWarrantyInterventionReport(
    WarrantyInterventionReportRecord report,
  ) async =>
      _fallback.saveWarrantyInterventionReport(report);

  @override
  Future<void> deleteWarrantyInterventionReport(String reportId) async =>
      _fallback.deleteWarrantyInterventionReport(reportId);

  @override
  Future<String> nextWarrantyInterventionReportNumber() async =>
      _fallback.nextWarrantyInterventionReportNumber();

  @override
  Future<List<ComplaintClientCentralizerRecord>>
      listComplaintClientCentralizers() async =>
          _fallback.listComplaintClientCentralizers();

  @override
  Future<void> saveComplaintClientCentralizer(
    ComplaintClientCentralizerRecord record,
  ) async =>
      _fallback.saveComplaintClientCentralizer(record);

  @override
  Future<void> deleteComplaintClientCentralizer(String documentId) async =>
      _fallback.deleteComplaintClientCentralizer(documentId);

  @override
  Future<String> nextComplaintClientCentralizerNumber() async =>
      _fallback.nextComplaintClientCentralizerNumber();

  @override
  Future<List<ComplaintWorkOrderRecord>> listComplaintWorkOrders() async =>
      _fallback.listComplaintWorkOrders();

  @override
  Future<void> saveComplaintWorkOrder(ComplaintWorkOrderRecord record) async =>
      _fallback.saveComplaintWorkOrder(record);

  @override
  Future<void> deleteComplaintWorkOrder(String documentId) async =>
      _fallback.deleteComplaintWorkOrder(documentId);

  @override
  Future<String> nextComplaintWorkOrderNumber() async =>
      _fallback.nextComplaintWorkOrderNumber();

  @override
  Future<List<FieldPhotoRecord>> listFieldPhotos({
    String sourceModule = '',
    String sourceEntityId = '',
    String documentId = '',
  }) async =>
      _fallback.listFieldPhotos(
        sourceModule: sourceModule,
        sourceEntityId: sourceEntityId,
        documentId: documentId,
      );

  @override
  Future<List<FieldPhotoRecord>> listFieldPhotosLocalOnly({
    String sourceModule = '',
    String sourceEntityId = '',
    String documentId = '',
  }) async =>
      _fallback.listFieldPhotosLocalOnly(
        sourceModule: sourceModule,
        sourceEntityId: sourceEntityId,
        documentId: documentId,
      );

  @override
  Future<void> saveFieldPhoto(FieldPhotoRecord photo) async =>
      _fallback.saveFieldPhoto(photo);

  @override
  Future<void> deleteFieldPhoto(String photoId) async =>
      _fallback.deleteFieldPhoto(photoId);

  @override
  Future<int> countLocalFieldPhotos({
    String sourceModule = '',
    String sourceEntityId = '',
  }) async =>
      _fallback.countLocalFieldPhotos(
        sourceModule: sourceModule,
        sourceEntityId: sourceEntityId,
      );

  @override
  Future<List<MonthlyTimesheetRecord>> listMonthlyTimesheets() async =>
      _fallback.listMonthlyTimesheets();

  @override
  Future<void> saveMonthlyTimesheet(MonthlyTimesheetRecord record) async =>
      _fallback.saveMonthlyTimesheet(record);

  @override
  Future<void> deleteMonthlyTimesheet(String recordId) async =>
      _fallback.deleteMonthlyTimesheet(recordId);

  @override
  Future<List<ClientRecord>> listClients() async => _fallback.listClients();

  @override
  Future<ClientRecord> saveClient(ClientRecord client) async =>
      _fallback.saveClient(client);

  @override
  Future<void> deleteClient(String clientId) async =>
      _fallback.deleteClient(clientId);

  @override
  Future<String> nextClientCode() async => _fallback.nextClientCode();

  @override
  Future<List<PartnerRecord>> listPartners() async => _fallback.listPartners();

  @override
  Future<PartnerRecord> savePartner(PartnerRecord partner) async =>
      _fallback.savePartner(partner);

  @override
  Future<void> deletePartner(String partnerId) async =>
      _fallback.deletePartner(partnerId);

  @override
  Future<List<PartnerWorkerRecord>> listPartnerWorkers() async =>
      _fallback.listPartnerWorkers();

  @override
  Future<PartnerWorkerRecord> savePartnerWorker(
    PartnerWorkerRecord worker,
  ) async =>
      _fallback.savePartnerWorker(worker);

  @override
  Future<void> deletePartnerWorker(String workerId) async =>
      _fallback.deletePartnerWorker(workerId);

  @override
  Future<List<PartnerVehicleRecord>> listPartnerVehicles() async =>
      _fallback.listPartnerVehicles();

  @override
  Future<PartnerVehicleRecord> savePartnerVehicle(
    PartnerVehicleRecord vehicle,
  ) async =>
      _fallback.savePartnerVehicle(vehicle);

  @override
  Future<void> deletePartnerVehicle(String vehicleId) async =>
      _fallback.deletePartnerVehicle(vehicleId);

  @override
  Future<List<LookupItem>> listClientsLookup() async =>
      _fallback.listClientsLookup();

  @override
  Future<List<EmployeeLookup>> listEmployeesLookup() async =>
      const <EmployeeLookup>[];

  @override
  Future<List<LookupItem>> listVehiclesLookup() async =>
      _fallback.listVehiclesLookup();

  @override
  Future<CompanyProfile> loadCompanyProfile() async =>
      _fallback.loadCompanyProfile();

  @override
  Future<void> saveCompanyProfile(CompanyProfile profile) async =>
      _fallback.saveCompanyProfile(profile);

  @override
  Future<List<RegistryEntry>> listRegistryEntries() async =>
      _fallback.listRegistryEntries();

  @override
  Future<void> saveRegistryEntry(RegistryEntry entry) async =>
      _fallback.saveRegistryEntry(entry);

  @override
  Future<void> deleteRegistryEntry(String entryId) async =>
      _fallback.deleteRegistryEntry(entryId);

  @override
  Future<RegistrySettings> loadRegistrySettings() async =>
      _fallback.loadRegistrySettings();

  @override
  Future<void> saveRegistrySettings(RegistrySettings settings) async =>
      _fallback.saveRegistrySettings(settings);

  @override
  Future<RegistryEntry> registerGeneratedDocument({
    required RegistryType registryType,
    required String documentCategory,
    required String documentTitle,
    required String documentNumber,
    DateTime? documentDate,
    String issuerName = '',
    String recipientName = '',
    String clientId = '',
    String jobId = '',
    String offerId = '',
    String estimateId = '',
    String contractId = '',
    String ticketId = '',
    String filePath = '',
    String fileName = '',
    String notes = '',
    String status = '',
  }) async =>
      _fallback.registerGeneratedDocument(
        registryType: registryType,
        documentCategory: documentCategory,
        documentTitle: documentTitle,
        documentNumber: documentNumber,
        documentDate: documentDate,
        issuerName: issuerName,
        recipientName: recipientName,
        clientId: clientId,
        jobId: jobId,
        offerId: offerId,
        estimateId: estimateId,
        contractId: contractId,
        ticketId: ticketId,
        filePath: filePath,
        fileName: fileName,
        notes: notes,
        status: status,
      );
  @override
  Future<List<JobRecord>> listJobs() async {
    return _fallback.listJobs();
  }

  @override
  Future<JobRecord> saveJob(JobRecord job) async {
    return _fallback.saveJob(job);
  }

  @override
  Future<void> deleteJob(String jobId) async {
    return _fallback.deleteJob(jobId);
  }

  @override
  Future<String> nextJobCode() async {
    return _fallback.nextJobCode();
  }

  @override
  Future<List<LookupItem>> listJobsLookup() async {
    return _fallback.listJobsLookup();
  }
}
