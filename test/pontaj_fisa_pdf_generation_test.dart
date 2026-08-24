import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/auth_models.dart';
import 'package:devizpro_ultra/core/company_profile.dart';
import 'package:devizpro_ultra/core/lookup_models.dart';
import 'package:devizpro_ultra/core/repositories/app_data_repository.dart';
import 'package:devizpro_ultra/core/team_models.dart';
import 'package:devizpro_ultra/features/clients/client_models.dart';
import 'package:devizpro_ultra/features/hr_deplasari/trip_models.dart';
import 'package:devizpro_ultra/features/jobs/job_models.dart';
import 'package:devizpro_ultra/features/jobs/job_partner_models.dart';
import 'package:devizpro_ultra/features/partners/partner_models.dart';
import 'package:devizpro_ultra/features/programari/appointment_models.dart';
import 'package:devizpro_ultra/features/registratura/registry_models.dart';
import 'package:devizpro_ultra/features/jobs/services/pontaj_fisa_aggregator.dart';
import 'package:devizpro_ultra/features/jobs/services/pontaj_fisa_cross_job_service.dart';
import 'package:devizpro_ultra/features/jobs/services/pontaj_fisa_pdf_service.dart';

/// `AppDataRepository` e `abstract class` cu implementări implicite pentru
/// majoritatea metodelor (`=> const []` etc.), dar 28 rămân strict
/// abstracte (fără corp implicit) — stub minim `UnimplementedError` pentru
/// acelea, nefolosite de codul testat aici (doar `listJobs`/`listPartners`/
/// `loadCompanyProfile` sunt apelate real de serviciile de pontaj).
class _FakeRepository extends AppDataRepository {
  _FakeRepository({
    required this.jobs,
    required this.partners,
  });

  final List<JobRecord> jobs;
  final List<PartnerRecord> partners;

  @override
  Future<List<JobRecord>> listJobs() async => jobs;

  @override
  Future<List<PartnerRecord>> listPartners() async => partners;

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pontaj_fisa_pdf_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  JobRecord buildJob({
    required String id,
    required String jobCode,
    required List<Map<String, dynamic>> laborEntries,
    required List<Map<String, dynamic>> jobPartnerWorkers,
  }) {
    return JobRecord.fromMap({
      'id': id,
      'job_code': jobCode,
      'title': 'Lucrare test $jobCode',
      'labor_entries': laborEntries,
      'job_partner_workers': jobPartnerWorkers,
    });
  }

