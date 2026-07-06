import 'package:devizpro_ultra/features/deviz_tehnic/deviz_tehnic_models.dart';
import 'package:flutter_test/flutter_test.dart';

DevizTehnicRecord _record({
  String currency = 'RON',
  double bnrRate = 0,
  double manualRate = 0,
  double exchangeCommissionPercent = 0,
  double effectiveExchangeRate = 1,
  double pretMat = 100,
  double pretMan = 0,
}) {
  final now = DateTime(2026, 1, 1);
  return DevizTehnicRecord(
    id: 'dt-test',
    numar: 'DT-TEST',
    titlu: 'Test deviz tehnic',
    clientName: 'Client test',
    articole: [
      DevizTehnicArticol(
        denumire: 'Articol test',
        um: 'buc',
        cantitate: 1,
        pretMat: pretMat,
        pretMan: pretMan,
      ),
    ],
    regiePercent: 0,
    profitPercent: 0,
    tvaPercent: 0,
    currency: currency,
    bnrRate: bnrRate,
    manualRate: manualRate,
    exchangeCommissionPercent: exchangeCommissionPercent,
    effectiveExchangeRate: effectiveExchangeRate,
    dataEmiterii: now,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('DevizTehnicRecord currency support', () {
    test('keeps old records backward-compatible as RON', () {
      final record = DevizTehnicRecord.fromMap({
        'id': 'old-dt',
        'numar': 'DT-OLD',
        'titlu': 'Deviz vechi',
        'client_name': 'Client vechi',
        'articole': [
          {
            'denumire': 'Articol vechi',
            'um': 'buc',
            'cantitate': 1,
            'pret_mat': 100,
          },
        ],
        'regie_percent': 0,
        'profit_percent': 0,
        'tva_percent': 0,
        'data_emiterii': '2026-01-01T00:00:00.000',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      });

      expect(record.normalizedCurrency, 'RON');
      expect(record.resolvedEffectiveExchangeRate, 1);
      expect(record.totalCuTva, 100);
      expect(record.formatMoney(record.totalCuTva), '100.00 RON');
    });

    test('keeps internal totals in RON and only converts for display', () {
      final record = _record(
        currency: 'EUR',
        manualRate: 5,
        effectiveExchangeRate: 5,
        pretMat: 500,
      );

      expect(record.totalCuTva, 500);
      expect(record.convertRonToCurrency(record.totalCuTva), 100);
      expect(record.formatMoney(record.totalCuTva), '100.00 EUR');
    });

    test('uses zero decimals for HUF display', () {
      final record = _record(
        currency: 'HUF',
        manualRate: 0.012,
        effectiveExchangeRate: 0.012,
        pretMat: 1200,
      );

      expect(record.totalCuTva, 1200);
      expect(record.convertRonToCurrency(record.totalCuTva), 100000);
      expect(record.formatMoney(record.totalCuTva), '100000 HUF');
    });

    test('can derive effective rate from base rate and commission', () {
      final record = _record(
        currency: 'EUR',
        manualRate: 5,
        exchangeCommissionPercent: 2,
        effectiveExchangeRate: 0,
        pretMat: 510,
      );

      expect(record.resolvedEffectiveExchangeRate, 5.1);
      expect(record.convertRonToCurrency(record.totalCuTva), 100);
    });

    test('HUF uses its BNR rate instead of a previous EUR manual rate', () {
      final hufState = DevizTehnicExchangeRateState.fromBnrRate(
        currency: 'HUF',
        bnrRate: 0.014827,
        exchangeCommissionPercent: 0,
      );

      expect(hufState.manualRate, 0);
      expect(hufState.baseRate, 0.014827);
      expect(hufState.effectiveRate, 0.014827);
      expect(hufState.effectiveRate, isNot(5.237400));
    });

    test('HUF with 2% commission computes effective rate from HUF rate', () {
      final hufState = DevizTehnicExchangeRateState.fromBnrRate(
        currency: 'HUF',
        bnrRate: 0.014827,
        exchangeCommissionPercent: 2,
      );

      expect(hufState.baseRate, 0.014827);
      expect(hufState.effectiveRate, closeTo(0.01512354, 0.000000001));
    });

    test('changing currency from EUR to HUF resets the EUR manual rate', () {
      const eurManualRate = 5.237400;
      final resetState = DevizTehnicExchangeRateState.forCurrencyChange(
        currency: 'HUF',
        exchangeCommissionPercent: 0,
      );
      final fetchedHufState = DevizTehnicExchangeRateState.fromBnrRate(
        currency: resetState.currency,
        bnrRate: 0.014827,
        exchangeCommissionPercent: resetState.exchangeCommissionPercent,
      );

      expect(eurManualRate, 5.237400);
      expect(resetState.currency, 'HUF');
      expect(resetState.manualRate, 0);
      expect(resetState.baseRate, 0);
      expect(fetchedHufState.baseRate, 0.014827);
      expect(fetchedHufState.effectiveRate, isNot(eurManualRate));
    });

    test('RON keeps rate 1 and ignores old manual exchange rates', () {
      final ronState = DevizTehnicExchangeRateState.forCurrencyChange(
        currency: 'RON',
        exchangeCommissionPercent: 2,
      );
      final record = _record(
        currency: ronState.currency,
        bnrRate: ronState.bnrRate,
        manualRate: 5.237400,
        exchangeCommissionPercent: ronState.exchangeCommissionPercent,
        effectiveExchangeRate: ronState.effectiveRate,
        pretMat: 123.45,
      );

      expect(ronState.manualRate, 0);
      expect(ronState.effectiveRate, 1);
      expect(record.resolvedEffectiveExchangeRate, 1);
      expect(record.convertRonToCurrency(record.totalCuTva), 123.45);
    });

    test('does not apply commercial rounding to technical estimate totals', () {
      final record = _record(
        currency: 'EUR',
        manualRate: 5,
        effectiveExchangeRate: 5,
        pretMat: 101,
      );

      expect(record.totalCuTva, 101);
      expect(record.totalCuTva, isNot(110));
      expect(record.convertRonToCurrency(record.totalCuTva), 20.2);
    });
  });
}
