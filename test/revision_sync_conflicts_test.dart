// Control de concurență (RC 120): reproduce defectul demonstrat pe 15.10.2026
// (A editează offline, B salvează online, A revine și sincronizează) și
// verifică editări simultane, reîncercări, crash după commit, repornire,
// dublu-click, cozi vechi (fără bază), scrieri ale aplicațiilor vechi,
// ștergeri, idempotență și îmbinarea ofertelor fără pierderi locale.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:devizpro_ultra/core/cloud/cloud_sync_models.dart';
import 'package:devizpro_ultra/core/cloud/local_cloud_sync_repository.dart';
import 'package:devizpro_ultra/core/cloud/offline_sync_runtime.dart';
import 'package:devizpro_ultra/core/cloud/revision_sync.dart';
import 'package:devizpro_ultra/features/oferte/local_oferte_repository.dart';
import 'package:devizpro_ultra/features/oferte/offer_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Server Firestore fals: tranzacții atomice, indisponibilitate, confirmare
/// pierdută după commit, scrieri oarbe ale aplicațiilor vechi.
class FakeServer implements RevisionTransport {
  final Map<String, Map<String, Map<String, dynamic>>> docs = {};
  bool unreachable = false;
  bool loseAckAfterCommit = false;
  int commits = 0;

  /// Regulile propuse M3: creare cu `_rev == 1`, actualizare cu `_rev + 1`,
  /// ștergere necondiționată. Refuzul = `permission-denied`, ca pe Firestore.
  bool enforceRevRules = false;

  /// Refuză orice scriere (de exemplu utilizator inactiv).
  bool denyAll = false;
  int rejections = 0;

  /// Rulează după citire și înaintea scrierii (fereastra neatomică de pe Windows).
  void Function(String col, String id)? afterRead;

  Map<String, dynamic>? read(String col, String id) {
    final d = docs[col]?[id];
    return d == null ? null : Map<String, dynamic>.from(d);
  }

  /// Aplicație veche (113/118/119): set(merge) orb, fără `_rev`, cu
  /// `updated_at` restampilat la trimitere.
  void legacyBlindWrite(String col, String id, Map<String, dynamic> data) {
    final current = docs.putIfAbsent(col, () => {})[id] ?? <String, dynamic>{};
    docs[col]![id] = {...current, ...data, 'updated_at': DateTime.now().toIso8601String()};
  }

  @override
  Future<T> run<T>(Future<T> Function(RevisionTx tx) body) async {
    if (unreachable) throw TimeoutException('server inaccesibil');
    final tx = _FakeTx(this);
    final result = await body(tx);
    if (tx.hasWrites) {
      try {
        tx.checkRules();
      } on FirebaseException {
        rejections++;
        rethrow;
      }
    }
    tx.commit();
    commits++;
    if (loseAckAfterCommit) {
      loseAckAfterCommit = false;
      throw TimeoutException('confirmare pierduta dupa commit');
    }
    return result;
  }
}

class _FakeTx implements RevisionTx {
  _FakeTx(this.server);
  final FakeServer server;
  final List<void Function()> _ops = [];
  final List<(String, String, Map<String, dynamic>?)> _writes = [];
  bool get hasWrites => _writes.isNotEmpty;
  @override
  Future<Map<String, dynamic>?> get(String collection, String id) async {
    final d = server.read(collection, id);
    server.afterRead?.call(collection, id);
    return d;
  }

  @override
  void set(String collection, String id, Map<String, dynamic> data) {
    _writes.add((collection, id, data));
    _ops.add(() {
      final c = server.docs.putIfAbsent(collection, () => {});
      c[id] = {...?c[id], ...data};
    });
  }

  @override
  void delete(String collection, String id) {
    _writes.add((collection, id, null));
    _ops.add(() => server.docs[collection]?.remove(id));
  }

