// Teste de sincronizare pe dispozitiv cu Firebase Emulator Suite LOCAL.
//
// Rulare EXCLUSIV prin tooling/sync_emulator/run_sync_scenarios.sh, pe un
// emulator Android dedicat, izolat (mod avion, fără rute). Proiectul folosit
// este demo-proventaris-sync, care există doar în emulatorul Firebase; testul
// se oprește înainte de orice acces Firestore dacă izolarea nu e confirmată.
// Faze: --dart-define=PHASE=<nume>; fiecare fază e un proces nou (restart).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devizpro_ultra/core/cloud/cloud_push.dart';
import 'package:devizpro_ultra/core/cloud/cloud_sync_models.dart';
import 'package:devizpro_ultra/core/cloud/firebase_bootstrap.dart';
import 'package:devizpro_ultra/core/cloud/local_cloud_sync_repository.dart';
import 'package:devizpro_ultra/core/cloud/offline_sync_runtime.dart';
import 'package:devizpro_ultra/core/repositories/local_app_data_repository.dart';
import 'package:devizpro_ultra/features/employees/firebase_angajati_repository.dart';
import 'package:devizpro_ultra/features/jobs/firebase_lucrari_repository.dart';
import 'package:devizpro_ultra/features/jobs/job_models.dart';
import 'package:devizpro_ultra/features/jobs/job_partner_models.dart';
import 'package:devizpro_ultra/features/jobs/services/lucrare_persistence.dart';
import 'package:devizpro_ultra/features/master/master_local_store.dart';
import 'package:devizpro_ultra/features/teams/firebase_echipe_repository.dart';
import 'package:devizpro_ultra/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Faza curentă: scrisă de script în directorul aplicației (`run-as`), ca un
/// singur APK să ruleze toate fazele fără rebuild; `--dart-define=PHASE` rămâne
/// rezervă pentru rulări manuale.
final String phase = () {
  const fromDefine = String.fromEnvironment('PHASE');
  if (fromDefine.isNotEmpty) return fromDefine;
  final f = File('/data/user/0/ro.proterm.proventaris/files/qa_sync_phase');
  return f.existsSync() ? f.readAsStringSync().trim() : '';
}();
const demoProject = 'demo-proventaris-sync';
const fsPort = 5310;
const authPort = 5311;
/// Numele emulatorului Firebase pe dispozitiv (în /system/etc/hosts → 127.0.0.1,
/// apoi tunel adb). Nu se folosește 127.0.0.1 direct: FlutterFire îl rescrie
/// automat în 10.0.2.2 pe emulatoarele Android.
const emuHost = 'fs-emulator.qa';
const _email = 'sync.qa@demo.test';
const _pwKey = 'qa_sync_emulator_pw';

/// Fazele în care emulatorul Firebase trebuie să fie accesibil.
const _onlinePhases = {'INIT', 'PULL', 'SYNC', 'PULL2', 'RETRY', 'KILL', 'AFTER_KILL'};

void log(String m) {
  // ignore: avoid_print
  print('QA_SYNC[$phase] $m');
}

Future<bool> _resolves(String host) => InternetAddress.lookup(host)
    .timeout(const Duration(seconds: 3))
    .then((r) => r.isNotEmpty)
    .catchError((Object _) => false);

Future<bool> _tcp(String host, int port) =>
    Socket.connect(host, port, timeout: const Duration(seconds: 3)).then((s) {
      s.destroy();
      return true;
    }).catchError((Object _) => false);

/// Oprește testul dacă dispozitivul are ieșire spre internet sau dacă starea
/// rețelei nu corespunde fazei.
Future<void> _assertIsolation() async {
  final google = await _resolves('google.com');
  final identity = await _resolves('identitytoolkit.googleapis.com');
  final dnsTcp = await _tcp('8.8.8.8', 53);
  final httpsTcp = await _tcp('142.250.180.10', 443);
  final fsResolved = await InternetAddress.lookup('firestore.googleapis.com')
      .timeout(const Duration(seconds: 3))
      .catchError((Object _) => <InternetAddress>[]);
  final fsLoopbackOnly = fsResolved.every((a) => a.isLoopback);
  final emuResolved = await InternetAddress.lookup(emuHost)
      .timeout(const Duration(seconds: 3))
      .catchError((Object _) => <InternetAddress>[]);
  final emulator = await _tcp('127.0.0.1', fsPort);
  log('IZOLARE google.com=$google identitytoolkit=$identity tcp8.8.8.8:53=$dnsTcp '
      'tcp142.250.180.10:443=$httpsTcp firestore.googleapis.com=${fsResolved.map((a) => a.address).toList()} '
      '$emuHost=${emuResolved.map((a) => a.address).toList()} emulator127.0.0.1:$fsPort=$emulator');
  final emuLoopbackOnly =
      emuResolved.isNotEmpty && emuResolved.every((a) => a.isLoopback);
  if (google || identity || dnsTcp || httpsTcp || !fsLoopbackOnly || !emuLoopbackOnly) {
    throw StateError('IZOLARE NEDEMONSTRATA - opresc testul');
  }
  final expectOnline = _onlinePhases.contains(phase);
  if (emulator != expectOnline) {
    throw StateError('stare retea neasteptata: emulator=$emulator, faza cere $expectOnline');
  }
}

