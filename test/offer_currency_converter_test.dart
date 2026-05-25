import 'package:devizpro_ultra/features/oferte/offer_currency_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfferCurrencyConverter.normalizeCurrency', () {
    test('normalizes only EUR and maps everything else to RON', () {
      expect(OfferCurrencyConverter.normalizeCurrency(' eur '), 'EUR');
      expect(OfferCurrencyConverter.normalizeCurrency('ron'), 'RON');
      expect(OfferCurrencyConverter.normalizeCurrency('usd'), 'RON');
    });
  });

  group('OfferCurrencyConverter.computeEffectiveRate', () {
    test('applies commission on top of base rate', () {
      final rate = OfferCurrencyConverter.computeEffectiveRate(
        baseRate: 5,
        commissionPercent: 2,
      );
      expect(rate, 5.1);
    });

    test('returns zero for invalid base rate', () {
      final rate = OfferCurrencyConverter.computeEffectiveRate(
        baseRate: -1,
        commissionPercent: 5,
      );
      expect(rate, 0);
    });
  });

  group('OfferCurrencyConverter.convertRonToOfferCurrency', () {
    test('converts RON to EUR using effective rate', () {
      final converted = OfferCurrencyConverter.convertRonToOfferCurrency(
        ronAmount: 510,
        currency: 'EUR',
        effectiveRate: 5.1,
      );
      expect(converted, 100);
    });

    test('returns original amount when rate is invalid', () {
      final converted = OfferCurrencyConverter.convertRonToOfferCurrency(
        ronAmount: 100,
        currency: 'EUR',
        effectiveRate: 0,
      );
      expect(converted, 100);
    });
  });
}
