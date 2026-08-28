import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/auth_models.dart';
import 'package:devizpro_ultra/core/company_profile.dart';
import 'package:devizpro_ultra/core/lookup_models.dart';
import 'package:devizpro_ultra/core/repositories/app_data_repository.dart';
import 'package:devizpro_ultra/core/team_models.dart';
import 'package:devizpro_ultra/features/clients/client_models.dart';
import 'package:devizpro_ultra/features/hr_deplasari/trip_models.dart';
import 'package:devizpro_ultra/features/jobs/job_models.dart';
import 'package:devizpro_ultra/features/partners/partner_models.dart';
import 'package:devizpro_ultra/features/programari/appointment_models.dart';
import 'package:devizpro_ultra/features/registratura/registry_models.dart';
import 'package:devizpro_ultra/features/jobs/services/pontaj_fisa_all_partners_service.dart';
import 'package:devizpro_ultra/features/jobs/services/pontaj_fisa_cross_job_service.dart';

/// FIX 1 (aug 2026): confirmă că numele partenerului se rezolvă din
/// `job.jobPartners` (entități JobPartner EMBEDATE per lucrare, id format
/// `job-partner-<timestamp>`) — NU din `repository.listPartners()`
/// (colecția globală PartnerRecord, spațiu de ID diferit, NICIODATĂ
/// compatibil cu `JobPartnerWorker.partnerId`).
///
/// `repository.listPartners()` e stubat aici să întoarcă intenționat o
/// listă cu ID-uri COMPLET diferite de cele din `job.jobPartners` — dacă
/// vreun cod ar reveni din greșeală la vechea sursă (colecția globală),
/// testul ar eșua imediat (numele ar rămâne gol).
class _FakeRepository extends AppDataRepository {
  _FakeRepository({required this.jobs});

  final List<JobRecord> jobs;

  @override
  Future<List<JobRecord>> listJobs() async => jobs;

  @override
  Future<List<PartnerRecord>> listPartners() async => [
        PartnerRecord(
          id: 'partner-record-global-999',
          name: 'NU AR TREBUI SA APARA NICIODATA',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];

  @override
  Future<CompanyProfile> loadCompanyProfile() async =>
      const CompanyProfile(companyName: 'PRO TERM SRL (test)');

  Never _unused(String name) =>
      throw UnimplementedError('$name neapelat in acest test');

  @override
  Future<AppUser?> loadCurrentUser() => _unused('loadCurrentUser');
  @override
  Future<void> saveCurrentUser(AppUser? user) => _unused('saveCurrentUser');
  @override
  Future<List<Appointment>> listAppointments() => _unused('listAppointments');
  @override
  Future<void> saveAppointment(Appointment appointment) =>
      _unused('saveAppointment');
  @override
  Future<void> deleteAppointment(String appointmentId) =>
      _unused('deleteAppointment');
  @override
  Future<List<Team>> listTeams() => _unused('listTeams');
  @override
  Future<void> saveTeam(Team team) => _unused('saveTeam');
  @override
  Future<void> deleteTeam(String teamId) => _unused('deleteTeam');
  @override
  Future<List<Trip>> listTrips() => _unused('listTrips');
  @override
  Future<void> saveTrip(Trip trip) => _unused('saveTrip');
  @override
  Future<void> deleteTrip(String tripId) => _unused('deleteTrip');
  @override
  Future<List<TravelOrder>> listTravelOrders() => _unused('listTravelOrders');
  @override
  Future<void> saveTravelOrder(TravelOrder order) =>
      _unused('saveTravelOrder');
  @override
  Future<void> deleteTravelOrder(String orderId) =>
      _unused('deleteTravelOrder');
  @override
  Future<List<ClientRecord>> listClients() => _unused('listClients');
  @override
  Future<ClientRecord> saveClient(ClientRecord client) =>
      _unused('saveClient');
  @override
  Future<void> deleteClient(String clientId) => _unused('deleteClient');
  @override
  Future<String> nextClientCode() => _unused('nextClientCode');
  @override
  Future<List<LookupItem>> listClientsLookup() => _unused('listClientsLookup');
  @override
  Future<List<EmployeeLookup>> listEmployeesLookup() =>
      _unused('listEmployeesLookup');
  @override
  Future<List<LookupItem>> listVehiclesLookup() =>
      _unused('listVehiclesLookup');
  @override
  Future<void> saveCompanyProfile(CompanyProfile profile) =>
      _unused('saveCompanyProfile');
  @override
  Future<List<RegistryEntry>> listRegistryEntries() =>
      _unused('listRegistryEntries');
  @override
  Future<void> saveRegistryEntry(RegistryEntry entry) =>
      _unused('saveRegistryEntry');
  @override
  Future<void> deleteRegistryEntry(String entryId) =>
      _unused('deleteRegistryEntry');
  @override
  Future<RegistrySettings> loadRegistrySettings() =>
      _unused('loadRegistrySettings');
  @override
  Future<void> saveRegistrySettings(RegistrySettings settings) =>
      _unused('saveRegistrySettings');
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
  }) =>
      _unused('registerGeneratedDocument');
}