  test(
      'PontajFisaPdfService.export scrie efectiv un fisier PDF pe disc (per lucrare)',
      () async {
    final repo = _FakeRepository(jobs: const [], partners: const []);

    final ownRows = buildPontajFisaOwnRows([
      {
        'who': 'Ion Popescu',
        'periodStartDate': DateTime(2026, 6, 10).toIso8601String(),
        'periodEndDate': DateTime(2026, 6, 10).toIso8601String(),
        'hoursPerDay': 8,
        'hours': 8,
        'hourlyRate': 50,
        'costOre': 400,
        'costDiurna': 0,
        'costCazare': 0,
      },
    ]);
    final partnerRows = buildPontajFisaPartnerRows([
      JobPartnerWorker(
        id: 'w1',
        jobId: 'job-1',
        partnerId: 'partner-1',
        fullName: 'Ana Dinu',
        workedHours: 8,
        hoursPerDay: 8,
        hourlyRate: 55,
        workPeriodStart: DateTime(2026, 6, 12),
        workPeriodEnd: DateTime(2026, 6, 12),
        workDays: 1,
        currency: 'RON',
      ),
    ], partnerNamesById: const {'partner-1': 'ACME SRL'});

    final path = await PontajFisaPdfService.export(
      repository: repo,
      documentTitle: 'FISA PONTAJ TEST',
      periodLabel: '10.06.2026 - 12.06.2026',
      ownRows: ownRows,
      partnerRows: partnerRows,
      fileNamePrefix: 'test_fisa_pontaj',
      outputDirectory: tempDir.path,
    );

    final file = File(path);
    expect(file.existsSync(), isTrue,
        reason: 'PDF-ul trebuie sa existe efectiv pe disc la calea returnata');
    final bytes = await file.readAsBytes();
    expect(bytes.length, greaterThan(1000),
        reason: 'Fisierul PDF trebuie sa aiba continut real, nu gol/trunchiat');
    // Header PDF standard.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('buildPontajFisaCrossJob scaneaza toate lucrarile si aduna corect o singura persoana',
      () async {
    final jobA = buildJob(
      id: 'job-a',
      jobCode: 'DVZ-2026-0001',
      laborEntries: [
        {
          'who': 'Ion Popescu',
          'periodStartDate': DateTime(2026, 6, 5).toIso8601String(),
          'periodEndDate': DateTime(2026, 6, 5).toIso8601String(),
          'hoursPerDay': 8,
          'hours': 8,
          'hourlyRate': 50,
          'costOre': 400,
        },
        {
          // Alta persoana - NU trebuie sa apara in rezultat.
          'who': 'Alt Angajat',
          'periodStartDate': DateTime(2026, 6, 5).toIso8601String(),
          'periodEndDate': DateTime(2026, 6, 5).toIso8601String(),
          'hoursPerDay': 8,
          'hours': 8,
          'hourlyRate': 40,
          'costOre': 320,
        },
      ],
      jobPartnerWorkers: const [],
    );
    final jobB = buildJob(
      id: 'job-b',
      jobCode: 'DVZ-2026-0002',
      laborEntries: [
        {
          'who': 'Ion Popescu',
          'periodStartDate': DateTime(2026, 6, 20).toIso8601String(),
          'periodEndDate': DateTime(2026, 6, 20).toIso8601String(),
          'hoursPerDay': 6,
          'hours': 6,
          'hourlyRate': 50,
          'costOre': 300,
        },
      ],
      jobPartnerWorkers: const [],
    );
    final jobC = buildJob(
      id: 'job-c',
      jobCode: 'DVZ-2026-0003',
      laborEntries: [
        {
          // In afara perioadei ceruta (iulie, nu iunie) -> exclus.
          'who': 'Ion Popescu',
          'periodStartDate': DateTime(2026, 7, 1).toIso8601String(),
          'periodEndDate': DateTime(2026, 7, 1).toIso8601String(),
          'hoursPerDay': 8,
          'hours': 8,
          'hourlyRate': 50,
          'costOre': 400,
        },
      ],
      jobPartnerWorkers: const [],
    );

    final repo = _FakeRepository(
      jobs: [jobA, jobB, jobC],
      partners: const [],
    );

    final result = await buildPontajFisaCrossJob(
      repository: repo,
      personaNume: 'Ion Popescu',
      periodStart: DateTime(2026, 6, 1),
      periodEnd: DateTime(2026, 6, 30),
    );

    expect(result.jobsScanned, 3);
    expect(result.ownRows.length, 2); // job-a (5 iun) + job-b (20 iun)
    expect(result.ownRows.every((r) => r.persoanaNume == 'Ion Popescu'), isTrue);
    expect(result.ownRows.map((r) => r.jobCode),
        containsAll(['DVZ-2026-0001', 'DVZ-2026-0002']));
    expect(result.total, 400 + 300);

    // Fisa PDF agregata se genereaza real, pe disc, din rezultatul de mai sus.
    final path = await PontajFisaPdfService.export(
      repository: repo,
      documentTitle: 'FISA PONTAJ AGREGATA TEST',
      periodLabel: '01.06.2026 - 30.06.2026',
      ownRows: result.ownRows,
      partnerRows: result.partnerRows,
      showJobColumn: true,
      fileNamePrefix: 'test_fisa_agregata',
      outputDirectory: tempDir.path,
    );
    expect(File(path).existsSync(), isTrue);
  });
}
