import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:devizpro_ultra/features/asociere/asociere_operational_common.dart';
import 'package:devizpro_ultra/features/asociere/tarif_asociere_models.dart';
import 'package:devizpro_ultra/features/asociere/tarif_asociere_repository.dart';

void main() {
  final now = DateTime(2026, 7, 20);

  TarifAsociereRecord tarif({
    required String id,
    String persoanaId = '',
    String calificare = 'instalator',
    double tarifOra = 50,
    AsociereParte asociat = AsociereParte.proTerm,
    DateTime? valabilDeLa,
    DateTime? valabilPanaLa,
    bool activ = true,
  }) =>
      TarifAsociereRecord(
        id: id,
        projectId: 'p1',
        persoanaId: persoanaId,
        calificare: calificare,
        tarifOra: tarifOra,
        asociat: asociat,
        valabilDeLa: valabilDeLa ?? now.subtract(const Duration(days: 30)),
        valabilPanaLa: valabilPanaLa,
        activ: activ,
        createdAt: now,
        updatedAt: now,
      );

  group('rezolvaTarifAsociere (pur, fallback)', () {
    test('lipsă tarif → sursa lipsa, tarif 0', () {
      final rez = rezolvaTarifAsociere(
        tarife: const [],
        persoanaId: 'u1',
        calificare: 'instalator',
        angajator: AsociereParte.proTerm,
        data: now,
      );
      expect(rez.tarifOra, 0);
      expect(rez.sursa, TarifAsociereSursa.lipsa);
      expect(rez.lipsa, isTrue);
    });

    test('tariful individual are prioritate față de cel pe calificare', () {
      final rez = rezolvaTarifAsociere(
        tarife: [
          tarif(id: 'calif', tarifOra: 40),
          tarif(id: 'indiv', persoanaId: 'u1', tarifOra: 65),
        ],
        persoanaId: 'u1',
        calificare: 'instalator',
        angajator: AsociereParte.proTerm,
        data: now,
      );
      expect(rez.sursa, TarifAsociereSursa.individual);
      expect(rez.tarifOra, 65);
    });

    test('fallback pe calificare + angajator când nu există individual', () {
      final rez = rezolvaTarifAsociere(
        tarife: [
          tarif(id: 'partener', tarifOra: 30, asociat: AsociereParte.partener),
          tarif(id: 'proterm', tarifOra: 55, asociat: AsociereParte.proTerm),
        ],
        persoanaId: 'u2',
        calificare: 'instalator',
        angajator: AsociereParte.proTerm,
        data: now,
      );
      expect(rez.sursa, TarifAsociereSursa.calificareAngajator);
      expect(rez.tarifOra, 55);
    });

    test('fallback pe calificare (orice angajator) dacă nu se potrivește parte',
        () {
      final rez = rezolvaTarifAsociere(
        tarife: [
          tarif(id: 'partener', tarifOra: 33, asociat: AsociereParte.partener),
        ],
        persoanaId: 'u3',
        calificare: 'instalator',
        angajator: AsociereParte.proTerm,
        data: now,
      );
      expect(rez.sursa, TarifAsociereSursa.calificare);
      expect(rez.tarifOra, 33);
    });

    test('un tarif expirat nu este folosit', () {
      final rez = rezolvaTarifAsociere(
        tarife: [
          tarif(
            id: 'expirat',
            persoanaId: 'u1',
            tarifOra: 80,
            valabilDeLa: DateTime(2026, 1, 1),
            valabilPanaLa: DateTime(2026, 6, 30),
          ),
        ],
        persoanaId: 'u1',
        calificare: 'instalator',
        angajator: AsociereParte.proTerm,
        data: now,
      );
      expect(rez.sursa, TarifAsociereSursa.lipsa);
    });
  });

  group('model backward compatibility', () {
    test('fromMap fără câmpuri persoană → tarif pe calificare', () {
      final vechi = TarifAsociereRecord.fromMap({
        'id': 't1',
        'project_id': 'p1',
        'calificare': 'electrician',
        'tarif_ora': 45,
        'valabil_de_la': now.toIso8601String(),
      });
      expect(vechi.esteIndividual, isFalse);
      expect(vechi.persoanaId, '');
      expect(vechi.tarifOra, 45);
    });

    test('roundtrip toMap/fromMap păstrează persoana', () {
      final t = tarif(id: 't2', persoanaId: 'u9');
      final restored = TarifAsociereRecord.fromMap(t.toMap());
      expect(restored.persoanaId, 'u9');
      expect(restored.esteIndividual, isTrue);
    });
  });

  group('TarifAsociereRepository unicitate', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('tarif individual și tarif pe calificare NU se ciocnesc', () async {
      final repo = TarifAsociereRepository.instance;
      await repo.upsertTarif(tarif(id: 'calif1'));
      await repo.upsertTarif(tarif(id: 'indiv1', persoanaId: 'u1'));
      final all = await repo.listByProject('p1');
      expect(all, hasLength(2));
    });

    test('duplicat pe calificare + perioadă aruncă', () async {
      final repo = TarifAsociereRepository.instance;
      await repo.upsertTarif(tarif(id: 'a'));
      expect(() => repo.upsertTarif(tarif(id: 'b')), throwsStateError);
    });

    test('rezolva din repository preferă tariful individual', () async {
      final repo = TarifAsociereRepository.instance;
      await repo.upsertTarif(tarif(id: 'calif', tarifOra: 40));
      await repo.upsertTarif(
          tarif(id: 'indiv', persoanaId: 'u1', tarifOra: 70));
      final rez = await repo.rezolva(
        projectId: 'p1',
        persoanaId: 'u1',
        calificare: 'instalator',
        angajator: AsociereParte.proTerm,
        data: now,
      );
      expect(rez.tarifOra, 70);
      expect(rez.sursa, TarifAsociereSursa.individual);
    });
  });
}
