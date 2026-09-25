// FAZA 1 (validare factura reala) — mapare minimala, izolata, a codurilor
// UBL de unitate de masura (UN/ECE Recommendation 20) la etichete
// prietenoase pentru UI. NU converteste cantitati (ex. bare -> metri) —
// doar eticheta afisata. Valoarea originala UBL ramane neschimbata in
// `SupplierInvoicePreviewLine.unit` si in ce se salveaza in
// `supplier_invoices/{id}/lines` (fidelitate fata de sursa).

const Map<String, String> kUblUnitFriendlyLabels = <String, String>{
  'H87': 'buc', // piece — cel mai frecvent cod intalnit la facturi Romstal
  'EA': 'buc', // each (echivalent uzual pentru H87)
  'MTR': 'm',
  'KGM': 'kg',
  'LTR': 'l',
  'MTQ': 'mc',
  'MTK': 'mp',
};

/// Eticheta prietenoasa pentru afisare in UI. Daca `ublCode` nu e in
/// mapare, se afiseaza codul original neschimbat (nu se inventeaza o
/// eticheta) — predictibil, fara conversii ascunse.
String friendlyUnitLabel(String? ublCode) {
  final normalized = (ublCode ?? '').trim().toUpperCase();
  if (normalized.isEmpty) return '';
  return kUblUnitFriendlyLabels[normalized] ?? ublCode!.trim();
}
