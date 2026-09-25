// FAZA 2 — conversie PURA (fara I/O) a unei linii de factura confirmate
// intr-o linie material compatibila cu schema REALA folosita azi de
// JobRecord.materials (vezi lucrare_detalii_page.dart _onAddMaterial /
// services/lucrare_cost_calc.dart). Testabila fara Firebase.
//
// MAPARE PRET (decizie documentata, cerinta FAZA 2 pct. 6):
//   - `price` (pretul "ofertat/initial" dupa terminologia
//     lucrare_cost_calc.dart) SI `realPrice` (costul real de achizitie,
//     preferat de LucrareCostCalc.materialLineTotal la calculul costului
//     real al lucrarii) sunt AMBELE setate la `unitPriceNoVat` din
//     factura. Motiv: nu exista niciun "pret ofertat" alternativ pentru un
//     material introdus dintr-o factura de achizitie (spre deosebire de
//     un material adaugat manual, unde utilizatorul introduce un pret
//     ofertat separat) — a lasa `price` la 0 ar produce o diferenta
//     "depasire" falsa si mare in comparatia economie/depasire
//     (materialLineRealVsOfferedDiff), desi nu exista nicio abatere reala.
//     Setand price == realPrice == unitPriceNoVat, diferenta este 0 (nicio
//     alterare artificiala a costului) si totalul e coerent cu
//     allocatedQty x unitPriceNoVat (cerinta pct. 7).
//   - `total` = allocatedQty x unitPriceNoVat, exact conventia folosita
//     de _onAddMaterial ('total': qty * price).
//
// CANTITATE (cerinta FAZA 2 pct. 3): `qty` pe material = allocatedQty
// (cantitatea confirmata pentru ACEASTA lucrare, poate fi mai mica decat
// cantitatea facturata pe linie). `allocatedQty` este pastrat SEPARAT ca
// audit trail imutabil al alocarii initiale — vezi nota din
// SupplierInvoicePreviewLine.allocatedQty. Nu e redundant cu `qty`:
// `qty` poate fi editat ulterior manual de utilizator in lucrare (ca orice
// alt material), caz in care `allocatedQty` ramane martorul valorii
// alocate la momentul importului.

import 'supplier_invoice_models.dart';

/// Construieste map-ul unei linii de material NOU, gata de adaugat in
/// `JobRecord.materials`, pornind de la o linie de factura confirmata.
///
/// Precondiii (verificate de apelant, de regula prin
/// `line.isValidForJobImport`): `line.unitPriceNoVat != null`,
/// `line.allocatedQty` este un numar > 0, `line.displayName` nu e gol.
///
/// [materialId] trebuie rezolvat IN PREALABIL (potrivire in catalog sau
/// id nou alocat) — vezi supplier_invoice_catalog_matcher.dart. Aceasta
/// functie NU face nicio potrivire/I-O, doar constructia deterministica a
/// map-ului.
Map<String, dynamic> buildJobMaterialFromInvoiceLine({
  required SupplierInvoicePreviewLine line,
  required String materialId,
  required String invoiceId,
  required String jobMaterialId,
}) {
  final allocatedQty = line.allocatedQty ?? 0;
  final unitPrice = line.unitPriceNoVat ?? 0;
  final total = allocatedQty * unitPrice;

  return <String, dynamic>{
    'id': jobMaterialId,
    'materialId': materialId,
    'name': line.displayName,
    'um': line.friendlyUnit,
    'qty': allocatedQty,
    'price': unitPrice,
    'realPrice': unitPrice,
    'total': total,
    // Audit trail — vezi FAZA 2 pct. 17. Nu duplica date fiscale
    // (furnizor/CUI/nr. factura) — acestea raman doar pe supplier_invoices.
    'sourceInvoiceId': invoiceId,
    if (line.lineDocId != null) 'sourceInvoiceLineId': line.lineDocId,
    if (line.sourceLineId != null)
      'sourceInvoiceSourceLineId': line.sourceLineId,
    'allocatedQty': allocatedQty,
  };
}

/// ID unic determinist pentru o linie de material noua, in acelasi format
/// ca `_onAddMaterial` (`job-mat-<millis>`), dar cu un `seed` explicit
/// (index in batch) ca sa nu coincida intre liniile importate simultan in
/// aceeasi milisecunda.
String generateJobMaterialId(int baseMillis, int seedIndex) =>
    'job-mat-$baseMillis-$seedIndex';

/// Verifica daca o linie de material din `JobRecord.materials` provine
/// din linia de factura data (`invoiceId` + `lineDocId`) — folosit pentru
/// detectia "deja importata" (FAZA 2 pct. 9).
bool jobMaterialMatchesInvoiceLine(
  Map<String, dynamic> materialRow, {
  required String invoiceId,
  required String lineDocId,
}) {
  return (materialRow['sourceInvoiceId'] ?? '').toString() == invoiceId &&
      (materialRow['sourceInvoiceLineId'] ?? '').toString() == lineDocId;
}

/// Multimea `lineDocId` deja importate in lucrarea curenta pentru factura
/// data — scanare LOCALA (materialele unei singure lucrari, deja in
/// memorie), NU o interogare globala pe toate lucrarile (vezi FAZA 2 pct.
/// 3: tracking-ul multi-job e amanat explicit, evitam scanari globale
/// disproportionate).
Set<String> alreadyImportedLineDocIds({
  required List<Map<String, dynamic>> jobMaterials,
  required String invoiceId,
}) {
  final result = <String>{};
  for (final row in jobMaterials) {
    if ((row['sourceInvoiceId'] ?? '').toString() != invoiceId) continue;
    final lineId = (row['sourceInvoiceLineId'] ?? '').toString();
    if (lineId.isNotEmpty) result.add(lineId);
  }
  return result;
}
