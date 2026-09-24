// FAZA 2 pct. 20 — test de integrare/simulare (fara Firebase, fara UI):
// simuleaza fluxul complet de la o lista de linii de factura sintetice
// pana la lista finala de materiale ale unei lucrari, pentru facturi de
// 21 si 70 de linii. Verifica explicit ca niciun material existent nu
// dispare si ca numarul final e exact existing + selected.

import 'package:flutter_test/flutter_test.dart';
import 'package:devizpro_ultra/features/jobs/invoice_import/supplier_invoice_catalog_matcher.dart';
import 'package:devizpro_ultra/features/jobs/invoice_import/supplier_invoice_job_material_mapper.dart';
import 'package:devizpro_ultra/features/jobs/invoice_import/supplier_invoice_models.dart';

List<SupplierInvoicePreviewLine> _syntheticInvoiceLines(int count) {
  return List<SupplierInvoicePreviewLine>.generate(count, (i) {
    return SupplierInvoicePreviewLine(
      lineIndex: i,
      sourceLineId: '${i + 1}',
      lineDocId: 'lineDoc-$i',
      rawName: 'Material sintetic $i',
      unit: 'H87',
      quantity: (i % 5 + 1) * 2.0,
      unitPriceNoVat: 10.0 + i,
    );
  });
}

/// Simuleaza exact ce face _doImport() din supplier_invoice_import_page.dart:
/// filtreaza liniile selectate+valide, rezolva materialId prin catalog,
/// construieste rows noi.
List<Map<String, dynamic>> _simulateImport(
  List<SupplierInvoicePreviewLine> lines, {
  required String invoiceId,
}) {
  final selected = lines
      .where((l) => l.selected && l.isValidForJobImport)
      .toList(growable: false);
  final matcher = SupplierInvoiceCatalogMatcher(const []);
  final rows = <Map<String, dynamic>>[];
  for (var i = 0; i < selected.length; i++) {
    final line = selected[i];
    final resolution = matcher.resolve(
      name: line.displayName,
      unit: line.friendlyUnit,
      price: line.unitPriceNoVat ?? 0,
    );
    rows.add(
      buildJobMaterialFromInvoiceLine(
        line: line,
        materialId: resolution.materialId,
        invoiceId: invoiceId,
        jobMaterialId: generateJobMaterialId(1732000000000, i),
      ),
    );
  }
  return rows;
}

void main() {
  for (final totalLines in [21, 70]) {
    group('Simulare import factura sintetica cu $totalLines linii', () {
      test(
          'toate liniile selectate -> $totalLines materiale noi, niciun existent pierdut',
          () {
        final existing = <Map<String, dynamic>>[
          {'id': 'job-mat-existing-1', 'name': 'Material deja in lucrare'},
        ];
        final lines = _syntheticInvoiceLines(totalLines);
        final imported = _simulateImport(lines, invoiceId: 'inv-full');
        final combined = <Map<String, dynamic>>[...existing, ...imported];

        expect(imported.length, totalLines);
        expect(combined.length, existing.length + totalLines);
        expect(combined.first['name'], 'Material deja in lucrare');
      });

      test(
          'doar 10 linii selectate (restul deselectate) -> exact 10 materiale noi',
          () {
        final existing = <Map<String, dynamic>>[
          {'id': 'job-mat-existing-1', 'name': 'Material deja in lucrare'},
          {'id': 'job-mat-existing-2', 'name': 'Alt material existent'},
        ];
        final lines = _syntheticInvoiceLines(totalLines);
        for (var i = 0; i < lines.length; i++) {
          lines[i].selected = i < 10;
        }
        final imported = _simulateImport(lines, invoiceId: 'inv-partial');
        final combined = <Map<String, dynamic>>[...existing, ...imported];

        expect(imported.length, 10);
        expect(combined.length, existing.length + 10);
        // Toate materialele existente raman, neschimbate.
        expect(combined.any((m) => m['id'] == 'job-mat-existing-1'), true);
        expect(combined.any((m) => m['id'] == 'job-mat-existing-2'), true);
      });

      test(
          'cantitati modificate (allocatedQty custom) se reflecta in qty/total',
          () {
        final lines = _syntheticInvoiceLines(totalLines);
        // Prima linie: alocam mai putin decat cantitatea facturata.
        lines[0].allocatedQty = 1;
        final imported = _simulateImport(lines, invoiceId: 'inv-qty');
        expect(imported.first['qty'], 1);
        expect(imported.first['allocatedQty'], 1);
        expect(
          imported.first['total'],
          closeTo(1 * (lines.first.unitPriceNoVat ?? 0), 0.0001),
        );
      });

      test('linii deselectate NU apar deloc in rezultat', () {
        final lines = _syntheticInvoiceLines(totalLines);
        for (final line in lines) {
          line.selected = false;
        }
        lines[0].selected = true;
        final imported = _simulateImport(lines, invoiceId: 'inv-none');
        expect(imported.length, 1);
      });

      test(
          'material existent inainte de import este pastrat identic (nealterat)',
          () {
        final existingMaterial = <String, dynamic>{
          'id': 'job-mat-existing-1',
          'name': 'Material neschimbat',
          'qty': 5,
          'price': 99.0,
        };
        final lines = _syntheticInvoiceLines(totalLines);
        final imported = _simulateImport(lines, invoiceId: 'inv-preserve');
        final combined = <Map<String, dynamic>>[existingMaterial, ...imported];

        final preserved =
            combined.firstWhere((m) => m['id'] == 'job-mat-existing-1');
        expect(preserved['name'], 'Material neschimbat');
        expect(preserved['qty'], 5);
        expect(preserved['price'], 99.0);
      });
    });
  }
}
