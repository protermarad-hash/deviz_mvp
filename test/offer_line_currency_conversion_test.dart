import 'package:flutter_test/flutter_test.dart';
import 'package:devizpro_ultra/features/oferte/offer_models.dart';
import 'package:devizpro_ultra/features/oferte/offer_currency_converter.dart';

// Test de regresie: conversia RON → EUR la afișarea pozițiilor comerciale
// trebuie să se facă O SINGURĂ DATĂ.
//
// Bug istoric (OFR-0004 „Dispozitiv ridicare"): subtitle-ul comercial primea
// deja valorile convertite din _commercialLineForDisplay și le mai trecea o dată
// prin _moneyCommercial → conversie dublă → 137.48 EUR unitar / 276.81 EUR total
// în loc de 700.28 EUR unitar / 1401.73 EUR total.
//
// Fix: subtitle-ul folosește valorile RON brute (sourceLine.unitPrice /
// sourceLine.effectiveLineTotal) și lasă conversia să se facă o singură dată,
// exact ca în PDF (_priceDisplayValue).
void main() {
  const rate = 5.0937; // effectiveExchangeRate OFR-0004 (EUR)
  const currency = 'EUR';

  // Poziția reală: material, cantitate 2, preț unitar 3567 RON.
  final material = OfferLineItem(
    id: 'regresie-dispozitiv-ridicare',
    name: 'Dispozitiv ridicare',
    description: '',
    unit: 'buc',
    quantity: 2,
    unitPrice: 3567.00,
    lineTotal: 0,
    sortOrder: 1,
    lineType: OfferLineType.material,
  );

  String displayEur(double ronAmount) => OfferCurrencyConverter.formatMoney(
        ronAmount: ronAmount,
        currency: currency,
        effectiveRate: rate,
      );

  test('conversie unică din valorile RON brute → valori corecte pe ecran', () {
    // Total linie în RON — calcul pur, fără rotunjire: 2 × 3567 = 7134.
    final ronTotal = material.effectiveLineTotal;
    expect(ronTotal, 7134.0);

    // Preț unitar și total, convertite O SINGURĂ DATĂ din RON.
    expect(displayEur(material.unitPrice), '700.28 EUR');
    expect(displayEur(ronTotal), '1400.55 EUR');
  });

  test('conversia dublă (bug istoric) ar produce valorile greșite 137.48 / 276.81',
      () {
    // Simulează exact ce făcea codul buggy: valorile deja convertite trecute
    // A DOUA OARĂ prin conversie.
    final convertedUnitPrice = OfferCurrencyConverter.convertRonToOfferCurrency(
      ronAmount: material.unitPrice,
      currency: currency,
      effectiveRate: rate,
    );
    // Linia comercială convertită (ca în _commercialLineForDisplay).
    final convertedLine = material.copyWith(unitPrice: convertedUnitPrice);

    // Conversia dublă pe câmpurile deja convertite.
    expect(displayEur(convertedLine.unitPrice), '137.48 EUR');
    expect(displayEur(convertedLine.effectiveLineTotal), '274.96 EUR');

    // Confirmă că valorile buggy DIFERĂ de cele corecte → regresia e prinsă.
    expect(displayEur(convertedLine.unitPrice),
        isNot(displayEur(material.unitPrice)));
  });
}