Future<void> _initDemoFirebase() async {
  // Aplicația implicită Android e creată nativ din google-services.json, pe care
  // scriptul îl construiește cu project_id demo (doar pentru APK-ul de test).
  // Opțiunile Dart reale (aceeași cheie API/bucket) refolosesc aplicația nativă.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.useFirestoreEmulator(emuHost, fsPort);
  await FirebaseAuth.instance.useAuthEmulator(emuHost, authPort);
  await FirebaseBootstrap.initializeSafe();
  final project = Firebase.app().options.projectId;
  final host = FirebaseFirestore.instance.settings.host;
  log('CONFIG projectId=$project firestoreHost=$host auth=$emuHost:$authPort '
      'initialized=${FirebaseBootstrap.isInitialized}');
  if (project != demoProject || !project.startsWith('demo-') ||
      host != '$emuHost:$fsPort') {
    throw StateError('PROIECT/ENDPOINT NEPERMIS - opresc testul');
  }
}

Future<void> _ensureSignedIn(SharedPreferences prefs) async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser != null) return;
  final pw = prefs.getString(_pwKey);
  if (pw == null) throw StateError('lipseste utilizatorul sintetic (faza INIT)');
  await auth.signInWithEmailAndPassword(email: _email, password: pw);
}

Future<List<CloudSyncItem>> _unsynced() async =>
    (await LocalCloudSyncRepository().listItems()).where((i) => !i.isSynced).toList();

String _queueSummary(List<CloudSyncItem> items) =>
    items.map((i) => '${i.entityType.name}:${i.entityId}(retry=${i.retryCount})').join(', ');

