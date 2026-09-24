// FAZA 2 — teste unitare pentru maparea PURA linie de factura -> material
// lucrare (fara Firebase, fara UI). Toate datele sunt sintetice.

import 'package:flutter_test/flutter_test.dart';
import 'package:devizpro_ultra/features/jobs/invoice_import/supplier_invoice_job_material_mapper.dart';
import 'package:devizpro_ultra/features/jobs/invoice_import/supplier_invoice_models.dart';

SupplierInvoicePreviewLine _line({
  String rawName = 'Teava cupru 1/2',
  String? editedName,
  String? unit = 'H87',
  double? quantity = 10,
  double? allocatedQty,
  double? unitPriceNoVat = 15.5,
  String? sourceLineId = '3',
  String? lineDocId = 'lineDoc-abc',
  bool alreadyImported = false,
}) {
  return SupplierInvoicePreviewLine(
    lineIndex: 0,
    sourceLineId: sourceLineId,
    lineDocId: lineDocId,
    rawName: rawName,
    editedName: editedName,
    unit: unit,
    quantity: quantity,
    allocatedQty: allocatedQty,
    unitPriceNoVat: unitPriceNoVat,
    alreadyImported: alreadyImported,
  );
}

void main() {
  group('buildJobMaterialFromInvoiceLine', () {
    test('1. conversie invoice line -> material: campuri de baza corecte', () {
      final line = _line();
      final result = buildJobMaterialFromInvoiceLine(
        line: line,
        materialId: 'mat-1',
        invoiceId: 'inv-1',
        jobMaterialId: 'job-mat-1',
      );
      expect(result['id'], 'job-mat-1');
      expect(result['materialId'], 'mat-1');
      expect(result['name'], 'Teava cupru 1/2');
    });

    test('2. editedName are prioritate fata de rawName', () {
      final withEdit = _line(
          rawName: 'Teava cupru 1/2', editedName: 'Teava cupru corectata');
      final result = buildJobMaterialFromInvoiceLine(
        line: withEdit,
        materialId: 'mat-1',
        invoiceId: 'inv-1',
        jobMaterialId: 'job-mat-1',
      );
      expect(result['name'], 'Teava cupru corectata');

      final withoutEdit = _line(rawName: 'Teava cupru 1/2');
      final result2 = buildJobMaterialFromInvoiceLine(
        line: withoutEdit,
        materialId: 'mat-1',
        invoiceId: 'inv-1',
        jobMaterialId: 'job-mat-1',
      );
      expect(result2['name'], 'Teava cupru 1/2');
    });

    test('3. H87 -> buc pe materialul din lucrare', () {
      final line = _line(unit: 'H87');
      final result = buildJobMaterialFromInvoiceLine(
        line: line,
        materialId: 'mat-1',
        invoiceId: 'inv-1',
        jobMaterialId: 'job-mat-1',
      );
      expect(result['um'], 'buc');
    });

    test('4. allocatedQty implicit = quantity (cand nu e specificat explicit)',
        () {
      final line = _line(quantity: 12, allocatedQty: null);
      expect(line.allocatedQty, 12);
    });

    test('5. allocatedQty custom, diferit de quantity facturata', () {
      final line = _line(quantity: 100, allocatedQty: 63);
      final result = buildJobMaterialFromInvoiceLine(
        line: line,
        materialId: 'mat-1',
        invoiceId: 'inv-1',
        jobMaterialId: 'job-mat-1',
      );
      expect(line.quantity, 100);
      expect(result['qty'], 63);
      expect(result['allocatedQty'], 63);
    });

    test('6. allocatedQty <= 0 -> linia nu e valida pentru import', () {
      final zero = _line(allocatedQty: 0);
      expect(zero.isValidForJobImport, false);
      final negative = _line(allocatedQty: -5);
      expect(negative.isValidForJobImport, false);
      final valid = _line(allocatedQty: 1);
      expect(valid.isValidForJobImport, true);
    });

    test(
        '7. price si realPrice mapate ambele la unitPriceNoVat (nu 0, nu dublate)',
        () {
      final line = _line(unitPriceNoVat: 145.04);
      final result = buildJobMaterialFromInvoiceLine(
        line: line,
        materialId: 'mat-1',
        invoiceId: 'inv-1',
        jobMaterialId: 'job-mat-1',
      );
      expect(result['price'], 145.04);
      expect(result['realPrice'], 145.04);
    });

    test('8. total = allocatedQty x unitPriceNoVat', () {
      final line = _line(quantity: 10, allocatedQty: 7, unitPriceNoVat: 145.04);
      final result = buildJobMaterialFromInvoiceLine(
        line: line,
        materialId: 'mat-1',
        invoiceId: 'inv-1',
        jobMaterialId: 'job-mat-1',
      );
      expect(result['total'], closeTo(7 * 145.04, 0.0001));
    });

    test('9. sourceInvoiceId setat pe material', () {
      final line = _line();
      final result = buildJobMaterialFromInvoiceLine(
        line: line,
        materialId: 'mat-1',
        invoiceId: 'inv-xyz',
        jobMaterialId: 'job-mat-1',
      );
      expect(result['sourceInvoiceId'], 'inv-xyz');
    });

    test('10. sourceInvoiceLineId setat din lineDocId', () {
      final line = _line(lineDocId: 'lineDoc-42');
      final result = buildJobMaterialFromInvoiceLine(
        line: line,
        materialId: 'mat-1',
        invoiceId: 'inv-1',
        jobMaterialId: 'job-mat-1',
      );
      expect(result['sourceInvoiceLineId'], 'lineDoc-42');
    });

    test('11. sourceLineId (cbc:ID) pastrat ca sourceInvoiceSourceLineId', () {
      final line = _line(sourceLineId: '7');
      final result = buildJobMaterialFromInvoiceLine(
        line: line,
        materialId: 'mat-1',
        invoiceId: 'inv-1',
        jobMaterialId: 'job-mat-1',
      );
      expect(result['sourceInvoiceSourceLineId'], '7');
    });

    test('11b. sourceLineId null -> camp absent, nu fabricat', () {
      final line = _line(sourceLineId: null);
      final result = buildJobMaterialFromInvoiceLine(
        line: line,
        materialId: 'mat-1',
        invoiceId: 'inv-1',
        jobMaterialId: 'job-mat-1',
      );
      expect(result.containsKey('sourceInvoiceSourceLineId'), false);
    });
  });

  group('alreadyImportedLineDocIds / jobMaterialMatchesInvoiceLine', () {
    test(
        '12. detecteaza duplicat in aceeasi lucrare dupa sourceInvoiceId+sourceInvoiceLineId',
        () {
      final jobMaterials = <Map<String, dynamic>>[
        {'sourceInvoiceId': 'inv-1', 'sourceInvoiceLineId': 'line-a'},
        {'sourceInvoiceId': 'inv-1', 'sourceInvoiceLineId': 'line-b'},
        {
          'sourceInvoiceId': 'inv-2',
          'sourceInvoiceLineId': 'line-a'
        }, // alta factura, nu conteaza
        {'name': 'Material manual, fara sursa'},
      ];
      final result = alreadyImportedLineDocIds(
        jobMaterials: jobMaterials,
        invoiceId: 'inv-1',
      );
      expect(result, {'line-a', 'line-b'});
    });

    test(
        '13. linie deja importata (alreadyImported=true) nu poate fi reimportata',
        () {
      final line = _line(alreadyImported: true, allocatedQty: 5);
      expect(line.isValidForJobImport, false);
    });

    test('jobMaterialMatchesInvoiceLine — potrivire exacta', () {
      final row = {'sourceInvoiceId': 'inv-1', 'sourceInvoiceLineId': 'line-a'};
      expect(
        jobMaterialMatchesInvoiceLine(row,
            invoiceId: 'inv-1', lineDocId: 'line-a'),
        true,
      );
      expect(
        jobMaterialMatchesInvoiceLine(row,
            invoiceId: 'inv-1', lineDocId: 'line-b'),
        false,
      );
      expect(
        jobMaterialMatchesInvoiceLine(row,
            invoiceId: 'inv-2', lineDocId: 'line-a'),
        false,
      );
    });
  });

  group('14. existingMaterials + importedMaterials', () {
    test('combinarea pastreaza TOATE pozitiile existente + cele noi', () {
      final existing = <Map<String, dynamic>>[
        {'id': 'job-mat-old-1', 'name': 'Material vechi 1'},
        {'id': 'job-mat-old-2', 'name': 'Material vechi 2'},
      ];
      final imported = List.generate(
        5,
        (i) => buildJobMaterialFromInvoiceLine(
          line: _line(lineDocId: 'lineDoc-$i'),
          materialId: 'mat-$i',
          invoiceId: 'inv-1',
          jobMaterialId: 'job-mat-new-$i',
        ),
      );
      final combined = <Map<String, dynamic>>[...existing, ...imported];
      expect(combined.length, existing.length + imported.length);
      expect(combined.first['name'], 'Material vechi 1');
      expect(combined[1]['name'], 'Material vechi 2');
      expect(combined.any((m) => m['id'] == 'job-mat-new-0'), true);
      expect(combined.any((m) => m['id'] == 'job-mat-new-4'), true);
    });
  });
}
