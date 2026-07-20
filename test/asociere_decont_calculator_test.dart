import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:devizpro_ultra/features/asociere/asociere_decont_calculator.dart';
import 'package:devizpro_ultra/features/asociere/asociere_models.dart';
import 'package:devizpro_ultra/features/asociere/asociere_repository.dart';
import 'package:devizpro_ultra/features/asociere/cost_asociere_models.dart';
import 'package:devizpro_ultra/features/asociere/cost_asociere_repository.dart';
import 'package:devizpro_ultra/features/asociere/decont_lunar_asociere_models.dart';
import 'package:devizpro_ultra/features/asociere/decont_lunar_asociere_repository.dart';

void main() {
  // ===========================================================================
  // SETTLE-UP — direcția PRO TERM încasează (contractant principal = PRO TERM)
  // ===========================================================================
  group('settle-up [PRO TERM încasează] — rambursare către partener', () {
    AsociereDecontSettleUp calc({
      required double venituri,
      required double costPT,
      required double costPartener,
      double cotaPT = 60,
      double cotaPartener = 40,
      double rezerva = 30,
    }) =>
        calculeazaDecontSettleUp(
          veniturIncasatTotal: venituri,
          costRecunoscutProTerm: costPT,
          costRecunoscutPartener: costPartener,
          cotaProTerm: cotaPT,
          cotaPartener: cotaPartener,
          incasator: AsociereIncasator.proTerm,
          procentRezervaGarantie: rezerva,
        );

    test('profit: PRO TERM datorează partenerului, cu reținere rezervă 30%', () {
      // venituri=10000, costPT=2000, costPartener=3000, cotaPartener=40%.
      // rezultat = 5000. T = 3000 + 0.4*5000 = 5000 → către partener.
      final r = calc(venituri: 10000, costPT: 2000, costPartener: 3000);
      expect(r.rezultat, 5000);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.partener);
      expect(r.sumaRambursare, 5000);
      expect(r.sumaRezervaRetinuta, 1500); // 30% din 5000
      expect(r.sumaDeAchitatAcum, 3500); // restul, 70%
    });

    test('poziții finale: fiecare parte ajunge la cota din rezultat', () {
      // PRO TERM ține numerarul V:
      // final PRO TERM = V - costPT - T ; final partener = -costPartener + T.
      const venituri = 10000.0, costPT = 2000.0, costPartener = 3000.0;
      const cotaPartener = 40.0;
      final r = calc(venituri: venituri, costPT: costPT, costPartener: costPartener);
      final t = r.sumaRambursare; // pozitiv → către partener
      final finalPartener = -costPartener + t;
      final finalProTerm = venituri - costPT - t;
      expect(finalPartener, closeTo(r.rezultat * cotaPartener / 100, 0.01));
      expect(finalProTerm, closeTo(r.rezultat * (100 - cotaPartener) / 100, 0.01));
    });

    test('pierdere: PRO TERM tot datorează partenerului (acoperă parte din pierdere)', () {
      // venituri=4000, costPT=2000, costPartener=3000. rezultat=-1000.
      // T = 3000 + 0.4*(-1000) = 2600.
      final r = calc(venituri: 4000, costPT: 2000, costPartener: 3000);
      expect(r.rezultat, -1000);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.partener);
      expect(r.sumaRambursare, 2600);
      expect(r.sumaRezervaRetinuta, 780); // 30% din 2600
      expect(r.sumaDeAchitatAcum, 1820);
    });

    test('partenerul datorează PRO TERM: fără rezervă (bani către încasator)', () {
      // venituri=0, costPT=5000, costPartener=0. rezultat=-5000.
      // T = 0 + 0.4*(-5000) = -2000 → partener datorează PRO TERM 2000.
      final r = calc(venituri: 0, costPT: 5000, costPartener: 0);
      expect(r.rezultat, -5000);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.proTerm);
      expect(r.sumaRambursare, 2000);
      expect(r.sumaRezervaRetinuta, 0);
      expect(r.sumaDeAchitatAcum, 2000);
    });

    test('sold zero: nimeni nu datorează nimic', () {
      // venituri=3000, costPT=3000, costPartener=0. rezultat=0. T=0.
      final r = calc(venituri: 3000, costPT: 3000, costPartener: 0);
      expect(r.rezultat, 0);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.niciunul);
      expect(r.sumaRambursare, 0);
      expect(r.sumaRezervaRetinuta, 0);
      expect(r.sumaDeAchitatAcum, 0);
    });

    test('rezervă + achitat acum însumează exact suma rambursare', () {
      final r = calc(
          venituri: 3333.33, costPT: 111.11, costPartener: 777.77, cotaPartener: 45, cotaPT: 55);
      expect(r.sumaRezervaRetinuta + r.sumaDeAchitatAcum,
          closeTo(r.sumaRambursare, 0.01));
    });
  });

  // ===========================================================================
  // SETTLE-UP — direcția PARTENER încasează (ex: contract Madalin/AIR, Art. 8.1)
  // ===========================================================================
  group('settle-up [PARTENER încasează] — rambursare către PRO TERM', () {
    AsociereDecontSettleUp calc({
      required double venituri,
      required double costPT,
      required double costPartener,
      double cotaPT = 60,
      double cotaPartener = 40,
      double rezerva = 30,
    }) =>
        calculeazaDecontSettleUp(
          veniturIncasatTotal: venituri,
          costRecunoscutProTerm: costPT,
          costRecunoscutPartener: costPartener,
          cotaProTerm: cotaPT,
          cotaPartener: cotaPartener,
          incasator: AsociereIncasator.partener,
          procentRezervaGarantie: rezerva,
        );

    test('profit: partenerul datorează PRO TERM, cu reținere rezervă 30%', () {
      // venituri=10000, costPT=2000, costPartener=3000, cotaPT=60%.
      // rezultat=5000. primitor=PRO TERM. T = 2000 + 0.6*5000 = 5000 → către PRO TERM.
      // Rezerva se reține (bani către partea care NU încasează = PRO TERM).
      final r = calc(venituri: 10000, costPT: 2000, costPartener: 3000);
      expect(r.rezultat, 5000);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.proTerm);
      expect(r.sumaRambursare, 5000);
      expect(r.sumaRezervaRetinuta, 1500);
      expect(r.sumaDeAchitatAcum, 3500);
    });

    test('poziții finale: fiecare parte ajunge la cota din rezultat', () {
      // Partenerul ține numerarul V:
      // final partener = V - costPartener - T ; final PRO TERM = -costPT + T.
      const venituri = 10000.0, costPT = 2000.0, costPartener = 3000.0;
      const cotaPT = 60.0;
      final r = calc(venituri: venituri, costPT: costPT, costPartener: costPartener);
      final t = r.sumaRambursare; // pozitiv → către PRO TERM
      final finalProTerm = -costPT + t;
      final finalPartener = venituri - costPartener - t;
      expect(finalProTerm, closeTo(r.rezultat * cotaPT / 100, 0.01));
      expect(finalPartener, closeTo(r.rezultat * (100 - cotaPT) / 100, 0.01));
    });

    test('pierdere: partenerul tot datorează PRO TERM (acoperă parte din pierdere)', () {
      // venituri=4000, costPT=2000, costPartener=3000. rezultat=-1000.
      // primitor=PRO TERM. T = 2000 + 0.6*(-1000) = 1400 → către PRO TERM.
      final r = calc(venituri: 4000, costPT: 2000, costPartener: 3000);
      expect(r.rezultat, -1000);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.proTerm);
      expect(r.sumaRambursare, 1400);
      expect(r.sumaRezervaRetinuta, 420); // 30% din 1400
      expect(r.sumaDeAchitatAcum, 980);
    });

    test('PRO TERM datorează partenerul: fără rezervă (bani către încasator)', () {
      // venituri=0, costPT=0, costPartener=5000, cotaPT=60%. rezultat=-5000.
      // primitor=PRO TERM. T = 0 + 0.6*(-5000) = -3000 → bani către partener (încasator).
      final r = calc(venituri: 0, costPT: 0, costPartener: 5000);
      expect(r.rezultat, -5000);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.partener);
      expect(r.sumaRambursare, 3000);
      expect(r.sumaRezervaRetinuta, 0); // bani către încasator → fără rezervă
      expect(r.sumaDeAchitatAcum, 3000);
    });

    test('sold zero: nimeni nu datorează nimic', () {
      // venituri=3000, costPT=0, costPartener=3000. rezultat=0. T=0.
      final r = calc(venituri: 3000, costPT: 0, costPartener: 3000);
      expect(r.rezultat, 0);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.niciunul);
      expect(r.sumaRambursare, 0);
      expect(r.sumaRezervaRetinuta, 0);
      expect(r.sumaDeAchitatAcum, 0);
    });

    test('rezervă + achitat acum însumează exact suma rambursare', () {
      final r = calc(
          venituri: 8888.88, costPT: 999.99, costPartener: 222.22, cotaPT: 55, cotaPartener: 45);
      expect(r.sumaRezervaRetinuta + r.sumaDeAchitatAcum,
          closeTo(r.sumaRambursare, 0.01));
    });
  });

  // ===========================================================================
  // BLOCARE — costuri cu aprobare incompletă (funcție pură)
  // ===========================================================================
  group('costuriCareBlocheazaDecont', () {
    CostAsociereRecord cost({
      required String id,
      required DateTime data,
      bool necesitaAprobare = true,
      bool aprobatPT = false,
      bool aprobatPartener = false,
    }) =>
        CostAsociereRecord(
          id: id,
          asociereId: 'a1',
          categorie: AsociereCostCategorie.material,
          data: data,
          descriere: 'cost $id',
          valoareFaraTva: 5000,
          asociatPlatitor: AsociereParte.proTerm,
          necesitaAprobare: necesitaAprobare,
          aprobatProTerm: aprobatPT,
          aprobatPartener: aprobatPartener,
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
        );

    test('blocare efectivă: cost din lună, necesită aprobare, neaprobat integral', () {
      final blocante = costuriCareBlocheazaDecont(
        [cost(id: 'c1', data: DateTime(2026, 7, 10))],
        7,
        2026,
      );
      expect(blocante.map((c) => c.id), ['c1']);
    });

    test('aprobat integral (PT + partener) → NU blochează', () {
      final blocante = costuriCareBlocheazaDecont(
        [cost(id: 'c1', data: DateTime(2026, 7, 10), aprobatPT: true, aprobatPartener: true)],
        7,
        2026,
      );
      expect(blocante, isEmpty);
    });

    test('aprobat parțial (doar PT) → tot blochează', () {
      final blocante = costuriCareBlocheazaDecont(
        [cost(id: 'c1', data: DateTime(2026, 7, 10), aprobatPT: true)],
        7,
        2026,
      );
      expect(blocante.map((c) => c.id), ['c1']);
    });

    test('cost din altă lună sau care nu necesită aprobare → nu blochează', () {
      final blocante = costuriCareBlocheazaDecont(
        [
          cost(id: 'alta-luna', data: DateTime(2026, 6, 10)),
          cost(id: 'fara-aprobare', data: DateTime(2026, 7, 10), necesitaAprobare: false),
        ],
        7,
        2026,
      );
      expect(blocante, isEmpty);
    });
  });

  // ===========================================================================
  // INTEGRARE — genereazaDecontPentruLuna blochează / reușește (repository real)
  // ===========================================================================
  group('genereazaDecontPentruLuna — blocare la aprobare incompletă', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    AsociereRecord asociere() => AsociereRecord(
          id: 'as-int',
          lucrareId: 'lucr-1',
          cineFactureazaBeneficiarul: AsociereIncasator.proTerm,
          cotaProTerm: 60,
          cotaPartener: 40,
          dataInceput: DateTime(2026, 7, 1),
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
        );

    CostAsociereRecord costNeaprobat() => CostAsociereRecord(
          id: 'cost-int',
          asociereId: 'as-int',
          categorie: AsociereCostCategorie.material,
          data: DateTime(2026, 7, 10),
          descriere: 'material scump',
          valoareFaraTva: 5000,
          asociatPlatitor: AsociereParte.proTerm,
          necesitaAprobare: true,
          aprobatProTerm: false,
          aprobatPartener: false,
          createdAt: DateTime(2026, 7, 10),
          updatedAt: DateTime(2026, 7, 10),
        );

    test('blocare efectivă: aruncă DecontAprobareIncompletaException', () async {
      await AsociereRepository.instance.upsertAsociere(asociere());
      await CostAsociereRepository.instance.upsertCost(costNeaprobat());

      expect(
        () => DecontLunarAsociereRepository.instance
            .genereazaDecontPentruLuna(asociereId: 'as-int', luna: 7, an: 2026),
        throwsA(isA<DecontAprobareIncompletaException>()),
      );
    });

    test('decont normal după aprobare integrală', () async {
      await AsociereRepository.instance.upsertAsociere(asociere());
      await CostAsociereRepository.instance.upsertCost(
        costNeaprobat().copyWith(
          aprobatProTerm: true,
          aprobatPartener: true,
          dataAprobare: DateTime(2026, 7, 12),
        ),
      );

      final decont = await DecontLunarAsociereRepository.instance
          .genereazaDecontPentruLuna(asociereId: 'as-int', luna: 7, an: 2026);
      expect(decont.status, DecontLunarStatus.draft);
      // Cost 5000 plătit de PRO TERM, fără venituri → rezultat = -5000.
      expect(decont.costRecunoscutProTerm, 5000);
      expect(decont.rezultat, -5000);
    });
  });
}
