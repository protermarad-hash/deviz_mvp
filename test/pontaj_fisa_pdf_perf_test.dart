import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/company_profile.dart';
import 'package:devizpro_ultra/core/auth_models.dart';
import 'package:devizpro_ultra/core/lookup_models.dart';
import 'package:devizpro_ultra/core/repositories/app_data_repository.dart';
import 'package:devizpro_ultra/core/team_models.dart';
import 'package:devizpro_ultra/features/clients/client_models.dart';
import 'package:devizpro_ultra/features/hr_deplasari/trip_models.dart';
import 'package:devizpro_ultra/features/jobs/job_models.dart';
import 'package:devizpro_ultra/features/partners/partner_models.dart';
import 'package:devizpro_ultra/features/programari/appointment_models.dart';
import 'package:devizpro_ultra/features/registratura/registry_models.dart';
import 'package:devizpro_ultra/features/jobs/services/pontaj_fisa_aggregator.dart';
import 'package:devizpro_ultra/features/jobs/services/pontaj_fisa_pdf_service.dart';

/// Test de MĂSURARE REALĂ (nu doar analiza de cod) a ipotezei: generarea
/// fisei de pontaj cu multe randuri (fisa cross-lucrare / all-partners)
/// devine extrem de costisitoare pentru ca `ProTermPdfTemplate.buildTable()`
/// construieste antetul+toate randurile+totalul intr-un SINGUR widget
/// monolitic (pw.Container/pw.Column), care NU e "spanning" pentru pachetul
/// `pdf` (^3.11.3) si deci nu poate fi despartit automat pe pagini de catre
/// pw.MultiPage.
///
/// Genereaza date SINTETICE (500/1000/2000 randuri) si cronometreaza
/// PontajFisaPdfService.export() direct (acelasi cod folosit de fisa reala),
/// bypassand scanarea de lucrari din Firestore (nerelevanta pentru ipoteza —
/// suspectul e layout-ul PDF, nu citirea datelor).
class _FakeRepository extends AppDataRepository {
  @override
  Future<List<JobRecord>> listJobs() async => const [];
  @override
  Future<List<PartnerRecord>> listPartners() async => const [];
  @override
  Future<CompanyProfile> loadCompanyProfile() async =>
      const CompanyProfile(companyName: 'PRO TERM SRL (test perf)');

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

List<PontajFisaRow> _syntheticPartnerRows(int count) {
  final base = DateTime(2026, 1, 5);
  return List.generate(count, (i) {
    final day = base.add(Duration(days: i % 300));
    return PontajFisaRow(
      persoanaNume: 'Muncitor test ${i + 1}',
      esteProprie: false,
      partenerId: 'partner-${i % 12}',
      partenerNume: 'Partener SRL ${i % 12}',
      rol: 'Tehnician',
      jobCode: 'DVZ-2026-${(i % 500).toString().padLeft(4, '0')}',
      jobTitle: 'Lucrare test ${i % 500}',
      dataStart: day,
      dataEnd: day,
      orePeZi: 8,
      oreTotale: 8,
      tarifOrar: 45 + (i % 20),
      costOre: 8 * (45 + (i % 20)),
      costDiurna: (i % 3 == 0) ? 50 : 0,
      costCazare: (i % 5 == 0) ? 120 : 0,
      moneda: 'RON',
    );
  }, growable: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pontaj_fisa_pdf_perf_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // Sub limita `maxTotalRows` (600) — trebuie sa genereze PDF real, in timp
  // rezonabil (nu doar "nu arunca exceptie" — masuram si timpul, ca sa
  // prindem o eventuala regresie de performanta viitoare).
  for (final rowCount in [10, 20, 30, 50, 100, 500]) {
    test(
      'PERF: PontajFisaPdfService.export cu $rowCount randuri partener sintetice genereaza PDF valid',
      () async {
        final repo = _FakeRepository();
        final rows = _syntheticPartnerRows(rowCount);

        final sw = Stopwatch()..start();
        final path = await PontajFisaPdfService.export(
          repository: repo,
          documentTitle: 'FISA PONTAJ PERF TEST',
          periodLabel: '01.01.2026 - 31.12.2026',
          ownRows: const [],
          partnerRows: rows,
          showJobColumn: true,
          fileNamePrefix: 'perf_fisa_pontaj_$rowCount',
          outputDirectory: tempDir.path,
        );
        sw.stop();

        final file = File(path);
        final sizeKb = file.existsSync()
            ? (file.lengthSync() / 1024).toStringAsFixed(1)
            : 'N/A';

        // ignore: avoid_print
        print(
          '[PERF] $rowCount randuri -> ${sw.elapsedMilliseconds} ms '
          '(${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)} s), '
          'fisier: $sizeKb KB',
        );

        expect(file.existsSync(), isTrue,
            reason: 'PDF-ul trebuie generat efectiv la $rowCount randuri');
        final bytes = await file.readAsBytes();
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        // Plasa anti-regresie: sub 500 randuri, generarea trebuie sa ramana
        // rapida (sub 10s) — daca urca mult peste asta, e semn ca defectul
        // de paginare (widget monolitic nesplitabil) a reaparut.
        expect(sw.elapsed, lessThan(const Duration(seconds: 10)),
            reason:
                'Generarea la $rowCount randuri a devenit neasteptat de lenta '
                '(posibila regresie a fixului de paginare)');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }

  // Peste limita `maxTotalRows` — trebuie sa esueze RAPID si CURAT, cu mesaj
  // clar, nu sa incerce sa genereze un PDF foarte lent/blocant.
  for (final rowCount in [1000, 2000]) {
    test(
      'PERF: PontajFisaPdfService.export cu $rowCount randuri respinge rapid cu mesaj clar',
      () async {
        final repo = _FakeRepository();
        final rows = _syntheticPartnerRows(rowCount);

        final sw = Stopwatch()..start();
        Object? caught;
        try {
          await PontajFisaPdfService.export(
            repository: repo,
            documentTitle: 'FISA PONTAJ PERF TEST',
            periodLabel: '01.01.2026 - 31.12.2026',
            ownRows: const [],
            partnerRows: rows,
            showJobColumn: true,
            fileNamePrefix: 'perf_fisa_pontaj_$rowCount',
            outputDirectory: tempDir.path,
          );
        } catch (e) {
          caught = e;
        }
        sw.stop();

        // ignore: avoid_print
        print('[PERF] $rowCount randuri -> respins in ${sw.elapsedMilliseconds} ms: $caught');

        expect(caught, isA<PontajFisaTooManyRowsException>(),
            reason: 'Peste limita configurata trebuie respins curat, nu sa '
                'incerce generarea (care ar bloca vizual aplicatia)');
        expect(sw.elapsed, lessThan(const Duration(seconds: 1)),
            reason: 'Respingerea trebuie sa fie instantanee (verificare de '
                'numar de randuri, inainte de orice layout PDF)');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}
