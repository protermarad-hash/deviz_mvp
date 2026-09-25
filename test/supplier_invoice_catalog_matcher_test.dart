// FAZA 2 pct. 8 — teste unitare pentru matching-ul DETERMINIST catalog
// (fara Firebase, fara fuzzy/AI). Date sintetice.

import 'package:flutter_test/flutter_test.dart';
import 'package:devizpro_ultra/features/jobs/invoice_import/supplier_invoice_catalog_matcher.dart';
import 'package:devizpro_ultra/features/master/master_local_store.dart';

void main() {
  group('SupplierInvoiceCatalogMatcher', () {
    test(
        'potrivire exacta (nume+UM identice) reutilizeaza materialId existent, nu creeaza',
        () {
      final catalog = [
        const MasterMaterial(
          id: 'mat-existing-1',
          name: 'Teava cupru 1/2',
          unit: 'buc',
          price: 12.0,
          notes: '',
        ),
      ];
      final matcher = SupplierInvoiceCatalogMatcher(catalog);
      final resolution = matcher.resolve(
        name: 'Teava cupru 1/2',
        unit: 'buc',
        price: 15.5, // pret DIFERIT fata de catalog — nu trebuie suprascris
      );
      expect(resolution.materialId, 'mat-existing-1');
      expect(resolution.toCreate, isNull);
    });

    test('potrivire normalizata: lowercase/trim/spatii consecutive', () {
      final catalog = [
        const MasterMaterial(
          id: 'mat-existing-2',
          name: 'Teava   Cupru 1/2',
          unit: ' BUC ',
          price: 10.0,
          notes: '',
        ),
      ];
      final matcher = SupplierInvoiceCatalogMatcher(catalog);
      final resolution = matcher.resolve(
        name: '  teava cupru 1/2  ',
        unit: 'buc',
        price: 15.5,
      );
      expect(resolution.materialId, 'mat-existing-2');
      expect(resolution.toCreate, isNull);
    });

    test('NU face fuzzy match — denumiri diferite raman diferite', () {
      final catalog = [
        const MasterMaterial(
          id: 'mat-existing-3',
          name: 'Teava cupru D22',
          unit: 'buc',
          price: 10.0,
          notes: '',
        ),
      ];
      final matcher = SupplierInvoiceCatalogMatcher(catalog);
      final resolution = matcher.resolve(
        name: 'Teava cupru, bara, L=3m, D.22x1mm',
        unit: 'buc',
        price: 145.04,
      );
      expect(resolution.materialId, isNot('mat-existing-3'));
      expect(resolution.toCreate, isNotNull);
      expect(resolution.toCreate!.name, 'Teava cupru, bara, L=3m, D.22x1mm');
    });

    test(
        'produs inexistent in catalog -> propune material nou cu pretul real din factura',
        () {
      final matcher = SupplierInvoiceCatalogMatcher(const []);
      final resolution = matcher.resolve(
        name: 'Produs nou',
        unit: 'buc',
        price: 42.5,
      );
      expect(resolution.toCreate, isNotNull);
      expect(resolution.toCreate!.price, 42.5);
      expect(resolution.toCreate!.name, 'Produs nou');
      expect(resolution.toCreate!.unit, 'buc');
    });

    test(
        'doua linii NOI, acelasi produs (in acelasi lot) -> acelasi materialId, o singura creare',
        () {
      final matcher = SupplierInvoiceCatalogMatcher(const []);
      final first = matcher.resolve(name: 'Produs X', unit: 'buc', price: 10);
      final second =
          matcher.resolve(name: 'produs x', unit: ' BUC ', price: 10);
      expect(second.materialId, first.materialId);
      expect(first.toCreate, isNotNull);
      expect(second.toCreate,
          isNull); // a doua reutilizeaza, nu propune alta creare
    });

    test('acelasi nume, UM diferit -> tratate ca produse diferite', () {
      final catalog = [
        const MasterMaterial(
          id: 'mat-buc',
          name: 'Set produs',
          unit: 'buc',
          price: 10.0,
          notes: '',
        ),
      ];
      final matcher = SupplierInvoiceCatalogMatcher(catalog);
      final resolution =
          matcher.resolve(name: 'Set produs', unit: 'set', price: 20);
      expect(resolution.materialId, isNot('mat-buc'));
      expect(resolution.toCreate, isNotNull);
    });

    test(
        '9. trei linii selectate din aceeasi factura, doua identice (nume+UM) -> '
        'un singur material propus pentru creare, nu doua', () {
      final matcher = SupplierInvoiceCatalogMatcher(const []);
      final r1 =
          matcher.resolve(name: 'Cot cupru 90 D22', unit: 'buc', price: 5);
      final r2 =
          matcher.resolve(name: 'Teava cupru D28', unit: 'buc', price: 20);
      final r3 =
          matcher.resolve(name: 'cot cupru 90 d22', unit: ' BUC ', price: 5);

      final toCreate = [r1, r2, r3]
          .map((r) => r.toCreate)
          .whereType<MasterMaterial>()
          .toList();

      expect(toCreate.length, 2); // doar 2 produse distincte, nu 3
      expect(r3.materialId, r1.materialId);
      expect(r3.toCreate, isNull);
    });
  });

  group('normalizeForCatalogMatch', () {
    test('lowercase + trim + spatii consecutive colapsate', () {
      expect(normalizeForCatalogMatch('  Teava   Cupru  '), 'teava cupru');
    });
  });
}
