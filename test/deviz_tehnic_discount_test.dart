import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/features/deviz_tehnic/deviz_tehnic_models.dart';

/// Teste pentru reducerile (discount) din devizul tehnic:
/// 1. Regresie zero — fără reduceri, totalurile rămân identice cu formula veche.
/// 2. Reducere de linie.
/// 3. Reducere totală (globală).
/// 4. Ambele combinate.
void main() {
  // Un articol de 100 RON total brut (cant 1 × Mat 60 + Man 40).
  DevizTehnicArticol articol({
    double mat = 60,
    double man = 40,
    String discountType = '',
    double discountValue = 0,
  }) =>
      DevizTehnicArticol(
        id: 'a1',
        denumire: 'Test',
        um: 'buc',
        cantitate: 1,
        pretMat: mat,
        pretMan: man,
        discountType: discountType,
        discountValue: discountValue,
      );

  DevizTehnicRecord record({
    required List<DevizTehnicArticol> articole,
    double regie = 9,
    double profit = 10,
    double tva = 21,
    String discountType = '',
    double discountValue = 0,
  }) =>
      DevizTehnicRecord(
        id: 'd1',
        articole: articole,
        regiePercent: regie,
        profitPercent: profit,
        tvaPercent: tva,
        dataEmiterii: DateTime(2026, 7, 16),
        createdAt: DateTime(2026, 7, 16),
        updatedAt: DateTime(2026, 7, 16),
        discountType: discountType,
        discountValue: discountValue,
      );

  test('Regresie zero: fără reduceri = formula veche', () {
    final d = record(articole: [articol()]);
    // Formula veche: direct=100, regie=9, profit=(100+9)*0.10=10.9,
    // faraTva=119.9, tva=25.179, cuTva=145.079
    expect(d.totalDirect, 100);
    expect(d.totalDiscountLinii, 0);
    expect(d.totalDirectNet, 100);
    expect(d.regie, closeTo(9, 1e-9));
    expect(d.discountTotalAmount, 0);
    expect(d.profit, closeTo(10.9, 1e-9));
    expect(d.totalFaraTva, closeTo(119.9, 1e-9));
    expect(d.tva, closeTo(25.179, 1e-9));
    expect(d.totalCuTva, closeTo(145.079, 1e-9));
  });

  test('Reducere de linie 10% pe articol de 100', () {
    final d = record(
        articole: [articol(discountType: 'procentual', discountValue: 10)]);
    // discount linie = 10, directNet = 90, regie = 90*0.09 = 8.1
    // subtotalDupaRegie = 98.1, fără discount total → profit = 98.1*0.10 = 9.81
    // faraTva = 107.91, tva = 22.6611, cuTva = 130.5711
    expect(d.totalDiscountLinii, closeTo(10, 1e-9));
    expect(d.totalDirectNet, closeTo(90, 1e-9));
    expect(d.regie, closeTo(8.1, 1e-9));
    expect(d.profit, closeTo(9.81, 1e-9));
    expect(d.totalFaraTva, closeTo(107.91, 1e-9));
    expect(d.totalCuTva, closeTo(130.5711, 1e-9));
  });

  test('Reducere de linie fixă 25 RON', () {
    final d = record(
        articole: [articol(discountType: 'fix', discountValue: 25)]);
    expect(d.totalDiscountLinii, closeTo(25, 1e-9));
    expect(d.totalDirectNet, closeTo(75, 1e-9));
    // regie=6.75, subtotal=81.75, profit=8.175, faraTva=89.925
    expect(d.regie, closeTo(6.75, 1e-9));
    expect(d.totalFaraTva, closeTo(89.925, 1e-9));
  });

  test('Reducere totală 10% (fără reduceri de linie)', () {
    final d = record(
        articole: [articol()],
        discountType: 'procentual',
        discountValue: 10);
    // direct=100, regie=9, subtotalDupaRegie=109
    // discountTotal=10.9, subtotalDupaReduceri=98.1
    // profit=9.81, faraTva=107.91, cuTva=130.5711
    expect(d.regie, closeTo(9, 1e-9));
    expect(d.discountTotalAmount, closeTo(10.9, 1e-9));
    expect(d.subtotalDupaReduceri, closeTo(98.1, 1e-9));
    expect(d.profit, closeTo(9.81, 1e-9));
    expect(d.totalFaraTva, closeTo(107.91, 1e-9));
    expect(d.totalCuTva, closeTo(130.5711, 1e-9));
  });

  test('Ambele combinate: linie 10% + total fix 5 RON', () {
    final d = record(
      articole: [articol(discountType: 'procentual', discountValue: 10)],
      discountType: 'fix',
      discountValue: 5,
    );
    // linie: discount 10 → directNet 90, regie 8.1, subtotalDupaRegie 98.1
    // total fix 5 → subtotalDupaReduceri 93.1
    // profit = 9.31, faraTva = 102.41, tva = 21.5061, cuTva = 123.9161
    expect(d.totalDirectNet, closeTo(90, 1e-9));
    expect(d.discountTotalAmount, closeTo(5, 1e-9));
    expect(d.subtotalDupaReduceri, closeTo(93.1, 1e-9));
    expect(d.profit, closeTo(9.31, 1e-9));
    expect(d.totalFaraTva, closeTo(102.41, 1e-9));
    expect(d.totalCuTva, closeTo(123.9161, 1e-9));
  });

  test('Clamp: procent > 100 nu produce total negativ', () {
    final d = record(
        articole: [articol(discountType: 'procentual', discountValue: 150)]);
    // discount clamp la totalArticol (100) → directNet 0
    expect(d.totalDiscountLinii, closeTo(100, 1e-9));
    expect(d.totalDirectNet, closeTo(0, 1e-9));
    expect(d.totalFaraTva, closeTo(0, 1e-9));
    expect(d.totalCuTva, closeTo(0, 1e-9));
  });

  test('Backward compat: fromMap fără câmpuri discount → fără reducere', () {
    final map = {
      'id': 'd2',
      'articole': [
        {
          'id': 'a1',
          'denumire': 'Vechi',
          'um': 'buc',
          'cantitate': 1,
          'pret_mat': 60,
          'pret_man': 40,
        }
      ],
      'regie_percent': 9,
      'profit_percent': 10,
      'tva_percent': 21,
      'data_emiterii': '2026-07-16T00:00:00.000',
      'created_at': '2026-07-16T00:00:00.000',
      'updated_at': '2026-07-16T00:00:00.000',
    };
    final d = DevizTehnicRecord.fromMap(map);
    expect(d.discountType, '');
    expect(d.discountValue, 0);
    expect(d.articole.first.discountType, '');
    expect(d.totalCuTva, closeTo(145.079, 1e-9));
  });

  test('Roundtrip toMap/fromMap păstrează reducerile', () {
    final d = record(
      articole: [articol(discountType: 'fix', discountValue: 15)],
      discountType: 'procentual',
      discountValue: 7,
    );
    final d2 = DevizTehnicRecord.fromMap(d.toMap());
    expect(d2.discountType, 'procentual');
    expect(d2.discountValue, 7);
    expect(d2.articole.first.discountType, 'fix');
    expect(d2.articole.first.discountValue, 15);
    expect(d2.totalCuTva, closeTo(d.totalCuTva, 1e-9));
  });
}
