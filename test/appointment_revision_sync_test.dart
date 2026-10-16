// RC 121: protecția la concurență pentru programări (calendar), pe aceeași
// infrastructură RevisionWriter ca la clienți/oferte/lucrări, cu payload-ul real
// al programărilor (FirebaseProgramariRepository.cloudMapFor).
import 'dart:async';

import 'package:devizpro_ultra/core/cloud/cloud_sync_models.dart';
import 'package:devizpro_ultra/core/cloud/keyed_mutex.dart';
import 'package:devizpro_ultra/core/cloud/revision_sync.dart';
import 'package:devizpro_ultra/features/programari/appointment_models.dart';
import 'package:devizpro_ultra/features/programari/firebase_programari_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'revision_sync_conflicts_test.dart' show FakeServer;

const col = 'appointments';
const t = CloudEntityType.appointments;
const id = 'appt-pilot-1';

Appointment appt(String title, {int? rev, String start = '08:00', String end = '09:00'}) =>
    Appointment.fromMap({
      'id': id,
      'title': title,
      'scheduled_date': '2026-10-25',
      'start_time': start,
      'end_time': end,
      'client_name': '-',
      'status': 'planificata',
      if (rev != null) '_rev': rev,
    });

RevisionWriter device(FakeServer s, String name) => RevisionWriter(
      transport: s,
      bases: RevisionBaseStore(namespace: name),
      conflicts: SyncConflictStore(namespace: name),
      deviceId: 'dev-$name',
    );

/// Scrierea exact ca FirebaseProgramariRepository.upsertAppointment.
Future<ConditionalWriteOutcome> save(RevisionWriter w, Appointment a) => w.upsert(
      type: t,
      collection: col,
      id: a.id,
      data: FirebaseProgramariRepository.cloudMapFor(a),
      startRev: a.syncRev,
    );

/// Ștergerea exact ca FirebaseProgramariRepository.deleteAppointment.
Future<ConditionalWriteOutcome> del(RevisionWriter w) => w.delete(
      type: t,
      collection: col,
      id: id,
      keysFor: FirebaseProgramariRepository.writerKeysFor,
    );

/// Citire de pe server (listă / ascultător în timp real) pe dispozitivul [w].
Future<void> pull(RevisionWriter w, FakeServer s, {Set<String> protectedIds = const {}}) =>
    w.recordServerBases(
      type: t,
      serverDocs: {id: s.read(col, id)!},
      keysFor: FirebaseProgramariRepository.writerKeysFor,
      protectedIds: protectedIds,
    );

