import 'package:flutter_test/flutter_test.dart';
import 'package:devizpro_ultra/features/asociere/asociere_decont_calculator.dart';
import 'package:devizpro_ultra/features/asociere/asociere_models.dart';
import 'package:devizpro_ultra/features/asociere/decont_lunar_asociere_models.dart';

void main() {
  group('calculator decont Asociere independent', () {
    test('profitul rambursează costul și distribuie cota cu rezervă', () {
      final result = calculeazaDecontSettleUp(
        veniturIncasatTotal: 10000,
        costRecunoscutProTerm: 2000,
        costRecunoscutPartener: 1000,
        cotaProTerm: 60,
        cotaPartener: 40,
        incasator: AsociereIncasator.proTerm,
        procentRezervaGarantie: 25,
      );
      expect(result.rezultat, 7000);
      expect(result.rambursareCosturi, 1000);
      expect(result.sumaRezervaRetinuta, 700);
      expect(result.distribuireProfitImediata, 2100);
      expect(result.sumaDeAchitatAcum, 3100);
      expect(result.rambursareDatorataCatre, AsociereRambursareCatre.partener);
    });

    test('pierderea nu reține rezervă', () {
      final result = calculeazaDecontSettleUp(
        veniturIncasatTotal: 1000,
        costRecunoscutProTerm: 3000,
        costRecunoscutPartener: 2000,
        cotaProTerm: 50,
        cotaPartener: 50,
        incasator: AsociereIncasator.proTerm,
        procentRezervaGarantie: 30,
      );
      expect(result.rezultat, -4000);
      expect(result.sumaRezervaRetinuta, 0);
      expect(result.distribuireProfitImediata, -2000);
      expect(result.sumaDeAchitatAcum, 0);
    });

    test('formula este simetrică dacă Partenerul încasează', () {
      final result = calculeazaDecontSettleUp(
        veniturIncasatTotal: 8000,
        costRecunoscutProTerm: 1200,
        costRecunoscutPartener: 800,
        cotaProTerm: 50,
        cotaPartener: 50,
        incasator: AsociereIncasator.partener,
        procentRezervaGarantie: 0,
      );
      expect(result.rambursareDatorataCatre, AsociereRambursareCatre.proTerm);
      expect(result.sumaDeAchitatAcum, 4200);
    });
  });
}