  void checkRules() {
    FirebaseException denied() =>
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
    if (server.denyAll) throw denied();
    if (!server.enforceRevRules) return;
    for (final (col, id, data) in _writes) {
      if (data == null) continue; // ștergere: necondiționată în regulile propuse
      final current = server.docs[col]?[id];
      final expected = current == null ? 1 : ((current['_rev'] as num?)?.toInt() ?? 0) + 1;
      if (data['_rev'] != expected) throw denied();
    }
  }
  void commit() {
    for (final op in _ops) {
      op();
    }
  }
}

RevisionWriter device(FakeServer s, String name) => RevisionWriter(
      transport: s,
      bases: RevisionBaseStore(namespace: name),
      conflicts: SyncConflictStore(namespace: name),
    );

Map<String, dynamic> client(String name, {String phone = '0700', String? notes}) => {
      'id': 'c1', 'name': name, 'phone': phone, if (notes != null) 'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    };

const col = 'clients';
const t = CloudEntityType.clients;

Future<ConditionalWriteOutcome> up(RevisionWriter w, Map<String, dynamic> data) =>
    w.upsert(type: t, collection: col, id: 'c1', data: data);

/// Dispozitivul citește documentul de pe server (cum fac listClients/watchClients).
Future<void> pull(RevisionWriter w, FakeServer s, {Set<String> protectedIds = const {}}) =>
    w.recordServerBases(
      type: t,
      serverDocs: {'c1': s.read(col, 'c1')!},
      keysFor: (d) => d.keys,
      protectedIds: protectedIds,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('defectul demonstrat: A offline, B online, A revine', () {
    test('REPRODUCERE comportament vechi (113/118/119): scrierea oarbă întârziată suprascrie B', () {
      final s = FakeServer()..legacyBlindWrite(col, 'c1', client('Original'));
      final editareA = client('Editare A (veche)'); // făcută offline, înaintea lui B
      s.legacyBlindWrite(col, 'c1', client('Editare B (noua)'));
      s.legacyBlindWrite(col, 'c1', editareA);           // A revine: set(merge) orb
      expect(s.read(col, 'c1')!['name'], 'Editare A (veche)', reason: 'defectul: versiunea nouă a lui B e pierdută');
    });

    test('versiunea mai nouă a lui B NU este suprascrisă; varianta lui A se păstrează ca conflict', () async {
      final s = FakeServer();
      final a = device(s, 'A'), b = device(s, 'B');
      await up(a, client('Original'));                  // rev 1, creat de A
      await pull(b, s);                                  // B vede rev 1
      // A editează offline (scrierea nu ajunge pe server).
      s.unreachable = true;
      await expectLater(up(a, client('Editare A (veche)')), throwsA(isA<TimeoutException>()));
      s.unreachable = false;
      // B salvează online o versiune mai nouă.
      expect(await up(b, client('Editare B (noua)')), ConditionalWriteOutcome.written);
      expect(s.read(col, 'c1')![kRevField], 2);
      // A revine și sincronizează (coada retrimite editarea lui A).
      await expectLater(up(a, client('Editare A (veche)')), throwsA(isA<RevisionConflictException>()));
      expect(s.read(col, 'c1')!['name'], 'Editare B (noua)', reason: 'serverul păstrează versiunea mai nouă');
      expect(s.read(col, 'c1')![kRevField], 2);
      final conflicts = await a.conflicts.listOpen();
      expect(conflicts, hasLength(1));
      expect(conflicts.single.kind, 'concurrent_edit');
      expect(conflicts.single.localPayload!['name'], 'Editare A (veche)', reason: 'varianta locală nu se pierde');
      expect(conflicts.single.serverPayload!['name'], 'Editare B (noua)');
      expect(conflicts.single.baseRev, 1);
      expect(conflicts.single.serverRev, 2);
    });

    test('ordinea NU se stabilește după updated_at: o ștampilă „mai nouă” nu câștigă conflictul', () async {
      final s = FakeServer();
      final a = device(s, 'A'), b = device(s, 'B');
      await up(a, client('Original'));
      await pull(b, s);
      await up(b, client('Editare B'));
      final future = {...client('Editare A'), 'updated_at': '2099-01-01T00:00:00.000'};
      await expectLater(up(a, future), throwsA(isA<RevisionConflictException>()));
      expect(s.read(col, 'c1')!['name'], 'Editare B');
    });
  });

  group('editări simultane, reîncercări, crash, repornire, dublu-click', () {
    test('două dispozitive de pe aceeași bază: primul câștigă, al doilea devine conflict', () async {
      final s = FakeServer();
      final a = device(s, 'A'), b = device(s, 'B');
      await up(a, client('X'));
      await pull(b, s);
      expect(await up(a, client('X-A')), ConditionalWriteOutcome.written);
      await expectLater(up(b, client('X-B')), throwsA(isA<RevisionConflictException>()));
      expect(s.read(col, 'c1')!['name'], 'X-A');
      expect((await b.conflicts.listOpen()).single.localPayload!['name'], 'X-B');
    });

    test('server inaccesibil: nimic scris, niciun conflict, baza neschimbată; reîncercarea reușește', () async {
      final s = FakeServer();
      final a = device(s, 'A');
      await up(a, client('V1'));
      s.unreachable = true;
      await expectLater(up(a, client('V2')), throwsA(isA<TimeoutException>()));
      expect(s.commits, 1);
      expect(await a.conflicts.listOpen(), isEmpty);
      expect((await a.bases.get(t, 'c1'))!.rev, 1);
      s.unreachable = false;
      expect(await up(a, client('V2')), ConditionalWriteOutcome.written);
      expect(s.read(col, 'c1')![kRevField], 2);
    });

    test('crash/confirmare pierdută după commit: reîncercarea e idempotentă (fără dublă incrementare)', () async {
      final s = FakeServer();
      final a = device(s, 'A');
      await up(a, client('V1'));
      s.loseAckAfterCommit = true;
      await expectLater(up(a, client('V2')), throwsA(isA<TimeoutException>()));
      expect(s.read(col, 'c1')![kRevField], 2, reason: 'serverul a aplicat scrierea');
      expect((await a.bases.get(t, 'c1'))!.rev, 1, reason: 'clientul nu a primit confirmarea');
      expect(await up(a, client('V2')), ConditionalWriteOutcome.alreadyApplied);
      expect(s.read(col, 'c1')![kRevField], 2);
      expect((await a.bases.get(t, 'c1'))!.rev, 2);
      expect(await a.conflicts.listOpen(), isEmpty);
    });

    test('repornire: baza și conflictele persistă (instanțe noi citesc aceleași date)', () async {
      final s = FakeServer();
      await up(device(s, 'A'), client('V1'));
      await pull(device(s, 'B'), s);
      await up(device(s, 'B'), client('V2-B'));
      // „Repornire” A: instanță nouă, aceeași stocare.
      await expectLater(up(device(s, 'A'), client('V2-A')), throwsA(isA<RevisionConflictException>()));
      expect(await device(s, 'A').conflicts.listOpen(), hasLength(1));
      expect((await device(s, 'A').bases.get(t, 'c1'))!.rev, 1);
    });

    test('dublu-click (aceeași salvare de două ori): o singură revizie nouă', () async {
      final s = FakeServer();
      final a = device(s, 'A');
      await up(a, client('V1'));
      final data = client('V2');
      expect(await up(a, data), ConditionalWriteOutcome.written);
      expect(await up(a, data), ConditionalWriteOutcome.alreadyApplied);
      expect(s.read(col, 'c1')![kRevField], 2);
      expect(s.commits, 3);
    });
  });

  group('compatibilitate: documente și cozi vechi, aplicații vechi', () {
    test('document vechi fără _rev, citit de 120: editarea reușește și inițializează revizia', () async {
      final s = FakeServer()..legacyBlindWrite(col, 'c1', client('Legacy'));
      final a = device(s, 'A');
      await pull(a, s);
      expect((await a.bases.get(t, 'c1'))!.rev, 0);
      expect(await up(a, client('Legacy editat de 120')), ConditionalWriteOutcome.written);
      expect(s.read(col, 'c1')![kRevField], 1);
    });

    test('element vechi din coadă (fără bază): conflict dacă serverul diferă, nu suprascriere', () async {
      final s = FakeServer()..legacyBlindWrite(col, 'c1', client('Server'));
      final a = device(s, 'A');
      await expectLater(up(a, client('Coada veche 119')), throwsA(isA<RevisionConflictException>()));
      expect(s.read(col, 'c1')!['name'], 'Server');
    });

    test('element vechi din coadă (fără bază): aplicat dacă serverul are deja exact conținutul', () async {
      final s = FakeServer()..legacyBlindWrite(col, 'c1', client('Identic'));
      expect(await up(device(s, 'A'), client('Identic')), ConditionalWriteOutcome.alreadyApplied);
    });

    test('element vechi din coadă (fără bază): documentul lipsă se creează', () async {
      final s = FakeServer();
      expect(await up(device(s, 'A'), client('Nou')), ConditionalWriteOutcome.written);
      expect(s.read(col, 'c1')![kRevField], 1);
    });

    test('aplicație veche (scriere oarbă, fără _rev) e detectată prin amprentă: 120 nu o suprascrie', () async {
      final s = FakeServer();
      final a = device(s, 'A');
      await up(a, client('V1'));
      s.legacyBlindWrite(col, 'c1', {'name': 'Editat pe 119', 'phone': '0700'});
      expect(s.read(col, 'c1')![kRevField], 1, reason: 'aplicația veche nu modifică _rev');
      await expectLater(up(a, client('Editat pe 120')), throwsA(isA<RevisionConflictException>()));
      expect(s.read(col, 'c1')!['name'], 'Editat pe 119');
    });
  });

  group('ștergeri', () {
    test('ștears de alt dispozitiv + editare locală: conflict, documentul NU este readus la viață', () async {
      final s = FakeServer();
      final a = device(s, 'A'), b = device(s, 'B');
      await up(a, client('V1'));
      await pull(b, s);
      expect(await b.delete(type: t, collection: col, id: 'c1'), ConditionalWriteOutcome.written);
      await expectLater(up(a, client('V2-A')), throwsA(isA<RevisionConflictException>()));
      expect(s.read(col, 'c1'), isNull);
      final c = (await a.conflicts.listOpen()).single;
      expect(c.kind, 'deleted_remotely');
      expect(c.localPayload!['name'], 'V2-A');
    });

    test('ștergere locală după o editare la distanță: conflict, editarea de pe server rămâne', () async {
      final s = FakeServer();
      final a = device(s, 'A'), b = device(s, 'B');
      await up(a, client('V1'));
      await pull(b, s);
      await up(b, client('V2-B'));
      await expectLater(a.delete(type: t, collection: col, id: 'c1'), throwsA(isA<RevisionConflictException>()));
      expect(s.read(col, 'c1')!['name'], 'V2-B');
      expect((await a.conflicts.listOpen()).single.kind, 'delete_vs_remote_edit');
    });

    test('ștergere pe baza curentă reușește; repetată este idempotentă', () async {
      final s = FakeServer();
      final a = device(s, 'A');
      await up(a, client('V1'));
      expect(await a.delete(type: t, collection: col, id: 'c1'), ConditionalWriteOutcome.written);
      expect(await a.delete(type: t, collection: col, id: 'c1'), ConditionalWriteOutcome.alreadyApplied);
    });
  });

  group('amprentă și baze', () {
    test('amprenta ignoră ordinea cheilor, int/double, null vs lipsă și câmpurile volatile', () {
      final keys = ['id', 'name', 'qty', 'notes', 'updated_at', '_rev'];
      final a = {'id': 'x', 'name': 'N', 'qty': 2, 'updated_at': '2026-01-01', '_rev': 3};
      final b = {'_rev': 9, 'updated_at': '2030-05-05', 'qty': 2.0, 'name': 'N', 'id': 'x', 'notes': null};
      expect(contentFingerprint(a, keys), contentFingerprint(b, keys));
      expect(contentFingerprint(a, keys), isNot(contentFingerprint({...a, 'name': 'M'}, keys)));
    });

    test('baza nu se actualizează la citire pentru entitățile protejate (editare locală nesincronizată)', () async {
      final s = FakeServer();
      final a = device(s, 'A'), b = device(s, 'B');
      await up(a, client('V1'));
      await pull(b, s);
      await up(b, client('V2-B'));
      await pull(a, s, protectedIds: {'c1'});
      expect((await a.bases.get(t, 'c1'))!.rev, 1, reason: 'altfel editarea locală ar suprascrie V2-B');
      await expectLater(up(a, client('V2-A')), throwsA(isA<RevisionConflictException>()));
    });

    test('conflictele se deduplică per entitate (cea mai recentă variantă locală)', () async {
      final s = FakeServer();
      final a = device(s, 'A'), b = device(s, 'B');
      await up(a, client('V1'));
      await pull(b, s);
      await up(b, client('V2-B'));
      await expectLater(up(a, client('A1')), throwsA(isA<RevisionConflictException>()));
      await expectLater(up(a, client('A2')), throwsA(isA<RevisionConflictException>()));
      final c = await a.conflicts.listOpen();
      expect(c, hasLength(1));
      expect(c.single.localPayload!['name'], 'A2');
    });
  });

  group('coadă și îmbinare fără pierderi', () {
    test('reîncercări epuizate: payload-ul se păstrează ca conflict înainte de curățare', () async {
      final repo = LocalCloudSyncRepository();
      await repo.upsertItem(CloudSyncItem(
        id: 'clients_c9_1', entityType: CloudEntityType.clients, entityId: 'c9',
        payload: const {'id': 'c9', 'name': 'Editare care nu a ajuns'},
        updatedAt: DateTime(2026, 10, 15), retryCount: 10,
      ));
      await OfflineSyncRuntime.instance.debugPreserveExhaustedItems();
      final c = (await SyncConflictStore().listOpen()).single;
      expect(c.kind, 'retry_exhausted');
      expect(c.localPayload!['name'], 'Editare care nu a ajuns');
    });

    test('oferte: îmbinarea păstrează varianta locală protejată și ofertele create offline', () async {
      final repo = LocalOferteRepository();
      OfferRecord o(String id, String title) =>
          OfferRecord.fromMap({'id': id, 'offer_number': 'N-$id', 'title': title});
      await repo.upsertOffer(o('o1', 'o1 local nesincronizat'));
      await repo.upsertOffer(o('o2', 'o2 local sincronizat'));
      await repo.upsertOffer(o('o3', 'o3 creata offline'));
      await repo.upsertOffer(o('o4', 'o4 stearsa pe server'));
      await repo.upsertOffer(o('o5', 'o5 doar locala, netrimisa'));
      // o4 a fost văzută pe server (are bază); o5 nu.
      await RevisionBaseStore().set(CloudEntityType.offers, 'o4', const RevisionBase(rev: 1, fingerprint: 'x'));
      LocalOferteRepository.debugProtectedIds = () async => {'o1', 'o3'};
      addTearDown(() => LocalOferteRepository.debugProtectedIds = null);
      final merged = await repo.mergeOffersFromCloud([o('o1', 'o1 din cloud'), o('o2', 'o2 din cloud')]);
      final byId = {for (final x in merged) x.id: x.title};
      expect(byId['o1'], 'o1 local nesincronizat');
      expect(byId['o2'], 'o2 din cloud');
      expect(byId['o3'], 'o3 creata offline');
      expect(byId.containsKey('o4'), isFalse, reason: 'văzută pe server, ștearsă acolo, fără modificare locală');
      expect(byId['o5'], 'o5 doar locala, netrimisa', reason: 'niciodată văzută pe server: nu se pierde');
      expect((await repo.listOffers()).map((x) => x.id).toSet(), {'o1', 'o2', 'o3', 'o5'});
      final queued = (await LocalCloudSyncRepository().listItems())
          .where((i) => i.entityType == CloudEntityType.offers && !i.isSynced)
          .map((i) => i.entityId);
      expect(queued, contains('o5'), reason: 'oferta netrimisă intră în coadă');
    });
  });
  group('fereastra neatomică citire→scriere (Windows) și regulile propuse M3', () {
    Future<(FakeServer, RevisionWriter)> seeded() async {
      final s = FakeServer();
      final a = device(s, 'A');
      await up(a, client('v1'));
      return (s, a);
    }

    void bWritesInWindow(FakeServer s) {
      var done = false;
      s.afterRead = (c, id) {
        if (done) return;
        done = true;
        final cur = s.read(c, id)!;
        s.docs[c]![id] = {...cur, 'name': 'Editare B (în fereastră)', '_rev': (cur['_rev'] as int) + 1};
      };
    }

    test('RISC fără reguli (înainte de M3): scrierea lui B din fereastră este suprascrisă', () async {
      final (s, a) = await seeded();
      bWritesInWindow(s);
      await up(a, client('Editare A'));
      expect(s.read(col, 'c1')!['name'], 'Editare A',
          reason: 'documentează de ce M3 este necesar pentru Windows');
    });

    test('cu regulile M3: A este respins, reevaluat imediat → conflict; B rămâne pe server', () async {
      final (s, a) = await seeded();
      s.enforceRevRules = true;
      bWritesInWindow(s);
      await expectLater(up(a, client('Editare A')), throwsA(isA<RevisionConflictException>()));
      expect(s.rejections, 1);
      expect(s.read(col, 'c1')!['name'], 'Editare B (în fereastră)');
      expect(s.read(col, 'c1')!['_rev'], 2);
      final c = (await a.conflicts.listOpen()).single;
      expect(c.kind, 'concurrent_edit');
      expect(c.localPayload!['name'], 'Editare A');
      expect(c.serverPayload!['name'], 'Editare B (în fereastră)');
    });

    test('cu regulile M3: refuz persistent (utilizator inactiv) → eroare propagată, nimic pierdut', () async {
      final (s, a) = await seeded();
      s.denyAll = true;
      await expectLater(up(a, client('Editare A')), throwsA(isA<FirebaseException>()));
      expect(s.rejections, 2, reason: 'o singură reevaluare, fără buclă');
      expect(await a.conflicts.listOpen(), isEmpty);
      expect((await a.bases.get(t, 'c1'))!.rev, 1, reason: 'baza rămâne versiunea editată');
      expect(s.read(col, 'c1')!['name'], 'v1');
    });

    test('cu regulile M3: confirmare pierdută → reîncercarea vede conținut identic, nu rescrie', () async {
      final (s, a) = await seeded();
      s.enforceRevRules = true;
      s.loseAckAfterCommit = true;
      await expectLater(up(a, client('v2')), throwsA(isA<TimeoutException>()));
      final commits = s.commits;
      expect(await up(a, client('v2')), ConditionalWriteOutcome.alreadyApplied);
      expect(s.commits, commits + 1, reason: 'tranzacție fără scriere');
      expect(s.rejections, 0);
      expect(s.read(col, 'c1')!['_rev'], 2);
    });

    test('cu regulile M3: document vechi fără _rev → prima scriere 120 cu _rev = 1 este acceptată', () async {
      final s = FakeServer()..legacyBlindWrite(col, 'c1', client('din 119'));
      s.enforceRevRules = true;
      final a = device(s, 'A');
      await pull(a, s);
      expect(await up(a, client('migrat')), ConditionalWriteOutcome.written);
      expect(s.read(col, 'c1')!['_rev'], 1);
    });

    test('RISC CUNOSCUT și cu regulile M3: ștergerea invechită din fereastră pierde editarea lui B', () async {
      final (s, a) = await seeded();
      s.enforceRevRules = true;
      bWritesInWindow(s);
      await a.delete(type: t, collection: col, id: 'c1');
      expect(s.read(col, 'c1'), isNull, reason: 'regulile nu condiționează ștergerea: vezi propunerea tombstone');
    });
  });
}
