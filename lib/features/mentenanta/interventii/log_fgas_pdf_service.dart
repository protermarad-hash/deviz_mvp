import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_font_helper.dart';
import '../../../core/pdf/pro_term_pdf_template.dart';
import '../../../core/pdf_document_branding.dart';
import '../../../core/pdf_export_settings.dart';
import '../../../core/pdf_save_service.dart';
import '../../../core/repositories/app_data_repository.dart';
import '../mentenanta_models.dart';
import 'interventie_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Registru F-Gas — fișă de intervenție conform Reg. (UE) Nr. 517/2014.
// Se generează DOAR dacă intervenția conține echipamente cu necesitaLogFGas.
// ─────────────────────────────────────────────────────────────────────────────

class LogFGasPdfService {
  const LogFGasPdfService._();

  static final _dateFmt = DateFormat('dd.MM.yyyy', 'ro_RO');

  static const _primaryRed = PdfColor(0.7765, 0.1569, 0.1569); // #C62828
  static const _borderGray = PdfColor(0.8, 0.8, 0.8);
  static const _mediumText = PdfColor(0.3804, 0.3804, 0.3804);

  /// Generează Log F-Gas și salvează pe disc. Returnează calea fișierului.
  static Future<String> export({
    required AppDataRepository repository,
    required ContractMentenanta contract,
    required InterventieService interventie,
    bool saveAs = false,
  }) async {
    await PdfFontHelper.initialize();
    final profile = await repository.loadCompanyProfile();
    final branding = DocumentBrandingData.fromCompanyProfile(profile);
    final bytes = await _buildPdfBytes(contract, interventie, branding);

    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final numarSafe =
        (interventie.numar.isEmpty ? interventie.id : interventie.numar)
            .replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
    final fileName = 'Log_FGas_${numarSafe}_$ts.pdf';

    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: fileName,
      category: PdfDocumentCategory.other,
      forceSaveAs: saveAs,
    );
  }

  static Future<Uint8List> _buildPdfBytes(
    ContractMentenanta contract,
    InterventieService interventie,
    DocumentBrandingData branding,
  ) async {
    final dateStr = _dateFmt.format(interventie.dataInterventie);
    // Doar echipamentele care necesită Log F-Gas.
    final fgasItems = interventie.echipamenteLucrate
        .where((e) => e.necesitaLogFGas)
        .toList(growable: false);

    final content = <pw.Widget>[];

    // 1. DATE OPERATOR
    content.add(_redSection('1. Date operator', [
      ProTermPdfTemplate.buildInfoRow(
          'Operator',
          branding.companyName.isEmpty
              ? 'SC PRO TERM SRL'
              : branding.companyName),
      ProTermPdfTemplate.buildInfoRow(
          'CUI', branding.cui.isEmpty ? 'RO11355602' : branding.cui),
      ProTermPdfTemplate.buildInfoRow('Autorizație F-Gas', '____________________'),
      ProTermPdfTemplate.buildInfoRow('Tehnician',
          interventie.tehnician.trim().isEmpty ? '-' : interventie.tehnician),
      ProTermPdfTemplate.buildInfoRow('Data', dateStr),
    ]));
    content.add(pw.SizedBox(height: 8));

    // 2. DATE INSTALAȚIE
    content.add(_redSection('2. Date instalație', [
      ProTermPdfTemplate.buildInfoRow('Client / Locație',
          contract.clientName.trim().isEmpty ? '-' : contract.clientName),
      ProTermPdfTemplate.buildInfoRow(
          'Contract nr.', contract.numar.isEmpty ? '-' : contract.numar),
      ProTermPdfTemplate.buildInfoRow('Sistem / instalație',
          contract.titlu.trim().isEmpty ? '-' : contract.titlu),
    ]));
    content.add(pw.SizedBox(height: 8));

    // 3. TABEL INTERVENȚII F-GAS
    content.add(_redSection('3. Intervenții agent frigorific (F-Gas)', [
      _buildFGasTable(fgasItems),
    ]));
    content.add(pw.SizedBox(height: 8));

    // 4. DECLARAȚIE CONFORMITATE
    final tehnicianNume =
        interventie.tehnician.trim().isEmpty ? '________' : interventie.tehnician;
    content.add(_redSection('4. Declarație conformitate', [
      pw.Text(
        'Subsemnatul $tehnicianNume, autorizat pentru operațiuni cu substanțe '
        'fluorurate cu efect de seră, declar că operațiunile efectuate respectă '
        'prevederile Regulamentului (UE) Nr. 517/2014 și că echipamentele au fost '
        'verificate pentru etanșeitate.',
        style: const pw.TextStyle(fontSize: 9),
        textAlign: pw.TextAlign.justify,
      ),
    ]));
    content.add(pw.SizedBox(height: 18));

    // Semnătură tehnician (1 coloană, centrat).
    content.add(_buildTechnicianSignature(tehnicianNume));

    return ProTermPdfTemplate.generateDocument(
      branding: branding,
      documentTitle: 'REGISTRU F-GAS — FIȘĂ DE INTERVENȚIE',
      documentSubtitle: 'Conform Regulamentului (UE) Nr. 517/2014',
      documentNumber: interventie.numar,
      documentDate: dateStr,
      contentWidgets: content,
      includePartiesSection: false,
      includeJobInfoSection: false,
      includeSignatureSection: false, // semnătură proprie (1 coloană)
    );
  }

  // ── Tabel F-Gas ──────────────────────────────────────────────────────────────

  static pw.Widget _buildFGasTable(List<EchipamentInterventie> items) {
    if (items.isEmpty) {
      return pw.Text('Niciun echipament cu agent frigorific raportabil.',
          style: const pw.TextStyle(fontSize: 9));
    }

    final fmt = NumberFormat('#,##0.00', 'ro_RO');

    const widths = <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(0.4), // Nr
      1: pw.FlexColumnWidth(1.8), // Echipament
      2: pw.FlexColumnWidth(1.4), // Model
      3: pw.FlexColumnWidth(1.1), // Agent
      4: pw.FlexColumnWidth(1.1), // Recuperat
      5: pw.FlexColumnWidth(1.1), // Adaugat
      6: pw.FlexColumnWidth(1.3), // Total in sistem
      7: pw.FlexColumnWidth(1.6), // Observatii
    };

    pw.Widget cell(String text,
        {pw.TextStyle? style,
        pw.Alignment align = pw.Alignment.centerLeft,
        PdfColor? bg}) {
      return pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        alignment: align,
        child: pw.Text(text, style: style ?? const pw.TextStyle(fontSize: 7.5)),
      );
    }

    pw.Widget h(String t, {pw.Alignment a = pw.Alignment.center}) => cell(t,
        style: pw.TextStyle(
            fontSize: 7,
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold),
        align: a,
        bg: _primaryRed);

    final rows = <pw.TableRow>[
      pw.TableRow(children: [
        h('Nr'),
        h('Echipament', a: pw.Alignment.centerLeft),
        h('Model', a: pw.Alignment.centerLeft),
        h('Agent\nfrigorific'),
        h('Cant. recup.\n(kg)'),
        h('Cant. adăug.\n(kg)'),
        h('Total în\nsistem (kg)'),
        h('Observații', a: pw.Alignment.centerLeft),
      ]),
    ];

    final r = const pw.TextStyle(fontSize: 7.5);
    var idx = 0;
    for (final e in items) {
      idx++;
      rows.add(pw.TableRow(children: [
        cell('$idx', style: r, align: pw.Alignment.center),
        cell(e.denumire.trim().isEmpty ? '-' : e.denumire, style: r),
        cell(e.model.trim().isEmpty ? '-' : e.model, style: r),
        cell(e.agentFrigorific.trim().isEmpty ? '-' : e.agentFrigorific,
            style: r, align: pw.Alignment.center),
        cell(fmt.format(e.cantitateRecuperata),
            style: r, align: pw.Alignment.centerRight),
        cell(fmt.format(e.cantitateAdaugata),
            style: r, align: pw.Alignment.centerRight),
        // Total în sistem necunoscut (cantitate inițială nu se cunoaște) → linie.
        cell('—', style: r, align: pw.Alignment.center),
        cell(e.observatii.trim().isEmpty ? '-' : e.observatii, style: r),
      ]));
    }

    return pw.Table(
      columnWidths: widths,
      border: pw.TableBorder.all(color: _borderGray, width: 0.5),
      children: rows,
    );
  }

  // ── Semnătură tehnician (1 coloană, centrat) ────────────────────────────────

  static pw.Widget _buildTechnicianSignature(String tehnician) {
    return pw.Container(
      alignment: pw.Alignment.center,
      child: pw.SizedBox(
        width: 220,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('TEHNICIAN F-GAS',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                    color: _primaryRed)),
            pw.SizedBox(height: 4),
            pw.Text(tehnician, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 28),
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                    top: pw.BorderSide(color: _mediumText, width: 0.5)),
              ),
              padding: const pw.EdgeInsets.only(top: 4),
              width: double.infinity,
              child: pw.Text('Semnătură și ștampilă',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8, color: _mediumText)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Secțiune cu header roșu ──────────────────────────────────────────────────

  static pw.Widget _redSection(String title, List<pw.Widget> children) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGray, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: const pw.BoxDecoration(
              color: _primaryRed,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                topRight: pw.Radius.circular(4),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
