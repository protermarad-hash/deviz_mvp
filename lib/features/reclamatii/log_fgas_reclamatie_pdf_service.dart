import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/pdf/pdf_font_helper.dart';
import '../../core/pdf/pro_term_pdf_template.dart';
import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import '../mentenanta/interventii/fgas_gwp_catalog.dart';
import 'repair_report_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Registru F-Gas pentru o reclamație (PV intervenție) — Reg. (UE) Nr. 517/2014.
// Adaptat din mentenanta/interventii/log_fgas_pdf_service.dart pentru modelul
// RepairReportRecord (o singură intervenție per reclamație) + coloane GWP/Tone.
// ─────────────────────────────────────────────────────────────────────────────

class LogFGasReclamatiePdfService {
  const LogFGasReclamatiePdfService._();

  static final _dateFmt = DateFormat('dd.MM.yyyy', 'ro_RO');

  static const _primaryRed = PdfColor(0.7765, 0.1569, 0.1569); // #C62828
  static const _borderGray = PdfColor(0.8, 0.8, 0.8);
  static const _mediumText = PdfColor(0.3804, 0.3804, 0.3804);

  /// Parsează o cantitate dintr-un câmp text liber (ex: „7,22 kg" → 7.22).
  static double _parseKg(String raw) {
    final cleaned =
        raw.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  /// Generează Log F-Gas pentru reclamație și salvează pe disc. Returnează calea.
  static Future<String> export({
    required AppDataRepository repository,
    required RepairReportRecord report,
    bool saveAs = false,
  }) async {
    await PdfFontHelper.initialize();
    final profile = await repository.loadCompanyProfile();
    final branding = DocumentBrandingData.fromCompanyProfile(profile);
    final bytes = await _buildPdfBytes(report, branding);

    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final numarSafe = (report.reportNumber.isEmpty ? report.id : report.reportNumber)
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
    final fileName = 'Log_FGas_Reclamatie_${numarSafe}_$ts.pdf';

    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: fileName,
      category: PdfDocumentCategory.other,
      forceSaveAs: saveAs,
    );
  }

  static Future<Uint8List> _buildPdfBytes(
    RepairReportRecord report,
    DocumentBrandingData branding,
  ) async {
    final dateStr = _dateFmt.format(report.interventionDate);
    final tehnicianNume =
        report.technicianName.trim().isEmpty ? '________' : report.technicianName;

    // Descriere echipament (tip + marcă + model).
    final echipament = [
      report.equipmentType,
      report.equipmentBrand,
      report.equipmentModel,
    ].where((s) => s.trim().isNotEmpty).join(' ');

    final content = <pw.Widget>[];

    // 1. DATE OPERATOR
    content.add(_redSection('1. Date operator', [
      ProTermPdfTemplate.buildInfoRow(
          'Operator',
          branding.companyName.isEmpty ? 'SC PRO TERM SRL' : branding.companyName),
      ProTermPdfTemplate.buildInfoRow(
          'CUI', branding.cui.isEmpty ? 'RO11355602' : branding.cui),
      ProTermPdfTemplate.buildInfoRow(
          'Autorizație F-Gas', '____________________'),
      ProTermPdfTemplate.buildInfoRow('Tehnician', tehnicianNume),
      ProTermPdfTemplate.buildInfoRow('Data', dateStr),
    ]));
    content.add(pw.SizedBox(height: 8));

    // 2. DATE INSTALAȚIE
    final client = report.beneficiaryName.trim().isNotEmpty
        ? report.beneficiaryName
        : report.contractorName;
    content.add(_redSection('2. Date instalație', [
      ProTermPdfTemplate.buildInfoRow(
          'Client', client.trim().isEmpty ? '-' : client),
      ProTermPdfTemplate.buildInfoRow(
          'Locație', report.location.trim().isEmpty ? '-' : report.location),
      ProTermPdfTemplate.buildInfoRow(
          'Echipament', echipament.isEmpty ? '-' : echipament),
      ProTermPdfTemplate.buildInfoRow('Ref. reclamație',
          report.reportNumber.isEmpty ? '-' : report.reportNumber),
    ]));
    content.add(pw.SizedBox(height: 8));

    // 3. TABEL INTERVENȚII F-GAS (o singură intervenție)
    content.add(_redSection('3. Intervenții agent frigorific (F-Gas)', [
      _buildFGasTable(report),
    ]));
    content.add(pw.SizedBox(height: 8));

    // 4. DECLARAȚIE CONFORMITATE (identică cu Mentenanță)
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

    // Semnătură tehnician (1 coloană, centrat) + data.
    content.add(_buildTechnicianSignature(tehnicianNume, dateStr));

    return ProTermPdfTemplate.generateDocument(
      branding: branding,
      documentTitle: 'REGISTRU F-GAS — FIȘĂ DE INTERVENȚIE',
      documentSubtitle: 'Conform Regulamentului (UE) Nr. 517/2014',
      documentNumber: report.reportNumber,
      documentDate: dateStr,
      contentWidgets: content,
      includePartiesSection: false,
      includeJobInfoSection: false,
      includeSignatureSection: false, // semnătură proprie (1 coloană)
    );
  }

