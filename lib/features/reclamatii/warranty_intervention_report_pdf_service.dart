import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/company_profile.dart';
import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_font_bundle.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import '../product_catalog/product_sales_models.dart';
import 'warranty_intervention_report_models.dart';

class WarrantyInterventionReportPdfService {
  const WarrantyInterventionReportPdfService._();

  static Future<Uint8List> buildPdfBytes({
    required CompanyProfile company,
    required WarrantyInterventionReportRecord report,
    WarrantyCertificateRecord? certificate,
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
            documentTitle: 'PROCES-VERBAL INTERVENTIE IN GARANTIE',
            template: template,
            metadata: <MapEntry<String, String>>[
              MapEntry(
                'Numar',
                report.documentNumber.trim().isEmpty
                    ? report.id
                    : report.documentNumber.trim(),
              ),
              MapEntry('Data', _date(report.documentDate ?? report.updatedAt)),
              MapEntry('Tehnician', report.technicianName),
              MapEntry('Client', report.clientName),
            ],
          ),
          pw.SizedBox(height: 16),
          _section(
              'Date client / interventie',
              [
                _row('Client / beneficiar', report.clientName),
                _row(
                  'Reprezentant beneficiar',
                  report.beneficiaryRepresentative,
                ),
                _row('Tehnician', report.technicianName),
                _row('Echipa', report.teamName),
                _row(
                  'Lucrare',
                  report.jobTitle.trim().isEmpty
                      ? report.jobId
                      : report.jobTitle,
                ),
              ],
              palette: palette),
          pw.SizedBox(height: 12),
          _section(
              'Garantie',
              [
                _row('Status garantie', report.warrantyCoverageStatus.label),
                _row(
                  'Certificat garantie',
                  certificate == null
                      ? report.warrantyCertificateId
                      : certificate.fullCertificateNumber,
                ),
                _row(
                  'Perioada garantie',
                  certificate == null ? '-' : _warrantyPeriod(certificate),
                ),
                _row(
                  'Talon / istoric service',
                  report.warrantyServiceTicketId.trim().isEmpty
                      ? '-'
                      : report.warrantyServiceTicketId,
                ),
              ],
              palette: palette),
          pw.SizedBox(height: 12),
          _section(
              'Echipament',
              [
                _row('Echipament', report.equipmentLabel),
                _row('Brand', report.brand),
                _row('Model', report.model),
                _row('Serie unitate interioara', report.serialNumberIndoor),
                _row('Serie unitate exterioara', report.serialNumberOutdoor),
              ],
              palette: palette),
          pw.SizedBox(height: 12),
          _section(
              'Constatare si interventie',
              [
                _paragraph('Constatare', report.findings),
                _paragraph('Lucrari efectuate', report.workPerformed),
                _paragraph('Materiale folosite', report.materialsUsedText),
                _paragraph('Piese inlocuite', report.partsReplacedText),
                _paragraph('Concluzii / recomandari', report.recommendations),
                _row('Rezultat interventie', _resultLabel(report.resultStatus)),
              ],
              palette: palette),
          if (_hasAgfr(report)) ...[
            pw.SizedBox(height: 12),
            _section(
                'Legaturi AGFR',
                [
                  _row('Echipament AGFR', report.agfrEquipmentId),
                  _row('Interventie AGFR', report.agfrInterventionId),
                  _row('Raport AGFR', report.agfrReportId),
                ],
                palette: palette),
          ],
          pw.SizedBox(height: 18),
          _signatureSection(
            clientSignature: _tryDecodeBase64(report.clientSignatureBase64),
            technicianSignature:
                _tryDecodeBase64(report.technicianSignatureBase64),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<String> export({
    required AppDataRepository repository,
    required CompanyProfile company,
    required WarrantyInterventionReportRecord report,
    WarrantyCertificateRecord? certificate,
    String outputDirectory = '',
    bool saveAs = false,
  }) async {
    final bytes = await buildPdfBytes(
      company: company,
      report: report,
      certificate: certificate,
    );
    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: _fileName(report),
      category: PdfDocumentCategory.other,
      outputDirectory: outputDirectory,
      forceSaveAs: saveAs,
    );
  }

  static String _fileName(WarrantyInterventionReportRecord report) {
    final number = report.documentNumber.trim().isEmpty
        ? report.id
        : report.documentNumber.trim();
    final safe = number.replaceAll(RegExp(r'[^A-Za-z0-9_\\-]+'), '_');
    return 'pv_garantie_$safe.pdf';
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
        pw.Expanded(
            child: signatureBox('Semnătură beneficiar', clientSignature)),
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

  static String _warrantyPeriod(WarrantyCertificateRecord certificate) {
    final start = certificate.warrantyStartDate;
    final end = certificate.warrantyEndDate;
    if (start == null && end == null) {
      return certificate.warrantyMonths <= 0
          ? '-'
          : '${certificate.warrantyMonths} luni';
    }
    final startText = start == null ? '-' : _date(start);
    final endText = end == null ? '-' : _date(end);
    return '$startText - $endText';
  }

  static String _resultLabel(String raw) {
    final mapped = raw.trim();
    if (mapped.isEmpty) {
      return '-';
    }
    switch (mapped) {
      case 'rezolvata':
        return 'Rezolvata';
      case 'necesita_revenire':
        return 'Necesita revenire';
      case 'necesita_piese':
        return 'Necesita piese';
      case 'monitorizare':
        return 'Monitorizare';
      case 'client_indisponibil':
        return 'Client indisponibil';
      case 'fara_defect_constatat':
        return 'Fara defect constatat';
      default:
        return mapped;
    }
  }

  static bool _hasAgfr(WarrantyInterventionReportRecord report) {
    return report.agfrEquipmentId.trim().isNotEmpty ||
        report.agfrInterventionId.trim().isNotEmpty ||
        report.agfrReportId.trim().isNotEmpty;
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
}
