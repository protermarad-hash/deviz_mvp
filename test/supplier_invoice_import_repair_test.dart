// FAZA 2.1 pct. 2/3/7/8/10/11 — teste pentru repairInvoiceImportMetadata.
//
// Mediul de test NU are Firebase initializat (niciun test din acest
// fisier apeleaza Firebase.initializeApp()) — deci:
//   - MaterialsCatalogService cade automat pe MasterLocalStore (local,
//     SharedPreferences mockat), EXACT calea reala folosita si de
//     aplicatie cand cloud-ul nu e disponibil — permite un test real,
//     nemockat, al idempotentei sincronizarii catalogului.
//   - SupplierInvoiceRepository.markInvoiceAllocated foloseste
//     FirebaseFirestore.instance direct si arunca ('No Firebase App'),
//     deci `linkedJobIdsOk` va fi `false` in aceste teste — comportament
//     AWAITAT si testat explicit (confirma ca esecul e prins, nu propagat).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:devizpro_ultra/features/jobs/invoice_import/supplier_invoice_import_repair.dart';
import 'package:devizpro_ultra/features/materials/materials_catalog_service.dart';
import 'package:devizpro_ultra/features/master/master_local_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('repairInvoiceImportMetadata', () {
    test(
        '7/10. markInvoiceAllocated indisponibil (fara Firebase) -> nu arunca, '
        'linkedJobIdsOk=false, functia se termina normal', () async {
      final result = await repairInvoiceImportMetadata(
        invoiceId: 'inv-1',
        jobId: 'job-1',
        materialsToEnsureInCatalog: const [],
      );
      expect(result.linkedJobIdsOk, false);
      expect(result.isFullySynced, false);
      // Nu s-a aruncat nicio exceptie pana aici -> apelantul (care a
      // salvat deja JobRecord.materials INAINTE de acest apel) nu are
      // niciun motiv sa faca rollback.
    });

    test('8. retry catalog sync este idempotent — nu creeaza duplicate',
        () async {
      const material = MasterMaterial(
        id: 'mat-inv-fix-1',
        name: 'Produs din factura',
        unit: 'buc',
        price: 42.5,
        notes: '',
      );

      final first = await repairInvoiceImportMetadata(
        invoiceId: 'inv-1',
        jobId: 'job-1',
        materialsToEnsureInCatalog: const [material],
      );
      expect(first.catalogMaterialsFailed, isEmpty);

      final afterFirst = await MaterialsCatalogService().listMaterials();
      expect(afterFirst.where((m) => m.id == 'mat-inv-fix-1').length, 1);

      // Al doilea apel — simuleaza un retry dupa un esec anterior (sau
      // un retry redundant al utilizatorului).
      final second = await repairInvoiceImportMetadata(
        invoiceId: 'inv-1',
        jobId: 'job-1',
        materialsToEnsureInCatalog: const [material],
      );
      expect(second.catalogMaterialsFailed, isEmpty);

      final afterSecond = await MaterialsCatalogService().listMaterials();
      expect(
        afterSecond.where((m) => m.id == 'mat-inv-fix-1').length,
        1,
        reason: 'Al doilea apel NU trebuie sa duplice materialul in catalog',
      );
      expect(afterSecond.length, afterFirst.length);
    });

    test(
        '11. materialele lucrarii nu sunt niciodata atinse de aceasta functie '
        '(nu exista niciun parametru/cale de cod care le poata modifica)',
        () async {
      // Contract structural: functia nu primeste si nu returneaza nimic
      // legat de JobRecord.materials — verificat prin semnatura (compile
      // time) si prin faptul ca apelul de mai jos, chiar cu Firebase
      // indisponibil (deci esuat pe partea de linkedJobIds), se termina
      // fara exceptie, confirmand ca apelantul poate continua in
      // siguranta cu materialele deja salvate.
      final result = await repairInvoiceImportMetadata(
        invoiceId: 'inv-x',
        jobId: 'job-x',
        materialsToEnsureInCatalog: const [
          MasterMaterial(
            id: 'mat-inv-fix-2',
            name: 'Alt produs',
            unit: 'buc',
            price: 1,
            notes: '',
          ),
        ],
      );
      expect(result, isNotNull);
    });
  });
}
