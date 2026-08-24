import '../job_partner_models.dart';
import '../../../core/repositories/app_data_repository.dart';
import 'pontaj_fisa_aggregator.dart';

/// Faza 3 — agregat CROSS-LUCRARE per persoană: citește TOATE lucrările
/// (`repository.listJobs()`) și adună rândurile de pontaj (propriu +
/// partener) ale unei persoane/partener specifice, pe o perioadă dată,
/// cu detaliere per lucrare.
///
/// LIMITARE DE COST, documentată explicit (nu ascunsă):
/// Structura actuală de date (`laborEntries`/`jobPartnerWorkers` sunt
/// array-uri EMBEDATE în documentul `JobRecord`, fără subcolecție/câmp
/// interogabil pe dată de muncă) NU permite un query Firestore restrâns
/// pe perioadă la nivel de rând — data unei zile lucrate nu are nicio
/// legătură garantată cu data creării/actualizării LUCRĂRII (o lucrare
/// deschisă în ianuarie poate avea manoperă înregistrată în august).
/// Filtrarea pe `JobRecord.updatedAt`/`status` ar putea exclude tăcut
/// lucrări valide doar pentru că nu au fost atinse recent — nu există
/// o limitare "sigură" pe niciun câmp disponibil azi.
/// Singura reducere aplicată: se refolosește `repository.listJobs()` —
/// ACEEAȘI metodă local-first (cache SharedPreferences + merge Firestore,
/// fără citire brută nouă) folosită deja de `jobs_page.dart` pentru lista
/// principală de lucrări — deci NU se introduce un nou tipar de citire
/// nemărginită, doar se reutilizează cel deja acceptat în aplicație.
/// Filtrarea pe persoană + perioadă rulează 100% local, în Dart, după
/// citire (consistent cu restul regulilor Firestore din CLAUDE.md:
/// „sortează/filtrează în Dart, nu în query").
class PontajFisaCrossJobResult {
  const PontajFisaCrossJobResult({
    required this.ownRows,
    required this.partnerRows,
    required this.jobsScanned,
  });

  final List<PontajFisaRow> ownRows;
  final List<PontajFisaRow> partnerRows;

  /// Câte lucrări au fost citite/scanate — util pentru diagnostic/UI
  /// ("scanate N lucrări, găsite M rânduri").
  final int jobsScanned;

  double get total =>
      ownRows.fold<double>(0, (s, r) => s + r.costTotal) +
      partnerRows.fold<double>(0, (s, r) => s + r.costTotal);
}

Future<PontajFisaCrossJobResult> buildPontajFisaCrossJob({
  required AppDataRepository repository,
  required String personaNume,
  required DateTime periodStart,
  required DateTime periodEnd,
}) async {
  final jobs = await repository.listJobs();
  final partners = await repository.listPartners();
  final partnerNamesById = {for (final p in partners) p.id: p.name};

  final targetName = personaNume.trim().toLowerCase();
  final ownRows = <PontajFisaRow>[];
  final partnerRows = <PontajFisaRow>[];

  for (final job in jobs) {
    final jobOwnRows = buildPontajFisaOwnRows(
      job.laborEntries,
      periodStart: periodStart,
      periodEnd: periodEnd,
      jobCode: job.jobCode,
      jobTitle: job.title,
    ).where((r) => r.persoanaNume.trim().toLowerCase() == targetName);
    ownRows.addAll(jobOwnRows);

    final jobPartnerWorkers = job.jobPartnerWorkers
        .map(JobPartnerWorker.fromMap)
        .where((w) => w.id.isNotEmpty)
        .toList(growable: false);
    final jobPartnerRows = buildPontajFisaPartnerRows(
      jobPartnerWorkers,
      periodStart: periodStart,
      periodEnd: periodEnd,
      jobCode: job.jobCode,
      jobTitle: job.title,
      partnerNamesById: partnerNamesById,
    ).where((r) => r.persoanaNume.trim().toLowerCase() == targetName);
    partnerRows.addAll(jobPartnerRows);
  }

  return PontajFisaCrossJobResult(
    ownRows: ownRows,
    partnerRows: partnerRows,
    jobsScanned: jobs.length,
  );
}
