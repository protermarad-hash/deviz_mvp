// ignore_for_file: unused_element, unnecessary_string_interpolations
import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../job_document_type_utils.dart';
import '../job_models.dart';
import '../lucrare_detalii_models.dart';
import '../lucrare_format_utils.dart';
import 'lucrare_labor_calc.dart';

/// Constructor de documente PDF pentru o lucrare — PDF per document asociat și
/// raportul complet al lucrării.
///
/// Extras din `lucrare_detalii_page.dart` (Faza 2). Nu deține UI și nu citește
/// starea direct: primește datele necesare ca parametri (job, liste, harta de
/// branding deja încărcată) și, pentru helperii cuplați la stare
/// (sanitizare text, valori comerciale, total material, rezolvare tip
/// document), primește closure-uri injectate din pagină. Calculul de manoperă
/// vine prin [LucrareLaborCalculator].
class LucrarePdfBuilder {
  LucrarePdfBuilder({
    required this.laborCalc,
    required this.sanitizePdfText,
    required this.commercialValue,
    required this.materialLineTotal,
    required this.resolveDocumentTypeLabel,
    required this.resolveDocumentCanonicalType,
  });

  final LucrareLaborCalculator laborCalc;
  final String Function(String) sanitizePdfText;
  final String Function(String) commercialValue;
  final double Function(Map<String, dynamic>) materialLineTotal;
  final String Function(Map<String, dynamic>) resolveDocumentTypeLabel;
  final String Function(Map<String, dynamic>) resolveDocumentCanonicalType;

