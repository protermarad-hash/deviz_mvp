// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/core/cloud/cloud_sync_models.dart';
import '../lib/core/cloud/local_cloud_sync_repository.dart';
import '../lib/features/master/master_local_store.dart';
import '../lib/features/pontaj_lucrari/pontaj_zi_lucrare_models.dart';
import '../lib/features/pontaj_lucrari/pontaj_zi_lucrare_repository.dart';

PontajZiLucrare _pontaj({
  String id = 'p1',
  double tarif = 300,
  double diurna = 50,
  double cazare = 120,
  bool includeDiurna = true,
  bool includeCazare = true,
}) {
  final now = DateTime(2026, 7, 30, 14, 25);
  return PontajZiLucrare(
    id: id,
    lucrareId: 'job-1',
    data: now,
    persoanaNume: 'Ion Popescu',
    sursaPersoana: SursaPersoanaPontaj.propriu,
    persoanaRefId: 'emp-1',
    tarifZilnicSnapshot: tarif,
    diurnaSnapshot: diurna,
    cazareSnapshot: cazare,
    includeDiurna: includeDiurna,
    includeCazare: includeCazare,
    observatii: 'test',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PontajZiLucrare – calcul costZi', () {
    test('tarif + diurnă + cazare când ambele sunt incluse', () {
      final p = _pontaj();
      expect(p.costZi, 300 + 50 + 120);
    });

    test('doar tarif când diurna și cazarea NU sunt incluse', () {
      final p = _pontaj(includeDiurna: false, includeCazare: false);
      expect(p.costZi, 300);
    });

    test('tarif + diurnă fără cazare', () {
      final p = _pontaj(includeCazare: false);
      expect(p.costZi, 350);
    });

    test('tarif + cazare fără diurnă', () {
      final p = _pontaj(includeDiurna: false);
      expect(p.costZi, 420);
    });

    test('snapshot-urile există dar nu intră în cost dacă nu sunt bifate', () {
      final p = _pontaj(includeDiurna: false, includeCazare: false);
      expect(p.diurnaSnapshot, 50);
      expect(p.cazareSnapshot, 120);
      expect(p.costZi, 300);
    });
  });

  group('PontajZiLucrare – serializare', () {
    test('toMap/fromMap roundtrip păstrează toate câmpurile', () {
      final original = _pontaj();
      final restored = PontajZiLucrare.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.lucrareId, original.lucrareId);
      expect(restored.ziCalendaristica, original.ziCalendaristica);
      expect(restored.persoanaNume, original.persoanaNume);
      expect(restored.sursaPersoana, original.sursaPersoana);
      expect(restored.persoanaRefId, original.persoanaRefId);
      expect(restored.tarifZilnicSnapshot, original.tarifZilnicSnapshot);
      expect(restored.diurnaSnapshot, original.diurnaSnapshot);
      expect(restored.cazareSnapshot, original.cazareSnapshot);
      expect(restored.includeDiurna, original.includeDiurna);
      expect(restored.includeCazare, original.includeCazare);
      expect(restored.observatii, original.observatii);
      expect(restored.costZi, original.costZi);
    });

    test('data se normalizează la zi calendaristică (fără oră)', () {
      final p = _pontaj();
      final restored = PontajZiLucrare.fromMap(p.toMap());
      expect(restored.data, DateTime(2026, 7, 30));
    });

    test('sursa partener + partenerNume se păstrează', () {
      final now = DateTime(2026, 7, 30);
      final p = PontajZiLucrare(
        id: 'p2',
        lucrareId: 'job-1',
        data: now,
        persoanaNume: 'Vasile Extern',
        sursaPersoana: SursaPersoanaPontaj.partener,
        persoanaRefId: 'pw-1',
        partenerNume: 'SC Partener SRL',
        tarifZilnicSnapshot: 250,
        createdAt: now,
        updatedAt: now,
      );
      final restored = PontajZiLucrare.fromMap(p.toMap());
      expect(restored.sursaPersoana, SursaPersoanaPontaj.partener);
      expect(restored.partenerNume, 'SC Partener SRL');
    });

    test('nume liber: refId și partenerNume rămân null', () {
      final now = DateTime(2026, 7, 30);
      final p = PontajZiLucrare(
        id: 'p3',
        lucrareId: 'job-1',
        data: now,
        persoanaNume: 'Zilier Necunoscut',
        sursaPersoana: SursaPersoanaPontaj.liber,
        tarifZilnicSnapshot: 200,
        createdAt: now,
        updatedAt: now,
      );
      final restored = PontajZiLucrare.fromMap(p.toMap());
      expect(restored.sursaPersoana, SursaPersoanaPontaj.liber);
      expect(restored.persoanaRefId, isNull);
      expect(restored.partenerNume, isNull);
    });
  });

  group('Snapshot – modificarea catalogului NU schimbă pontajul salvat', () {
    test('pontajul păstrează valorile de la momentul salvării', () {
      // Angajat cu tarif 300 la momentul pontării.
      const employeeV1 = MasterEmployee(
        id: 'emp-1',
        name: 'Ion Popescu',
        role: 'montator',
        active: true,
        dailyAllowance: 50,
        defaultLodgingCost: 120,
        tarifZilnic: 300,
      );
      final now = DateTime(2026, 7, 30);
      final pontaj = PontajZiLucrare(
        id: 'p1',
        lucrareId: 'job-1',
        data: now,
        persoanaNume: employeeV1.name,
        sursaPersoana: SursaPersoanaPontaj.propriu,
        persoanaRefId: employeeV1.id,
        tarifZilnicSnapshot: employeeV1.tarifZilnic!,
        diurnaSnapshot: employeeV1.dailyAllowance,
        cazareSnapshot: employeeV1.defaultLodgingCost,
        includeDiurna: true,
        includeCazare: true,
        createdAt: now,
        updatedAt: now,
      );

      // Catalogul se modifică ulterior (tarif dublu).
      const employeeV2 = MasterEmployee(
        id: 'emp-1',
        name: 'Ion Popescu',
        role: 'montator',
        active: true,
        dailyAllowance: 100,
        defaultLodgingCost: 200,
        tarifZilnic: 600,
      );
      expect(employeeV2.tarifZilnic, 600);

      // Pontajul salvat NU se schimbă — snapshot fixat.
      final restored = PontajZiLucrare.fromMap(pontaj.toMap());
      expect(restored.tarifZilnicSnapshot, 300);
      expect(restored.diurnaSnapshot, 50);
      expect(restored.cazareSnapshot, 120);
      expect(restored.costZi, 470);
    });
  });

  group('MasterEmployee – backward-compat tarifZilnic', () {
    test('fromMap fără tarifZilnic → null (documente vechi valide)', () {
      final employee = MasterEmployee.fromMap({
        'id': 'emp-old',
        'name': 'Angajat Vechi',
        'role': 'tehnician',
        'active': true,
        'dailyAllowance': 40.0,
      });
      expect(employee.tarifZilnic, isNull);
      expect(employee.dailyAllowance, 40.0);
    });

    test('fromMap cu tarifZilnic → valoare', () {
      final employee = MasterEmployee.fromMap({
        'id': 'emp-new',
        'name': 'Angajat Nou',
        'role': 'tehnician',
        'active': true,
        'tarifZilnic': 350.0,
      });
      expect(employee.tarifZilnic, 350.0);
    });

    test('fromMap cu tarif_zilnic (snake_case) → valoare', () {
      final employee = MasterEmployee.fromMap({
        'id': 'emp-snake',
        'name': 'Angajat',
        'role': 'tehnician',
        'active': true,
        'tarif_zilnic': 275.5,
      });
      expect(employee.tarifZilnic, 275.5);
    });

    test('toMap fără tarifZilnic nu include cheia (compat versiuni vechi)', () {
      const employee = MasterEmployee(
        id: 'emp-1',
        name: 'Test',
        role: 'r',
        active: true,
      );
      expect(employee.toMap().containsKey('tarifZilnic'), isFalse);
    });

    test('roundtrip toMap/fromMap păstrează tarifZilnic', () {
      const employee = MasterEmployee(
        id: 'emp-1',
        name: 'Test',
        role: 'r',
        active: true,
        tarifZilnic: 300,
      );
      final restored = MasterEmployee.fromMap(employee.toMap());
      expect(restored.tarifZilnic, 300);
    });
  });

  group('PontajZiLucrareRepository – offline (local + queue)', () {
    test('save offline: id local-, apare în listLocal și în queue', () async {
      final repo = PontajZiLucrareRepository();
      final saved = await repo.save(_pontaj(id: ''));

      expect(saved.id, startsWith('local-'));

      final locals = await repo.listLocal();
      expect(locals.length, 1);
      expect(locals.first.id, saved.id);
      expect(locals.first.costZi, 470);

      final queue = LocalCloudSyncRepository();
      final pending = await queue.listPendingItems();
      expect(pending.length, 1);
      expect(pending.first.entityType, CloudEntityType.pontajZileLucrari);
      expect(pending.first.entityId, saved.id);
      expect(pending.first.deleted, isFalse);
    });

    test('listForLucrare filtrează după lucrareId', () async {
      final repo = PontajZiLucrareRepository();
      await repo.save(_pontaj(id: ''));
      final now = DateTime(2026, 7, 30);
      await repo.save(PontajZiLucrare(
        id: '',
        lucrareId: 'job-ALTUL',
        data: now,
        persoanaNume: 'Alt Om',
        sursaPersoana: SursaPersoanaPontaj.liber,
        tarifZilnicSnapshot: 100,
        createdAt: now,
        updatedAt: now,
      ));

      final forJob1 = await repo.listForLucrare('job-1');
      expect(forJob1.length, 1);
      expect(forJob1.first.persoanaNume, 'Ion Popescu');

      final forJob2 = await repo.listForLucrare('job-ALTUL');
      expect(forJob2.length, 1);
    });

    test('delete: dispare din local și rămâne delete în queue', () async {
      final repo = PontajZiLucrareRepository();
      final saved = await repo.save(_pontaj(id: ''));

      await repo.delete(saved.id);

      final locals = await repo.listLocal();
      expect(locals, isEmpty);

      final queue = LocalCloudSyncRepository();
      final pending = await queue.listPendingItems();
      // Deduplicare: upsert + delete pe aceeași entitate → rămâne doar delete.
      expect(pending.length, 1);
      expect(pending.first.deleted, isTrue);
      expect(pending.first.entityType, CloudEntityType.pontajZileLucrari);
    });

    test('save pe id existent actualizează în loc să dubleze', () async {
      final repo = PontajZiLucrareRepository();
      final saved = await repo.save(_pontaj(id: ''));
      final updated = await repo.save(saved.copyWith(
        tarifZilnicSnapshot: 999,
        revision: saved.revision + 1,
      ));

      expect(updated.id, saved.id);
      final locals = await repo.listLocal();
      expect(locals.length, 1);
      expect(locals.first.tarifZilnicSnapshot, 999);
      expect(locals.first.revision, saved.revision + 1);
    });
  });
}
