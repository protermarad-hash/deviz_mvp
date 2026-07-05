import 'package:flutter_test/flutter_test.dart';
import 'package:devizpro_ultra/features/oferte/offer_models.dart';

// Regresie: totalValue NU se mai rotunjește separat la multiplu de 10.
// totalValue = subtotalComercial + vatValue EXACT.
// Rotunjirea la 10 rămâne DOAR pe pozițiile individuale (effectiveLineTotal)
// și pe subtotalComercial — nu se mai aplică a doua oară pe totalul final.
void main() {
  test('totalValue = subtotalComercial + vatValue exact, fără rotunjire', () {
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

    // Poziția: 2 × 3567 = 7134 → rotunjit în sus la 10 = 7140.
    expect(totals.subtotalComercial, 7140.0);
    // TVA 21%: 7140 × 0.21 = 1499.4.
    expect(totals.vatValue, 1499.4);
    // Total NU mai e rotunjit la 8640 — rămâne 8639.4.
    expect(totals.totalValue, 8639.4);
    // Egalitate exactă subtotalComercial + vatValue == totalValue.
    expect(totals.totalValue, totals.subtotalComercial + totals.vatValue);
  });
}