JobRecord _localJob({double hours = 24}) {
  final start = DateTime(2026, 8, 4), end = DateTime(2026, 8, 6);
  return JobRecord.fromMap({
    'id': 'j-local-1', 'job_code': 'QA-LOCAL-1', 'title': 'Lucrare creata offline (sintetic)',
    'client_id': 'qa', 'notes': 'creata offline', 'details_updated_at': DateTime.now().toIso8601String(),
    'labor_entries': [{
      'id': 'l-local-1', 'jobId': 'j-local-1', 'whoId': 'emp:e-local-1', 'type': 'person',
      'whoLabel': 'Angajat Local QA', 'who': 'Angajat Local QA', 'date': '04.08.2026',
      'periodStartDate': '2026-08-04', 'periodEndDate': '2026-08-06',
      'hoursPerDay': 8.0, 'hours': hours, 'hourlyRate': 40.0, 'tripDays': 3.0,
      'includeDiurna': true, 'includeCazare': true, 'zileDiurna': 3.0, 'valoareDiurnaPeZi': 55.0,
      'noptiCazare': 3.0, 'valoareCazarePeNoapte': 125.0, 'costOre': hours * 40.0,
      'costDiurna': 165.0, 'costCazare': 375.0, 'costTotalLinie': hours * 40.0 + 540.0,
    }],
    'job_partners': [JobPartner(id: 'qa-partner', jobId: 'j-local-1', name: 'Partener QA SRL').toMap()],
    'job_partner_workers': [JobPartnerWorker(
        id: 'pw-local-1', jobId: 'j-local-1', partnerId: 'qa-partner', fullName: 'Muncitor Partener QA',
        workedHours: 24, hoursPerDay: 8, hourlyRate: 40, workPeriodStart: start, workPeriodEnd: end,
        workDays: 3, perDiemDays: 3, perDiemPerDay: 55, lodgingNights: 3, lodgingPerNight: 125).toMap()],
  });
}

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _assertIsolation();
    await _initDemoFirebase();
  });

  test('sincronizare faza $phase', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalAppDataRepository();
    final jobsCloud = FirebaseLucrariRepository();
    final empCloud = FirebaseAngajatiRepository();
    final teamCloud = FirebaseEchipeRepository();
    final online = await FirebaseBootstrap.checkOnline();
    log('checkOnline=$online');

    switch (phase) {
      case 'INIT':
        await prefs.clear();
        final rnd = Random.secure();
        final pw = List.generate(24, (_) => 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'[rnd.nextInt(55)]).join();
        await prefs.setString(_pwKey, pw); // sintetic, doar pentru emulatorul Auth local
        final cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: _email, password: pw);
        log('UID=${cred.user!.uid}');
        expect(online, isTrue);
        return;

      case 'PULL':
        await _ensureSignedIn(prefs);
        final emps = await empCloud.listEmployees();
        final localEmps = await MasterLocalStore.replaceEmployeesFromCloud(emps,
            fromCache: empCloud.lastListFromCache);
        final teams = await teamCloud.listTeams();
        final localTeams = await MasterLocalStore.replaceTeamsFromCloud(teams,
            fromCache: teamCloud.lastListFromCache);
        final jobs = await jobsCloud.listJobs();
        await repo.mergeJobsFromCloud(jobs);
        final j = (await repo.listJobs()).firstWhere((x) => x.id == 'j-cloud-1');
        final e = localEmps.firstWhere((x) => x.id == 'e-cloud-1');
        log('PULL employees fromCache=${empCloud.lastListFromCache} local=${localEmps.map((x) => x.id).toList()} '
            'e-cloud-1 tarif=${e.tarifOrar} diurna=${e.dailyAllowance} cazare=${e.defaultLodgingCost}');
        log('PULL teams local=${localTeams.map((x) => x.id).toList()}');
        log('PULL job j-cloud-1 labor=${j.laborEntries.length} costTotalLinie=${j.laborEntries.first['costTotalLinie']} notes=${j.notes}');
        expect(empCloud.lastListFromCache, isFalse);
        expect(e.tarifOrar, 40.0);
        expect(localTeams.map((x) => x.id), containsAll(['t-cloud-1', 't-cloud-2']));
        expect(j.laborEntries.single['costTotalLinie'], 1500.0);
        return;

      case 'OFFLINE_EDIT':
        expect(online, isFalse, reason: 'faza cere offline');
        // Lucrare nouă cu pontaj (angajat + partener), salvată de două ori.
        await lucrareSaveJobWithSync(job: _localJob(hours: 16), repository: repo, cloud: jobsCloud);
        await lucrareSaveJobWithSync(job: _localJob(hours: 24), repository: repo, cloud: jobsCloud);
        // Editare locală a unei lucrări care există în cloud (conflict).
        final jc = (await repo.listJobs()).firstWhere((x) => x.id == 'j-cloud-1');
        await lucrareSaveJobWithSync(
            job: jc.copyWith(notes: 'editat local offline'), repository: repo, cloud: jobsCloud);
        // Angajat nou: local întâi, apoi scriere cloud ne-blocantă (ca pagina).
        const emp = MasterEmployee(id: 'e-local-1', name: 'Angajat Local QA', role: 'Tehnician',
            active: true, tarifOrar: 40.0, dailyAllowance: 55.0, defaultLodgingCost: 125.0);
        await MasterLocalStore.writeEmployees([...await MasterLocalStore.readEmployees(), emp]);
        final empOutcome = await pushToCloudWithoutBlocking(() => empCloud.upsertEmployee(emp));
        // Echipă nouă: local întâi; dacă nu e confirmată, intră în coadă (ca pagina).
        const team = MasterTeam(id: 't-local-1', name: 'Echipa Locala QA', notes: '', memberIds: ['e-local-1']);
        await MasterLocalStore.writeTeams([...await MasterLocalStore.readTeams(), team]);
        final teamOutcome = await pushToCloudWithoutBlocking(() => teamCloud.upsertTeam(team));
        if (teamOutcome != CloudPushOutcome.synced) await OfflineSyncRuntime.instance.queueTeam(team);
        final q = await _unsynced();
        log('OFFLINE angajat=$empOutcome echipa=$teamOutcome coada=[${_queueSummary(q)}]');
        expect(q.where((i) => i.entityId == 'j-local-1'), hasLength(1),
            reason: 'doua salvari ale aceleiasi lucrari => un singur element in coada');
        expect(q.map((i) => i.entityId), containsAll(['j-local-1', 'j-cloud-1', 't-local-1']));
        return;

      case 'RESTART_OFFLINE':
        expect(online, isFalse);
        final q = await _unsynced();
        final jobs = await repo.listJobs();
        final jl = jobs.firstWhere((x) => x.id == 'j-local-1');
        // Cache-ul Firestore (cu scrierea în așteptare) — fuzionat, nu autoritativ.
        final cachedJobs = await jobsCloud.listJobs();
        await repo.mergeJobsFromCloud(cachedJobs);
        final jc = (await repo.listJobs()).firstWhere((x) => x.id == 'j-cloud-1');
        final cachedEmps = await empCloud.listEmployees();
        log('RESTART coada=[${_queueSummary(q)}] j-local-1 ore=${jl.laborEntries.single['hours']} '
            'partener=${jl.jobPartnerWorkers.length} j-cloud-1 notes="${jc.notes}" '
            'cache angajati fromCache=${empCloud.lastListFromCache} ids=${cachedEmps.map((e) => e.id).toList()}');
        expect(q.map((i) => i.entityId), containsAll(['j-local-1', 'j-cloud-1', 't-local-1']));
        expect(jl.laborEntries.single['hours'], 24.0);
        expect(jc.notes, 'editat local offline', reason: 'editarea locala in asteptare nu e suprascrisa');
        expect(cachedEmps.map((e) => e.id), contains('e-local-1'),
            reason: 'scrierea in asteptare a angajatului supravietuieste restartului');
        return;

      case 'SYNC':
        await _ensureSignedIn(prefs);
        // Înainte de PUSH: serverul are editarea „altui dispozitiv”.
        final serverJobs = await jobsCloud.listJobs();
        await repo.mergeJobsFromCloud(serverJobs);
        final before = (await repo.listJobs()).firstWhere((x) => x.id == 'j-cloud-1');
        log('SYNC inainte: server notes="${serverJobs.firstWhere((x) => x.id == 'j-cloud-1').notes}" '
            'local notes="${before.notes}"');
        expect(before.notes, 'editat local offline');
        final sw = Stopwatch()..start();
        final ok = await OfflineSyncRuntime.instance.syncPending();
        await FirebaseFirestore.instance.waitForPendingWrites().timeout(const Duration(seconds: 30));
        final q = await _unsynced();
        log('SYNC syncPending=$ok (${sw.elapsedMilliseconds}ms) coada nesincronizata=[${_queueSummary(q)}]');
        expect(ok, isTrue);
        expect(q, isEmpty);
        return;

      case 'PULL2':
        await _ensureSignedIn(prefs);
        final emps = await MasterLocalStore.replaceEmployeesFromCloud(await empCloud.listEmployees(),
            fromCache: empCloud.lastListFromCache);
        final teams = await MasterLocalStore.replaceTeamsFromCloud(await teamCloud.listTeams(),
            fromCache: teamCloud.lastListFromCache);
        final cloudJobs = await jobsCloud.listJobs();
        await repo.mergeJobsFromCloud(cloudJobs);
        final local = await repo.listJobs();
        String laborSig(JobRecord j) => jsonEncode(j.laborEntries
            .map((l) => [l['id'], l['hours'], l['costDiurna'], l['costCazare'], l['costTotalLinie']])
            .toList());
        final cl = cloudJobs.firstWhere((x) => x.id == 'j-local-1');
        final ll = local.firstWhere((x) => x.id == 'j-local-1');
        log('PULL2 angajati=${emps.map((e) => '${e.id}:${e.tarifOrar}').toList()} '
            'echipe=${teams.map((t) => t.id).toList()}');
        log('PULL2 integritate j-local-1 cloud=${laborSig(cl)} local=${laborSig(ll)} '
            'partener cloud=${cl.jobPartnerWorkers.length} local=${ll.jobPartnerWorkers.length} '
            'j-cloud-1 local notes="${local.firstWhere((x) => x.id == 'j-cloud-1').notes}"');
        expect(emps.firstWhere((e) => e.id == 'e-cloud-1').tarifOrar, 45.0,
            reason: 'modificarea din cloud ajunge local');
        expect(emps.map((e) => e.id), contains('e-local-1'));
        expect(teams.map((t) => t.id), isNot(contains('t-cloud-2')),
            reason: 'raspunsul serverului e autoritativ (echipa stearsa in cloud)');
        expect(teams.map((t) => t.id), containsAll(['t-cloud-1', 't-local-1']));
        expect(laborSig(cl), laborSig(ll));
        expect(cl.jobPartnerWorkers.length, ll.jobPartnerWorkers.length);
        return;

      case 'RETRY':
        // Eșec real: scriere fără autentificare, respinsă de reguli.
        await FirebaseAuth.instance.signOut();
        final retryJob = _localJob().copyWith(id: 'j-retry-1', jobCode: 'QA-RETRY-1');
        await lucrareSaveJobWithSync(job: retryJob, repository: repo, cloud: jobsCloud);
        await Future<void>.delayed(const Duration(seconds: 6));
        await OfflineSyncRuntime.instance.syncPending();
        final failed = (await _unsynced()).where((i) => i.entityId == 'j-retry-1').toList();
        log('RETRY dupa esec: ${_queueSummary(failed)} eroare="${failed.isEmpty ? '' : failed.single.lastError}"');
        expect(failed, hasLength(1));
        expect(failed.single.retryCount, greaterThanOrEqualTo(1));
        await _ensureSignedIn(prefs);
        // Backoff-ul primei reîncercări este de 30 s.
        await Future<void>.delayed(const Duration(seconds: 32));
        final ok = await OfflineSyncRuntime.instance.syncPending();
        final after = (await _unsynced()).where((i) => i.entityId == 'j-retry-1').toList();
        log('RETRY dupa reautentificare+backoff syncPending=$ok ramase=${_queueSummary(after)}');
        expect(after, isEmpty);
        await Future<void>.delayed(const Duration(seconds: 6));
        final again = await OfflineSyncRuntime.instance.syncPending();
        log('RETRY a doua sincronizare (idempotenta) syncPending=$again nesincronizate=${(await _unsynced()).length}');
        expect(await _unsynced(), isEmpty);
        return;

      case 'KILL':
        await _ensureSignedIn(prefs);
        for (var i = 1; i <= 40; i++) {
          final j = _localJob().copyWith(id: 'j-kill-$i', jobCode: 'QA-KILL-$i');
          await repo.saveJob(j);
          await OfflineSyncRuntime.instance.queueJob(j);
        }
        log('KILL coada=${(await _unsynced()).length} SYNC_STARTED');
        unawaited(OfflineSyncRuntime.instance.syncPending());
        // Procesul este oprit din exterior în timpul sincronizării.
        await Future<void>.delayed(const Duration(seconds: 90));
        log('KILL procesul NU a fost oprit (sincronizarea s-a terminat inainte)');
        return;

      case 'AFTER_KILL':
        await _ensureSignedIn(prefs);
        final all = await LocalCloudSyncRepository().listItems();
        final kill = all.where((i) => i.entityId.startsWith('j-kill-')).toList();
        final pending = kill.where((i) => !i.isSynced).length;
        final perEntity = <String, int>{};
        for (final i in kill) {
          perEntity[i.entityId] = (perEntity[i.entityId] ?? 0) + 1;
        }
        log('AFTER_KILL elemente=${kill.length} nesincronizate_la_restart=$pending '
            'duplicate_in_coada=${perEntity.values.where((n) => n > 1).length}');
        final ok = await OfflineSyncRuntime.instance.syncPending();
        await FirebaseFirestore.instance.waitForPendingWrites().timeout(const Duration(seconds: 30));
        final left = (await _unsynced()).where((i) => i.entityId.startsWith('j-kill-')).length;
        log('AFTER_KILL syncPending=$ok nesincronizate=$left');
        expect(perEntity.values.every((n) => n == 1), isTrue);
        expect(left, 0);
        return;

      case 'CACHE':
        expect(online, isFalse);
        // Angajat doar local (nu a ajuns niciodată în cloud/cache).
        const only = MasterEmployee(id: 'e-local-only', name: 'Doar local QA', role: 'QA', active: true);
        await MasterLocalStore.writeEmployees([...await MasterLocalStore.readEmployees(), only]);
        final cached = await empCloud.listEmployees();
        final merged = await MasterLocalStore.replaceEmployeesFromCloud(cached,
            fromCache: empCloud.lastListFromCache);
        final cachedTeams = await teamCloud.listTeams();
        final mergedTeams = await MasterLocalStore.replaceTeamsFromCloud(cachedTeams,
            fromCache: teamCloud.lastListFromCache);
        log('CACHE angajati fromCache=${empCloud.lastListFromCache} cache=${cached.map((e) => e.id).toList()} '
            'local_dupa=${merged.map((e) => e.id).toList()} echipe local_dupa=${mergedTeams.map((t) => t.id).toList()}');
        expect(empCloud.lastListFromCache, isTrue);
        expect(merged.map((e) => e.id), containsAll(['e-local-only', 'e-cloud-1', 'e-local-1']));
        expect(mergedTeams.map((t) => t.id), containsAll(['t-cloud-1', 't-local-1']));
        return;
    }
    throw StateError('faza necunoscuta: $phase');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
