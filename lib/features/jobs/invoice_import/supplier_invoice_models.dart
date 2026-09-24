// FAZA 1 / FAZA 2 — Import materiale din factura: modele izolate pentru
// factura furnizorului (XML e-Factura). Vezi rapoartele FAZA 1/1.1/1.2/2
// pentru justificarea fiecarui camp.

import 'supplier_invoice_unit_labels.dart';

/// Antetul facturii, asa cum a fost extras de Cloud Function
/// `parseSupplierInvoiceXml` (vezi functions/supplier_invoice_parse.js) SAU
/// citit dintr-un document `supplier_invoices/{id}` deja persistat (FAZA 2
/// — reutilizare factura existenta, aceleasi nume de campuri).
/// Toate campurile sunt nullable — un camp lipsa in XML ramane `null`,
/// NICIODATA fabricat.
class SupplierInvoiceParsedHeader {
  const SupplierInvoiceParsedHeader({
    this.invoiceNumber,
    this.invoiceDate,
    this.currency,
    this.supplierName,
    this.supplierTaxId,
    this.totalWithoutVat,
    this.totalVat,
  });

  factory SupplierInvoiceParsedHeader.fromMap(Map<String, dynamic> map) {
    double? asDouble(dynamic v) => v is num ? v.toDouble() : null;
    String? asString(dynamic v) =>
        (v is String && v.trim().isNotEmpty) ? v.trim() : null;
    return SupplierInvoiceParsedHeader(
      invoiceNumber: asString(map['invoiceNumber']),
      invoiceDate: asString(map['invoiceDate']),
      currency: asString(map['currency']),
      supplierName: asString(map['supplierName']),
      supplierTaxId: asString(map['supplierTaxId']),
      totalWithoutVat: asDouble(map['totalWithoutVat']),
      totalVat: asDouble(map['totalVat']),
    );
  }

  final String? invoiceNumber;
  final String? invoiceDate;
  final String? currency;
  final String? supplierName;
  final String? supplierTaxId;
  final double? totalWithoutVat;
  final double? totalVat;
}

/// O linie de factura in ecranul de verificare (preview) — mutabila,
/// editabila de utilizator, INAINTE de orice import in lucrare. `rawName`
/// NU se modifica niciodata de UI (cerinta FAZA 1 pct. 4: "nu normaliza
/// distructiv denumirea"); editarea denumirii se face separat in
/// `editedName`.
class SupplierInvoicePreviewLine {
  SupplierInvoicePreviewLine({
    required this.lineIndex,
    this.sourceLineId,
    this.lineDocId,
    required this.rawName,
    this.supplierProductCode,
    this.unit,
    this.quantity,
    double? allocatedQty,
    this.unitPriceNoVat,
    this.unitPriceDerived = false,
    this.vatRate,
    this.sourceLineTotalNoVat,
    this.currency,
    this.warnings = const <String>[],
    this.selected = true,
    this.editedName,
    this.alreadyImported = false,
  }) : allocatedQty = allocatedQty ?? quantity;

  factory SupplierInvoicePreviewLine.fromMap(
    Map<String, dynamic> map, {
    String? lineDocId,
  }) {
    double? asDouble(dynamic v) => v is num ? v.toDouble() : null;
    String? asString(dynamic v) =>
        (v is String && v.trim().isNotEmpty) ? v.trim() : null;
    final quantity = asDouble(map['quantity']);
    return SupplierInvoicePreviewLine(
      lineIndex:
          (map['lineIndex'] is num) ? (map['lineIndex'] as num).toInt() : 0,
      sourceLineId: asString(map['sourceLineId']),
      lineDocId: lineDocId,
      rawName: asString(map['rawName']) ?? '',
      editedName: asString(map['editedName']),
      supplierProductCode: asString(map['supplierProductCode']),
      unit: asString(map['unit']),
      quantity: quantity,
      allocatedQty: quantity,
      unitPriceNoVat: asDouble(map['unitPriceNoVat']),
      unitPriceDerived: map['unitPriceDerived'] == true,
      vatRate: asDouble(map['vatRate']),
      sourceLineTotalNoVat: asDouble(map['lineTotalNoVat']),
      currency: asString(map['currency']),
      warnings: (map['warnings'] is List)
          ? (map['warnings'] as List).map((e) => e.toString()).toList()
          : const <String>[],
    );
  }

  final int lineIndex;

  /// ID-ul declarat de furnizor pe linie (cbc:ID din InvoiceLine, ex.
  /// "1".."21") — distinct de `lineIndex` (pozitia 0-based in document).
  /// Nullable: unele facturi pot sa nu il populeze.
  final String? sourceLineId;

  /// ID-ul documentului Firestore `supplier_invoices/{invoiceId}/lines/{id}`
  /// — `null` pentru o linie proaspat parsata, inca nepersistata. Setat
  /// dupa persistare (import nou) sau la incarcarea unei facturi deja
  /// existente (FAZA 2 pct. 14). Necesar pentru `sourceInvoiceLineId` pe
  /// materialul din lucrare si pentru detectia "deja importata".
  String? lineDocId;

