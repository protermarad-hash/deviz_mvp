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
import 'pontaj_fisa_aggregator.dart';

/// Fișă de pontaj PDF — combină personal PROPRIU + PARTENER într-un singur
/// document (decizie de produs, Faza 2/3 paritate pontaj partener).
///
/// Folosit în DOUĂ moduri (aceeași funcție `export`, diferă doar datele
/// pregătite de apelant via `pontaj_fisa_aggregator.dart`):
///  - per LUCRARE: rândurile provin dintr-o singură lucrare, filtrate pe
///    perioadă (`showJobColumn: false` — nu are sens o coloană "Lucrare"
///    repetitivă când toate rândurile aparțin aceleiași lucrări).
///  - agregat CROSS-LUCRARE per persoană: rândurile provin din mai multe
///    lucrări (`showJobColumn: true` — coloana "Lucrare" arată detalierea).
class PontajFisaPdfService {
  const PontajFisaPdfService._();

  static const _pageFormat = PdfPageFormat(
    297 * PdfPageFormat.mm,
    210 * PdfPageFormat.mm,
    marginAll: 10 * PdfPageFormat.mm,
  );

  static final _moneyFmt = NumberFormat('#,##0.00', 'ro_RO');
  static String _money(double v) => _moneyFmt.format(v);

  static String _dateLabel(DateTime? v) {
    if (v == null) return '-';
    return '${v.day.toString().padLeft(2, '0')}.'
        '${v.month.toString().padLeft(2, '0')}.${v.year}';
  }

  static String _periodLabel(PontajFisaRow row) {
    final start = row.dataStart;
    if (start == null) return '-';
    final end = row.dataEnd ?? start;
    final startLabel = _dateLabel(start);
    final endLabel = _dateLabel(end);
    return startLabel == endLabel ? startLabel : '$startLabel - $endLabel';
  }

  static Future<String> export({
    required AppDataRepository repository,
    required String documentTitle,
    required String periodLabel,
    required List<PontajFisaRow> ownRows,
    required List<PontajFisaRow> partnerRows,
    bool showJobColumn = false,
    String fileNamePrefix = 'fisa_pontaj',
    String outputDirectory = '',
    bool saveAs = false,
  }) async {
    await PdfFontHelper.initialize();
    final doc = pw.Document(theme: PdfFontHelper.theme);
    final companyProfile = await repository.loadCompanyProfile();
    final branding = DocumentBrandingData.fromCompanyProfile(companyProfile);
    final generatedAt = DateTime.now();

    final ownTotal = ownRows.fold<double>(0, (s, r) => s + r.costTotal);
    final partnerTotal = partnerRows.fold<double>(0, (s, r) => s + r.costTotal);
    final grandTotal = ownTotal + partnerTotal;
    final currency = [...ownRows, ...partnerRows]
        .map((r) => r.moneda)
        .firstWhere((_) => true, orElse: () => 'RON');

    List<String> headers({required bool isPartner}) => [
          'Persoană',
          if (isPartner) 'Partener',
          if (isPartner && ownRows.isNotEmpty) 'Rol',
          if (showJobColumn) 'Lucrare',
          'Perioadă',
          'Ore/zi',
          'Ore',
          'Tarif/oră',
          'Diurnă',
          'Cazare',
          'Total',
        ];

    List<String> rowCells(PontajFisaRow row, {required bool isPartner}) => [
          row.persoanaNume,
          if (isPartner) row.partenerNume,
          if (isPartner && ownRows.isNotEmpty) row.rol,
          if (showJobColumn)
            row.jobTitle.isEmpty ? row.jobCode : '${row.jobCode} · ${row.jobTitle}',
          _periodLabel(row),
          row.orePeZi.toStringAsFixed(2),
          row.oreTotale.toStringAsFixed(2),
          '${row.tarifOrar.toStringAsFixed(2)} ${row.moneda}',
          row.costDiurna > 0 ? '${row.costDiurna.toStringAsFixed(2)} ${row.moneda}' : '-',
          row.costCazare > 0 ? '${row.costCazare.toStringAsFixed(2)} ${row.moneda}' : '-',
          '${row.costTotal.toStringAsFixed(2)} ${row.moneda}',
        ];

    pw.Widget buildEmpty(String text) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        header: (context) => context.pageNumber == 1
            ? ProTermPdfTemplate.buildHeader(
                branding: branding,
                documentTitle: documentTitle,
                documentNumber: '',
                documentDate: _dateLabel(generatedAt),
                documentSubtitle: 'Perioadă: $periodLabel',
              )
            : pw.SizedBox.shrink(),
        footer: (context) => ProTermPdfTemplate.buildPageFooter(
          documentTitle: documentTitle,
          pageNumber: context.pageNumber,
          totalPages: context.pagesCount,
          date: _dateLabel(generatedAt),
        ),
        build: (context) => [
          pw.SizedBox(height: 10),
          ProTermPdfTemplate.buildSection(
            'Personal propriu (${ownRows.length})',
            [
              pw.SizedBox(height: 4),
              ownRows.isEmpty
                  ? buildEmpty('Nicio înregistrare de manoperă proprie în perioada selectată.')
                  : ProTermPdfTemplate.buildTable(
                      headers: headers(isPartner: false),
                      rows: ownRows
                          .map((r) => rowCells(r, isPartner: false))
                          .toList(growable: false),
                      showTotal: true,
                      totalLabel: 'Total personal propriu',
                      totalValue: '${_money(ownTotal)} $currency',
                    ),
            ],
          ),
          pw.SizedBox(height: 12),
          ProTermPdfTemplate.buildSection(
            'Personal partener (${partnerRows.length})',
            [
              pw.SizedBox(height: 4),
              partnerRows.isEmpty
                  ? buildEmpty('Nicio înregistrare de personal partener în perioada selectată.')
                  : ProTermPdfTemplate.buildTable(
                      headers: headers(isPartner: true),
                      rows: partnerRows
                          .map((r) => rowCells(r, isPartner: true))
                          .toList(growable: false),
                      showTotal: true,
                      totalLabel: 'Total personal partener',
                      totalValue: '${_money(partnerTotal)} $currency',
                    ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: ProTermPdfTemplate.lightRed,
              border: pw.Border.all(color: ProTermPdfTemplate.primaryRed),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL GENERAL (propriu + partener)',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                    color: ProTermPdfTemplate.primaryRed,
                  ),
                ),
                pw.Text(
                  '${_money(grandTotal)} $currency',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                    color: ProTermPdfTemplate.primaryRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final safeName = fileNamePrefix
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final fileName =
        '${safeName}_${generatedAt.millisecondsSinceEpoch}.pdf';
    final Uint8List bytes = await doc.save();
    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: fileName,
      category: PdfDocumentCategory.jobs,
      outputDirectory: outputDirectory,
      forceSaveAs: saveAs,
    );
  }
}
