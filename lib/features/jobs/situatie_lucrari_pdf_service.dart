import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_font_bundle.dart';

/// Parametrii necesari pentru generarea unei Situații de Lucrări.
class SituatieLucrariParams {
  const SituatieLucrariParams({
    required this.number,
    required this.documentDate,
    required this.jobCode,
    required this.jobTitle,
    required this.clientName,
    required this.contractNumber,
    required this.contractDate,
    required this.periodStart,
    required this.periodEnd,
    required this.location,
    required this.materials,
    required this.laborEntries,
    required this.vatPercent,
    required this.notes,
    required this.branding,
    required this.template,
  });

  final String number;
  final DateTime documentDate;
  final String jobCode;
  final String jobTitle;
  final String clientName;
  final String contractNumber;
  final String contractDate;
  final String periodStart;
  final String periodEnd;
  final String location;

  /// Fiecare element are cheile: name, um, qty, price, total (toate String sau num)
  final List<Map<String, dynamic>> materials;

  /// Fiecare element are cheile: who, hours, rate, total (toate String sau num)
  final List<Map<String, dynamic>> laborEntries;

  final double vatPercent;
  final String notes;
  final DocumentBrandingData branding;
  final PdfVisualTemplate template;
}

class SituatieLucrariPdfService {
  const SituatieLucrariPdfService._();