Map<String, dynamic> _jobPartner({
  required String id,
  required String jobId,
  required String name,
}) =>
    {'id': id, 'jobId': jobId, 'name': name};

Map<String, dynamic> _jobPartnerWorker({
  required String id,
  required String jobId,
  required String partnerId,
  required String fullName,
  required DateTime date,
  double workedHours = 8,
  double hourlyRate = 50,
}) =>
    {
      'id': id,
      'jobId': jobId,
      'partnerId': partnerId,
      'fullName': fullName,
      'workedHours': workedHours,
      'hoursPerDay': 8,
      'workPeriodStart': date.toIso8601String(),
      'workPeriodEnd': date.toIso8601String(),
      'hourlyRate': hourlyRate,
    };

void main() {
  JobRecord buildJob({
    required String id,
    required String jobCode,
    required List<Map<String, dynamic>> jobPartners,
    required List<Map<String, dynamic>> jobPartnerWorkers,
  }) {
    return JobRecord.fromMap({
      'id': id,
      'job_code': jobCode,
      'title': 'Lucrare test $jobCode',
      'job_partners': jobPartners,
      'job_partner_workers': jobPartnerWorkers,
    });
  }

  group('buildPontajFisaAllPartnerRows — rezolvare nume partener (FIX 1)', () {
    test('numele partenerului se rezoleva din job.jobPartners, nu ramane gol',
        () async {
      final job = buildJob(
        id: 'job-1',
        jobCode: 'DVZ-2026-0001',
        jobPartners: [
          _jobPartner(id: 'job-partner-1784200843936853', jobId: 'job-1', name: 'ACME Instalatii SRL'),
        ],
        jobPartnerWorkers: [
          _jobPartnerWorker(
            id: 'w1',
            jobId: 'job-1',
            partnerId: 'job-partner-1784200843936853',
            fullName: 'Ion Popescu',
            date: DateTime(2026, 6, 10),
          ),
        ],
      );

      final repo = _FakeRepository(jobs: [job]);
      final result = await buildPontajFisaAllPartnerRows(
        repository: repo,
        periodStart: DateTime(2026, 6, 1),
        periodEnd: DateTime(2026, 6, 30),
      );

      expect(result.rows.length, 1);
      expect(result.rows.single.partenerNume, 'ACME Instalatii SRL',
          reason: 'NU trebuie sa ramana gol sau sa arate id-ul brut');
      expect(result.rows.single.partenerId, 'job-partner-1784200843936853');
    });

    test(
        'firma cu 2 JobPartner.id diferite pe 2 lucrari diferite -> fiecare '
        'rand isi rezolva propriul nume corect (fragmentarea de id ramane, '
        'dar numele NU mai e gol pe niciunul din fragmente)', () async {
      final jobA = buildJob(
        id: 'job-a',
        jobCode: 'DVZ-2026-0001',
        jobPartners: [
          _jobPartner(id: 'job-partner-aaa', jobId: 'job-a', name: 'ACME Instalatii SRL'),
        ],
        jobPartnerWorkers: [
          _jobPartnerWorker(
            id: 'wa',
            jobId: 'job-a',
            partnerId: 'job-partner-aaa',
            fullName: 'Ion Popescu',
            date: DateTime(2026, 6, 9),
          ),
        ],
      );
      final jobB = buildJob(
        id: 'job-b',
        jobCode: 'DVZ-2026-0002',
        jobPartners: [
          // Aceeasi firma reala, dar adaugata separat pe lucrarea B ->
          // JobPartner.id DIFERIT (confirmat in investigatia anterioara,
          // partner_dialogs.dart:207 genereaza mereu un id nou).
          _jobPartner(id: 'job-partner-bbb', jobId: 'job-b', name: 'ACME Instalatii SRL'),
        ],
        jobPartnerWorkers: [
          _jobPartnerWorker(
            id: 'wb',
            jobId: 'job-b',
            partnerId: 'job-partner-bbb',
            fullName: 'Vasile Ionescu',
            date: DateTime(2026, 6, 10),
          ),
        ],
      );

      final repo = _FakeRepository(jobs: [jobA, jobB]);
      final result = await buildPontajFisaAllPartnerRows(
        repository: repo,
        periodStart: DateTime(2026, 6, 1),
        periodEnd: DateTime(2026, 6, 30),
      );

      expect(result.rows.length, 2);
      // Ambele rezolva corect numele, desi id-urile difera (fragmentare
      // separata, deja documentata — NU e scopul acestui fix).
      expect(result.rows.every((r) => r.partenerNume == 'ACME Instalatii SRL'),
          isTrue);
      expect(result.rows.map((r) => r.partenerId).toSet(),
          {'job-partner-aaa', 'job-partner-bbb'});
    });

    test('partener fara nume in job.jobPartners (lipsa) -> ramane gol, '
        'nu explodeaza', () async {
      final job = buildJob(
        id: 'job-2',
        jobCode: 'DVZ-2026-0003',
        jobPartners: const [], // JobPartner lipsa din lista (caz defensiv)
        jobPartnerWorkers: [
          _jobPartnerWorker(
            id: 'w2',
            jobId: 'job-2',
            partnerId: 'job-partner-necunoscut',
            fullName: 'Gheorghe Marin',
            date: DateTime(2026, 6, 11),
          ),
        ],
      );

      final repo = _FakeRepository(jobs: [job]);
      final result = await buildPontajFisaAllPartnerRows(
        repository: repo,
        periodStart: DateTime(2026, 6, 1),
        periodEnd: DateTime(2026, 6, 30),
      );

      expect(result.rows.single.partenerNume, '');
    });
  });

  group('buildPontajFisaCrossJob — rezolvare nume partener (FIX 1)', () {
    test('coloana Partener din fisa PDF cross-lucrare foloseste numele real',
        () async {
      final job = buildJob(
        id: 'job-3',
        jobCode: 'DVZ-2026-0004',
        jobPartners: [
          _jobPartner(id: 'job-partner-xyz', jobId: 'job-3', name: 'Beta Construct SRL'),
        ],
        jobPartnerWorkers: [
          _jobPartnerWorker(
            id: 'w3',
            jobId: 'job-3',
            partnerId: 'job-partner-xyz',
            fullName: 'Mihai Stan',
            date: DateTime(2026, 6, 12),
          ),
        ],
      );

      final repo = _FakeRepository(jobs: [job]);
      final result = await buildPontajFisaCrossJob(
        repository: repo,
        personaNume: 'Mihai Stan',
        periodStart: DateTime(2026, 6, 1),
        periodEnd: DateTime(2026, 6, 30),
      );

      expect(result.partnerRows.length, 1);
      expect(result.partnerRows.single.partenerNume, 'Beta Construct SRL');
    });
  });
}
