import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/company_profile.dart';
import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_font_bundle.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'scule_models.dart';

class SculeHandoverPdfService {
  const SculeHandoverPdfService._();

  static Future<String> export({
    required AppDataRepository repository,
    required CompanyProfile company,
    required String documentNumber,
    required DateTime documentDate,
    required String teamName,
    required String responsibleName,
    required List<ToolHandoverLine> lines,
    required String predatDe,
    required String primitDe,
    String documentTitle = 'PROCES VERBAL PREDARE-PRIMIRE SCULE',
    String operationLabel = '',
    String packageName = '',
    String outputDirectory = '',
  }) async {
    final pdfFonts = await PdfFontBundle.load();
    final doc = pw.Document(theme: pdfFonts.theme);
    final branding = DocumentBrandingData.fromCompanyProfile(company);
    final template = company.pdfExportSettings.visualTemplate;

    String dateLabel(DateTime value) {
      final d = value.day.toString().padLeft(2, '0');
      final m = value.month.toString().padLeft(2, '0');
      return '$d.$m.${value.year}';
    }

    pw.Widget infoRow(String label, String value) {
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
              child: pw.Text(value.trim().isEmpty ? '-' : value.trim()),
            ),
          ],
        ),
      );
    }

    pw.Widget section(String title, List<pw.Widget> rows) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
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
              ),
            ),
            pw.SizedBox(height: 6),
            ...rows,
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          buildClassicDocumentHeader(
            branding: branding,
            documentTitle: documentTitle.trim().isEmpty
                ? 'PROCES-VERBAL PREDARE-PRIMIRE SCULE'
                : documentTitle.trim(),
            template: template,
            metadata: <MapEntry<String, String>>[
              MapEntry('Numar', documentNumber),
              MapEntry('Data', dateLabel(documentDate)),
              MapEntry('Echipa', teamName),
              MapEntry('Responsabil', responsibleName),
            ],
          ),
          pw.SizedBox(height: 12),
          section(
            'Date predare-primire',
            [
              infoRow(
                'Firma',
                company.companyName.trim().isEmpty ? '-' : company.companyName,
              ),
              infoRow('Nr. document', documentNumber),
              infoRow('Data document', dateLabel(documentDate)),
              if (operationLabel.trim().isNotEmpty)
                infoRow('Tip operatiune', operationLabel),
              if (packageName.trim().isNotEmpty)
                infoRow('Pachet scule', packageName),
              infoRow('Echipa destinatar', teamName),
              infoRow('Responsabil echipa', responsibleName),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const <String>[
              'Nr.',
              'Denumire',
              'Categorie',
              'Brand/Model',
              'Cod inventar',
              'Serie',
              'Stare/Observații',
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            columnWidths: <int, pw.TableColumnWidth>{
              0: const pw.FixedColumnWidth(24),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(1.6),
              3: const pw.FlexColumnWidth(2.2),
              4: const pw.FlexColumnWidth(1.8),
              5: const pw.FlexColumnWidth(1.8),
              6: const pw.FlexColumnWidth(2.8),
            },
            data: lines
                .asMap()
                .entries
                .map(
                  (entry) => <String>[
                    '${entry.key + 1}',
                    entry.value.name,
                    entry.value.category,
                    entry.value.brandModel,
                    entry.value.inventoryCode,
                    entry.value.serialNumber,
                    '${entry.value.statusLabel}${entry.value.notes.trim().isEmpty ? '' : ' | ${entry.value.notes.trim()}'}',
                  ],
                )
                .toList(growable: false),
          ),
          pw.SizedBox(height: 12),
          section(
            'Checklist predare-primire',
            [
              infoRow('Inventar verificat', 'DA'),
              infoRow('Stare scule consemnata', 'DA'),
              infoRow('Serii/coduri inventar consemnate', 'DA'),
              infoRow('Anexe foto teren', 'Conform procedurilor interne'),
            ],
          ),
          pw.SizedBox(height: 12),
          section(
            'Declaratii si mentiuni',
            [
              pw.Text(
                'Partile confirma predarea-primirea bunurilor mentionate, cu starea tehnica si observatiile consemnate in prezentul document.',
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Documentul are caracter de proces-verbal operational si se completeaza impreuna cu anexele tehnice/logistice aferente (dupa caz).',
              ),
            ],
          ),
          pw.SizedBox(height: 28),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Predat de',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(predatDe.trim().isEmpty ? '-' : predatDe.trim()),
                    pw.SizedBox(height: 28),
                    pw.Text('Semnătură: __________________________'),
                    pw.SizedBox(height: 8),
                    pw.Text('Data: ${dateLabel(documentDate)}'),
                  ],
                ),
              ),
              pw.SizedBox(width: 30),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Primit de',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(primitDe.trim().isEmpty ? '-' : primitDe.trim()),
                    pw.SizedBox(height: 28),
                    pw.Text('Semnătură: __________________________'),
                    pw.SizedBox(height: 8),
                    pw.Text('Data: ${dateLabel(documentDate)}'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final fileName = _fileName(documentNumber);
    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: fileName,
      category: PdfDocumentCategory.other,
      outputDirectory: outputDirectory,
    );
  }

  static String _fileName(String number) {
    final normalized = number
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final value = normalized.isEmpty ? 'PV_SCULE' : normalized;
    return 'pv_predare_primire_scule_$value.pdf';
  }
}
