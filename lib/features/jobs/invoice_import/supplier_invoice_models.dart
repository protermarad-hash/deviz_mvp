// FAZA 1 — Import materiale din factura: modele izolate pentru factura
// furnizorului (XML e-Factura). NU ating JobRecord/materials — vezi
// raportul FAZA 1 pentru justificarea fiecarui camp.

/// Antetul facturii, asa cum a fost extras de Cloud Function
/// `parseSupplierInvoiceXml` (vezi functions/supplier_invoice_parse.js).
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
/// editabila de utilizator, INAINTE de orice persistare. `rawName` NU se
/// modifica niciodata de UI (cerinta FAZA 1 pct. 4: "nu normaliza
/// distructiv denumirea"); editarea denumirii se face separat in
/// `editedName`.
class SupplierInvoicePreviewLine {
  SupplierInvoicePreviewLine({
    required this.lineIndex,
    this.sourceLineId,
    required this.rawName,
    this.supplierProductCode,
    this.unit,
    this.quantity,
    this.unitPriceNoVat,
    this.unitPriceDerived = false,
    this.vatRate,
    this.sourceLineTotalNoVat,
    this.currency,
    this.warnings = const <String>[],
    this.selected = true,
    this.editedName,
  });

  factory SupplierInvoicePreviewLine.fromMap(Map<String, dynamic> map) {
    double? asDouble(dynamic v) => v is num ? v.toDouble() : null;
    String? asString(dynamic v) =>
        (v is String && v.trim().isNotEmpty) ? v.trim() : null;
    return SupplierInvoicePreviewLine(
      lineIndex:
          (map['lineIndex'] is num) ? (map['lineIndex'] as num).toInt() : 0,
      sourceLineId: asString(map['sourceLineId']),
      rawName: asString(map['rawName']) ?? '',
      supplierProductCode: asString(map['supplierProductCode']),
      unit: asString(map['unit']),
      quantity: asDouble(map['quantity']),
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

  /// Text ORIGINAL din XML (Item/Name) — imutabil dupa parsare.
  final String rawName;

  String? supplierProductCode;
  String? unit;
  double? quantity;
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

  /// Selectia din tabelul de verificare (checkbox). Faza 1: NU are niciun
  /// efect asupra JobRecord.materials — controleaza doar ce se salveaza in
  /// `supplier_invoices/{id}/lines` la "Salveaza factura pentru verificare".
  bool selected;

  /// Denumire editata de utilizator in preview. Daca e `null`, se
  /// foloseste `rawName` neschimbat.
  String? editedName;

  String get displayName =>
      (editedName != null && editedName!.trim().isNotEmpty)
          ? editedName!.trim()
          : rawName;

  /// Valoare fara TVA curenta pentru afisare: recalculata determinist din
  /// cantitate x pret unitar DACA ambele sunt disponibile (editare
  /// utilizator), altfel valoarea din XML.
  double? get currentLineTotalNoVat {
    if (quantity != null && unitPriceNoVat != null) {
      return quantity! * unitPriceNoVat!;
    }
    return sourceLineTotalNoVat;
  }

  bool get hasProblem =>
      rawName.trim().isEmpty ||
      unit == null ||
      quantity == null ||
      unitPriceNoVat == null;

  Map<String, dynamic> toLineDocMap() {
    return <String, dynamic>{
      'id': 'line-$lineIndex',
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

enum SupplierInvoiceStatus { pendingReview, parsed, discarded }

String supplierInvoiceStatusToString(SupplierInvoiceStatus status) {
  switch (status) {
    case SupplierInvoiceStatus.pendingReview:
      return 'pendingReview';
    case SupplierInvoiceStatus.parsed:
      return 'parsed';
    case SupplierInvoiceStatus.discarded:
      return 'discarded';
  }
}
