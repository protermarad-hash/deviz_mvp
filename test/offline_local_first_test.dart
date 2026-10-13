import 'dart:async';

import 'package:devizpro_ultra/core/cloud/cloud_push.dart';
import 'package:devizpro_ultra/core/cloud/cloud_sync_models.dart';
import 'package:devizpro_ultra/core/cloud/local_cloud_sync_repository.dart';
import 'package:devizpro_ultra/core/repositories/local_app_data_repository.dart';
import 'package:devizpro_ultra/features/jobs/job_models.dart';
import 'package:devizpro_ultra/features/jobs/lucrari_cloud_repository.dart';
import 'package:devizpro_ultra/features/jobs/services/lucrare_persistence.dart';
import 'package:devizpro_ultra/features/master/master_local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cloud fals: `hang` = scriere care nu se confirmă niciodată (offline real
/// Firestore), `fail` = eroare (ex. permission-denied).
class _FakeCloud implements LucrariCloudRepository {
  _FakeCloud({this.hang = false, this.fail = false});
  final bool hang;
  final bool fail;
  final upserts = <JobRecord>[];

  @override
  Future<void> upsertJob(JobRecord job) {
    upserts.add(job);
    if (hang) return Completer<void>().future;
    if (fail) return Future<void>.error(StateError('permission-denied'));
    return Future<void>.value();
  }

  @override
  Future<List<JobRecord>> listJobs() async => const [];
  @override
  Stream<List<JobRecord>> watchJobs() => const Stream.empty();
  @override
  Future<void> deleteJob(String jobId) async {}
}

JobRecord _job(String id, String title, {double perDiem = 55}) =>
    JobRecord.fromMap({
      'id': id,
      'job_code': 'QA-$id',
      'title': title,
      'details_updated_at': '2026-10-14T10:00:00.000',
      'job_partner_workers': [
        {
          'id': 'pw-$id',
          'jobId': id,
          'partnerId': 'p',
          'fullName': 'QA',
          'workDays': 3,
          'perDiemDays': 3,
          'perDiemPerDay': perDiem,
        }
      ],
    });

double _perDiem(JobRecord j) =>
    (j.jobPartnerWorkers.single['perDiemPerDay'] as num).toDouble();

