import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/company_profile.dart';
import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_font_bundle.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'complaint_document_models.dart';

class ComplaintClientCentralizerPdfService {
  const ComplaintClientCentralizerPdfService._();

  static Future<Uint8List> buildPdfBytes({
    required CompanyProfile company,
    required ComplaintClientCentralizerRecord record,
  }) async {
    final pdfFonts = await PdfFontBundle.load();
    final doc = pw.Document(theme: pdfFonts.theme);
    final branding = DocumentBrandingData.fromCompanyProfile(company);
    final template = company.pdfExportSettings.visualTemplate;
    final palette = resolvePdfTemplatePalette(template);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          buildClassicDocumentHeader(
            branding: branding,
            documentTitle: 'CENTRALIZATOR INTERVENTII / OFERTE',
            template: template,
            metadata: <MapEntry<String, String>>[
              MapEntry('Numar', record.documentNumber.trim()),
              MapEntry('Client', record.clientName.trim()),
              MapEntry(
                'Perioada',
                '${_date(record.periodStart)} - ${_date(record.periodEnd)}',
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          _section(
            'Date document',
            [
              _row('Titlu', record.title.trim().isEmpty ? '-' : record.title),
              _row('Client', record.clientName),
              _row('Interval',
                  '${_date(record.periodStart)} - ${_date(record.periodEnd)}'),
              _row('Total lucrari', _money(record.totalValue)),
            ],
            palette: palette,
          ),
          if (record.summaryDescription.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _section(
              'Sumar perioada',
              [pw.Text(record.summaryDescription.trim())],
              palette: palette,
            ),
          ],
          pw.SizedBox(height: 12),
          _linesTable(record, palette),
          pw.SizedBox(height: 12),
          _section(
            'Acceptare client',
            [
              _row('Persoana', record.acceptancePerson),
              _row('Functie', record.acceptanceRole),
              _row('Data', record.acceptanceDateText),
              _paragraph('Observații acceptare', record.acceptanceNotes),
              _row('Semnătură', '______________________________'),
            ],
            palette: palette,
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<String> export({
    required AppDataRepository repository,
    required CompanyProfile company,
    required ComplaintClientCentralizerRecord record,
    String outputDirectory = '',
    bool saveAs = false,
  }) async {
    final bytes = await buildPdfBytes(company: company, record: record);
    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: _fileName(record),
      category: PdfDocumentCategory.other,
      outputDirectory: outputDirectory,
      forceSaveAs: saveAs,
    );
  }

  static String _fileName(ComplaintClientCentralizerRecord record) {
    final safe = record.documentNumber
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_')
        .trim();
    return 'centralizator_client_${safe.isEmpty ? record.id : safe}.pdf';
  }

  static pw.Widget _linesTable(
    ComplaintClientCentralizerRecord record,
    PdfTemplatePalette palette,
  ) {
    if (record.lines.isEmpty) {
      return _section(
        'Interventii incluse',
        [pw.Text('Nu exista linii selectate pentru acest document.')],
        palette: palette,
      );
    }
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: palette.border),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Interventii incluse',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
              color: palette.primary,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 8,
            ),
            headerDecoration: pw.BoxDecoration(color: palette.primary),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(5),
            headers: const <String>[
              'Data',
              'Reclamatie',
              'Beneficiar',
              'Descriere',
              'Oferta',
              'Valoare',
            ],
            data: record.lines.map((line) {
              return <String>[
                _date(line.interventionDate),
                line.complaintNumber.trim().isEmpty
                    ? '-'
                    : line.complaintNumber,
                line.beneficiaryName.trim().isEmpty
                    ? '-'
                    : line.beneficiaryName,
                line.workSummary.trim().isEmpty ? '-' : line.workSummary,
                line.offerNumber.trim().isEmpty ? '-' : line.offerNumber,
                line.includeInTotal ? _money(line.offerValue) : '-',
              ];
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }

  static pw.Widget _section(
    String title,
    List<pw.Widget> children, {
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
          ...children,
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
            width: 120,
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
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(value.trim().isEmpty ? '-' : value.trim()),
      ],
    );
  }

  static String _date(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  static String _money(double value) {
    return '${value.toStringAsFixed(2)} lei';
  }
}
