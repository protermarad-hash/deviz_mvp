import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/company_profile.dart';
import '../../core/pdf/pdf_font_helper.dart';
import 'complaint_models.dart';

/// Generează PDF ofertă rapidă per reclamație.
class ComplaintQuickOfferPdfService {
  const ComplaintQuickOfferPdfService._();

  static final _fmt = NumberFormat('#,##0.00', 'ro_RO');
  static final _fmtDate = DateFormat('dd.MM.yyyy');

  static Future<String> export({
    required ComplaintRecord complaint,
    required List<ComplaintOfferLine> linii,
    required double tvaPercent,
    String nota = '',
    CompanyProfile? companyProfile,
    bool forColaborator = false,
  }) async {
    await PdfFontHelper.initialize();

    final bold = PdfFontHelper.bold;
    final regular = PdfFontHelper.regular;

    final doc = pw.Document(theme: PdfFontHelper.theme);
    final now = DateTime.now();

    // Culori brand
    const red = PdfColor(0.7765, 0.1569, 0.1569); // #C62828
    const lightGray = PdfColor(0.96, 0.96, 0.96);
    const darkText = PdfColor(0.13, 0.13, 0.13);

    final totalFaraTva = linii.fold(0.0, (s, l) => s + l.total);
    final totalTva = totalFaraTva * tvaPercent / 100;
    final totalCuTva = totalFaraTva + totalTva;

    final destinatar = forColaborator
        ? complaint.colaboratorNume
        : complaint.beneficiaryName;
    final titluDoc = forColaborator ? 'OFERTĂ COLABORATOR' : 'OFERTĂ';
    final refRecl = complaint.complaintNumber;
    final refCollab = complaint.colaboratorRefNumber;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          // ── Header ────────────────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      companyProfile?.companyName ?? 'PRO TERM SRL',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 16,
                        color: red,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'CUI: ${companyProfile?.cui ?? ""} | '
                      '${companyProfile?.address ?? ""} | '
                      '${companyProfile?.phone ?? ""}',
                      style: pw.TextStyle(font: regular, fontSize: 8, color: darkText),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    titluDoc,
                    style: pw.TextStyle(font: bold, fontSize: 18, color: red),
                  ),
                  pw.Text(
                    'Nr. reclamație: $refRecl',
                    style: pw.TextStyle(font: regular, fontSize: 9, color: darkText),
                  ),
                  if (refCollab.isNotEmpty)
                    pw.Text(
                      'Ref. colaborator: $refCollab',
                      style: pw.TextStyle(font: regular, fontSize: 9, color: darkText),
                    ),
                  pw.Text(
                    'Data: ${_fmtDate.format(now)}',
                    style: pw.TextStyle(font: regular, fontSize: 9, color: darkText),
                  ),
                ],
              ),
            ],
          ),
          pw.Divider(color: red, thickness: 1.5),
          pw.SizedBox(height: 8),

          // ── Destinatar ────────────────────────────────────────────────────
          if (destinatar.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: lightGray,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('DESTINATAR:',
                      style: pw.TextStyle(font: bold, fontSize: 9, color: red)),
                  pw.SizedBox(height: 4),
                  pw.Text(destinatar,
                      style: pw.TextStyle(font: bold, fontSize: 11, color: darkText)),
                  if (complaint.location.isNotEmpty)
                    pw.Text(complaint.location,
                        style: pw.TextStyle(font: regular, fontSize: 9, color: darkText)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
          ],

          // ── Echipament ────────────────────────────────────────────────────
          if (complaint.equipmentBrand.isNotEmpty || complaint.equipmentModel.isNotEmpty) ...[
            pw.Text('Echipament:',
                style: pw.TextStyle(font: bold, fontSize: 10, color: darkText)),
            pw.Text(
              '${complaint.equipmentBrand} ${complaint.equipmentModel}'.trim(),
              style: pw.TextStyle(font: regular, fontSize: 10, color: darkText),
            ),
            pw.SizedBox(height: 10),
          ],

          // ── Tabel linii ───────────────────────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(color: lightGray, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1.5),
              4: pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: red),
                children: [
                  _cell('Denumire', bold, 9, isHeader: true),
                  _cell('UM', bold, 9, isHeader: true),
                  _cell('Cant.', bold, 9, isHeader: true, align: pw.Alignment.centerRight),
                  _cell('Preț/UM (RON)', bold, 9, isHeader: true, align: pw.Alignment.centerRight),
                  _cell('Total (RON)', bold, 9, isHeader: true, align: pw.Alignment.centerRight),
                ],
              ),
              // Linii
              for (final (i, line) in linii.indexed)
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i.isEven ? PdfColors.white : lightGray,
                  ),
                  children: [
                    _cell(line.denumire, regular, 9),
                    _cell(line.um, regular, 9),
                    _cell(line.cantitate.toStringAsFixed(line.cantitate == line.cantitate.roundToDouble() ? 0 : 2),
                        regular, 9, align: pw.Alignment.centerRight),
                    _cell(_fmt.format(line.pretUnitar), regular, 9, align: pw.Alignment.centerRight),
                    _cell(_fmt.format(line.total), regular, 9, align: pw.Alignment.centerRight),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 8),

          // ── Total ─────────────────────────────────────────────────────────
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 200,
              child: pw.Column(
                children: [
                  _totalRow('Total fără TVA:', _fmt.format(totalFaraTva), regular, 10, darkText),
                  _totalRow('TVA ${tvaPercent.toStringAsFixed(0)}%:', _fmt.format(totalTva), regular, 10, darkText),
                  pw.Divider(color: red, thickness: 0.5),
                  _totalRow('TOTAL:', '${_fmt.format(totalCuTva)} RON', bold, 12, red),
                ],
              ),
            ),
          ),

          // ── Notă ──────────────────────────────────────────────────────────
          if (nota.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Condiții și note:',
                style: pw.TextStyle(font: bold, fontSize: 10, color: darkText)),
            pw.Text(nota, style: pw.TextStyle(font: regular, fontSize: 9, color: darkText)),
          ],

          if (forColaborator) ...[
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: red, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                'DOCUMENT INTERN — numai pentru uz administrativ intern',
                style: pw.TextStyle(font: bold, fontSize: 9, color: red),
              ),
            ),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    final tmpDir = await getTemporaryDirectory();
    final numarSafe = complaint.complaintNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final suffix = forColaborator ? '_colaborator' : '_client';
    final fileName = 'oferta_$numarSafe$suffix.pdf';
    final file = File('${tmpDir.path}/$fileName');
    await file.writeAsBytes(Uint8List.fromList(bytes));
    return file.path;
  }

  static pw.Widget _cell(
    String text,
    pw.Font font,
    double fontSize, {
    bool isHeader = false,
    pw.Alignment align = pw.Alignment.centerLeft,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Align(
          alignment: align,
          child: pw.Text(
            text,
            style: pw.TextStyle(
              font: font,
              fontSize: fontSize,
              color: isHeader ? PdfColors.white : const PdfColor(0.13, 0.13, 0.13),
            ),
          ),
        ),
      );

  static pw.Widget _totalRow(
    String label,
    String value,
    pw.Font font,
    double fontSize,
    PdfColor color,
  ) =>
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: fontSize, color: color)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: fontSize, color: color)),
        ],
      );
}
