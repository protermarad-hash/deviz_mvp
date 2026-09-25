// FAZA 2.1 pct. 1 — teste pentru regula OBLIGATORIE
// `0 < allocatedQty <= quantity facturata`. Date sintetice.

import 'package:flutter_test/flutter_test.dart';
import 'package:devizpro_ultra/features/jobs/invoice_import/supplier_invoice_models.dart';

SupplierInvoicePreviewLine _line({
  double? quantity = 10,
  double? allocatedQty,
}) {
  return SupplierInvoicePreviewLine(
    lineIndex: 0,
    lineDocId: 'lineDoc-1',
    rawName: 'Material test',
    unit: 'H87',
    quantity: quantity,
    allocatedQty: allocatedQty,
    unitPriceNoVat: 10.0,
  );
}

void main() {
  group('Validare allocatedQty vs quantity (FAZA 2.1 pct. 1)', () {
    test('1. allocatedQty == quantity -> valid', () {
      final line = _line(quantity: 10, allocatedQty: 10);
      expect(line.isValidForJobImport, true);
      expect(line.jobImportBlockReason, isNull);
    });

    test('2. allocatedQty < quantity -> valid', () {
      final line = _line(quantity: 100, allocatedQty: 63);
      expect(line.isValidForJobImport, true);
    });

    test('3. allocatedQty == 0 -> invalid', () {
      final line = _line(quantity: 10, allocatedQty: 0);
      expect(line.isValidForJobImport, false);
      expect(
        line.jobImportBlockReason,
        contains('mai mare decat 0'),
      );
    });

    test('4. allocatedQty < 0 -> invalid', () {
      final line = _line(quantity: 10, allocatedQty: -3);
      expect(line.isValidForJobImport, false);
    });

    test('5. allocatedQty > quantity -> invalid (NU doar avertisment)', () {
      final line = _line(quantity: 10, allocatedQty: 10.01);
      expect(line.isValidForJobImport, false);
      expect(
        line.jobImportBlockReason,
        'Cantitatea alocata nu poate depasi cantitatea facturata.',
      );
    });

    test('allocatedQty null -> implicit egal cu quantity -> valid', () {
      final line = _line(quantity: 25, allocatedQty: null);
      expect(line.allocatedQty, 25);
      expect(line.isValidForJobImport, true);
    });

    test(
        'quantity null (parsare esuata) -> invalid, nu se poate valida alocarea',
        () {
      final line = _line(quantity: null, allocatedQty: 5);
      expect(line.isValidForJobImport, false);
      expect(
          line.jobImportBlockReason, contains('Cantitatea facturata lipseste'));
    });

    test(
        'NU corecteaza automat valoarea — allocatedQty ramane cea introdusa de utilizator',
        () {
      final line = _line(quantity: 10, allocatedQty: 999);
      expect(line.allocatedQty, 999); // neschimbat, doar marcat invalid
      expect(line.isValidForJobImport, false);
    });
  });

  group(
      '6. Import partial aceeasi factura — doar liniile ramase sunt importabile',
      () {
    test('linii deja importate raman disabled, restul importabile', () {
      final lines = List<SupplierInvoicePreviewLine>.generate(5, (i) {
        return SupplierInvoicePreviewLine(
          lineIndex: i,
          lineDocId: 'lineDoc-$i',
          rawName: 'Material $i',
          unit: 'H87',
          quantity: 10,
          unitPriceNoVat: 5.0,
        );
      });

      // Simuleaza ca liniile 0 si 2 au fost deja importate anterior in
      // ACEEASI lucrare (exact ce face _markAlreadyImportedLines).
      for (final line in lines) {
        if (line.lineDocId == 'lineDoc-0' || line.lineDocId == 'lineDoc-2') {
          line.alreadyImported = true;
          line.selected = false;
        }
      }

      final importable = lines.where((l) => l.isValidForJobImport).toList();
      expect(importable.length, 3);
      expect(importable.map((l) => l.lineDocId),
          containsAll(['lineDoc-1', 'lineDoc-3', 'lineDoc-4']));
      expect(lines[0].isValidForJobImport, false);
      expect(lines[2].isValidForJobImport, false);
      expect(lines[0].jobImportBlockReason, contains('deja importata'));
    });
  });
}