  static Future<Uint8List> buildPdfBytes(SituatieLucrariParams p) async {
    final pdfFonts = await PdfFontBundle.load();
    final doc = pw.Document(theme: pdfFonts.theme);
    final palette = resolvePdfTemplatePalette(p.template);

    final dateStr = _fmtDate(p.documentDate);

    // ---- Calcule financiare ----
    double matTotal = 0;
    for (final m in p.materials) {
      matTotal += _num(m['total']) > 0
          ? _num(m['total'])
          : _num(m['qty']) * _num(m['price']);
    }
    double laborTotal = 0;
    for (final l in p.laborEntries) {
      laborTotal += _num(l['total']) > 0
          ? _num(l['total'])
          : _num(l['hours']) * _num(l['rate']);
    }
    final subtotal = matTotal + laborTotal;
    final vatValue = subtotal * p.vatPercent / 100;
    final totalWithVat = subtotal + vatValue;

    // ---- Widgeturi helper ----
    pw.Widget sectionHeader(String title) => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: pw.BoxDecoration(
            color: palette.primary,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        );

    pw.Widget infoRow(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 130,
                child: pw.Text(
                  label,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8.8,
                    color: palette.secondary,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  value.trim().isEmpty ? '-' : value.trim(),
                  style: const pw.TextStyle(fontSize: 8.8),
                ),
              ),
            ],
          ),
        );

    pw.Widget summaryRow(String label, String value,
            {bool emphasize = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                label,
                style: emphasize
                    ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)
                    : const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                value,
                style: emphasize
                    ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)
                    : const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        );

    String money(double v) => v.toStringAsFixed(2);

    // ---- Table helpers ----
    pw.Widget headerCell(String text,
            {pw.TextAlign align = pw.TextAlign.left}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: pw.Text(
            text,
            textAlign: align,
            style: pw.TextStyle(
              fontSize: 8.2,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        );

    pw.Widget dataCell(String text,
            {pw.TextAlign align = pw.TextAlign.left, pw.TextStyle? style}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Text(
            text,
            textAlign: align,
            style: style ?? const pw.TextStyle(fontSize: 8.2),
          ),
        );

    // ---- Construim tabelul de materiale ----
    List<pw.TableRow> buildMaterialRows() {
      final rows = <pw.TableRow>[];
      // Header
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: palette.primary),
        children: [
          headerCell('Nr.', align: pw.TextAlign.center),
          headerCell('Denumire'),
          headerCell('UM', align: pw.TextAlign.center),
          headerCell('Cantitate', align: pw.TextAlign.right),
          headerCell('Preț unitar\n(lei)', align: pw.TextAlign.right),
          headerCell('Valoare\n(lei)', align: pw.TextAlign.right),
        ],
      ));
      // Date
      for (int i = 0; i < p.materials.length; i++) {
        final m = p.materials[i];
        final name = _str(m['name']);
        final um = _str(m['um']);
        final qty = _num(m['qty']);
        final price = _num(m['price']);
        final total = _num(m['total']) > 0 ? _num(m['total']) : qty * price;
        rows.add(pw.TableRow(
          decoration: pw.BoxDecoration(
            color: i.isEven ? PdfColors.white : palette.surfaceAlt,
          ),
          children: [
            dataCell('${i + 1}', align: pw.TextAlign.center),
            dataCell(name),
            dataCell(um, align: pw.TextAlign.center),
            dataCell(money(qty), align: pw.TextAlign.right),
            dataCell(money(price), align: pw.TextAlign.right),
            dataCell(
              money(total),
              align: pw.TextAlign.right,
              style:
                  pw.TextStyle(fontSize: 8.2, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ));
      }
      // Total materiale
      rows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          dataCell('', align: pw.TextAlign.center),
          dataCell(
            'TOTAL MATERIALE',
            style: pw.TextStyle(fontSize: 8.4, fontWeight: pw.FontWeight.bold),
          ),
          dataCell(''),
          dataCell(''),
          dataCell(''),
          dataCell(
            money(matTotal),
            align: pw.TextAlign.right,
            style: pw.TextStyle(fontSize: 8.4, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ));
      return rows;
    }

    // ---- Construim tabelul de manoperă ----
    List<pw.TableRow> buildLaborRows() {
      final rows = <pw.TableRow>[];
      // Header
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: palette.primary),
        children: [
          headerCell('Nr.', align: pw.TextAlign.center),
          headerCell('Persoană / Echipă'),
          headerCell('UM', align: pw.TextAlign.center),
          headerCell('Ore', align: pw.TextAlign.right),
          headerCell('Tarif\n(lei/oră)', align: pw.TextAlign.right),
          headerCell('Valoare\n(lei)', align: pw.TextAlign.right),
        ],
      ));
      for (int i = 0; i < p.laborEntries.length; i++) {
        final l = p.laborEntries[i];
        final who = _str(l['who']);
        final hours = _num(l['hours']);
        final rate = _num(l['rate']);
        final total = _num(l['total']) > 0 ? _num(l['total']) : hours * rate;
        rows.add(pw.TableRow(
          decoration: pw.BoxDecoration(
            color: i.isEven ? PdfColors.white : palette.surfaceAlt,
          ),
          children: [
            dataCell('${i + 1}', align: pw.TextAlign.center),
            dataCell(who),
            dataCell('oră', align: pw.TextAlign.center),
            dataCell(money(hours), align: pw.TextAlign.right),
            dataCell(rate > 0 ? money(rate) : '-', align: pw.TextAlign.right),
            dataCell(
              money(total),
              align: pw.TextAlign.right,
              style:
                  pw.TextStyle(fontSize: 8.2, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ));
      }
      // Total manoperă
      rows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          dataCell('', align: pw.TextAlign.center),
          dataCell(
            'TOTAL MANOPERĂ',
            style: pw.TextStyle(fontSize: 8.4, fontWeight: pw.FontWeight.bold),
          ),
          dataCell(''),
          dataCell(''),
          dataCell(''),
          dataCell(
            money(laborTotal),
            align: pw.TextAlign.right,
            style: pw.TextStyle(fontSize: 8.4, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ));
      return rows;
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(24, 18, 24, 18),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox.shrink()
          : pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.only(bottom: 6),
              decoration: const pw.BoxDecoration(
                border:
                    pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    p.branding.companyName,
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Situație lucrări nr. ${p.number}  |  Pagina ${context.pageNumber}',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
      footer: (context) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.only(top: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Document generat automat | ${p.branding.companyName}',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            ),
            pw.Text(
              'Pagina ${context.pageNumber} din ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            ),
          ],
        ),
      ),
      build: (context) => [
        // ---- HEADER COMPANIE ----
        buildClassicDocumentHeader(
          branding: p.branding,
          documentTitle: 'SITUAȚIE DE LUCRĂRI',
          documentSubtitle: 'Nr. ${p.number} din data $dateStr',
          template: p.template,
          metadata: [
            MapEntry('Lucrare', '${p.jobCode} - ${p.jobTitle}'),
            MapEntry('Beneficiar / Client', p.clientName),
            if (p.contractNumber.trim().isNotEmpty)
              MapEntry('Contract',
                  '${p.contractNumber}${p.contractDate.trim().isNotEmpty ? " din ${p.contractDate.trim()}" : ""}'),
            if (p.location.trim().isNotEmpty) MapEntry('Locație', p.location),
            if (p.periodStart.trim().isNotEmpty ||
                p.periodEnd.trim().isNotEmpty)
              MapEntry('Perioadă de execuție',
                  '${p.periodStart.trim().isNotEmpty ? p.periodStart.trim() : "-"} – ${p.periodEnd.trim().isNotEmpty ? p.periodEnd.trim() : "-"}'),
          ],
        ),
        pw.SizedBox(height: 12),

        // ---- INFORMAȚII GENERALE ----
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: palette.surface,
            border: pw.Border.all(color: palette.border),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Antreprenor / Executant',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: palette.primary,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    infoRow('Denumire', p.branding.companyName),
                    if (p.branding.cui.isNotEmpty)
                      infoRow('CUI', p.branding.cui),
                    if (p.branding.tradeRegister.isNotEmpty)
                      infoRow('Reg. Com.', p.branding.tradeRegister),
                    if (p.branding.address.isNotEmpty)
                      infoRow('Adresă', p.branding.address),
                    if (p.branding.bank.isNotEmpty)
                      infoRow('Bancă', p.branding.bank),
                    if (p.branding.iban.isNotEmpty)
                      infoRow('IBAN', p.branding.iban),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Beneficiar',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: palette.primary,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    infoRow('Denumire', p.clientName),
                    infoRow('Locație lucrare', p.location),
                    if (p.contractNumber.trim().isNotEmpty)
                      infoRow('Nr. contract', p.contractNumber),
                    if (p.contractDate.trim().isNotEmpty)
                      infoRow('Dată contract', p.contractDate),
                    if (p.periodStart.trim().isNotEmpty)
                      infoRow('Început execuție', p.periodStart),
                    if (p.periodEnd.trim().isNotEmpty)
                      infoRow('Sfârșit execuție', p.periodEnd),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),

        // ---- MATERIALE ----
        if (p.materials.isNotEmpty) ...[
          sectionHeader('I. MATERIALE UTILIZATE'),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: palette.border, width: 0.6),
            columnWidths: const {
              0: pw.FixedColumnWidth(28),
              1: pw.FlexColumnWidth(4.0),
              2: pw.FixedColumnWidth(38),
              3: pw.FixedColumnWidth(56),
              4: pw.FixedColumnWidth(68),
              5: pw.FixedColumnWidth(72),
            },
            children: buildMaterialRows(),
          ),
          pw.SizedBox(height: 12),
        ],

        // ---- MANOPERA ----
        if (p.laborEntries.isNotEmpty) ...[
          sectionHeader('II. MANOPERĂ / FORȚĂ DE MUNCĂ'),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: palette.border, width: 0.6),
            columnWidths: const {
              0: pw.FixedColumnWidth(28),
              1: pw.FlexColumnWidth(4.0),
              2: pw.FixedColumnWidth(38),
              3: pw.FixedColumnWidth(56),
              4: pw.FixedColumnWidth(68),
              5: pw.FixedColumnWidth(72),
            },
            children: buildLaborRows(),
          ),
          pw.SizedBox(height: 12),
        ],

        // ---- CENTRALIZATOR VALORIC ----
        sectionHeader('III. CENTRALIZATOR VALORIC'),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Spacer(),
            pw.Container(
              width: 300,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: palette.surface,
                border: pw.Border.all(color: palette.border),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (p.materials.isNotEmpty)
                    summaryRow('Total materiale', '${money(matTotal)} lei'),
                  if (p.laborEntries.isNotEmpty)
                    summaryRow('Total manoperă', '${money(laborTotal)} lei'),
                  pw.Divider(color: PdfColors.grey400, height: 12),
                  summaryRow('Total fără TVA', '${money(subtotal)} lei'),
                  summaryRow(
                    'TVA ${p.vatPercent.toStringAsFixed(0)}%',
                    '${money(vatValue)} lei',
                  ),
                  pw.Divider(color: PdfColors.grey400, height: 12),
                  summaryRow(
                    'TOTAL CU TVA',
                    '${money(totalWithVat)} lei',
                    emphasize: true,
                  ),
                ],
              ),
            ),
          ],
        ),

        // ---- OBSERVAȚII ----
        if (p.notes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 12),
          sectionHeader('IV. OBSERVAȚII'),
          pw.SizedBox(height: 6),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: palette.border),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              p.notes.trim(),
              style: const pw.TextStyle(fontSize: 8.8),
            ),
          ),
        ],

        // ---- SEMNĂTURI ----
        pw.SizedBox(height: 20),
        sectionHeader('V. SEMNĂTURI ȘI CONFIRMARE'),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: palette.border),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ANTREPRENOR / EXECUTANT',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: palette.primary,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      p.branding.companyName,
                      style: const pw.TextStyle(fontSize: 8.8),
                    ),
                    if (p.branding.contactName.trim().isNotEmpty)
                      pw.Text(
                        'Responsabil: ${p.branding.contactName.trim()}',
                        style: const pw.TextStyle(fontSize: 8.8),
                      ),
                    pw.SizedBox(height: 40),
                    pw.Container(
                      height: 0.6,
                      color: PdfColors.grey600,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Data: ___________    Semnătură și ștampilă',
                      style:
                          pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: palette.border),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BENEFICIAR',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: palette.primary,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      p.clientName.isEmpty ? '_______________' : p.clientName,
                      style: const pw.TextStyle(fontSize: 8.8),
                    ),
                    pw.SizedBox(height: 40),
                    pw.Container(
                      height: 0.6,
                      color: PdfColors.grey600,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Data: ___________    Semnătură și ștampilă',
                      style:
                          pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ));

    return doc.save();
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse('$v'.replaceAll(',', '.')) ?? 0;
  }

  static String _str(dynamic v) => (v ?? '').toString().trim();
}