  Future<Uint8List> buildDocumentPdfBytes(
    Map<String, dynamic> row, {
    required Map<String, dynamic> companyMap,
    required JobRecord job,
    required String clientName,
    required List<dynamic> appointmentsFallback,
    required List<dynamic> materialsFallback,
    required List<dynamic> laborFallback,
    required List<BeneficiarySuppliedEquipment> beneficiaryEquipmentFallback,
    required List<BeneficiarySuppliedMaterial> beneficiaryMaterialsFallback,
    required LucrareOption? assignedTeam,
    required String assignedTeamMembersLabel,
  }) async {
    final doc = pw.Document();
    final companyName = _readCompanyField(companyMap, const [
      'companyName',
      'name',
      'company_name',
      'numeFirma',
    ]);
    final companyPhone = _readCompanyField(companyMap, const [
      'phone',
      'companyPhone',
      'company_phone',
      'telefon',
    ]);
    final companyEmail = _readCompanyField(companyMap, const [
      'email',
      'companyEmail',
      'company_email',
    ]);
    final companyCui = _readCompanyField(companyMap, const [
      'cui',
      'companyCui',
      'company_cui',
    ]);
    final companyReg = _readCompanyField(companyMap, const [
      'tradeRegister',
      'companyTradeRegister',
      'company_trade_register',
      'regCom',
    ]);
    final companyContact = _readCompanyField(companyMap, const [
      'contactPerson',
      'companyContactName',
      'company_contact_name',
      'persoanaContact',
      'persoana_contact',
      'contact',
    ]);
    final companyAddress = _readCompanyField(companyMap, const [
      'address',
      'companyAddress',
      'company_address',
      'adresa',
    ]);
    final companyLogoRaw = _readCompanyField(companyMap, const [
      'logoBase64',
      'companyLogoBase64',
      'company_logo_base64',
    ]);
    final companyLines = <String>[
      if (companyCui.isNotEmpty) 'CUI/CIF: $companyCui',
      if (companyReg.isNotEmpty) 'Reg. Com.: $companyReg',
      if (companyAddress.isNotEmpty) 'Adresa: $companyAddress',
      if (companyPhone.isNotEmpty) 'Telefon: $companyPhone',
      if (companyEmail.isNotEmpty) 'Email: $companyEmail',
      if (companyContact.isNotEmpty) 'Persoana contact: $companyContact',
    ];
    final logoBytes = _decodeLogoBytes(companyLogoRaw);
    final normalizedType = resolveDocumentCanonicalType(row);
    final typeLabel = resolveDocumentTypeLabel(row);
    final documentTitle = typeLabel;
    final number = '${row['numarDocument'] ?? row['number'] ?? '-'}';
    final date = '${row['dataDocument'] ?? row['date'] ?? '-'}';
    final title = '${row['titlu'] ?? row['title'] ?? '-'}';
    final status = '${row['status'] ?? '-'}';
    final notes = '${row['observatii'] ?? row['notes'] ?? ''}';
    final detailsA =
        '${row['obiectDescriere'] ?? row['descrierePunereInFunctiune'] ?? ''}';
    final detailsB = '${row['constatari'] ?? row['parametriRezultate'] ?? ''}';
    final subtype = normalizedType.isEmpty
        ? normalizeDocumentTypeCanonical(
            '${row['documentSubtype'] ?? row['type'] ?? row['tipDocument'] ?? ''}',
          )
        : normalizedType;

    final appointmentSourceRaw = row['programariSnapshot'];
    final materialSourceRaw = row['materialeSnapshot'];
    final laborSourceRaw = row['manoperaSnapshot'];
    final beneficiaryEquipmentSourceRaw =
        row['beneficiarySuppliedEquipmentSnapshot'];
    final beneficiaryMaterialsSourceRaw =
        row['beneficiarySuppliedMaterialsSnapshot'];
    final appointmentSource = appointmentSourceRaw is List
        ? appointmentSourceRaw
        : appointmentsFallback;
    final materialSource =
        materialSourceRaw is List ? materialSourceRaw : materialsFallback;
    final laborSource =
        laborSourceRaw is List ? laborSourceRaw : laborFallback;
    final beneficiaryEquipmentSource = beneficiaryEquipmentSourceRaw is List
        ? beneficiaryEquipmentSourceRaw
        : beneficiaryEquipmentFallback.map((entry) => entry.toMap()).toList(
              growable: false,
            );
    final beneficiaryMaterialsSource = beneficiaryMaterialsSourceRaw is List
        ? beneficiaryMaterialsSourceRaw
        : beneficiaryMaterialsFallback.map((entry) => entry.toMap()).toList(
              growable: false,
            );

    pw.Widget line(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 170,
              child: pw.Text(
                sanitizePdfText(label),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Expanded(child: pw.Text(sanitizePdfText(value))),
          ],
        ),
      );
    }

    pw.Widget sectionTitle(String title) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          sanitizePdfText(title),
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
      );
    }

    pw.Widget infoBlock({
      required String title,
      required List<pw.Widget> children,
    }) {
      return pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            sectionTitle(title),
            ...children,
          ],
        ),
      );
    }

    String asMoney(dynamic raw, {String fallback = '-'}) {
      if (raw == null) return fallback;
      final text = '$raw'.trim();
      if (text.isEmpty || text == '-') return fallback;
      final value = double.tryParse(text.replaceAll(',', '.'));
      if (value == null) return sanitizePdfText(text);
      return value.toStringAsFixed(2);
    }

    double asPercent(dynamic raw) {
      if (raw == null) return 0;
      final text = '$raw'.trim();
      if (text.isEmpty || text == '-') return 0;
      return lucrareAsDouble(text.replaceAll('%', '')).toDouble();
    }

    String percentLabel(double value) {
      if (value <= 0) return '-';
      final rounded = value.roundToDouble();
      if ((value - rounded).abs() < 0.0001) {
        return rounded.toStringAsFixed(0);
      }
      var out = value.toStringAsFixed(2);
      out = out.replaceAll(RegExp(r'0+$'), '');
      out = out.replaceAll(RegExp(r'\.$'), '');
      return out;
    }

    List<pw.Widget> simpleList(String title, List<String> rows) {
      return [
        pw.Text(
          sanitizePdfText(title),
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (rows.isEmpty)
          pw.Text('Nu exista date.')
        else
          ...rows.map((e) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('- '),
                    pw.Expanded(
                      child: pw.Text(
                        sanitizePdfText(e).replaceAll(' | ', '\n'),
                      ),
                    ),
                  ],
                ),
              )),
      ];
    }

    final appointmentsText = appointmentSource.map((e) {
      final dateText = '${e['date'] ?? '-'}';
      final titleText = '${e['title'] ?? '-'}';
      final locText = '${e['location'] ?? '-'}';
      return 'Data: $dateText | Titlu: $titleText | Locatie: $locText';
    }).toList(growable: false);

    final materialsText = materialSource.map((e) {
      final total = lucrareAsDouble(e['total']) > 0
          ? lucrareAsDouble(e['total'])
          : materialLineTotal(Map<String, dynamic>.from(e as Map));
      return 'Material: ${e['name'] ?? '-'} | UM: ${e['um'] ?? '-'} | Cant: ${lucrareAsDouble(e['qty']).toStringAsFixed(2)} | Pret: ${lucrareAsDouble(e['price']).toStringAsFixed(2)} | Total: ${total.toStringAsFixed(2)}';
    }).toList(growable: false);

    final laborText = laborSource.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return 'Data: ${map['date'] ?? '-'} | Resursa: ${map['who'] ?? '-'} | Ore: ${lucrareAsDouble(map['hours']).toStringAsFixed(2)} | Tarif: ${laborCalc.laborRateForRow(map).toStringAsFixed(2)} | Cost ore: ${laborCalc.laborOreCost(map).toStringAsFixed(2)} | Cost diurna: ${laborCalc.laborPerDiemCost(map).toStringAsFixed(2)} | Cost cazare: ${laborCalc.laborLodgingCost(map).toStringAsFixed(2)} | Cost total: ${laborCalc.laborTotalLineCost(map).toStringAsFixed(2)}';
    }).toList(growable: false);
    final beneficiaryEquipmentText = beneficiaryEquipmentSource.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      final details = <String>[
        'Denumire: ${map['name'] ?? map['denumire'] ?? '-'}',
        'Tip: ${map['equipment_type'] ?? map['equipmentType'] ?? map['type'] ?? '-'}',
        'Brand: ${map['brand'] ?? '-'}',
        'Model: ${map['model'] ?? '-'}',
        'Serie: ${map['serial_number'] ?? map['serialNumber'] ?? map['serie'] ?? '-'}',
        'Cantitate: ${lucrareAsDouble(map['quantity'] ?? map['cantitate']).toStringAsFixed(2)}',
      ];
      final notes = '${map['notes'] ?? map['observatii'] ?? ''}'.trim();
      if (notes.isNotEmpty) {
        details.add('Observatii: $notes');
      }
      return details.join(' | ');
    }).toList(growable: false);
    final beneficiaryMaterialsText = beneficiaryMaterialsSource.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      final details = <String>[
        'Denumire: ${map['name'] ?? map['denumire'] ?? '-'}',
        'UM: ${map['unit'] ?? map['um'] ?? '-'}',
        'Cantitate: ${lucrareAsDouble(map['quantity'] ?? map['cantitate']).toStringAsFixed(2)}',
      ];
      final notes = '${map['notes'] ?? map['observatii'] ?? ''}'.trim();
      if (notes.isNotEmpty) {
        details.add('Observatii: $notes');
      }
      return details.join(' | ');
    }).toList(growable: false);

    final materialTotal = lucrareAsDouble(row['materialTotal']) > 0
        ? lucrareAsDouble(row['materialTotal'])
        : materialSource.fold<double>(
            0,
            (sum, e) =>
                sum +
                (lucrareAsDouble(e['total']) > 0
                    ? lucrareAsDouble(e['total'])
                    : materialLineTotal(Map<String, dynamic>.from(e as Map))),
          );
    final laborTotal = lucrareAsDouble(row['laborTotal']) > 0
        ? lucrareAsDouble(row['laborTotal'])
        : laborSource.fold<double>(
            0,
            (sum, e) =>
                sum +
                laborCalc
                    .laborTotalLineCost(Map<String, dynamic>.from(e as Map)),
          );
    final subtotal = lucrareAsDouble(row['subtotal']) > 0
        ? lucrareAsDouble(row['subtotal'])
        : materialTotal + laborTotal;
    final vatPercentFromRow = lucrareAsDouble(row['vatPercent']).toDouble();
    final vatPercentFromDoc = asPercent(
      readDocField(row, const ['vatPercent', 'tvaContract']),
    );
    final vatPercentFromGlobal =
        asPercent(commercialValue('vatPercent')).toDouble();
    final double vatPercent = vatPercentFromDoc > 0
        ? vatPercentFromDoc
        : (vatPercentFromRow > 0
            ? vatPercentFromRow
            : (vatPercentFromGlobal > 0 ? vatPercentFromGlobal : 0));
    final vatTotal = lucrareAsDouble(row['vatTotal']) > 0
        ? lucrareAsDouble(row['vatTotal'])
        : subtotal * vatPercent / 100;
    final grandTotal = lucrareAsDouble(row['grandTotal']) > 0
        ? lucrareAsDouble(row['grandTotal'])
        : (lucrareAsDouble(row['total']) > 0
            ? lucrareAsDouble(row['total'])
            : subtotal + vatTotal);
    final vatCanonical = percentLabel(vatPercent);

    String fixLegacyVatLabel(String input) {
      if (input.trim().isEmpty) return input;
      return input
          .replaceAll('TVA (19%)', 'TVA ($vatCanonical%)')
          .replaceAll('TVA (19 %)', 'TVA ($vatCanonical%)');
    }

    final contractParties = '${row['partiContractante'] ?? ''}'.trim();
    final contractObject =
        '${row['obiectContract'] ?? row['obiectDescriere'] ?? ''}'.trim();
    final contractReferences = '${row['documenteReferinte'] ?? ''}'.trim();
    final contractDuration = '${row['durataExecutie'] ?? ''}'.trim();
    final contractExecutionTerm = '${row['termenExecutie'] ?? ''}'.trim();
    final contractPrice = '${row['grandTotal'] ?? row['total'] ?? ''}'.trim();
    final contractAdvance = '${row['avans'] ?? ''}'.trim();
    final contractInstallments = '${row['transePlata'] ?? ''}'.trim();
    final contractVat =
        '${row['tvaContract'] ?? row['vatPercent'] ?? ''}'.trim();
    final contractPayment = '${row['conditiiPlata'] ?? ''}'.trim();
    final contractorObligations = '${row['obligatiiParti'] ?? ''}'.trim();
    final beneficiaryObligations = '${row['obligatiiBeneficiar'] ?? ''}'.trim();
    final logistics = '${row['materialeLogistica'] ?? ''}'.trim();
    final reception = '${row['receptie'] ?? ''}'.trim();
    final penalties = '${row['penalitati'] ?? ''}'.trim();
    final forceMajeure = '${row['fortaMajora'] ?? ''}'.trim();
    final termination = '${row['incetareContract'] ?? ''}'.trim();
    final disputes = '${row['litigii'] ?? ''}'.trim();
    final finalClauses = '${row['dispozitiiFinale'] ?? ''}'.trim();
    final signatures = '${row['semnaturi'] ?? ''}'.trim();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        sanitizePdfText(
                            companyName.isEmpty ? 'Firma' : companyName),
                        style: pw.TextStyle(
                            fontSize: 13, fontWeight: pw.FontWeight.bold),
                      ),
                      if (companyLines.isNotEmpty)
                        ...companyLines.map(
                          (item) => pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: pw.Text(
                              sanitizePdfText(item),
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (logoBytes != null)
                  pw.Container(
                    width: 64,
                    height: 64,
                    margin: const pw.EdgeInsets.only(left: 10),
                    child: pw.Image(pw.MemoryImage(logoBytes),
                        fit: pw.BoxFit.contain),
                  ),
              ],
            ),
          ),
          pw.Container(height: 1, color: PdfColors.grey500),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              sanitizePdfText(documentTitle),
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Column(
              children: [
                line('Numar document', number),
                line('Data document', date),
                line('Status document', status),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          infoBlock(
            title: 'Date lucrare',
            children: [
              line('Titlu document', title),
              line('Cod lucrare', job.jobCode),
              line('Titlu lucrare', job.title),
              line('Client', clientName),
              line('Locatie', job.location),
              line(
                'Status lucrare',
                '${job.status.label}'
                    .replaceAll('�', ''),
              ),
            ],
          ),
          infoBlock(
            title: 'Echipa alocata',
            children: [
              line('Echipa', assignedTeam?.label ?? '-'),
              line(
                'Membri',
                assignedTeamMembersLabel.isEmpty
                    ? '-'
                    : assignedTeamMembersLabel,
              ),
            ],
          ),
          line(
            'Status lucrare',
            '${job.status.label}'
                .replaceAll('�', '')
                .replaceAll('', ''),
          ),
          pw.SizedBox(height: 2),
          if (subtype == 'oferta') ...[
            sectionTitle('Structura comerciala'),
            ...simpleList('Lista comerciala / sintetica', materialsText),
            pw.SizedBox(height: 8),
            ...simpleList('Manopera (sinteza)', laborText),
            pw.SizedBox(height: 8),
            infoBlock(
              title: 'Totaluri oferta',
              children: [
                line('Subtotal', subtotal.toStringAsFixed(2)),
                line(
                  vatCanonical == '-' ? 'TVA' : 'TVA ($vatCanonical%)',
                  vatTotal.toStringAsFixed(2),
                ),
                line('Total', grandTotal.toStringAsFixed(2)),
              ],
            ),
            infoBlock(
              title: 'Conditii comerciale',
              children: [
                line(
                  'Termen executie',
                  commercialValue('executionTerm').isEmpty
                      ? '-'
                      : commercialValue('executionTerm'),
                ),
                line(
                  'Termen plata',
                  commercialValue('paymentTerm').isEmpty
                      ? '-'
                      : commercialValue('paymentTerm'),
                ),
                line(
                  'Valabilitate oferta',
                  readDocField(row, const [
                    'valabilitateOferta',
                    'offerValidity'
                  ]).trim().isEmpty
                      ? (commercialValue('offerValidity').isEmpty
                          ? '-'
                          : commercialValue('offerValidity'))
                      : readDocField(row,
                          const ['valabilitateOferta', 'offerValidity']).trim(),
                ),
                line('Observatii', notes.isEmpty ? '-' : notes),
              ],
            ),
          ] else if (subtype == 'deviz') ...[
            sectionTitle('Structura tehnica'),
            ...simpleList('Materiale', materialsText),
            pw.SizedBox(height: 8),
            ...simpleList('Manopera', laborText),
            pw.SizedBox(height: 8),
            infoBlock(
              title: 'Totaluri deviz',
              children: [
                line('Total materiale', materialTotal.toStringAsFixed(2)),
                line('Total manopera', laborTotal.toStringAsFixed(2)),
                line('Subtotal', subtotal.toStringAsFixed(2)),
                line(
                  vatCanonical == '-' ? 'TVA' : 'TVA ($vatCanonical%)',
                  vatTotal.toStringAsFixed(2),
                ),
                line('Total general', grandTotal.toStringAsFixed(2)),
              ],
            ),
            infoBlock(
              title: 'Observatii tehnice / comerciale',
              children: [
                line('Detalii', notes.isEmpty ? '-' : notes),
              ],
            ),
          ] else if (subtype == 'contract') ...[
            infoBlock(
              title: 'Cadru contractual',
              children: [
                line('Parti contractante',
                    contractParties.isEmpty ? '-' : contractParties),
                line('Obiectul contractului',
                    contractObject.isEmpty ? '-' : contractObject),
                line(
                  'Documente si referinte ale lucrarii',
                  contractReferences.isEmpty ? '-' : contractReferences,
                ),
                line(
                  'Durata / termen executie',
                  contractDuration.isEmpty
                      ? (contractExecutionTerm.isEmpty
                          ? '-'
                          : contractExecutionTerm)
                      : contractDuration,
                ),
              ],
            ),
            infoBlock(
              title: 'Conditii comerciale',
              children: [
                line(
                  'Pretul contractului',
                  contractPrice.isEmpty
                      ? grandTotal.toStringAsFixed(2)
                      : asMoney(contractPrice,
                          fallback: grandTotal.toStringAsFixed(2)),
                ),
                line('Conditii de plata',
                    contractPayment.isEmpty ? '-' : contractPayment),
                line('Avans',
                    contractAdvance.isEmpty ? '-' : asMoney(contractAdvance)),
                line('Transe de plata',
                    contractInstallments.isEmpty ? '-' : contractInstallments),
                line(
                  vatCanonical == '-' ? 'TVA' : 'TVA (%)',
                  contractVat.isEmpty
                      ? vatCanonical
                      : percentLabel(asPercent(contractVat)),
                ),
                line('Penalitati', penalties.isEmpty ? '-' : penalties),
              ],
            ),
            infoBlock(
              title: 'Obligatii si executie',
              children: [
                line(
                  'Obligatiile executantului',
                  contractorObligations.isEmpty ? '-' : contractorObligations,
                ),
                line(
                  'Obligatiile beneficiarului / antreprenorului',
                  beneficiaryObligations.isEmpty ? '-' : beneficiaryObligations,
                ),
                line(
                  'Materiale / utilaje / logistica',
                  logistics.isEmpty ? '-' : logistics,
                ),
                line(
                    'Receptie / PV / PIF', reception.isEmpty ? '-' : reception),
                line('Forta majora', forceMajeure.isEmpty ? '-' : forceMajeure),
                line(
                  'Incetarea contractului',
                  termination.isEmpty ? '-' : termination,
                ),
                line('Litigii', disputes.isEmpty ? '-' : disputes),
                line(
                  'Dispozitii finale',
                  finalClauses.isEmpty ? '-' : finalClauses,
                ),
              ],
            ),
            ...simpleList('Referinta operativa', appointmentsText),
            pw.SizedBox(height: 8),
            infoBlock(
              title: 'Observatii',
              children: [
                line('Detalii', notes.isEmpty ? '-' : notes),
              ],
            ),
          ] else ...[
            ...simpleList('Programari asociate', appointmentsText),
            pw.SizedBox(height: 8),
            ...simpleList('Materiale asociate', materialsText),
            pw.SizedBox(height: 8),
            ...simpleList('Manopera / ore', laborText),
            pw.SizedBox(height: 8),
          ],
          if (beneficiaryEquipmentText.isNotEmpty) ...[
            ...simpleList(
              'Echipamente furnizate de beneficiar',
              beneficiaryEquipmentText,
            ),
            pw.SizedBox(height: 8),
          ],
          if (beneficiaryMaterialsText.isNotEmpty) ...[
            ...simpleList(
              'Materiale furnizate de beneficiar',
              beneficiaryMaterialsText,
            ),
            pw.SizedBox(height: 8),
          ],
          if (subtype == 'pv') ...[
            line('Obiect / descriere', detailsA.isEmpty ? '-' : detailsA),
            line('Constatari', detailsB.isEmpty ? '-' : detailsB),
          ] else if (subtype == 'pif') ...[
            line('Descriere punere in functiune',
                detailsA.isEmpty ? '-' : detailsA),
            line('Parametri / rezultate', detailsB.isEmpty ? '-' : detailsB),
          ],
          if (subtype == 'pv' || subtype == 'pif')
            line('Observatii', notes.isEmpty ? '-' : notes),
          pw.SizedBox(height: 12),
          infoBlock(
            title: 'Semnaturi',
            children: [
              if (subtype == 'contract' && signatures.isNotEmpty)
                pw.Text(sanitizePdfText(signatures))
              else
                pw.Row(
                  children: [
                    pw.Expanded(
                        child: pw.Text('Responsabil: ____________________')),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                        child: pw.Text('Beneficiar: ____________________')),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  List<Map<String, dynamic>> payloadRows(
    Map<String, dynamic> payload,
    String key,
  ) {
    final raw = payload[key];
    if (raw is List) {
      return raw
          .map((e) {
            if (e is Map<String, dynamic>) return e;
            if (e is Map) return Map<String, dynamic>.from(e);
            return <String, dynamic>{};
          })
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Uint8List> buildCompleteReportPdfBytes(
    Map<String, dynamic> payload, {
    required Map<String, dynamic> companyMap,
  }) async {
    final doc = pw.Document();
    final companyName = _readCompanyField(companyMap, const [
      'companyName',
      'name',
      'company_name',
      'numeFirma',
    ]);
    final companyPhone = _readCompanyField(companyMap, const [
      'phone',
      'companyPhone',
      'company_phone',
      'telefon',
    ]);
    final companyEmail = _readCompanyField(companyMap, const [
      'email',
      'companyEmail',
      'company_email',
    ]);
    final companyCui = _readCompanyField(companyMap, const [
      'cui',
      'companyCui',
      'company_cui',
    ]);
    final companyReg = _readCompanyField(companyMap, const [
      'tradeRegister',
      'companyTradeRegister',
      'company_trade_register',
      'regCom',
    ]);
    final companyAddress = _readCompanyField(companyMap, const [
      'address',
      'companyAddress',
      'company_address',
      'adresa',
    ]);
    final companyLogoRaw = _readCompanyField(companyMap, const [
      'logoBase64',
      'companyLogoBase64',
      'company_logo_base64',
    ]);
    final logoBytes = _decodeLogoBytes(companyLogoRaw);
    final companyLines = <String>[
      if (companyCui.isNotEmpty) 'CUI/CIF: $companyCui',
      if (companyReg.isNotEmpty) 'Reg. Com.: $companyReg',
      if (companyAddress.isNotEmpty) 'Adresa: $companyAddress',
      if (companyPhone.isNotEmpty) 'Telefon: $companyPhone',
      if (companyEmail.isNotEmpty) 'Email: $companyEmail',
    ];

    final jobCode = '${payload['jobCode'] ?? ''}'.trim();
    final jobTitle = '${payload['jobTitle'] ?? ''}'.trim();
    final clientName = '${payload['clientName'] ?? ''}'.trim();
    final location = '${payload['location'] ?? ''}'.trim();
    final statusLabel = '${payload['statusLabel'] ?? ''}'.trim();
    final generatedAt = '${payload['generatedAt'] ?? ''}'.trim();

    final estimatedValue = lucrareAsDouble(payload['estimatedValue']);
    final materialTotal = lucrareAsDouble(payload['materialTotal']);
    final laborFullTotal = lucrareAsDouble(payload['laborFullTotal']);
    final laborPerDiemTotal = lucrareAsDouble(payload['laborPerDiemTotal']);
    final laborLodgingTotal = lucrareAsDouble(payload['laborLodgingTotal']);
    final realTotalCost = lucrareAsDouble(payload['realTotalCost']);
    final differenceVsEstimate = lucrareAsDouble(payload['differenceVsEstimate']);
    final materialsCount = lucrareAsDouble(payload['materialsCount']).toInt();
    final laborEntriesCount = lucrareAsDouble(payload['laborEntriesCount']).toInt();
    final appointmentsCount = lucrareAsDouble(payload['appointmentsCount']).toInt();
    final personHoursTotal = lucrareAsDouble(payload['personHoursTotal']);
    final teamHoursTotal = lucrareAsDouble(payload['teamHoursTotal']);
    final currentTeamLabel = '${payload['currentTeamLabel'] ?? '-'}'.trim();

    final appointments = payloadRows(payload, 'appointments');
    final materials = payloadRows(payload, 'materials');
    final labor = payloadRows(payload, 'labor');
    final documents = payloadRows(payload, 'documents');
    final beneficiaryEquipment =
        payloadRows(payload, 'beneficiarySuppliedEquipment');
    final beneficiaryMaterials =
        payloadRows(payload, 'beneficiarySuppliedMaterials');

    final documentCounts = <String, int>{
      'oferta': 0,
      'deviz': 0,
      'contract': 0,
      'pv': 0,
      'pif': 0,
    };
    for (final row in documents) {
      final type = normalizeDocumentTypeCanonical(
        '${row['type'] ?? row['tipDocument'] ?? row['documentSubtype'] ?? row['documentType'] ?? row['typeLegacy'] ?? ''}',
      );
      if (documentCounts.containsKey(type)) {
        documentCounts[type] = (documentCounts[type] ?? 0) + 1;
      }
    }

    pw.Widget line(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 190,
              child: pw.Text(
                sanitizePdfText(label),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Expanded(child: pw.Text(sanitizePdfText(value))),
          ],
        ),
      );
    }

    List<pw.Widget> simpleList(String title, List<String> rows) {
      return [
        pw.Text(
          sanitizePdfText(title),
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        if (rows.isEmpty)
          pw.Text('Nu exista date.')
        else
          ...rows.map(
            (e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(sanitizePdfText(e)),
            ),
          ),
      ];
    }

    String yesNo(int count) => count > 0 ? 'Exista ($count)' : 'Lipseste';

    final appointmentsText = appointments.map((row) {
      final date = '${row['date'] ?? row['data'] ?? '-'}';
      final title = '${row['title'] ?? row['titlu'] ?? '-'}';
      final loc = '${row['location'] ?? row['locatie'] ?? '-'}';
      final status = '${row['status'] ?? '-'}';
      return 'Data: $date | Titlu: $title | Locatie: $loc | Status: $status';
    }).toList(growable: false);

    final materialsText = materials.map((row) {
      final qty = lucrareAsDouble(row['qty']);
      final price = lucrareAsDouble(row['price']);
      final total = lucrareAsDouble(row['total']) > 0
          ? lucrareAsDouble(row['total'])
          : materialLineTotal(row);
      return 'Material: ${row['name'] ?? row['denumire'] ?? '-'} | UM: ${row['um'] ?? '-'} | Cant: ${qty.toStringAsFixed(2)} | Pret: ${price.toStringAsFixed(2)} | Total: ${total.toStringAsFixed(2)}';
    }).toList(growable: false);

    final laborText = labor.map((row) {
      final hours = lucrareAsDouble(row['hours']) > 0
          ? lucrareAsDouble(row['hours'])
          : lucrareAsDouble(row['ore']);
      final rate = lucrareAsDouble(row['hourlyRate']);
      final oreCost = lucrareAsDouble(row['costOre']) > 0
          ? lucrareAsDouble(row['costOre'])
          : lucrareAsDouble(row['cost_ore']);
      final diurna = lucrareAsDouble(row['costDiurna']) > 0
          ? lucrareAsDouble(row['costDiurna'])
          : lucrareAsDouble(row['cost_diurna']);
      final cazare = lucrareAsDouble(row['costCazare']) > 0
          ? lucrareAsDouble(row['costCazare'])
          : lucrareAsDouble(row['cost_cazare']);
      final total = lucrareAsDouble(row['costTotalLinie']) > 0
          ? lucrareAsDouble(row['costTotalLinie'])
          : (lucrareAsDouble(row['cost_total_linie']) > 0
              ? lucrareAsDouble(row['cost_total_linie'])
              : (oreCost + diurna + cazare));
      return 'Resursa: ${row['whoLabel'] ?? row['who'] ?? row['label'] ?? '-'} | Data: ${row['date'] ?? row['data'] ?? '-'} | Ore: ${hours.toStringAsFixed(2)} | Tarif: ${rate.toStringAsFixed(2)} | Total: ${total.toStringAsFixed(2)}';
    }).toList(growable: false);
    final beneficiaryEquipmentText = beneficiaryEquipment.map((row) {
      final type =
          '${row['equipment_type'] ?? row['equipmentType'] ?? row['type'] ?? '-'}';
      final brand = '${row['brand'] ?? '-'}';
      final model = '${row['model'] ?? '-'}';
      final serial =
          '${row['serial_number'] ?? row['serialNumber'] ?? row['serie'] ?? '-'}';
      final qty =
          lucrareAsDouble(row['quantity'] ?? row['cantitate']).toStringAsFixed(2);
      final notes = '${row['notes'] ?? row['observatii'] ?? ''}'.trim();
      return 'Denumire: ${row['name'] ?? row['denumire'] ?? '-'} | Tip: $type | Brand: $brand | Model: $model | Serie: $serial | Cantitate: $qty${notes.isEmpty ? '' : ' | Observatii: $notes'}';
    }).toList(growable: false);
    final beneficiaryMaterialsText = beneficiaryMaterials.map((row) {
      final qty =
          lucrareAsDouble(row['quantity'] ?? row['cantitate']).toStringAsFixed(2);
      final notes = '${row['notes'] ?? row['observatii'] ?? ''}'.trim();
      return 'Denumire: ${row['name'] ?? row['denumire'] ?? '-'} | UM: ${row['unit'] ?? row['um'] ?? '-'} | Cantitate: $qty${notes.isEmpty ? '' : ' | Observatii: $notes'}';
    }).toList(growable: false);

    final lastDocuments = [...documents]..sort(
        (a, b) => '${b['updatedAt'] ?? b['createdAt'] ?? ''}'
            .compareTo('${a['updatedAt'] ?? a['createdAt'] ?? ''}'),
      );
    final docsText = lastDocuments.take(8).map((row) {
      final type = resolveDocumentTypeLabel(row);
      final number = '${row['numarDocument'] ?? row['number'] ?? '-'}';
      final status = '${row['status'] ?? '-'}';
      final date = '${row['dataDocument'] ?? row['date'] ?? '-'}';
      return '$type - $number | Status: $status | Data: $date';
    }).toList(growable: false);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      sanitizePdfText(
                          companyName.isEmpty ? 'Firma' : companyName),
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold),
                    ),
                    if (companyLines.isNotEmpty)
                      ...companyLines.map(
                        (item) => pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(
                            sanitizePdfText(item),
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (logoBytes != null)
                pw.Container(
                  width: 64,
                  height: 64,
                  margin: const pw.EdgeInsets.only(left: 10),
                  child: pw.Image(pw.MemoryImage(logoBytes),
                      fit: pw.BoxFit.contain),
                ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 1, color: PdfColors.grey500),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              'Raport complet lucrare',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),
          ...simpleList('Header lucrare', [
            'Cod lucrare: $jobCode',
            'Titlu lucrare: $jobTitle',
            'Client: $clientName',
            'Locatie: $location',
            'Status lucrare: $statusLabel',
            'Generat la: $generatedAt',
          ]),
          pw.SizedBox(height: 10),
          ...simpleList('Indicatori economici si operativi', [
            'Valoare estimata: ${estimatedValue.toStringAsFixed(2)}',
            'Cost real total: ${realTotalCost.toStringAsFixed(2)}',
            'Diferenta estimat vs real: ${differenceVsEstimate.toStringAsFixed(2)}',
            'Total materiale: ${materialTotal.toStringAsFixed(2)}',
            'Total manopera: ${laborFullTotal.toStringAsFixed(2)}',
            'Total diurna: ${laborPerDiemTotal.toStringAsFixed(2)}',
            'Total cazare: ${laborLodgingTotal.toStringAsFixed(2)}',
            'Numar materiale: $materialsCount',
            'Numar inregistrari ore: $laborEntriesCount',
            'Numar programari: $appointmentsCount',
            'Ore persoane: ${personHoursTotal.toStringAsFixed(2)}',
            'Ore echipe: ${teamHoursTotal.toStringAsFixed(2)}',
            'Echipa alocata: $currentTeamLabel',
          ]),
          pw.SizedBox(height: 10),
          ...simpleList('Situatie documente', [
            'Oferta: ${yesNo(documentCounts['oferta'] ?? 0)}',
            'Deviz: ${yesNo(documentCounts['deviz'] ?? 0)}',
            'Contract: ${yesNo(documentCounts['contract'] ?? 0)}',
            'PV: ${yesNo(documentCounts['pv'] ?? 0)}',
            'PIF: ${yesNo(documentCounts['pif'] ?? 0)}',
          ]),
          pw.SizedBox(height: 10),
          ...simpleList('Programari asociate', appointmentsText),
          pw.SizedBox(height: 10),
          ...simpleList('Materiale asociate', materialsText),
          pw.SizedBox(height: 10),
          ...simpleList(
            'Echipamente furnizate de beneficiar',
            beneficiaryEquipmentText,
          ),
          pw.SizedBox(height: 10),
          ...simpleList(
            'Materiale furnizate de beneficiar',
            beneficiaryMaterialsText,
          ),
          pw.SizedBox(height: 10),
          ...simpleList('Manopera / ore', laborText),
          pw.SizedBox(height: 10),
          ...simpleList('Ultimele documente utile', docsText),
        ],
      ),
    );

    return doc.save();
  }
}

// === Helperi puri relocați din pagină ===

/// Întoarce prima valoare nevidă din `map` pentru lista de chei dată.
String _readCompanyField(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = '${map[key] ?? ''}'.trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

/// Întoarce prima valoare nevidă din `row` pentru lista de chei dată, altfel
/// `fallback`.
String readDocField(
  Map<String, dynamic> row,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = '${row[key] ?? ''}'.trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return fallback;
}

/// Decodează un logo base64 în bytes; întoarce null dacă lipsește/invalid.
Uint8List? _decodeLogoBytes(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}
