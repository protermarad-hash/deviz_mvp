import 'package:devizpro_ultra/features/oferte/bnr_exchange_rate_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fragment reprezentativ din nbrfxrates.xml (BNR). HUF are multiplier="100",
/// EUR nu are (implicit 1). Testul garantează că împărțirea la multiplier NU
/// este ștearsă din greșeală în viitor (ar da un curs de 100x greșit pentru HUF).
const String _sampleBnrXml = '''
<?xml version="1.0" encoding="utf-8"?>
<DataSet xmlns="http://www.bnr.ro/xsd">
  <Body>
    <Cube date="2026-07-05">
      <Rate currency="EUR">4.9771</Rate>
      <Rate currency="HUF" multiplier="100">1.2494</Rate>
      <Rate currency="JPY" multiplier="100">3.0517</Rate>
      <Rate currency="USD">4.6120</Rate>
    </Cube>
  </Body>
</DataSet>
''';

void main() {
  group('BnrExchangeRateService.parseRateFromXml — multiplier', () {
    test('HUF cu multiplier="100" → valoare / 100 (0.012494, NU 1.2494)', () {
      final rate = BnrExchangeRateService.parseRateFromXml(_sampleBnrXml, 'HUF');
      expect(rate, isNotNull);
      // 1.2494 / 100 = 0.012494
      expect(rate, closeTo(0.012494, 1e-9));
      // Garanție explicită împotriva regresiei: NU trebuie să fie valoarea brută.
      expect(rate, isNot(closeTo(1.2494, 1e-6)));
    });

    test('EUR fără multiplier → valoare brută (implicit multiplier 1)', () {
      final rate = BnrExchangeRateService.parseRateFromXml(_sampleBnrXml, 'EUR');
      expect(rate, isNotNull);
      expect(rate, closeTo(4.9771, 1e-9));
    });

    test('JPY cu multiplier="100" → valoare / 100', () {
      final rate = BnrExchangeRateService.parseRateFromXml(_sampleBnrXml, 'JPY');
      expect(rate, isNotNull);
      expect(rate, closeTo(0.030517, 1e-9));
    });

    test('case-insensitive pe codul valutei', () {
      final rate = BnrExchangeRateService.parseRateFromXml(_sampleBnrXml, 'huf');
      expect(rate, closeTo(0.012494, 1e-9));
    });

    test('valută inexistentă → null', () {
      final rate = BnrExchangeRateService.parseRateFromXml(_sampleBnrXml, 'GBP');
      expect(rate, isNull);
    });
  });
}
