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
// PV Intervenție Service — folosește ProTermPdfTemplate (headere roșii #C62828)
// Aliniat vizual cu PV Montaj din job_site_document_pdf_service.dart.
// ─────────────────────────────────────────────────────────────────────────────

class PvInterventiePdfService {
  const PvInterventiePdfService._();

  static final _dateFmt = DateFormat('dd.MM.yyyy', 'ro_RO');

  // Culori brand (identice cu repair_report / job_site).
  static const _primaryRed = PdfColor(0.7765, 0.1569, 0.1569); // #C62828
  static const _borderGray = PdfColor(0.8, 0.8, 0.8);

  /// Generează PDF-ul PV intervenție și salvează pe disc. Returnează calea.
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

    // Timestamp anti-cache (vizualizatorul Windows nu mai arată versiunea veche).
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final numarSafe = (interventie.numar.isEmpty ? interventie.id : interventie.numar)
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
    final fileName = 'PV_Interventie_${numarSafe}_$ts.pdf';

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
    final content = _buildContent(contract, interventie, dateStr);

    return ProTermPdfTemplate.generateDocument(
      branding: branding,
      documentTitle: 'PROCES-VERBAL DE INTERVENȚIE SERVICE',
      documentSubtitle: interventie.tipInterventie.label,
      documentNumber: interventie.numar,
      documentDate: dateStr,
      contentWidgets: content,
      clientName: contract.clientName.trim().isNotEmpty
          ? contract.clientName
          : null,
      // Secțiunile sunt randate explicit (1. Date generale), dezactivăm cele
      // automate ale template-ului pentru a evita duplicarea.
      includePartiesSection: false,
      includeJobInfoSection: false,
      includeSignatureSection: true,
    );
  }

  // ── Conținut ─────────────────────────────────────────────────────────────────

  static List<pw.Widget> _buildContent(
    ContractMentenanta contract,
    InterventieService interventie,
    String dateStr,
  ) {
    final widgets = <pw.Widget>[];

    // 1. DATE GENERALE
    widgets.add(_redSection('1. Date generale', [
      ProTermPdfTemplate.buildInfoRow('Client',
          contract.clientName.trim().isEmpty ? '-' : contract.clientName),
      ProTermPdfTemplate.buildInfoRow(
          'Contract nr.', contract.numar.isEmpty ? '-' : contract.numar),
      ProTermPdfTemplate.buildInfoRow('Tehnician',
          interventie.tehnician.trim().isEmpty ? '-' : interventie.tehnician),
      ProTermPdfTemplate.buildInfoRow(
          'Echipă', interventie.echipa.trim().isEmpty ? '-' : interventie.echipa),
      ProTermPdfTemplate.buildInfoRow(
          'Tip intervenție', interventie.tipInterventie.label),
      ProTermPdfTemplate.buildInfoRow('Data intervenției', dateStr),
    ]));
    widgets.add(pw.SizedBox(height: 8));

    // 2. ECHIPAMENTE VERIFICATE — tabel cu status colorat
    widgets.add(_redSection('2. Echipamente verificate', [
      _buildEchipamenteTable(interventie.echipamenteLucrate),
    ]));
    widgets.add(pw.SizedBox(height: 8));

    // 3. OBSERVAȚII GENERALE — omite dacă gol
    if (interventie.observatii.trim().isNotEmpty) {
      widgets.add(_redSection('3. Observații generale', [
        pw.Text(interventie.observatii.trim(),
            style: const pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.justify),
      ]));
      widgets.add(pw.SizedBox(height: 8));
    }

    // 4. CONCLUZII — text standard
    widgets.add(_redSection('4. Concluzii', [
      pw.Text(
        'Intervenția de tip ${interventie.tipInterventie.label} a fost efectuată '
        'la data de $dateStr, conform contractului nr. '
        '${contract.numar.isEmpty ? '—' : contract.numar}.',
        style: const pw.TextStyle(fontSize: 9),
        textAlign: pw.TextAlign.justify,
      ),
    ]));
    widgets.add(pw.SizedBox(height: 8));

    return widgets;
  }

  // ── Tabel echipamente cu status colorat ─────────────────────────────────────

  static pw.Widget _buildEchipamenteTable(
      List<EchipamentInterventie> echipamente) {
    if (echipamente.isEmpty) {
      return pw.Text('Niciun echipament inclus în intervenție.',
          style: const pw.TextStyle(fontSize: 9));
    }

    const widths = <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(0.5), // Nr
      1: pw.FlexColumnWidth(2.4), // Tip echipament
      2: pw.FlexColumnWidth(2.2), // Model
      3: pw.FlexColumnWidth(1.3), // Status
      4: pw.FlexColumnWidth(3.0), // Observatii
    };

    pw.Widget cell(String text,
        {pw.TextStyle? style,
        pw.Alignment align = pw.Alignment.centerLeft,
        PdfColor? bg}) {
      return pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        alignment: align,
        child: pw.Text(text, style: style ?? const pw.TextStyle(fontSize: 8)),
      );
    }

    pw.Widget headerCell(String t,
            {pw.Alignment a = pw.Alignment.centerLeft}) =>
        cell(t,
            style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold),
            align: a,
            bg: _primaryRed);

    final rows = <pw.TableRow>[
      pw.TableRow(children: [
        headerCell('Nr', a: pw.Alignment.center),
        headerCell('Tip echipament'),
        headerCell('Model'),
        headerCell('Status', a: pw.Alignment.center),
        headerCell('Observații'),
      ]),
    ];

    var idx = 0;
    for (final e in echipamente) {
      idx++;
      rows.add(pw.TableRow(children: [
        cell('$idx', align: pw.Alignment.center),
        cell(e.denumire.trim().isEmpty ? '-' : e.denumire),
        cell(e.model.trim().isEmpty ? '-' : e.model),
        cell(e.status.label,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _statusColor(e.status)),
            align: pw.Alignment.center),
        cell(e.observatii.trim().isEmpty ? '-' : e.observatii),
      ]));
    }

    return pw.Table(
      columnWidths: widths,
      border: pw.TableBorder.all(color: _borderGray, width: 0.5),
      children: rows,
    );
  }

  /// Status → culoare PDF: Efectuat=verde, Parțial=portocaliu, Amânat=gri,
  /// De remediat=roșu.
  static PdfColor _statusColor(StatusEchipamentInterventie status) {
    switch (status) {
      case StatusEchipamentInterventie.efectuat:
        return PdfColors.green700;
      case StatusEchipamentInterventie.partial:
        return PdfColors.orange700;
      case StatusEchipamentInterventie.amanat:
        return PdfColors.grey600;
      case StatusEchipamentInterventie.deRemediat:
        return _primaryRed;
    }
  }

  // ── Secțiune cu header roșu (stil PV Montaj / Reclamații) ────────────────────

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
