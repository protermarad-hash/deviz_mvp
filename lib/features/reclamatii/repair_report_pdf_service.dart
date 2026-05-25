import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/company_profile.dart';
import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_font_bundle.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'complaint_models.dart';
import 'pv_pif_pdf_common.dart';
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
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          buildClassicDocumentHeader(
            branding: branding,
            documentTitle: 'PROCES-VERBAL / PIF DE INTERVENTIE TEHNICA',
            template: template,
            metadata: <MapEntry<String, String>>[
              MapEntry(
                'Numar',
                report.reportNumber.trim().isEmpty
                    ? report.id
                    : report.reportNumber.trim(),
              ),
              MapEntry('Data', _date(report.interventionDate)),
              MapEntry('Tehnician', report.technicianName),
              MapEntry('Beneficiar', report.beneficiaryName),
            ],
          ),
          pw.SizedBox(height: 16),
          _section(
              'Date interventie',
              [
                _row('Beneficiar', report.beneficiaryName),
                if (report.contractorName.trim().isNotEmpty)
                  _row('Societate contractanta', report.contractorName),
                _row('Persoana de contact', report.contactPerson),
                _row('Telefon', report.phone),
                _row('Email', report.email),
                _row('Locatie', report.location),
                _row('Tehnician', report.technicianName),
                _row('Echipa', report.teamName),
                _row('Status rezolvare', report.resolutionStatus.label),
              ],
              palette: palette),
          if (_hasEquipmentData(report)) ...[
            pw.SizedBox(height: 12),
            _section(
                'Echipament / Utilaj',
                [
                  _row('Tip echipament',
                      _equipmentTypeLabel(report.equipmentType)),
                  _row('Brand', report.equipmentBrand),
                  _row('Model', report.equipmentModel),
                  _row('Serie unitate exterioara', report.outdoorUnitSerial),
                  _row('Serii unitati interioare', report.indoorUnitSerials),
                  _row('Detalii tehnice', report.equipmentDetails),
                ],
                palette: palette),
          ],
          pw.SizedBox(height: 12),
          _section(
              'Continut',
              [
                _paragraph('Descriere reclamatie', report.complaintDescription),
                _paragraph('Constatare', report.findings),
                _paragraph('Lucrari efectuate', report.workPerformed),
                _paragraph('Materiale / piese folosite', report.materialsUsed),
                _paragraph('Recomandari / observatii', report.recommendations),
              ],
              palette: palette),
          pw.SizedBox(height: 12),
          _section(
              'Checklist tehnic interventie',
              [
                PvPifPdfCommon.checkLine(
                  label: 'Identificare aparat (tip/brand/model/serii)',
                  completed: _hasEquipmentData(report),
                ),
                PvPifPdfCommon.checkLine(
                  label: 'Simptom reclamat documentat',
                  completed: report.complaintDescription.trim().isNotEmpty,
                ),
                PvPifPdfCommon.checkLine(
                  label: 'Constatare tehnica completata',
                  completed: report.findings.trim().isNotEmpty,
                ),
                PvPifPdfCommon.checkLine(
                  label: 'Operatiuni executate descrise',
                  completed: report.workPerformed.trim().isNotEmpty,
                ),
                PvPifPdfCommon.checkLine(
                  label: 'Materiale/piese consemnate',
                  completed: report.materialsUsed.trim().isNotEmpty,
                ),
                PvPifPdfCommon.checkLine(
                  label: 'Recomandari post-interventie',
                  completed: report.recommendations.trim().isNotEmpty,
                ),
              ],
              palette: palette),
          pw.SizedBox(height: 12),
          _section(
              'Probe functionale / parametri urmariti',
              [
                _paragraph(
                  'Probe functionale executate',
                  PvPifPdfCommon.functionalChecksText,
                ),
                _paragraph(
                  'Parametri relevanti in teren',
                  PvPifPdfCommon.fieldParametersText,
                ),
              ],
              palette: palette),
          pw.SizedBox(height: 12),
          _section(
              'Materiale si piese (evidenta)',
              [
                _paragraph(
                  'Cod articol / denumire / cantitate',
                  report.materialsUsed,
                ),
                _paragraph(
                  'Traseu piese defecte/inlocuite',
                  PvPifPdfCommon.partsTraceabilityText,
                ),
              ],
              palette: palette),
          pw.SizedBox(height: 12),
          _section(
              'Identificare administrativa',
              [
                _row('ID document', report.id),
                _row('ID reclamatie', report.complaintId),
                _row('ID programare', report.appointmentId),
                _row('ID lucrare', report.jobId),
                _row('Document emis de', company.companyName.trim()),
                _row('CUI emitent', company.cui.trim()),
              ],
              palette: palette),
          pw.SizedBox(height: 12),
          _section(
              'Declaratii si mentiuni',
              [
                _paragraph(
                  'Scop document',
                  'Prezentul document consemneaza constatarea tehnica si operatiunile efectuate la fata locului pentru echipamentul mentionat.',
                ),
                _paragraph(
                  'Conditii garantie',
                  'Interventia se analizeaza in raport cu certificatul de garantie, istoricul de service si conditiile de utilizare/exploatare declarate de beneficiar.',
                ),
                _paragraph(
                  'Observații juridice',
                  PvPifPdfCommon.legalObservationsText,
                ),
                _paragraph(
                  'Anexe foto teren',
                  PvPifPdfCommon.fieldPhotoAnnexText,
                ),
              ],
              palette: palette),
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

  static bool _hasEquipmentData(RepairReportRecord report) {
    return report.equipmentType.trim().isNotEmpty ||
        report.equipmentBrand.trim().isNotEmpty ||
        report.equipmentModel.trim().isNotEmpty ||
        report.outdoorUnitSerial.trim().isNotEmpty ||
        report.indoorUnitSerials.trim().isNotEmpty ||
        report.equipmentDetails.trim().isNotEmpty;
  }

  static String _equipmentTypeLabel(String raw) {
    return ComplaintEquipmentType.fromValue(raw)?.label ??
        (raw.trim().isEmpty ? '-' : raw.trim());
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
}
