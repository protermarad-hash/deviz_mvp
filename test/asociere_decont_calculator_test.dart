import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/features/asociere/asociere_decont_calculator.dart';
import 'package:devizpro_ultra/features/asociere/decont_lunar_asociere_models.dart';

void main() {
  group('calculeazaDecontSettleUp — settle-up pe cote + rezervă', () {
    test('profit: PRO TERM datorează partenerului, cu reținere rezervă 30%', () {
      // venituri=10000, costPT=2000, costPartener=3000, cotaPartener=40%.
      // rezultat = 10000 - 5000 = 5000.
      // T = 3000 + 0.4*5000 = 5000 → PRO TERM datorează partenerului 5000.
      final r = calculeazaDecontSettleUp(
        veniturIncasatTotal: 10000,
        costRecunoscutProTerm: 2000,
        costRecunoscutPartener: 3000,
        cotaPartener: 40,
        procentRezervaGarantie: 30,
      );
      expect(r.rezultat, 5000);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.partener);
      expect(r.sumaRambursare, 5000);
      expect(r.sumaRezervaRetinuta, 1500); // 30% din 5000
      expect(r.sumaDeAchitatAcum, 3500); // restul, 70%
    });

    test('poziții finale corecte: fiecare parte ajunge la cota din rezultat', () {
      // Verifică invariantul modelului (PRO TERM ține numerarul):
      // final PRO TERM = venituri - costPT - T ; final partener = -costPartener + T.
      const venituri = 10000.0, costPT = 2000.0, costPartener = 3000.0;
      const cotaPartener = 40.0;
      final r = calculeazaDecontSettleUp(
        veniturIncasatTotal: venituri,
        costRecunoscutProTerm: costPT,
        costRecunoscutPartener: costPartener,
        cotaPartener: cotaPartener,
        procentRezervaGarantie: 30,
      );
      final t = r.sumaRambursare; // pozitiv → către partener
      final finalPartener = -costPartener + t;
      final finalProTerm = venituri - costPT - t;
      expect(finalPartener, closeTo(r.rezultat * cotaPartener / 100, 0.01));
      expect(finalProTerm, closeTo(r.rezultat * (100 - cotaPartener) / 100, 0.01));
    });

    test('pierdere: PRO TERM tot datorează partenerului (parte din pierdere acoperită)', () {
      // venituri=4000, costPT=2000, costPartener=3000, cotaPartener=40%.
      // rezultat = -1000. T = 3000 + 0.4*(-1000) = 2600.
      final r = calculeazaDecontSettleUp(
        veniturIncasatTotal: 4000,
        costRecunoscutProTerm: 2000,
        costRecunoscutPartener: 3000,
        cotaPartener: 40,
        procentRezervaGarantie: 30,
      );
      expect(r.rezultat, -1000);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.partener);
      expect(r.sumaRambursare, 2600);
      expect(r.sumaRezervaRetinuta, 780); // 30% din 2600
      expect(r.sumaDeAchitatAcum, 1820);
    });

    test('partenerul datorează PRO TERM: fără rezervă reținută', () {
      // venituri=0, costPT=5000, costPartener=0, cotaPartener=40%.
      // rezultat = -5000. T = 0 + 0.4*(-5000) = -2000 → partener datorează 2000.
      final r = calculeazaDecontSettleUp(
        veniturIncasatTotal: 0,
        costRecunoscutProTerm: 5000,
        costRecunoscutPartener: 0,
        cotaPartener: 40,
        procentRezervaGarantie: 30,
      );
      expect(r.rezultat, -5000);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.proTerm);
      expect(r.sumaRambursare, 2000);
      expect(r.sumaRezervaRetinuta, 0); // rezerva doar la plata către partener
      expect(r.sumaDeAchitatAcum, 2000); // se achită integral către PRO TERM
    });

    test('sold zero: nimeni nu datorează nimic', () {
      // venituri=5000, costPT=3000, costPartener=0, cotaPartener=40%.
      // rezultat=2000. T = 0 + 0.4*2000 = 800 → partener. (nu e zero)
      // Construim un caz cu T=0: costPartener=0, rezultat=0.
      final r = calculeazaDecontSettleUp(
        veniturIncasatTotal: 3000,
        costRecunoscutProTerm: 3000,
        costRecunoscutPartener: 0,
        cotaPartener: 40,
        procentRezervaGarantie: 30,
      );
      expect(r.rezultat, 0);
      expect(r.rambursareDatorataCatre, AsociereRambursareCatre.niciunul);
      expect(r.sumaRambursare, 0);
      expect(r.sumaRezervaRetinuta, 0);
      expect(r.sumaDeAchitatAcum, 0);
    });

    test('rezervă + achitat acum însumează mereu exact suma rambursare', () {
      final r = calculeazaDecontSettleUp(
        veniturIncasatTotal: 3333.33,
        costRecunoscutProTerm: 111.11,
        costRecunoscutPartener: 777.77,
        cotaPartener: 45,
        procentRezervaGarantie: 30,
      );
      expect(
        r.sumaRezervaRetinuta + r.sumaDeAchitatAcum,
        closeTo(r.sumaRambursare, 0.01),
      );
    });
  });
}