  /// Text ORIGINAL din XML (Item/Name) — imutabil dupa parsare.
  final String rawName;

  String? supplierProductCode;
  String? unit;

  /// Cantitate FACTURATA (din XML, eventual corectata manual in preview
  /// daca parsarea a gresit). Referinta, afisata read-context in UI.
  double? quantity;

  /// Cantitate ALOCATA lucrarii curente (FAZA 2 pct. 3) — implicit egala
  /// cu `quantity`, dar editabila independent de utilizator (ex. factura
  /// are 100 buc, dar in aceasta lucrare se folosesc doar 63).
  double? allocatedQty;

  double? unitPriceNoVat;

  /// true daca unitPriceNoVat a fost derivat (LineExtensionAmount/Quantity)
  /// si nu citit direct din Price/PriceAmount — afisat ca avertisment UI.
  bool unitPriceDerived;
  double? vatRate;

  /// Valoare fara TVA asa cum a fost citita din XML (LineExtensionAmount),
  /// pastrata separat de valoarea curenta afisata (care poate reflecta
  /// editari de cantitate/pret facute de utilizator in preview).
  final double? sourceLineTotalNoVat;
  String? currency;
  final List<String> warnings;

  /// Selectia din tabelul de verificare (checkbox). Controleaza ce se
  /// persista la "Importa in lucrare".
  bool selected;

  /// Denumire editata de utilizator in preview. Daca e `null`, se
  /// foloseste `rawName` neschimbat.
  String? editedName;

  /// true daca aceasta linie (dupa `sourceInvoiceId`+`lineDocId`) a fost
  /// deja importata in materialele LUCRARII CURENTE — vezi FAZA 2 pct. 9.
  /// UI: forteaza `selected=false`, dezactiveaza checkbox-ul.
  bool alreadyImported;

  String get displayName =>
      (editedName != null && editedName!.trim().isNotEmpty)
          ? editedName!.trim()
          : rawName;

  /// Eticheta UM prietenoasa (H87 -> buc) — cea care trebuie sa ajunga pe
  /// materialul din lucrare (FAZA 2 pct. 4), NU codul UBL brut.
  String get friendlyUnit => friendlyUnitLabel(unit);

  /// Valoare fara TVA curenta pentru afisare (cantitate FACTURATA x pret):
  /// recalculata determinist DACA ambele sunt disponibile (editare
  /// utilizator), altfel valoarea din XML.
  double? get currentLineTotalNoVat {
    if (quantity != null && unitPriceNoVat != null) {
      return quantity! * unitPriceNoVat!;
    }
    return sourceLineTotalNoVat;
  }

  /// Valoarea fara TVA a alocarii curente (allocatedQty x pret) — cea care
  /// va ajunge efectiv ca `total` pe materialul din lucrare.
  double? get allocatedLineTotalNoVat {
    if (allocatedQty != null && unitPriceNoVat != null) {
      return allocatedQty! * unitPriceNoVat!;
    }
    return null;
  }

  bool get hasProblem =>
      rawName.trim().isEmpty ||
      unit == null ||
      quantity == null ||
      unitPriceNoVat == null;

  /// Conditiile cerute pentru ca linia sa poata fi importata in lucrare
  /// (FAZA 2 pct. 15): denumire/UM/pret valide + allocatedQty > 0 +
  /// nu e deja importata.
  bool get isValidForJobImport =>
      !alreadyImported &&
      displayName.trim().isNotEmpty &&
      friendlyUnit.trim().isNotEmpty &&
      unitPriceNoVat != null &&
      (allocatedQty ?? 0) > 0;

  Map<String, dynamic> toLineDocMap() {
    return <String, dynamic>{
      'id': lineDocId ?? 'line-$lineIndex',
      'lineIndex': lineIndex,
      if (sourceLineId != null) 'sourceLineId': sourceLineId,
      'rawName': rawName,
      if (editedName != null && editedName!.trim().isNotEmpty)
        'editedName': editedName!.trim(),
      'supplierProductCode': supplierProductCode,
      'unit': unit,
      'quantity': quantity,
      'unitPriceNoVat': unitPriceNoVat,
      'unitPriceDerived': unitPriceDerived,
      'vatRate': vatRate,
      'lineTotalNoVat': currentLineTotalNoVat,
      'currency': currency,
    };
  }
}

/// FAZA 2 pct. 12: statusul facturii NU trebuie sa sugereze fals ca
/// "intreaga factura a fost consumata" — o factura poate fi alocata in mai
/// multe lucrari, partial de fiecare data. `hasAllocations` inlocuieste
/// varianta ambigua "applied" propusa initial.
enum SupplierInvoiceStatus { pendingReview, parsed, hasAllocations, discarded }

String supplierInvoiceStatusToString(SupplierInvoiceStatus status) {
  switch (status) {
    case SupplierInvoiceStatus.pendingReview:
      return 'pendingReview';
    case SupplierInvoiceStatus.parsed:
      return 'parsed';
    case SupplierInvoiceStatus.hasAllocations:
      return 'hasAllocations';
    case SupplierInvoiceStatus.discarded:
      return 'discarded';
  }
}
