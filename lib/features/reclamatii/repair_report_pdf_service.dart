import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/company_profile.dart';
import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_font_bundle.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'repair_report_models.dart';

class RepairReportPdfService {
  const RepairReportPdfService._();

  static Future<Uint8List> buildPdfBytes({
    required CompanyProfile company,
    required RepairReportRecord report,
  }) async {
    final pdfFonts = await PdfFontBundle.load();
    final doc = pw.Document(theme: pdfFonts.theme);
    final branding = DocumentBrandingData.fromCompanyProfile(company);
    final template = company.pdfExportSettings.visualTemplate;
    final palette = resolvePdfTemplatePalette(template);
    final hasPhotos =
        report.photoBase64List.isNotEmpty || report.photoUrls.isNotEmpty;
    final annexPages =
        hasPhotos ? await _buildPhotoAnnexPages(report, pdfFonts) : <pw.Page>[];

    // Titlu document in functie de tipul PV
    final docTitle = _pvTypePdfTitle(report.pvType);
    final docNumber = report.reportNumber.trim().isEmpty
        ? '—'
        : report.reportNumber.trim();

    // Continut sectiunile 1-7 (cu fallback la campurile vechi)
    final sec1 = report.motivulInterventiei.trim().isNotEmpty
        ? report.motivulInterventiei.trim()
        : report.complaintDescription.trim();
    final sec2 = report.constatariLocFinding.trim().isNotEmpty
        ? report.constatariLocFinding.trim()
        : report.findings.trim();
    final sec3 = report.lucrariEfectuateDetailed.trim().isNotEmpty
        ? report.lucrariEfectuateDetailed.trim()
        : report.workPerformed.trim();
    final sec4 = report.observatiiTehnice.trim();
    final sec5 = report.concluzie.trim();
    final sec6 = report.recomandari.trim().isNotEmpty
        ? report.recomandari.trim()
        : report.recommendations.trim();
    final sec7 = report.mentiuni.trim();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          // Antet firmă + titlu document
          buildClassicDocumentHeader(
            branding: branding,
            documentTitle: docTitle,
            template: template,
            metadata: <MapEntry<String, String>>[
              MapEntry('Nr.', docNumber),
              MapEntry('Data', _date(report.interventionDate)),
              MapEntry('Status', report.resolutionStatus.label),
            ],
          ),
          pw.SizedBox(height: 10),

          // Banner revenire (PV înlănțuit)
          if (report.isFollowUp && report.previousReportNumber.isNotEmpty) ...[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                border: pw.Border.all(color: PdfColors.blue200),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'INTERVENȚIA NR. ${report.interventionNumber} — REVENIRE dupa ${report.previousReportNumber}',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: PdfColors.blue800),
                  ),
                  if (report.previousInterventionSummary.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Rezumat anterior: ${report.previousInterventionSummary}',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.blue700),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],

          // TABEL HEADER (4 coloane: Label | Value | Label | Value)
          _buildHeaderTable(company, report, pdfFonts),
          pw.SizedBox(height: 10),

          // Sectiunile 1-7 (skip automat daca sunt goale)
          if (sec1.isNotEmpty) ...[
            _contentSection('1. Motivul interventiei', sec1, pdfFonts),
            pw.SizedBox(height: 6),
          ],
          if (sec2.isNotEmpty) ...[
            _contentSection('2. Constatari la fata locului', sec2, pdfFonts),
            pw.SizedBox(height: 6),
          ],
          if (sec3.isNotEmpty) ...[
            _contentSection('3. Lucrari efectuate', sec3, pdfFonts),
            pw.SizedBox(height: 6),
          ],
          if (sec4.isNotEmpty) ...[
            _contentSection('4. Observatii tehnice', sec4, pdfFonts),
            pw.SizedBox(height: 6),
          ],
          if (sec5.isNotEmpty) ...[
            _contentSection('5. Concluzie', sec5, pdfFonts),
            pw.SizedBox(height: 6),
          ],
          if (sec6.isNotEmpty) ...[
            _contentSection('6. Recomandari', sec6, pdfFonts),
            pw.SizedBox(height: 6),
          ],
          if (sec7.isNotEmpty) ...[
            _contentSection('7. Mentiuni', sec7, pdfFonts),
            pw.SizedBox(height: 6),
          ],

          // Materiale si piese (daca exista)
          if (report.materialeDetailed.trim().isNotEmpty ||
              report.materialsUsed.trim().isNotEmpty) ...[
            _section(
                'Materiale si piese',
                [
                  if (report.materialeDetailed.trim().isNotEmpty)
                    _paragraph('Cod / denumire / cantitate',
                        report.materialeDetailed.trim()),
                  if (report.materialeDetailed.trim().isEmpty &&
                      report.materialsUsed.trim().isNotEmpty)
                    _paragraph('Materiale folosite', report.materialsUsed),
                  if (report.traseulPieselorDefecte.trim().isNotEmpty)
                    _paragraph('Traseu piese defecte/inlocuite',
                        report.traseulPieselorDefecte),
                ],
                palette: palette),
            pw.SizedBox(height: 6),
          ],

          // Informatii document
          _section(
              'Informatii document',
              [
                _row('Nr. document', docNumber),
                _row('Emis de', company.companyName.trim()),
                _row('CUI emitent', company.cui.trim()),
                if (report.complaintId.trim().isNotEmpty &&
                    report.complaintId.trim() != '-')
                  _row(
                    'Ref. reclamatie',
                    report.complaintId.length >= 8
                        ? report.complaintId.substring(0, 8).toUpperCase()
                        : report.complaintId.toUpperCase(),
                  ),
              ],
              palette: palette),
          pw.SizedBox(height: 12),

          // Nota anexa foto
          if (hasPhotos)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                border: pw.Border.all(color: PdfColors.blue200),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'Anexat: ${report.photoBase64List.isNotEmpty ? report.photoBase64List.length : report.photoUrls.length} fotografii — vezi paginile urmatoare',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue800),
              ),
            ),

          // Semnaturi
          _signatureSection(
            clientSignature: _tryDecodeBase64(report.clientSignatureBase64),
            technicianSignature:
                _tryDecodeBase64(report.technicianSignatureBase64),
          ),
        ],
      ),
    );
    for (final page in annexPages) {
      doc.addPage(page);
    }
    return doc.save();
  }

  static String _pvTypePdfTitle(String pvType) {
    switch (pvType) {
      case 'interventie':
        return 'PROCES-VERBAL DE INTERVENTIE';
      case 'montaj':
        return 'PROCES-VERBAL DE RECEPTIE MONTAJ';
      case 'garantie':
        return 'PROCES-VERBAL DE INTERVENTIE IN GARANTIE';
      default:
        return 'PROCES-VERBAL DE CONSTATARE TEHNICA';
    }
  }

  // Sectiune cu titlu pe fond rosu PRO TERM si continut text
  static pw.Widget _contentSection(
      String title, String content, PdfFontBundle fonts) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const pw.BoxDecoration(
              color: PdfColor(0.7765, 0.1569, 0.1569), // #C62828
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
                font: fonts.bold,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              content,
              style: pw.TextStyle(fontSize: 8.5, font: fonts.base),
              textAlign: pw.TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }

  // Tabel header 4 coloane (Label | Value | Label | Value)
  static pw.Widget _buildHeaderTable(
      CompanyProfile company, RepairReportRecord report, PdfFontBundle fonts) {
    final labelStyle = pw.TextStyle(
        fontWeight: pw.FontWeight.bold, fontSize: 8, font: fonts.bold);
    final valueStyle = pw.TextStyle(fontSize: 8, font: fonts.base);
    const labelBg = PdfColor(0.9608, 0.9608, 0.9608); // #F5F5F5

    pw.Widget cell(String text,
        {bool isLabel = false, bool span = false}) {
      return pw.Container(
        color: isLabel ? labelBg : null,
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(
          text.trim().isEmpty ? '—' : text.trim(),
          style: isLabel ? labelStyle : valueStyle,
        ),
      );
    }

    final equipLabel = [
      report.equipmentBrand,
      report.equipmentModel,
    ].where((s) => s.trim().isNotEmpty).join(' / ');

    final techPhone = [
      company.phone.trim(),
      company.email.trim(),
    ].where((s) => s.isNotEmpty).join(' / ');

    final rows = <List<String>>[
      ['Data constatarii', _date(report.interventionDate), 'Locatia', report.location],
      ['Beneficiar', report.beneficiaryName, 'Reprezentant beneficiar', report.reprezentantBeneficiar],
      ['Firma service / tehnician', '${company.companyName.trim()} — ${report.technicianName.trim()}', 'Telefon / e-mail', techPhone],
      ['Echipament / model', equipLabel.isEmpty ? '—' : equipLabel, 'Serie / ODU', report.outdoorUnitSerial.trim().isEmpty ? '—' : report.outdoorUnitSerial.trim()],
      if (report.agentFrigorific.trim().isNotEmpty || report.cantitateRecuperata.trim().isNotEmpty)
        ['Agent frigorific', report.agentFrigorific, 'Cantitate recuperata', report.cantitateRecuperata],
      if (report.coduriEroare.trim().isNotEmpty || report.stareTest.trim().isNotEmpty)
        ['Motiv / coduri eroare', report.coduriEroare, 'Stare test', report.stareTest],
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(110),
        1: pw.FlexColumnWidth(),
        2: pw.FixedColumnWidth(110),
        3: pw.FlexColumnWidth(),
      },
      children: rows
          .map((row) => pw.TableRow(children: [
                cell(row[0], isLabel: true),
                cell(row[1]),
                cell(row[2], isLabel: true),
                cell(row[3]),
              ]))
          .toList(),
    );
  }

  static Future<String> export({
    required AppDataRepository repository,
    required CompanyProfile company,
    required RepairReportRecord report,
    String outputDirectory = '',
    bool saveAs = false,
  }) async {
    final bytes = await buildPdfBytes(company: company, report: report);
    final fileName = _fileName(report);
    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: fileName,
      category: PdfDocumentCategory.other,
      outputDirectory: outputDirectory,
      forceSaveAs: saveAs,
    );
  }

  static Future<void> share({
    required CompanyProfile company,
    required RepairReportRecord report,
  }) async {
    final bytes = await buildPdfBytes(company: company, report: report);
    await Printing.sharePdf(
      bytes: bytes,
      filename: _fileName(report),
    );
  }

  static String _fileName(RepairReportRecord report) {
    final number = report.reportNumber.trim().isEmpty
        ? report.id
        : report.reportNumber.trim();
    final safe = number.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
    return 'proces_verbal_interventie_$safe.pdf';
  }

  static pw.Widget _section(
    String title,
    List<pw.Widget> rows, {
    required PdfTemplatePalette palette,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: palette.surfaceAlt,
        border: pw.Border.all(color: palette.border),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
              color: palette.primary,
            ),
          ),
          pw.SizedBox(height: 6),
          ...rows,
        ],
      ),
    );
  }

  static pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 170,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
              child: pw.Text(value.trim().isEmpty ? '-' : value.trim())),
        ],
      ),
    );
  }

  static pw.Widget _paragraph(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(value.trim().isEmpty ? '-' : value.trim()),
        ],
      ),
    );
  }

  static pw.Widget _signatureSection({
    required pw.MemoryImage? clientSignature,
    required pw.MemoryImage? technicianSignature,
  }) {
    pw.Widget signatureBox(String label, pw.MemoryImage? image) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            height: 90,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            alignment: pw.Alignment.center,
            child: image == null
                ? pw.Text('Fara semnatura')
                : pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Image(image, fit: pw.BoxFit.contain),
                  ),
          ),
        ],
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: signatureBox('Semnătură client', clientSignature)),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: signatureBox('Semnătură tehnician', technicianSignature),
        ),
      ],
    );
  }

  static String _date(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  static pw.MemoryImage? _tryDecodeBase64(String value) {
    if (value.trim().isEmpty) {
      return null;
    }
    try {
      final bytes = UriData.parse(value).contentAsBytes();
      return pw.MemoryImage(bytes);
    } catch (_) {
      try {
        final bytes = Uint8List.fromList(const Base64Decoder().convert(value));
        return pw.MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
  }

  static Future<List<pw.Page>> _buildPhotoAnnexPages(
    RepairReportRecord report,
    PdfFontBundle pdfFonts,
  ) async {
    // Construiește lista de imagini: base64 local (offline) > URL Firebase
    final images = <pw.MemoryImage>[];
    final captions = <String>[];

    for (int i = 0; i < report.photoBase64List.length; i++) {
      final b64 = report.photoBase64List[i];
      if (b64.isEmpty) continue;
      try {
        final bytes = Uint8List.fromList(const Base64Decoder().convert(b64));
        images.add(pw.MemoryImage(bytes));
        captions.add(i < report.photoCaptions.length ? report.photoCaptions[i] : '');
      } catch (_) {}
    }

    // Fallback la URL Firebase Storage dacă nu avem base64
    if (images.isEmpty) {
      for (int i = 0; i < report.photoUrls.length; i++) {
        final url = report.photoUrls[i];
        if (url.isEmpty || !url.startsWith('https://')) continue;
        try {
          final response = await http.get(Uri.parse(url))
              .timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            images.add(pw.MemoryImage(response.bodyBytes));
            captions.add(i < report.photoCaptions.length ? report.photoCaptions[i] : '');
          }
        } catch (_) {}
      }
    }

    if (images.isEmpty) return [];

    const photosPerPage = 2;
    final pages = <pw.Page>[];

    for (int pageIdx = 0; pageIdx * photosPerPage < images.length; pageIdx++) {
      final startIdx = pageIdx * photosPerPage;
      final endIdx = (startIdx + photosPerPage).clamp(0, images.length);
      final pageImages = images.sublist(startIdx, endIdx);
      final pageCaptions = captions.sublist(startIdx, endIdx);
      final totalPhotos = images.length;

      pages.add(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15 * PdfPageFormat.mm),
        build: (context) => pw.Column(
          children: [
            // Header anexă
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: pw.BoxDecoration(
                color: PdfColors.red800,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'ANEXĂ FOTOGRAFII — ${report.reportNumber.isEmpty ? report.id : report.reportNumber}',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                      font: pdfFonts.bold,
                    ),
                  ),
                  pw.Text(
                    'Foto ${startIdx + 1}-$endIdx din $totalPhotos',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 8, font: pdfFonts.base),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            // Pozele pe pagină (2 stivuite vertical)
            pw.Expanded(
              child: pw.Column(
                children: List.generate(pageImages.length, (imgIdx) {
                  return pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Container(
                            width: double.infinity,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey300),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.ClipRRect(
                              horizontalRadius: 4,
                              verticalRadius: 4,
                              child: pw.Image(pageImages[imgIdx], fit: pw.BoxFit.contain),
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            pw.Text(
                              'Foto ${startIdx + imgIdx + 1}',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, font: pdfFonts.bold),
                            ),
                            if (pageCaptions[imgIdx].isNotEmpty) ...[
                              pw.Text(' — ', style: pw.TextStyle(fontSize: 8, font: pdfFonts.base)),
                              pw.Text(pageCaptions[imgIdx], style: pw.TextStyle(fontSize: 8, font: pdfFonts.base)),
                            ],
                          ],
                        ),
                        if (imgIdx < pageImages.length - 1)
                          pw.SizedBox(height: 8),
                      ],
                    ),
                  );
                }),
              ),
            ),
            // Footer
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Anexă la: ${report.reportNumber.isEmpty ? report.id : report.reportNumber} — ${report.beneficiaryName}',
                  style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, font: pdfFonts.base),
                ),
                pw.Text(
                  'Data: ${_date(report.interventionDate)}',
                  style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, font: pdfFonts.base),
                ),
              ],
            ),
          ],
        ),
      ));
    }

    return pages;
  }
}
