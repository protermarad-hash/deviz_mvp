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
  // SETTLE-UP — direcția PRO TERM încasează. Primitor (partea care NU
  // încasează) = partenerul. Se verifică SEPARAT cele 3 componente:
  // rambursareCosturi (integral), distribuireProfitImediata, rezervaRetinuta.
  // ===========================================================================
  group('settle-up [PRO TERM încasează] — primitor = partener', () {
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

    test('profit: rezerva DOAR din profit (600), nu din costuri', () {
      // venituri=10000, costPT=2000, costPartener=3000. rezultat=5000.
      // rambursareCosturi = costPartener = 3000 (integral, fără rezervă).
      // cotaProfit partener = 0.4*5000 = 2000 → rezervă 30% = 600, imediat 1400.
      final r = calc(venituri: 10000, costPT: 2000, costPartener: 3000);
      expect(r.rezultat, 5000);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.partener);
      expect(r.rambursareCosturi, 3000);
      expect(r.distribuireProfitImediata, 1400);
      expect(r.sumaRezervaRetinuta, 600); // 30% DIN PROFIT (2000), nu din 5000
      expect(r.sumaRambursare, 5000); // total înainte de rezervă
      expect(r.sumaDeAchitatAcum, 4400); // 3000 costuri + 1400 profit imediat
    });

    test('poziții finale (settlement total, incl. rezerva) ating cotele', () {
      const venituri = 10000.0, costPT = 2000.0, costPartener = 3000.0;
      const cotaPartener = 40.0;
      final r = calc(venituri: venituri, costPT: costPT, costPartener: costPartener);
      final total = r.rambursareCosturi + r.distribuireProfitImediata + r.sumaRezervaRetinuta;
      final finalPartener = -costPartener + total;
      final finalProTerm = venituri - costPT - total;
      expect(finalPartener, closeTo(r.rezultat * cotaPartener / 100, 0.01));
      expect(finalProTerm, closeTo(r.rezultat * (100 - cotaPartener) / 100, 0.01));
    });

    test('pierdere: fără rezervă; cota de pierdere se scade acum (negativă)', () {
      // venituri=4000, costPT=2000, costPartener=3000. rezultat=-1000.
      // rambursareCosturi=3000. cotaProfit partener = 0.4*(-1000) = -400 → fără rezervă.
      final r = calc(venituri: 4000, costPT: 2000, costPartener: 3000);
      expect(r.rezultat, -1000);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.partener);
      expect(r.rambursareCosturi, 3000);
      expect(r.distribuireProfitImediata, -400); // cota de pierdere, integral acum
      expect(r.sumaRezervaRetinuta, 0); // NIMIC din pierdere
      expect(r.sumaRambursare, 2600); // 3000 - 400
      expect(r.sumaDeAchitatAcum, 2600);
    });

    test('partenerul datorează PRO TERM (bani către încasator, fără rezervă)', () {
      // venituri=0, costPT=5000, costPartener=0. rezultat=-5000.
      // rambursareCosturi=0. cotaProfit partener = 0.4*(-5000) = -2000 → total -2000.
      final r = calc(venituri: 0, costPT: 5000, costPartener: 0);
      expect(r.rezultat, -5000);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.proTerm);
      expect(r.rambursareCosturi, 0);
      expect(r.distribuireProfitImediata, -2000);
      expect(r.sumaRezervaRetinuta, 0);
      expect(r.sumaRambursare, 2000);
      expect(r.sumaDeAchitatAcum, 2000);
    });

    test('sold zero: toate componentele 0', () {
      final r = calc(venituri: 3000, costPT: 3000, costPartener: 0);
      expect(r.rezultat, 0);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.niciunul);
      expect(r.rambursareCosturi, 0);
      expect(r.distribuireProfitImediata, 0);
      expect(r.sumaRezervaRetinuta, 0);
      expect(r.sumaRambursare, 0);
      expect(r.sumaDeAchitatAcum, 0);
    });

    test('invarianți: componente însumează totalul; rezerva=30% doar din profit', () {
      final r = calc(
          venituri: 3333.33, costPT: 111.11, costPartener: 777.77, cotaPartener: 45, cotaPT: 55);
      final cotaProfit = 0.45 * r.rezultat;
      expect(r.rambursareCosturi + r.distribuireProfitImediata + r.sumaRezervaRetinuta,
          closeTo(r.sumaRambursare, 0.01));
      expect(r.sumaDeAchitatAcum + r.sumaRezervaRetinuta,
          closeTo(r.sumaRambursare, 0.01));
      expect(r.sumaRezervaRetinuta, closeTo(cotaProfit > 0 ? cotaProfit * 0.3 : 0, 0.01));
    });
  });

  // ===========================================================================
  // SETTLE-UP — direcția PARTENER încasează (ex: contract Madalin/AIR, Art.8.1).
  // Primitor (partea care NU încasează) = PRO TERM.
  // ===========================================================================
  group('settle-up [PARTENER încasează] — primitor = PRO TERM', () {
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

    test('profit: rezerva DOAR din profitul PRO TERM (900), nu din costuri', () {
      // venituri=10000, costPT=2000, costPartener=3000, cotaPT=60. rezultat=5000.
      // rambursareCosturi = costPT = 2000. cotaProfit PT = 0.6*5000 = 3000 →
      // rezervă 900, imediat 2100.
      final r = calc(venituri: 10000, costPT: 2000, costPartener: 3000);
      expect(r.rezultat, 5000);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.proTerm);
      expect(r.rambursareCosturi, 2000);
      expect(r.distribuireProfitImediata, 2100);
      expect(r.sumaRezervaRetinuta, 900); // 30% din 3000
      expect(r.sumaRambursare, 5000);
      expect(r.sumaDeAchitatAcum, 4100); // 2000 + 2100
    });

    test('poziții finale (settlement total, incl. rezerva) ating cotele', () {
      const venituri = 10000.0, costPT = 2000.0, costPartener = 3000.0;
      const cotaPT = 60.0;
      final r = calc(venituri: venituri, costPT: costPT, costPartener: costPartener);
      final total = r.rambursareCosturi + r.distribuireProfitImediata + r.sumaRezervaRetinuta;
      final finalProTerm = -costPT + total;
      final finalPartener = venituri - costPartener - total;
      expect(finalProTerm, closeTo(r.rezultat * cotaPT / 100, 0.01));
      expect(finalPartener, closeTo(r.rezultat * (100 - cotaPT) / 100, 0.01));
    });

    test('pierdere: fără rezervă; cota de pierdere PT se scade acum', () {
      // venituri=4000, costPT=2000, costPartener=3000. rezultat=-1000.
      // rambursareCosturi=2000. cotaProfit PT = 0.6*(-1000) = -600 → fără rezervă.
      final r = calc(venituri: 4000, costPT: 2000, costPartener: 3000);
      expect(r.rezultat, -1000);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.proTerm);
      expect(r.rambursareCosturi, 2000);
      expect(r.distribuireProfitImediata, -600);
      expect(r.sumaRezervaRetinuta, 0);
      expect(r.sumaRambursare, 1400);
      expect(r.sumaDeAchitatAcum, 1400);
    });

    test('PRO TERM datorează partenerul (bani către încasator, fără rezervă)', () {
      // venituri=0, costPT=0, costPartener=5000, cotaPT=60. rezultat=-5000.
      // rambursareCosturi=0. cotaProfit PT = 0.6*(-5000) = -3000 → total -3000.
      final r = calc(venituri: 0, costPT: 0, costPartener: 5000);
      expect(r.rezultat, -5000);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.partener);
      expect(r.rambursareCosturi, 0);
      expect(r.distribuireProfitImediata, -3000);
      expect(r.sumaRezervaRetinuta, 0);
      expect(r.sumaRambursare, 3000);
      expect(r.sumaDeAchitatAcum, 3000);
    });

    test('sold zero: toate componentele 0', () {
      final r = calc(venituri: 3000, costPT: 0, costPartener: 3000);
      expect(r.rezultat, 0);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.niciunul);
      expect(r.rambursareCosturi, 0);
      expect(r.distribuireProfitImediata, 0);
      expect(r.sumaRezervaRetinuta, 0);
      expect(r.sumaRambursare, 0);
      expect(r.sumaDeAchitatAcum, 0);
    });

    test('invarianți: componente însumează totalul; rezerva=30% doar din profit', () {
      final r = calc(
          venituri: 8888.88, costPT: 999.99, costPartener: 222.22, cotaPT: 55, cotaPartener: 45);
      final cotaProfit = 0.55 * r.rezultat;
      expect(r.rambursareCosturi + r.distribuireProfitImediata + r.sumaRezervaRetinuta,
          closeTo(r.sumaRambursare, 0.01));
      expect(r.sumaDeAchitatAcum + r.sumaRezervaRetinuta,
          closeTo(r.sumaRambursare, 0.01));
      expect(r.sumaRezervaRetinuta, closeTo(cotaProfit > 0 ? cotaProfit * 0.3 : 0, 0.01));
    });
  });

  // ===========================================================================
  // BLOCARE — costuri cu aprobare incompletă (funcție pură, ancoră unică)
  // ===========================================================================
  group('costuriCareBlocheazaDecont', () {
    CostAsociereRecord cost({
      required String id,
      required DateTime data,
      bool necesitaAprobare = true,
      bool aprobatPT = false,
      bool aprobatPartener = false,
      DateTime? dataAprobare,
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
          dataAprobare: dataAprobare,
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
        );

    test('blocare efectivă: cost din lună, necesită aprobare, neaprobat integral', () {
      final blocante = costuriCareBlocheazaDecont(
          [cost(id: 'c1', data: DateTime(2026, 7, 10))], 7, 2026);
      expect(blocante.map((c) => c.id), ['c1']);
    });

    test('aprobat integral → NU blochează (ancoră = data aprobării)', () {
      final blocante = costuriCareBlocheazaDecont(
          [cost(id: 'c1', data: DateTime(2026, 7, 10), aprobatPT: true, aprobatPartener: true, dataAprobare: DateTime(2026, 7, 12))],
          7, 2026);
      expect(blocante, isEmpty);
    });

    test('aprobat parțial (doar PT) → tot blochează', () {
      final blocante = costuriCareBlocheazaDecont(
          [cost(id: 'c1', data: DateTime(2026, 7, 10), aprobatPT: true)], 7, 2026);
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
  // PROBLEMA 2 — ancoră de dată CONSECVENTĂ între blocare și recunoaștere
  // ===========================================================================
  group('dataApartenentaLuna — regulă unică de apartenență la lună', () {
    CostAsociereRecord cost({
      required DateTime data,
      bool necesitaAprobare = false,
      bool aprobat = false,
      DateTime? dataAprobare,
    }) =>
        CostAsociereRecord(
          id: 'c',
          asociereId: 'a1',
          categorie: AsociereCostCategorie.material,
          data: data,
          descriere: 'x',
          valoareFaraTva: 100,
          asociatPlatitor: AsociereParte.proTerm,
          necesitaAprobare: necesitaAprobare,
          aprobatProTerm: aprobat,
          aprobatPartener: aprobat,
          dataAprobare: dataAprobare,
          createdAt: data,
          updatedAt: data,
        );

    test('fără aprobare → apartenența = data cheltuielii', () {
      expect(cost(data: DateTime(2026, 7, 10)).dataApartenentaLuna,
          DateTime(2026, 7, 10));
    });

    test('necesită aprobare, neaprobat → fallback la data cheltuielii', () {
      expect(cost(data: DateTime(2026, 7, 10), necesitaAprobare: true).dataApartenentaLuna,
          DateTime(2026, 7, 10));
    });

    test('aprobat în luna următoare → apartenența = data aprobării (luna următoare)', () {
      // data = iulie, dataAprobare = august → costul aparține lunii AUGUST.
      final c = cost(
          data: DateTime(2026, 7, 10),
          necesitaAprobare: true,
          aprobat: true,
          dataAprobare: DateTime(2026, 8, 3));
      expect(c.dataApartenentaLuna, DateTime(2026, 8, 3));
    });

    test('neaprobat cu data iulie → blochează IULIE, nu august (ancoră = data)', () {
      final c = cost(data: DateTime(2026, 7, 10), necesitaAprobare: true);
      expect(costuriCareBlocheazaDecont([c], 7, 2026).map((x) => x.id), ['c']);
      expect(costuriCareBlocheazaDecont([c], 8, 2026), isEmpty);
    });
  });

  // ===========================================================================
  // INTEGRARE — genereazaDecontPentruLuna (repository real, SharedPreferences mock)
  // ===========================================================================
  group('genereazaDecontPentruLuna — blocare + consecvență ancoră', () {
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

    CostAsociereRecord cost({
      required bool aprobat,
      DateTime? dataAprobare,
    }) =>
        CostAsociereRecord(
          id: 'cost-int',
          asociereId: 'as-int',
          categorie: AsociereCostCategorie.material,
          data: DateTime(2026, 7, 10),
          descriere: 'material scump',
          valoareFaraTva: 5000,
          asociatPlatitor: AsociereParte.proTerm,
          necesitaAprobare: true,
          aprobatProTerm: aprobat,
          aprobatPartener: aprobat,
          dataAprobare: dataAprobare,
          createdAt: DateTime(2026, 7, 10),
          updatedAt: DateTime(2026, 7, 10),
        );

    test('blocare efectivă: aruncă DecontAprobareIncompletaException', () async {
      await AsociereRepository.instance.upsertAsociere(asociere());
      await CostAsociereRepository.instance.upsertCost(cost(aprobat: false));

      expect(
        () => DecontLunarAsociereRepository.instance
            .genereazaDecontPentruLuna(asociereId: 'as-int', luna: 7, an: 2026),
        throwsA(isA<DecontAprobareIncompletaException>()),
      );
    });

    test('decont normal după aprobare integrală în aceeași lună', () async {
      await AsociereRepository.instance.upsertAsociere(asociere());
      await CostAsociereRepository.instance
          .upsertCost(cost(aprobat: true, dataAprobare: DateTime(2026, 7, 12)));

      final decont = await DecontLunarAsociereRepository.instance
          .genereazaDecontPentruLuna(asociereId: 'as-int', luna: 7, an: 2026);
      expect(decont.status, DecontLunarStatus.draft);
      expect(decont.costRecunoscutProTerm, 5000);
      expect(decont.rezultat, -5000);
    });

    test('consecvență: cost aprobat în august → exclus din iulie, inclus în august', () async {
      // data=iulie, aprobat cu dataAprobare=august → aparține lunii AUGUST prin
      // ACEEAȘI regulă folosită și de blocare (PROBLEMA 2).
      await AsociereRepository.instance.upsertAsociere(asociere());
      await CostAsociereRepository.instance
          .upsertCost(cost(aprobat: true, dataAprobare: DateTime(2026, 8, 3)));

      // Iulie: cost aprobat (nu blochează) și NU aparține lui iulie → exclus.
      final iulie = await DecontLunarAsociereRepository.instance
          .genereazaDecontPentruLuna(asociereId: 'as-int', luna: 7, an: 2026);
      expect(iulie.costRecunoscutProTerm, 0);
      expect(iulie.rezultat, 0);

      // August: costul aparține lunii → inclus (verificat de blocarea lunii august).
      final august = await DecontLunarAsociereRepository.instance
          .genereazaDecontPentruLuna(asociereId: 'as-int', luna: 8, an: 2026);
      expect(august.costRecunoscutProTerm, 5000);
      expect(august.rezultat, -5000);
    });
  });
}