  // ── Tabel F-Gas (un rând) cu GWP + Tone CO₂ ─────────────────────────────────

  static pw.Widget _buildFGasTable(RepairReportRecord report) {
    final fmt = NumberFormat('#,##0.00', 'ro_RO');
    final agent = report.agentFrigorific.trim();
    final gwp = FGasGwpCatalog.getGwp(agent);
    final recuperat = _parseKg(report.cantitateRecuperata);
    final adaugat = _parseKg(report.cantitateAdaugata);
    final neta = (adaugat - recuperat).clamp(0.0, double.infinity);
    final tone = gwp != null ? gwp * neta / 1000.0 : null;
    final depaseste =
        tone != null && tone >= FGasGwpCatalog.pragRaportareTone;

    const widths = <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(0.4), // Nr
      1: pw.FlexColumnWidth(1.3), // Agent
      2: pw.FlexColumnWidth(1.0), // GWP
      3: pw.FlexColumnWidth(1.2), // Recuperat
      4: pw.FlexColumnWidth(1.2), // Adaugat
      5: pw.FlexColumnWidth(1.2), // Neta
      6: pw.FlexColumnWidth(1.3), // Tone CO2
    };

    pw.Widget cell(String text,
        {pw.TextStyle? style,
        pw.Alignment align = pw.Alignment.centerLeft,
        PdfColor? bg}) {
      return pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        alignment: align,
        child: pw.Text(text, style: style ?? const pw.TextStyle(fontSize: 8)),
      );
    }

    pw.Widget h(String t, {pw.Alignment a = pw.Alignment.center}) => cell(t,
        style: pw.TextStyle(
            fontSize: 7.5,
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold),
        align: a,
        bg: _primaryRed);

    final r = const pw.TextStyle(fontSize: 8);
    final dash = '—';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Table(
          columnWidths: widths,
          border: pw.TableBorder.all(color: _borderGray, width: 0.5),
          children: [
            pw.TableRow(children: [
              h('Nr'),
              h('Agent\nfrigorific', a: pw.Alignment.centerLeft),
              h('GWP'),
              h('Cant. recup.\n(kg)'),
              h('Cant. adăug.\n(kg)'),
              h('Cant. netă\n(kg)'),
              h('Tone CO₂\nechiv.'),
            ]),
            pw.TableRow(children: [
              cell('1', style: r, align: pw.Alignment.center),
              cell(agent.isEmpty ? dash : agent, style: r),
              cell(gwp != null ? '$gwp' : dash,
                  style: r, align: pw.Alignment.center),
              cell(fmt.format(recuperat), style: r, align: pw.Alignment.centerRight),
              cell(fmt.format(adaugat), style: r, align: pw.Alignment.centerRight),
              cell(fmt.format(neta), style: r, align: pw.Alignment.centerRight),
              cell(tone != null ? tone.toStringAsFixed(3) : dash,
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: depaseste ? _primaryRed : PdfColors.black),
                  align: pw.Alignment.centerRight),
            ]),
          ],
        ),
        if (depaseste) ...[
          pw.SizedBox(height: 6),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              color: const PdfColor(1.0, 0.92, 0.92),
              border: pw.Border.all(color: _primaryRed, width: 0.5),
            ),
            child: pw.Text(
              '⚠️ Depășește pragul de raportare (5 t CO₂ eq.) — verificări '
              'periodice de etanșeitate obligatorii conform Reg. UE 517/2014.',
              style: pw.TextStyle(
                  fontSize: 8,
                  color: _primaryRed,
                  fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }

  // ── Semnătură tehnician (1 coloană, centrat) + data ─────────────────────────

  static pw.Widget _buildTechnicianSignature(String tehnician, String dateStr) {
    return pw.Column(
      children: [
        pw.Container(
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
                      style:
                          const pw.TextStyle(fontSize: 8, color: _mediumText)),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Data: $dateStr',
            style: const pw.TextStyle(fontSize: 9, color: _mediumText)),
      ],
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