Appointment fromServer(FakeServer s) => Appointment.fromMap({...s.read(col, id)!, 'id': id});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('model: _rev circulă prin toMap/fromMap/copyWith; payload-ul cloud nu poartă _rev', () {
    final a = appt('C1', rev: 3);
    expect(a.syncRev, 3);
    expect(Appointment.fromMap(a.toMap()).syncRev, 3);
    expect(a.copyWith(title: 'x').syncRev, 3, reason: 'actualizările automate (kit, echipă, culoare) păstrează revizia');
    expect(FirebaseProgramariRepository.cloudMapFor(a).containsKey(kRevField), isFalse);
  });

  test('amprenta ignoră updated_at restampilat la fiecare trimitere', () async {
    final m1 = FirebaseProgramariRepository.cloudMapFor(appt('C1'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final m2 = FirebaseProgramariRepository.cloudMapFor(appt('C1'));
    expect(m1['updated_at'] == m2['updated_at'], isFalse);
    final keys = FirebaseProgramariRepository.writerKeysFor(m1).toList();
    expect(contentFingerprint(m1, keys), contentFingerprint(m2, keys));
  });

  test('creare + editare pe același dispozitiv: _rev 1 → 2, fără conflict', () async {
    final s = FakeServer();
    final a = device(s, 'A');
    expect(await save(a, appt('C1')), ConditionalWriteOutcome.written);
    expect(s.read(col, id)!['_rev'], 1);
    expect(await save(a, appt('C1', rev: 1, start: '10:00', end: '11:00')), ConditionalWriteOutcome.written);
    expect(s.read(col, id)!['_rev'], 2);
    expect(s.read(col, id)!['start_time'], '10:00');
  });

  test('DEFECTUL: editare offline întârziată NU mai suprascrie modificarea mai nouă (conflict, ambele păstrate)', () async {
    final s = FakeServer();
    final a = device(s, 'A');
    final b = device(s, 'B');
    await save(a, appt('C1'));
    await pull(b, s);
    final offlineEditA = appt('C1 offline A', rev: 1); // coada lui A, payload cu _rev 1
    await save(b, fromServer(s).copyWith(startTime: '12:00')); // B online, rev 2
    await expectLater(save(a, offlineEditA), throwsA(isA<RevisionConflictException>()));
    expect(s.read(col, id)!['start_time'], '12:00', reason: 'serverul păstrează B');
    expect(s.read(col, id)!['_rev'], 2);
    final c = (await a.conflicts.listOpen()).single;
    expect(c.kind, 'concurrent_edit');
    expect(c.localPayload!['title'], 'C1 offline A', reason: 'varianta locală păstrată');
  });

  test('editare simultană: editor deschis pe rev 1, celălalt PC salvează rev 2 → conflict, nu suprascriere', () async {
    final s = FakeServer();
    final a = device(s, 'A');
    final b = device(s, 'B');
    await save(a, appt('C1'));
    await pull(b, s);
    final editorB = fromServer(s); // rev 1
    await save(a, fromServer(s).copyWith(title: 'A rev2'));
    await pull(b, s); // ascultătorul în timp real al lui B avansează baza la rev 2
    await expectLater(save(b, editorB.copyWith(title: 'B din editor vechi')), throwsA(isA<RevisionConflictException>()));
    expect(s.read(col, id)!['title'], 'A rev2');
  });

  test('două salvări rapide identice / confirmare pierdută / reluare din coadă: fără dublură, fără revizie în plus', () async {
    final s = FakeServer();
    final a = device(s, 'A');
    await save(a, appt('C1'));
    s.loseAckAfterCommit = true;
    await expectLater(save(a, appt('C1', rev: 1, start: '10:00')), throwsA(isA<TimeoutException>()));
    expect(await save(a, appt('C1', rev: 1, start: '10:00')), ConditionalWriteOutcome.alreadyApplied);
    expect(await save(a, appt('C1', rev: 1, start: '10:00')), ConditionalWriteOutcome.alreadyApplied);
    expect(s.read(col, id)!['_rev'], 2);
    expect(s.docs[col]!.length, 1, reason: 'un singur document');
  });

  test('timeout / server inaccesibil: nimic scris, reîncercarea ulterioară reușește o singură dată', () async {
    final s = FakeServer();
    final a = device(s, 'A');
    await save(a, appt('C1'));
    s.unreachable = true;
    await expectLater(save(a, appt('C1', rev: 1, start: '11:00')), throwsA(isA<TimeoutException>()));
    expect(s.read(col, id)!['start_time'], '08:00');
    s.unreachable = false;
    expect(await save(a, appt('C1', rev: 1, start: '11:00')), ConditionalWriteOutcome.written);
    expect(s.read(col, id)!['_rev'], 2);
  });

  test('repornire: conflictul și baza persistă (instanțe noi pe aceleași date)', () async {
    final s = FakeServer();
    final a = device(s, 'A');
    final b = device(s, 'B');
    await save(a, appt('C1'));
    await pull(b, s);
    await save(b, fromServer(s).copyWith(title: 'B'));
    await expectLater(save(a, appt('A vechi', rev: 1)), throwsA(isA<RevisionConflictException>()));
    final restarted = device(s, 'A');
    expect((await restarted.conflicts.listOpen()).single.localPayload!['title'], 'A vechi');
    expect((await restarted.bases.get(t, id))!.rev, 1, reason: 'baza nu avansează peste editarea locală');
  });

  test('ștergere concurentă cu editare: ștergerea învechită e respinsă, editarea rămâne pe server', () async {
    final s = FakeServer();
    final a = device(s, 'A');
    final b = device(s, 'B');
    await save(a, appt('C1'));
    await pull(b, s);
    await save(b, fromServer(s).copyWith(title: 'B editat'));
    await expectLater(del(a), throwsA(isA<RevisionConflictException>()));
    expect(s.read(col, id)!['title'], 'B editat');
    final c = (await a.conflicts.listOpen()).single;
    expect(c.kind, 'delete_vs_remote_edit');
    expect(c.serverPayload!['title'], 'B editat', reason: 'varianta serverului e disponibilă pentru restaurare locală');
  });

  test('ștergere acceptată → programarea nu reînvie dintr-o copie rămasă / coadă veche', () async {
    final s = FakeServer();
    final a = device(s, 'A');
    final b = device(s, 'B');
    await save(a, appt('C1'));
    await pull(b, s);
    expect(await del(a), ConditionalWriteOutcome.written);
    expect(s.read(col, id), isNull);
    await expectLater(save(b, fromServer0(s, rev: 1)), throwsA(isA<RevisionConflictException>()));
    expect(s.read(col, id), isNull, reason: 'fără reapariție');
    expect((await b.conflicts.listOpen()).single.kind, 'deleted_remotely');
    expect(await del(a), ConditionalWriteOutcome.alreadyApplied, reason: 'ștergerea reluată e idempotentă');
  });

  test('document vechi fără _rev (aplicație 112/113): prima scriere 120+ → rev 1; scrierea oarbă ulterioară a aplicației vechi e detectată', () async {
    final s = FakeServer()
      ..legacyBlindWrite(col, id, FirebaseProgramariRepository.cloudMapFor(appt('din 112')));
    final a = device(s, 'A');
    await pull(a, s);
    expect(await save(a, fromServer(s).copyWith(title: 'migrat 121')), ConditionalWriteOutcome.written);
    expect(s.read(col, id)!['_rev'], 1);
    await pull(a, s);
    s.legacyBlindWrite(col, id, {'title': 'scris de telefon vechi'}); // nu modifică _rev
    await expectLater(save(a, fromServer(s).copyWith(title: 'A după')), throwsA(isA<RevisionConflictException>()),
        reason: 'amprenta detectează scrierea fără revizie');
  });

  test('actualizare automată (kit/echipă/culoare) pe copie locală veche: conflict, nu suprascriere', () async {
    final s = FakeServer();
    final a = device(s, 'A');
    final b = device(s, 'B');
    await save(a, appt('C1'));
    await pull(b, s);
    final localOnB = fromServer(s);
    await save(a, fromServer(s).copyWith(notes: 'materiale actualizate de A'));
    await pull(b, s);
    await expectLater(save(b, localOnB.copyWith(colorCode: 'red')), throwsA(isA<RevisionConflictException>()));
    expect(s.read(col, id)!['notes'], 'materiale actualizate de A');
  });

  test('regulile M3 propuse + fereastra Windows: scrierea învechită e respinsă și devine conflict imediat', () async {
    final s = FakeServer();
    final a = device(s, 'A');
    await save(a, appt('C1'));
    s.enforceRevRules = true;
    var once = false;
    s.afterRead = (c, i) {
      if (once) return;
      once = true;
      final cur = s.read(c, i)!;
      s.docs[c]![i] = {...cur, 'title': 'B în fereastră', '_rev': (cur['_rev'] as int) + 1};
    };
    await expectLater(save(a, appt('A', rev: 1)), throwsA(isA<RevisionConflictException>()));
    expect(s.read(col, id)!['title'], 'B în fereastră');
  });

  test('review #3: lucrul pornit în fundal dintr-o secțiune blocată AȘTEAPTĂ blocarea după eliberare', () async {
    final order = <String>[];
    Future<void>? bg;
    await KeyedMutex.run('k121', () async {
      bg = KeyedMutex.detached(() => KeyedMutex.run('k121', () async => order.add('fundal')));
      unawaited(bg);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      order.add('secțiune');
    });
    final other = KeyedMutex.run('k121', () async {
      order.add('alt-apel-început');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      order.add('alt-apel-sfârșit');
    });
    await Future.wait([bg!, other]);
    expect(order.first, 'secțiune');
    expect(order.indexOf('fundal') < order.indexOf('alt-apel-început') ||
        order.indexOf('fundal') > order.indexOf('alt-apel-sfârșit'), isTrue,
        reason: 'fundalul nu se intercalează în interiorul altei deținători: $order');
  });

  test('review #2: fără bază (prima pornire / pornire offline) dar editorul pornit din revizia curentă → scriere', () async {
    final s = FakeServer();
    final a = device(s, 'A');
    final b = device(s, 'B');
    await save(a, appt('C1')); // rev 1
    // B nu a înregistrat nicio bază (citire doar din cache), dar copia locală are _rev 1
    expect(await save(b, appt('C1 editat pe B', rev: 1)), ConditionalWriteOutcome.written);
    expect(s.read(col, id)!['_rev'], 2);
    // același lucru dintr-o revizie veche → conflict (nu suprascriere)
    final c = device(s, 'C');
    await expectLater(save(c, appt('C din rev 1', rev: 1)), throwsA(isA<RevisionConflictException>()));
    expect(s.read(col, id)!['title'], 'C1 editat pe B');
  });
}

/// Copia locală rămasă pe B (rev 1) după ștergerea de pe A.
Appointment fromServer0(FakeServer s, {required int rev}) => appt('copie ramasa pe B', rev: rev);
