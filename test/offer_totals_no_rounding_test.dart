import 'package:flutter_test/flutter_test.dart';
import 'package:devizpro_ultra/features/oferte/offer_models.dart';

// Regresie: calcul PUR în modulul oferte, fără nicio rotunjire artificială
// (roundPriceUpToTen eliminat de pe poziții, subtotal și total).
// - totalul liniei = quantity × unitPrice exact
// - subtotalComercial = suma exactă a liniilor
// - totalValue = subtotalComercial + vatValue exact
void main() {
  test('linie material: total = quantity × unitPrice exact, fără rotunjire', () {
    final material = OfferLineItem(
      id: 'test-linie',
      name: 'Material test',
      description: '',
      unit: 'buc',
      quantity: 2,
      unitPrice: 3567.00,
      lineTotal: 0,
      sortOrder: 1,
      lineType: OfferLineType.material,
    );

    // 2 × 3567 = 7134 EXACT (înainte era rotunjit la 7140).
    expect(material.effectiveLineTotal, 7134.0);
  });

  test('totaluri: subtotal = suma liniilor, total = subtotal + TVA, fără rotunjire',
      () {
    final material = OfferLineItem(
      id: 'test-linie',
      name: 'Material test',
      description: '',
      unit: 'buc',
      quantity: 2,
      unitPrice: 3567.00,
      lineTotal: 0,
      sortOrder: 1,
      lineType: OfferLineType.material,
    );

    final totals = OfferRecord.computeTotals(
      lines: [material],
      vatPercent: 21,
    );

    // subtotalComercial = suma exactă a liniilor = 7134 (înainte 7140).
    expect(totals.subtotalComercial, 7134.0);
    // TVA 21%: 7134 × 0.21 = 1498.14.
    expect(totals.vatValue, closeTo(1498.14, 1e-9));
    // Total = subtotalComercial + vatValue exact (înainte rotunjit la 8640).
    expect(totals.totalValue, totals.subtotalComercial + totals.vatValue);
    // Nu mai e multiplu de 10.
    expect(totals.totalValue, closeTo(8632.14, 1e-9));
  });
}
