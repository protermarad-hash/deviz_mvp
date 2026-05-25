import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/company_profile.dart';
import '../../core/pdf/pdf_font_helper.dart';
import 'deviz_filtre_cta_models.dart';

/// Serviciu generare PDF pentru Deviz Filtre CTA.
class FiltreCtaPdfService {
  FiltreCtaPdfService._();

  static final _fmtEur = NumberFormat('#,##0.00', 'ro_RO');
  static String _eur(double v) => '${_fmtEur.format(v)} EUR';

  static Future<String> generate({
    required DevizFiltreCta deviz,
    required CompanyProfile company,
  }) async {
    await PdfFontHelper.initialize();
    final doc = pw.Document(theme: PdfFontHelper.theme);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        header: (ctx) => _buildHeader(company, deviz),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Pagina ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(font: PdfFontHelper.regular, fontSize: 7),
          ),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 8),
          _buildTable(deviz),
          pw.SizedBox(height: 12),
          _buildTotaluri(deviz),
          pw.SizedBox(height: 16),
          _buildSemnatura(deviz, company),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = deviz.titluDeviz
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(' ', '_');
    final nr = deviz.numar.isNotEmpty
        ? deviz.numar
        : '${DateTime.now().millisecondsSinceEpoch}';
    final file = File(
        '${dir.path}${Platform.pathSeparator}DevizFiltreCTA_${nr}_$safeTitle.pdf');
    await file.writeAsBytes(await doc.save());
    return file.path;
  }

  // ── Header ───────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(CompanyProfile company, DevizFiltreCta deviz) {
    const baseColor = PdfColor.fromInt(0xFF1565C0);
    final name = company.companyName.trim().isNotEmpty
        ? company.companyName
        : 'S.C. PRO TERM S.R.L.';
    final cui = company.cui.trim().isNotEmpty ? company.cui : 'RO11355602';
    final reg = company.tradeRegister.trim().isNotEmpty
        ? company.tradeRegister
        : 'J02/999/2003';
    final adr = company.address.trim().isNotEmpty
        ? company.address
        : 'ARAD, STR. A. SAGUNA NR. 34';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(name,
                    style: pw.TextStyle(
                        font: PdfFontHelper.bold, fontSize: 12, color: baseColor)),
                pw.Text('CUI: $cui  |  Reg. Com.: $reg',
                    style: pw.TextStyle(font: PdfFontHelper.regular, fontSize: 8)),
                pw.Text('Adresa: $adr',
                    style: pw.TextStyle(font: PdfFontHelper.regular, fontSize: 8)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (deviz.numar.trim().isNotEmpty)
                  pw.Text('Nr: ${deviz.numar}',
                      style: pw.TextStyle(
                          font: PdfFontHelper.bold, fontSize: 9, color: baseColor)),
                pw.Text(
                    'Data: ${DateFormat('dd.MM.yyyy').format(deviz.dataEmitere)}',
                    style: pw.TextStyle(font: PdfFontHelper.regular, fontSize: 8)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: pw.BoxDecoration(
            color: baseColor,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(
            deviz.titluDeviz.trim().isNotEmpty
                ? deviz.titluDeviz.trim()
                : 'Deviz inlocuire filtre CTA-uri',
            style: pw.TextStyle(
                font: PdfFontHelper.bold, fontSize: 9, color: PdfColors.white),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 4),
      ],
    );
  }

  // ── Tabel ────────────────────────────────────────────────────────────────

  static pw.Widget _buildTable(DevizFiltreCta deviz) {
    const baseColor = PdfColor.fromInt(0xFF1565C0);
    const zoneBg = PdfColor.fromInt(0xFFBBDEFB);
    const rowAlt = PdfColor.fromInt(0xFFF5F9FF);
    const subtotalBg = PdfColor.fromInt(0xFFE8F5E9);

    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(28),
      1: const pw.FlexColumnWidth(3.0),
      2: const pw.FlexColumnWidth(2.2),
      3: const pw.FixedColumnWidth(78),
      4: const pw.FlexColumnWidth(4.0),
      5: const pw.FixedColumnWidth(72),
    };

    final rows = <pw.TableRow>[];

    // Header row
    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: baseColor),
      children: [
        _hc('NR.\nCRT.'),
        _hc('C.T.A.'),
        _hc('SERIA'),
        _hc('POZITIE'),
        _hc('MARIMI FILTRE'),
        _hc('PRET/SCHIMB\n[EUR] manopera'),
      ],
    ));

    ZonaCta? lastZona;
    int zonaIdx = 0;

    for (final cta in deviz.ctas) {
      // Separator zona
      if (lastZona != cta.zona) {
        lastZona = cta.zona;
        zonaIdx = 0;
        rows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: zoneBg),
          children: [
            pw.SizedBox(height: 16),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
              child: pw.Text(
                cta.zona.label.toUpperCase(),
                style: pw.TextStyle(font: PdfFontHelper.bold, fontSize: 7.5),
              ),
            ),
            pw.SizedBox(), pw.SizedBox(), pw.SizedBox(), pw.SizedBox(),
          ],
        ));
      }
      zonaIdx++;

      final PdfColor rowBg =
          zonaIdx.isOdd ? PdfColors.white : rowAlt;

      for (int fi = 0; fi < cta.filtre.length; fi++) {
        final f = cta.filtre[fi];
        final isFirst = fi == 0;

        rows.add(pw.TableRow(
          decoration: pw.BoxDecoration(color: rowBg),
          children: [
            isFirst
                ? _dc('${cta.nrCrt}', bold: true, center: true)
                : _dc(''),
            isFirst
                ? pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(cta.denumireCta,
                            style: pw.TextStyle(
                                font: PdfFontHelper.bold, fontSize: 7)),
                        if (cta.locatie.isNotEmpty)
                          pw.Text(cta.locatie,
                              style: pw.TextStyle(
                                  font: PdfFontHelper.italic,
                                  fontSize: 6.5,
                                  color: PdfColors.grey700)),
                      ],
                    ),
                  )
                : _dc(''),
            isFirst ? _dc(cta.serie, sz: 6.5) : _dc(''),
            _dc(f.pozitie),
            _dc(f.marimi.join('\n'), sz: 6.5),
            f.pret > 0
                ? _dc(_eur(f.pret), bold: true, center: true)
                : _dc('-', center: true),
          ],
        ));
      }

      // Subtotal CTA (daca are multiple filtre cu pret)
      if (cta.filtre.length > 1 && cta.totalPret > 0) {
        rows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: subtotalBg),
          children: [
            _dc(''), _dc(''), _dc(''), _dc(''),
            pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text(
                'Total CTA ${cta.nrCrt}:',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    font: PdfFontHelper.bold,
                    fontSize: 7,
                    color: PdfColor.fromInt(0xFF1B5E20)),
              ),
            ),
            _dc(_eur(cta.totalPret), bold: true, center: true),
          ],
        ));
      }
    }

    return pw.Table(
      columnWidths: colWidths,
      border: pw.TableBorder(
        horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: 0.4),
        verticalInside: const pw.BorderSide(color: PdfColors.grey400, width: 0.4),
        left: const pw.BorderSide(color: PdfColors.grey500, width: 0.5),
        right: const pw.BorderSide(color: PdfColors.grey500, width: 0.5),
        top: const pw.BorderSide(color: PdfColors.grey500, width: 0.5),
        bottom: const pw.BorderSide(color: PdfColors.grey500, width: 0.5),
      ),
      children: rows,
    );
  }

  // ── Totaluri ─────────────────────────────────────────────────────────────

  static pw.Widget _buildTotaluri(DevizFiltreCta deviz) {
    const totalBg = PdfColor.fromInt(0xFF1565C0);

    final zones = <Map<String, dynamic>>[
      {'label': ZonaCta.turnatorii.label, 'val': deviz.totalTurnatorii},
      {'label': ZonaCta.spumatorie.label, 'val': deviz.totalSpumatorie},
      {'label': ZonaCta.cusatorii.label, 'val': deviz.totalCusatorii},
      {'label': ZonaCta.logistica.label, 'val': deviz.totalLogistica},
      {'label': ZonaCta.altele.label, 'val': deviz.totalAltele},
    ].where((z) => (z['val'] as double) > 0).toList();

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 310,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            children: [
              for (final z in zones)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.4),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total ${z['label']}:',
                          style: pw.TextStyle(
                              font: PdfFontHelper.bold, fontSize: 8)),
                      pw.Text(_eur(z['val'] as double),
                          style: pw.TextStyle(
                              font: PdfFontHelper.bold, fontSize: 8)),
                    ],
                  ),
                ),
              pw.Container(
                decoration: const pw.BoxDecoration(color: totalBg),
                padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL GENERAL:',
                        style: pw.TextStyle(
                            font: PdfFontHelper.bold,
                            fontSize: 10,
                            color: PdfColors.white)),
                    pw.Text(_eur(deviz.totalGeneral),
                        style: pw.TextStyle(
                            font: PdfFontHelper.bold,
                            fontSize: 10,
                            color: PdfColors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Semnatura ────────────────────────────────────────────────────────────

  static pw.Widget _buildSemnatura(DevizFiltreCta deviz, CompanyProfile company) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Intocmit:',
                style: pw.TextStyle(font: PdfFontHelper.bold, fontSize: 8)),
            pw.SizedBox(height: 2),
            pw.Text(
              deviz.intocmitDe.trim().isNotEmpty
                  ? deviz.intocmitDe.trim()
                  : company.companyName.trim(),
              style: pw.TextStyle(font: PdfFontHelper.regular, fontSize: 8),
            ),
            pw.SizedBox(height: 14),
            pw.Container(width: 120, height: 0.5, color: PdfColors.grey700),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Beneficiar:',
                style: pw.TextStyle(font: PdfFontHelper.bold, fontSize: 8)),
            pw.SizedBox(height: 2),
            pw.Text(
              deviz.clientName.trim().isNotEmpty
                  ? deviz.clientName.trim()
                  : '_______________________',
              style: pw.TextStyle(font: PdfFontHelper.regular, fontSize: 8),
            ),
            pw.SizedBox(height: 14),
            pw.Container(width: 120, height: 0.5, color: PdfColors.grey700),
          ],
        ),
      ],
    );
  }

  // ── Celule helper ─────────────────────────────────────────────────────────

  static pw.Widget _hc(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(3),
        child: pw.Text(text,
            style: pw.TextStyle(
                font: PdfFontHelper.bold, fontSize: 7, color: PdfColors.white),
            textAlign: pw.TextAlign.center),
      );

  static pw.Widget _dc(
    String text, {
    bool bold = false,
    bool center = false,
    double sz = 7,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(3),
        child: pw.Text(text,
            style: pw.TextStyle(
              font: bold ? PdfFontHelper.bold : PdfFontHelper.regular,
              fontSize: sz,
            ),
            textAlign: center ? pw.TextAlign.center : pw.TextAlign.left),
      );
}
