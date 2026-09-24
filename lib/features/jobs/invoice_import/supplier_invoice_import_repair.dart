// FAZA 2.1 pct. 2/3 — reparare IDEMPOTENTA a pasilor post-save best-effort
// (markInvoiceAllocated + creare materiale lipsa in catalog). Materialele
// lucrarii sunt DEJA salvate cu succes inainte ca acest fisier sa fie
// apelat vreodata — el nu atinge niciodata JobRecord.materials, doar
// completeaza metadata facturii si catalogul.
//
// De ce e idempotent fara logica noua de deduplicare:
//   - `markInvoiceAllocated` foloseste deja `FieldValue.arrayUnion` —
//     apelat de N ori cu acelasi jobId produce acelasi rezultat.
//   - Materialele din `materialsToEnsureInCatalog` au deja un `id` FIX,
//     alocat o singura data la momentul importului (in
//     SupplierInvoiceCatalogMatcher, in timpul salvarii initiale) — NU
//     se realoca un id nou aici. `MaterialsCatalogService.upsertMaterial`
//     e prin constructie idempotent pe `id` (inlocuieste daca exista,
//     adauga daca nu) — reapelarea cu exact acelasi MasterMaterial e
//     un no-op semantic, niciodata un duplicat.

import '../../master/master_local_store.dart';
import '../../materials/materials_catalog_service.dart';
import 'supplier_invoice_repository.dart';

class InvoiceImportRepairOutcome {
  const InvoiceImportRepairOutcome({
    required this.linkedJobIdsOk,
    required this.catalogMaterialsFailed,
  });

  final bool linkedJobIdsOk;

  /// Numele materialelor care TOT nu au putut fi sincronizate in catalog
  /// dupa aceasta incercare — goala daca totul a reusit.
  final List<String> catalogMaterialsFailed;

  bool get isFullySynced => linkedJobIdsOk && catalogMaterialsFailed.isEmpty;
}

/// Reincearca, in siguranta, cei doi pasi POST-SAVE best-effort ai unui
/// import de factura: (A) asocierea facturii cu lucrarea
/// (`linkedJobIds`/status) si (B) crearea materialelor noi in catalogul
/// general. NU atinge niciodata `JobRecord.materials` — acelea sunt deja
/// salvate si raman sursa de adevar indiferent de rezultatul acestei
/// functii (vezi FAZA 2.1 pct. 2: "materialele NU trebuie rollback-uite").
Future<InvoiceImportRepairOutcome> repairInvoiceImportMetadata({
  required String invoiceId,
  required String jobId,
  required List<MasterMaterial> materialsToEnsureInCatalog,
  SupplierInvoiceRepository? invoiceRepository,
  MaterialsCatalogService? catalogService,
}) async {
  // BUG gasit prin testare (FAZA 2.1): daca instantierea repository-ului
  // insasi arunca (ex. Firebase indisponibil in acel moment), exceptia
  // trebuie prinsa la fel ca un esec al apelului — altfel intreaga functie
  // ar arunca necontrolat, incalcand exact garantia ceruta ("nu arunca,
  // apelantul poate continua in siguranta cu materialele deja salvate").
  // De aceea constructia e in INTERIORUL try-ului, nu inainte.
  var linkedOk = false;
  try {
    final invoiceRepo = invoiceRepository ?? SupplierInvoiceRepository();
    await invoiceRepo.markInvoiceAllocated(invoiceId: invoiceId, jobId: jobId);
    linkedOk = true;
  } catch (_) {
    linkedOk = false;
  }

  final failed = <String>[];
  if (materialsToEnsureInCatalog.isNotEmpty) {
    final catalog = catalogService ?? MaterialsCatalogService();
    for (final material in materialsToEnsureInCatalog) {
      try {
        await catalog.upsertMaterial(material);
      } catch (_) {
        failed.add(material.name);
      }
    }
  }

  return InvoiceImportRepairOutcome(
    linkedJobIdsOk: linkedOk,
    catalogMaterialsFailed: failed,
  );
}
