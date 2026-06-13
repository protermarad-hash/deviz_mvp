import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/company_profile.dart';
import '../../core/pdf/pdf_font_helper.dart';
import '../../core/pdf/pro_term_pdf_template.dart';
import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'partner_financial_models.dart';

/// Generează Fișă Decont Partener (PDF) și Export CSV.
class PartnerDecontService {
  const PartnerDecontService._();

  static final _fmt = NumberFormat('#,##0.00', 'ro_RO');
  static final _dateFmt = DateFormat('dd.MM.yyyy');

  // ─────────────────────────────────────────────────────────────────────────
  // PDF — Fișă decont partener
  // ─────────────────────────────────────────────────────────────────────────

  static Future<String> exportPdf({
    required List<PartnerTransaction> transactions,
    required String partnerName,
    required AppDataRepository repository,
    DateTime? periodStart,
    DateTime? periodEnd,
    bool forceSaveAs = false,
  }) async {
    await PdfFontHelper.initialize();

    CompanyProfile profile;
    try {
      profile = await repository.loadCompanyProfile();
    } catch (_) {
      profile = const CompanyProfile();
    }
    final branding = DocumentBrandingData.fromCompanyProfile(profile);

    // Filtrare pe perioadă
    final filtered = _filterByPeriod(transactions, periodStart, periodEnd);

    // Calcul sumar
    final lucrari = filtered
        .where((t) =>
            t.type == PartnerTransactionType.incasareProgramare &&
            t.financialDirection == 'credit_neincasat')
        .toList();
    final materiale = filtered
        .where((t) => t.type == PartnerTransactionType.consumMateriale)
        .toList();
    final produse = filtered
        .where((t) =>
            t.type == PartnerTransactionType.vanzareProdus &&
            t.financialDirection == 'credit_neincasat')
        .toList();
    final incasari = filtered
        .where((t) => t.type == PartnerTransactionType.incasareManuala)
        .toList();
    final datorii = filtered
        .where((t) =>
            t.financialDirection == 'plata_efectuata' ||
            t.financialDirection == 'plata_efectuata_achitata')
        .toList();

    final totalLucrari = lucrari.fold<double>(0, (s, t) => s + t.amount);
    final totalMateriale = materiale.fold<double>(0, (s, t) => s + t.amount);
    final totalProduse = produse.fold<double>(0, (s, t) => s + t.amount);
    final totalIncasari = incasari.fold<double>(0, (s, t) => s + t.amount);
    final totalDatorii = datorii
        .where((t) => t.financialDirection == 'plata_efectuata')
        .fold<double>(0, (s, t) => s + t.amount);
    final totalCredite = totalLucrari + totalMateriale + totalProduse;
    final restDeIncasat = (totalCredite - totalIncasari).clamp(0.0, double.infinity);

    final dateGen = _dateFmt.format(DateTime.now());
    final perioadaLabel = _buildPerioadaLabel(periodStart, periodEnd);

    final doc = pw.Document(theme: PdfFontHelper.theme);
    final bold = PdfFontHelper.bold;
    final regular = PdfFontHelper.regular;

    pw.TextStyle ts({double size = 9, pw.Font? font, PdfColor color = ProTermPdfTemplate.darkText}) =>
        pw.TextStyle(font: font ?? regular, fontSize: size, color: color);
    pw.TextStyle tsBold({double size = 9, PdfColor color = ProTermPdfTemplate.darkText}) =>
        pw.TextStyle(font: bold, fontSize: size, color: color);
    pw.TextStyle tsRed({double size = 9}) =>
        pw.TextStyle(font: bold, fontSize: size, color: ProTermPdfTemplate.primaryRed);

    // ── Widget titlu secțiune ─────────────────────────────────────────────
    pw.Widget sectionTitle(String title, {PdfColor? color}) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12, bottom: 4),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: pw.BoxDecoration(
            color: color ?? ProTermPdfTemplate.primaryRed,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              font: bold,
              fontSize: 9,
              color: PdfColors.white,
            ),
          ),
        );

    // ── Widget linie sumar ────────────────────────────────────────────────
    pw.Widget sumRow(String label, String value,
        {bool highlight = false, bool isBig = false}) {
      return pw.Container(
        color: highlight ? ProTermPdfTemplate.lightRed : null,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                label,
                style: highlight
                    ? tsBold(
                        size: isBig ? 11 : 9,
                        color: ProTermPdfTemplate.primaryRed)
                    : ts(size: isBig ? 10 : 9),
              ),
            ),
            pw.Text(
              value,
              style: highlight
                  ? tsBold(
                      size: isBig ? 11 : 9,
                      color: ProTermPdfTemplate.primaryRed)
                  : ts(size: isBig ? 10 : 9),
            ),
          ],
        ),
      );
    }

    // ── Widget tabel tranzacții ───────────────────────────────────────────
    pw.Widget txTable({
      required List<String> headers,
      required List<List<String>> rows,
      required List<double> widths,
      required double total,
      required String totalLabel,
    }) {
      if (rows.isEmpty) return pw.SizedBox.shrink();
      return ProTermPdfTemplate.buildTable(
        headers: headers,
        rows: rows,
        columnWidths: widths,
        showTotal: true,
        totalLabel: totalLabel,
        totalValue: '${_fmt.format(total)} RON',
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15 * PdfPageFormat.mm),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            ProTermPdfTemplate.buildHeader(
              branding: branding,
              documentTitle: 'FIȘĂ DECONT PARTENER',
              documentNumber: '',
              documentDate: dateGen,
              documentSubtitle: perioadaLabel.isNotEmpty
                  ? 'Perioadă: $perioadaLabel'
                  : null,
            ),
            pw.SizedBox(height: 4),
            // Date partener
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: pw.BoxDecoration(
                color: ProTermPdfTemplate.lightGray,
                border: pw.Border.all(
                    color: ProTermPdfTemplate.borderGray, width: 0.5),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Row(
                children: [
                  pw.Text('PARTENER: ',
                      style: tsRed(size: 10)),
                  pw.Expanded(
                    child: pw.Text(
                      partnerName,
                      style: tsBold(size: 10),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(top: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border(
                top: pw.BorderSide(
                    color: ProTermPdfTemplate.borderGray, width: 0.5)),
          ),
          child: pw.Text(
            'Pagina ${ctx.pageNumber} / ${ctx.pagesCount} · Generat: $dateGen',
            style: ts(size: 7.5, color: ProTermPdfTemplate.mediumText),
          ),
        ),
        build: (ctx) => [
          // ── SUMAR FINANCIAR ────────────────────────────────────────────
          sectionTitle('SUMAR FINANCIAR'),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: ProTermPdfTemplate.borderGray),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Column(
              children: [
                if (totalLucrari > 0)
                  sumRow('Lucrări / manoperă de decontat',
                      '${_fmt.format(totalLucrari)} RON'),
                if (totalMateriale > 0)
                  sumRow('Materiale / kituri de recuperat',
                      '${_fmt.format(totalMateriale)} RON'),
                if (totalProduse > 0)
                  sumRow('Produse vândute de încasat',
                      '${_fmt.format(totalProduse)} RON'),
                pw.Container(
                  height: 0.5,
                  color: ProTermPdfTemplate.borderGray,
                ),
                sumRow(
                  'TOTAL DATORAT DE PARTENER',
                  '${_fmt.format(totalCredite)} RON',
                ),
                sumRow(
                  'Plăți primite de la partener',
                  '- ${_fmt.format(totalIncasari)} RON',
                ),
                pw.Container(
                  height: 0.5,
                  color: ProTermPdfTemplate.primaryRed,
                ),
                sumRow(
                  'REST DE ÎNCASAT',
                  '${_fmt.format(restDeIncasat)} RON',
                  highlight: true,
                  isBig: true,
                ),
                if (totalDatorii > 0) ...[
                  pw.Container(
                    height: 0.5,
                    color: ProTermPdfTemplate.borderGray,
                  ),
                  sumRow(
                    'Datorii neachitate către partener',
                    '${_fmt.format(totalDatorii)} RON',
                  ),
                ],
              ],
            ),
          ),

          // ── LUCRĂRI / SERVICII ─────────────────────────────────────────
          if (lucrari.isNotEmpty) ...[
            sectionTitle('LUCRĂRI / SERVICII DE DECONTAT',
                color: const PdfColor(0.0, 0.4549, 0.3216)),
            txTable(
              headers: ['Nr.', 'Data', 'Descriere', 'Referință', 'Sumă (RON)'],
              rows: lucrari.asMap().entries.map((e) {
                final t = e.value;
                return [
                  '${e.key + 1}',
                  _dateFmt.format(t.date),
                  t.description,
                  t.referenceId.isNotEmpty ? t.referenceId : '-',
                  _fmt.format(t.amount),
                ];
              }).toList(),
              widths: [0.05, 0.1, 0.55, 0.15, 0.15],
              total: totalLucrari,
              totalLabel: 'Total lucrări',
            ),
          ],

          // ── MATERIALE / KITURI ─────────────────────────────────────────
          if (materiale.isNotEmpty) ...[
            sectionTitle('MATERIALE / KITURI DE RECUPERAT',
                color: const PdfColor(0.0, 0.4745, 0.5216)),
            txTable(
              headers: ['Nr.', 'Data', 'Descriere', 'Kit', 'Sumă (RON)'],
              rows: materiale.asMap().entries.map((e) {
                final t = e.value;
                return [
                  '${e.key + 1}',
                  _dateFmt.format(t.date),
                  t.description,
                  t.kitName.isNotEmpty ? t.kitName : '-',
                  _fmt.format(t.amount),
                ];
              }).toList(),
              widths: [0.05, 0.1, 0.5, 0.2, 0.15],
              total: totalMateriale,
              totalLabel: 'Total materiale',
            ),
          ],

          // ── PRODUSE VÂNDUTE ────────────────────────────────────────────
          if (produse.isNotEmpty) ...[
            sectionTitle('PRODUSE VÂNDUTE NEÎNCASATE',
                color: const PdfColor(0.2118, 0.3059, 0.6784)),
            txTable(
              headers: ['Nr.', 'Data', 'Descriere', 'Sumă (RON)'],
              rows: produse.asMap().entries.map((e) {
                final t = e.value;
                return [
                  '${e.key + 1}',
                  _dateFmt.format(t.date),
                  t.description,
                  _fmt.format(t.amount),
                ];
              }).toList(),
              widths: [0.05, 0.1, 0.7, 0.15],
              total: totalProduse,
              totalLabel: 'Total produse',
            ),
          ],

          // ── PLĂȚI PRIMITE ──────────────────────────────────────────────
          if (incasari.isNotEmpty) ...[
            sectionTitle('PLĂȚI PRIMITE DE LA PARTENER',
                color: const PdfColor(0.2353, 0.5020, 0.2314)),
            txTable(
              headers: [
                'Nr.',
                'Data',
                'Descriere',
                'Metodă',
                'Categorie',
                'Sumă (RON)',
              ],
              rows: incasari.asMap().entries.map((e) {
                final t = e.value;
                return [
                  '${e.key + 1}',
                  _dateFmt.format(t.date),
                  t.description,
                  t.paymentMethod.label,
                  t.collectionCategory == PartnerCollectionCategory.general
                      ? 'General'
                      : t.collectionCategory.label,
                  _fmt.format(t.amount),
                ];
              }).toList(),
              widths: [0.04, 0.09, 0.38, 0.12, 0.18, 0.15],
              total: totalIncasari,
              totalLabel: 'Total încasat',
            ),
          ],

          // ── DATORII PARTENER ───────────────────────────────────────────
          if (datorii.isNotEmpty) ...[
            sectionTitle('DATORII CĂTRE PARTENER',
                color: ProTermPdfTemplate.primaryRed),
            txTable(
              headers: ['Nr.', 'Data', 'Descriere', 'Status', 'Sumă (RON)'],
              rows: datorii.asMap().entries.map((e) {
                final t = e.value;
                return [
                  '${e.key + 1}',
                  _dateFmt.format(t.date),
                  t.description,
                  t.status.label,
                  _fmt.format(t.amount),
                ];
              }).toList(),
              widths: [0.05, 0.1, 0.55, 0.15, 0.15],
              total: datorii.fold(0, (s, t) => s + t.amount),
              totalLabel: 'Total datorii',
            ),
          ],

          pw.SizedBox(height: 8),
          pw.Divider(
              color: ProTermPdfTemplate.borderGray, height: 1, thickness: 0.5),
          pw.SizedBox(height: 4),
          pw.Text(
            'Document generat automat de aplicația PRO TERM · $dateGen',
            style: ts(
                size: 7.5, color: ProTermPdfTemplate.mediumText),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final safeName = partnerName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final fileName =
        'Decont_${safeName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: fileName,
      category: PdfDocumentCategory.other,
      forceSaveAs: forceSaveAs,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CSV — Export date partener
  // ─────────────────────────────────────────────────────────────────────────

  static Future<String> exportCsv({
    required List<PartnerTransaction> transactions,
    required String partnerName,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) async {
    final filtered = _filterByPeriod(transactions, periodStart, periodEnd);

    final buf = StringBuffer();
    // BOM UTF-8 pentru Excel Windows
    buf.write('﻿');

    // Header CSV
    buf.writeln(
        'Data,Tip,Descriere,Directie,Suma (RON),Status,Metoda plata,Categorie alocare,Suma lucrari,Suma materiale,Suma produse,Referinta,Kit');

    for (final t in filtered) {
      final row = [
        _dateFmt.format(t.date),
        t.type.label,
        _csvEscape(t.description),
        t.direction.label,
        t.amount.toStringAsFixed(2).replaceAll('.', ','),
        t.status.label,
        t.paymentMethod.label,
        t.collectionCategory.label,
        t.allocatedWorkAmount > 0
            ? t.allocatedWorkAmount.toStringAsFixed(2).replaceAll('.', ',')
            : '',
        t.allocatedMaterialsAmount > 0
            ? t.allocatedMaterialsAmount
                .toStringAsFixed(2)
                .replaceAll('.', ',')
            : '',
        t.allocatedProductsAmount > 0
            ? t.allocatedProductsAmount
                .toStringAsFixed(2)
                .replaceAll('.', ',')
            : '',
        _csvEscape(t.referenceId),
        _csvEscape(t.kitName),
      ].join(';');
      buf.writeln(row);
    }

    final dir = await getTemporaryDirectory();
    final safeName = partnerName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final fileName =
        'Decont_${safeName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buf.toString(), encoding: utf8);
    return file.path;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers private
  // ─────────────────────────────────────────────────────────────────────────

  static List<PartnerTransaction> _filterByPeriod(
    List<PartnerTransaction> transactions,
    DateTime? start,
    DateTime? end,
  ) {
    if (start == null && end == null) return transactions;
    return transactions.where((t) {
      if (start != null && t.date.isBefore(start)) return false;
      if (end != null &&
          t.date.isAfter(end.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();
  }

  static String _buildPerioadaLabel(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    if (start != null && end != null) {
      return '${_dateFmt.format(start)} — ${_dateFmt.format(end)}';
    }
    if (start != null) return 'de la ${_dateFmt.format(start)}';
    return 'până la ${_dateFmt.format(end!)}';
  }

  static String _csvEscape(String value) {
    if (value.contains(';') ||
        value.contains('"') ||
        value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
