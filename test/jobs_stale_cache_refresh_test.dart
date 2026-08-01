import 'package:devizpro_ultra/features/jobs/job_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduce identic algoritmul din `jobs_page.dart` (`_applyJobUpdate` +
/// `_compareJobsByStatus`), FĂRĂ dependințele grele ale `JobsPage`
/// (repository, Firebase, Navigator) — același stil de test folosit deja în
/// `lucrare_resurse_proprii_visibility_test.dart` pentru a izola logica pură
/// de widget-ul complet.
///
/// FIX cache stale (iul 2026): la orice ieșire din `LucrareDetaliiPage`
/// (nu doar 'edit'), `JobsPage` trebuie să înlocuiască punctual intrarea din
/// `_jobs` cu ultimul `JobRecord` întors de pagină (labor/parteneri/
/// vehicule/documente), altfel la reintrare pagina se inițializează din
/// `widget.job` stale.
int _jobStatusRank(JobStatus status) {
  switch (status) {
    case JobStatus.inExecutie:
      return 0;
    case JobStatus.planificata:
      return 1;
    case JobStatus.noua:
      return 2;
    case JobStatus.ofertata:
      return 3;
    case JobStatus.suspendata:
      return 4;
    case JobStatus.inchisa:
      return 5;
    case JobStatus.finalizata:
      return 6;
  }
}

int _compareJobsByStatus(JobRecord a, JobRecord b) {
  final byStatus = _jobStatusRank(a.status).compareTo(_jobStatusRank(b.status));
  if (byStatus != 0) return byStatus;
  return b.createdAt.compareTo(a.createdAt);
}

/// Mirror al `JobsPage._applyJobUpdate` (jobs_page.dart).
List<JobRecord> applyJobUpdate(List<JobRecord> jobs, JobRecord updated) {
  final idx = jobs.indexWhere((j) => j.id == updated.id);
  if (idx == -1) return jobs;
  final next = List<JobRecord>.from(jobs);
  next[idx] = updated;
  next.sort(_compareJobsByStatus);
  return next;
}

JobRecord _job({
  required String id,
  List<Map<String, dynamic>> laborEntries = const [],
  List<Map<String, dynamic>> jobPartnerWorkers = const [],
  List<Map<String, dynamic>> jobOwnVehicles = const [],
  List<Map<String, dynamic>> documents = const [],
  JobStatus status = JobStatus.inExecutie,
}) {
  final now = DateTime(2026, 7, 30);
  return JobRecord(
    id: id,
    jobCode: 'JOB-$id',
    clientId: 'client-1',
    title: 'Lucrare test',
    location: 'Arad',
    city: 'Arad',
    county: 'AR',
    contactPerson: '',
    contactPhone: '',
    description: '',
    category: '',
    status: status,
    startDate: now,
    dueDate: now,
    closedDate: null,
    estimatedValue: 100,
    notes: '',
    isActive: true,
    createdAt: now,
    updatedAt: now,
    laborEntries: laborEntries,
    jobPartnerWorkers: jobPartnerWorkers,
    jobOwnVehicles: jobOwnVehicles,
    documents: documents,
  );
}

void main() {
  group('JobsPage — fix cache stale la reintrare pe lucrare', () {
    test(
        'pop fără "edit" (back button/gest sistem) înlocuiește intrarea din '
        '_jobs cu job-ul proaspăt întors de LucrareDetaliiPage', () {
      final stale = _job(
        id: 'A',
        laborEntries: const [
          {'who': 'Ion Popescu', 'hours': 4},
        ],
      );
      final jobs = [stale, _job(id: 'B')];

      // Simulează: utilizatorul a adăugat manoperă în ecran, apoi a apăsat
      // back (sistem) — LucrareDetaliiPage întoarce _jobSnapshot actualizat
      // prin PopScope, NU string-ul 'edit'.
      final fresh = stale.copyWith(
        laborEntries: const [
          {'who': 'Ion Popescu', 'hours': 4},
          {'who': 'Vasile Ionescu', 'hours': 8},
        ],
      );

      final result = applyJobUpdate(jobs, fresh);
      final updatedA = result.firstWhere((j) => j.id == 'A');

      expect(updatedA.laborEntries.length, 2,
          reason: 'labor-ul nou adăugat trebuie reflectat imediat în _jobs, '
              'fără reload complet și fără redeschiderea ecranului');
      expect(jobs[0].laborEntries.length, 1,
          reason: 'lista veche nu trebuie mutată — se produce o listă nouă');
    });

    test(
        'FIX se aplică simetric: labor + parteneri + vehicule + documente '
        'sunt actualizate deodată prin ÎNLOCUIREA întregului JobRecord, nu '
        'prin 4 fix-uri separate per categorie', () {
      final stale = _job(id: 'A');
      final jobs = [stale];

      final fresh = stale.copyWith(
        laborEntries: const [
          {'who': 'Echipa 1', 'hours': 8},
        ],
        jobPartnerWorkers: const [
          {'fullName': 'Muncitor partener'},
        ],
        jobOwnVehicles: const [
          {'plate': 'AR-01-XYZ'},
        ],
        documents: const [
          {'type': 'pv', 'filePath': '/tmp/pv.pdf'},
        ],
      );

      final result = applyJobUpdate(jobs, fresh);
      final updated = result.single;

      expect(updated.laborEntries, isNotEmpty);
      expect(updated.jobPartnerWorkers, isNotEmpty);
      expect(updated.jobOwnVehicles, isNotEmpty);
      expect(updated.documents, isNotEmpty);
    });

    test('job absent din _jobs (ex: șters între timp) nu produce crash — no-op',
        () {
      final jobs = [_job(id: 'A')];
      final orphan = _job(id: 'ZZZ');

      final result = applyJobUpdate(jobs, orphan);

      expect(result, jobs);
      expect(result.any((j) => j.id == 'ZZZ'), isFalse);
    });

    test('actualizarea unei intrări nu afectează celelalte intrări din listă',
        () {
      final jobA = _job(id: 'A');
      final jobB = _job(id: 'B', laborEntries: const [
        {'who': 'Neschimbat', 'hours': 2}
      ]);
      final jobs = [jobA, jobB];

      final freshA = jobA.copyWith(laborEntries: const [
        {'who': 'Nou', 'hours': 3}
      ]);

      final result = applyJobUpdate(jobs, freshA);
      final unchangedB = result.firstWhere((j) => j.id == 'B');

      expect(unchangedB.laborEntries.single['who'], 'Neschimbat');
    });
  });
}
