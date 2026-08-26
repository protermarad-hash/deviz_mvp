import '../job_partner_models.dart';
import '../../../core/repositories/app_data_repository.dart';
import 'pontaj_fisa_aggregator.dart';

/// Scanează TOATE lucrările și extrage rândurile de pontaj PARTENER (toți
/// muncitorii, nu doar unul), într-un interval [periodStart, periodEnd]
/// ales liber — bază pentru raportul agregat săptămânal
/// (`pontaj_fisa_weekly_grouping.dart`).
///
/// Diferă de `buildPontajFisaCrossJob()`
/// (`pontaj_fisa_cross_job_service.dart`) DOAR prin faptul că NU filtrează
/// pe o singură persoană — returnează rândurile TUTUROR muncitorilor
/// parteneri. Reutilizează `buildPontajFisaPartnerRows()` din
/// `pontaj_fisa_aggregator.dart` (Faza 2) — nu duplică logica de extragere.
///
/// Read-only: NU scrie nimic, NU atinge `Appointment`/`assignedEmployeeIds`/
/// `employee_financial_*`. Aceeași limitare de cost documentată la
/// `pontaj_fisa_cross_job_service.dart` se aplică și aici — se citesc TOATE
/// lucrările via `repository.listJobs()` (aceeași metodă local-first deja
/// folosită de `jobs_page.dart`), filtrarea pe perioadă rulează 100% în
/// Dart, după citire.
class PontajFisaAllPartnersResult {
  const PontajFisaAllPartnersResult({
    required this.rows,
    required this.jobsScanned,
  });

  /// Toate rândurile de pontaj-partener din interval, indiferent de
  /// muncitor sau partener.
  final List<PontajFisaRow> rows;

  /// Câte lucrări au fost citite/scanate — util pentru diagnostic/UI.
  final int jobsScanned;
}

Future<PontajFisaAllPartnersResult> buildPontajFisaAllPartnerRows({
  required AppDataRepository repository,
  required DateTime periodStart,
  required DateTime periodEnd,
}) async {
  final jobs = await repository.listJobs();
  final partners = await repository.listPartners();
  final partnerNamesById = {for (final p in partners) p.id: p.name};

  final rows = <PontajFisaRow>[];
  for (final job in jobs) {
    final jobPartnerWorkers = job.jobPartnerWorkers
        .map(JobPartnerWorker.fromMap)
        .where((w) => w.id.isNotEmpty)
        .toList(growable: false);
    if (jobPartnerWorkers.isEmpty) continue;

    rows.addAll(
      buildPontajFisaPartnerRows(
        jobPartnerWorkers,
        periodStart: periodStart,
        periodEnd: periodEnd,
        jobCode: job.jobCode,
        jobTitle: job.title,
        partnerNamesById: partnerNamesById,
      ),
    );
  }

  return PontajFisaAllPartnersResult(rows: rows, jobsScanned: jobs.length);
}
