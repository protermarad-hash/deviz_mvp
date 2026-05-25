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

class ComplaintWorkOrderPdfService {
  const ComplaintWorkOrderPdfService._();

  static Future<Uint8List> buildPdfBytes({
    required CompanyProfile company,
    required ComplaintWorkOrderRecord record,
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
            documentTitle: 'COMANDA DE LUCRARI',
            template: template,
            metadata: <MapEntry<String, String>>[
              MapEntry('Numar', record.documentNumber.trim()),
              MapEntry('Data', _date(record.issueDate)),
              MapEntry('Client', record.clientName.trim()),
            ],
          ),
          pw.SizedBox(height: 14),
          _section(
            'Date client',
            [
              _row('Client', record.clientName),
              _row('Beneficiar', record.beneficiaryName),
              _row('Solicitant', record.requestedBy),
              _row('Telefon', record.requestedPhone),
              _row('Email', record.requestedEmail),
              _row('Locatie', record.location),
            ],
            palette: palette,
          ),
          pw.SizedBox(height: 12),
          _section(
            'Comanda',
            [
              _row('Subiect', record.subject),
              _paragraph('Lucrari comandate', record.scopeOfWork),
              _paragraph('Note executie / facturare', record.executionNotes),
            ],
            palette: palette,
          ),
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
    required ComplaintWorkOrderRecord record,
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

  static String _fileName(ComplaintWorkOrderRecord record) {
    final safe = record.documentNumber
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_')
        .trim();
    return 'comanda_lucrari_${safe.isEmpty ? record.id : safe}.pdf';
  }

  static pw.Widget _linesTable(
    ComplaintWorkOrderRecord record,
    PdfTemplatePalette palette,
  ) {
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
            'Articole comandate',
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
              'Descriere',
              'Beneficiar',
              'Cant.',
              'UM',
              'Pret unitar',
              'Total',
            ],
            data: record.lines.map((line) {
              return <String>[
                line.description.trim().isEmpty ? '-' : line.description,
                line.beneficiaryName.trim().isEmpty
                    ? '-'
                    : line.beneficiaryName,
                line.quantity.toStringAsFixed(2),
                line.unit.trim().isEmpty ? '-' : line.unit,
                _money(line.unitPrice),
                _money(line.totalValue),
              ];
            }).toList(growable: false),
          ),
          pw.SizedBox(height: 8),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total comanda: ${_money(record.totalValue)}',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: palette.primary,
              ),
            ),
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
            width: 130,
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

  static String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  static String _money(double value) {
    return '${value.toStringAsFixed(2)} lei';
  }
}