Future<List<CloudSyncItem>> _queueFor(String id) async =>
    (await LocalCloudSyncRepository().listItems())
        .where((i) => i.entityType == CloudEntityType.jobs && i.entityId == id)
        .toList();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('pushToCloudWithoutBlocking', () {
    test('offline: nu așteaptă scrierea → pendingOffline imediat', () async {
      final sw = Stopwatch()..start();
      final r = await pushToCloudWithoutBlocking(
          () => Completer<void>().future,
          online: false);
      expect(r, CloudPushOutcome.pendingOffline);
      expect(sw.elapsedMilliseconds, lessThan(500));
    });
    test('online: confirmată → synced', () async {
      expect(await pushToCloudWithoutBlocking(() async {}, online: true),
          CloudPushOutcome.synced);
    });
    test('online: eroare → failed', () async {
      expect(
          await pushToCloudWithoutBlocking(
              () => Future<void>.error(StateError('x')),
              online: true),
          CloudPushOutcome.failed);
    });
    test('online: fără răspuns → failed după timeout', () async {
      expect(
          await pushToCloudWithoutBlocking(() => Completer<void>().future,
              online: true, timeout: const Duration(milliseconds: 50)),
          CloudPushOutcome.failed);
    });
    test('excepție sincronă → failed', () async {
      expect(
          await pushToCloudWithoutBlocking(() => throw StateError('sync'),
              online: true),
          CloudPushOutcome.failed);
    });
  });

  group('lucrareSaveJobWithSync — local întâi', () {
    test('offline + scriere cloud blocată: revine imediat, local + coadă',
        () async {
      final repo = LocalAppDataRepository();
      final cloud = _FakeCloud(hang: true);
      final sw = Stopwatch()..start();
      final saved = await lucrareSaveJobWithSync(
        job: _job('j1', 'Lucrare QA', perDiem: 100),
        repository: repo,
        cloud: cloud,
        online: false,
      );
      expect(sw.elapsedMilliseconds, lessThan(1000));
      expect(_perDiem(saved), 100);
      final local = await repo.listJobs();
      expect(local.map((j) => j.id), ['j1']);
      expect(_perDiem(local.single), 100);
      expect(cloud.upserts, hasLength(1),
          reason: 'scrierea cloud e lansată (Firestore o ține în așteptare)');
      expect(await _queueFor('j1'), hasLength(1));
    });
    test('salvări repetate offline: fără duplicate, ultima valoare câștigă',
        () async {
      final repo = LocalAppDataRepository();
      final cloud = _FakeCloud(hang: true);
      for (final v in [60.0, 80.0, 100.0]) {
        await lucrareSaveJobWithSync(
            job: _job('j1', 'Lucrare QA', perDiem: v),
            repository: repo,
            cloud: cloud,
            online: false);
      }
      final local = await repo.listJobs();
      expect(local, hasLength(1));
      expect(_perDiem(local.single), 100);
      final queued = await _queueFor('j1');
      expect(queued, hasLength(1));
      expect(
          ((queued.single.payload['job_partner_workers'] as List).single
              as Map)['perDiemPerDay'],
          100);
    });
    test('online + eroare cloud: salvat local, pus în coadă (observabil)',
        () async {
      final repo = LocalAppDataRepository();
      await lucrareSaveJobWithSync(
          job: _job('j1', 'Lucrare QA'),
          repository: repo,
          cloud: _FakeCloud(fail: true),
          online: true);
      expect(await repo.listJobs(), hasLength(1));
      expect(await _queueFor('j1'), hasLength(1));
    });
    test('online + confirmare cloud: salvat local, fără coadă', () async {
      final repo = LocalAppDataRepository();
      await lucrareSaveJobWithSync(
          job: _job('j1', 'Lucrare QA'),
          repository: repo,
          cloud: _FakeCloud(),
          online: true);
      expect(await repo.listJobs(), hasLength(1));
      expect(await _queueFor('j1'), isEmpty);
    });
    test('fără cloud: salvat local + coadă', () async {
      final repo = LocalAppDataRepository();
      await lucrareSaveJobWithSync(
          job: _job('j1', 'Lucrare QA'), repository: repo, cloud: null);
      expect(await repo.listJobs(), hasLength(1));
      expect(await _queueFor('j1'), hasLength(1));
    });
  });

  group('mergeJobsFromCloud — modificarea offline nu e suprascrisă', () {
    test('job cu upsert în coadă: versiunea locală rămâne', () async {
      final repo = LocalAppDataRepository();
      await lucrareSaveJobWithSync(
          job: _job('j1', 'Lucrare QA', perDiem: 100),
          repository: repo,
          cloud: _FakeCloud(hang: true),
          online: false);
      final merged =
          await repo.mergeJobsFromCloud([_job('j1', 'Lucrare QA', perDiem: 55)]);
      expect(merged, hasLength(1));
      expect(_perDiem(merged.single), 100);
      expect(_perDiem((await repo.listJobs()).single), 100);
    });
    test('item în pauză de reîncercare (nextAttemptAt viitor): tot protejat',
        () async {
      final repo = LocalAppDataRepository();
      await repo.saveJob(_job('j1', 'Lucrare QA', perDiem: 100));
      final queue = LocalCloudSyncRepository();
      await queue.upsertItem(CloudSyncItem(
        id: 'jobs_j1_1',
        entityType: CloudEntityType.jobs,
        entityId: 'j1',
        payload: _job('j1', 'Lucrare QA', perDiem: 100).toMap(),
        updatedAt: DateTime.now(),
        retryCount: 2,
        nextAttemptAt: DateTime.now().add(const Duration(hours: 1)),
      ));
      final merged =
          await repo.mergeJobsFromCloud([_job('j1', 'Lucrare QA', perDiem: 55)]);
      expect(_perDiem(merged.single), 100);
    });
    test('fără modificări în coadă: cloud-ul rămâne sursa (comportament neschimbat)',
        () async {
      final repo = LocalAppDataRepository();
      await repo.saveJob(_job('j1', 'Lucrare QA', perDiem: 55));
      final merged = await repo.mergeJobsFromCloud(
          [_job('j1', 'Lucrare QA', perDiem: 120), _job('j2', 'Alta')]);
      expect(merged.map((j) => j.id).toSet(), {'j1', 'j2'});
      expect(_perDiem(merged.firstWhere((j) => j.id == 'j1')), 120);
    });
  });

  group('MasterLocalStore.replaceEmployeesFromCloud', () {
    const emp =
        MasterEmployee(id: 'e1', name: 'Angajat QA', role: 'QA', active: true);
    test('cache offline gol NU golește lista locală', () async {
      await MasterLocalStore.writeEmployees(const [emp]);
      final r = await MasterLocalStore.replaceEmployeesFromCloud(const [],
          fromCache: true);
      expect(r.map((e) => e.id), ['e1']);
      expect((await MasterLocalStore.readEmployees()).map((e) => e.id), ['e1']);
    });
    test('listă goală confirmată de server rămâne autoritativă', () async {
      await MasterLocalStore.writeEmployees(const [emp]);
      final r = await MasterLocalStore.replaceEmployeesFromCloud(const [],
          fromCache: false);
      expect(r, isEmpty);
      expect(await MasterLocalStore.readEmployees(), isEmpty);
    });
    test('listă nevidă (cache sau server) actualizează local', () async {
      await MasterLocalStore.writeEmployees(const [emp]);
      const e2 = MasterEmployee(
          id: 'e2', name: 'Angajat QA 2', role: 'QA', active: true);
      final r = await MasterLocalStore.replaceEmployeesFromCloud(
          const [emp, e2],
          fromCache: true);
      expect(r.map((e) => e.id), ['e1', 'e2']);
      expect(
          (await MasterLocalStore.readEmployees()).map((e) => e.id), ['e1', 'e2']);
    });
  });
}
