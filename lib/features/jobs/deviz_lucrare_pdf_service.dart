import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/pdf_document_branding.dart';
import '../../core/pdf_font_bundle.dart';
import 'job_models.dart';

/// Generează PDF deviz planificat sau situație de lucrări dintr-un JobRecord.
class DevizLucrarePdfService {
  DevizLucrarePdfService._();
  static final instance = DevizLucrarePdfService._();

  static final _fmtNum = NumberFormat('#,##0.00', 'ro_RO');
  static final _fmtDate = DateFormat('dd.MM.yyyy');

  // Culori brand
  static const _red = PdfColor(0.7765, 0.1569, 0.1569);
  static const _lightGray = PdfColor(0.96, 0.96, 0.96);
  static const _darkText = PdfColor(0.13, 0.13, 0.13);
  static const _green = PdfColor(0.18, 0.55, 0.34);
  static const _orange = PdfColor(0.85, 0.45, 0.10);

  // ── DEVIZ PLANIFICAT ───────────────────────────────────────────────────────

  Future<String> generateDevizPlanificat(
    JobRecord job,
    DocumentBrandingData branding,
  ) async {
    final fonts = await PdfFontBundle.load();
    final doc = pw.Document(theme: fonts.theme);
    final now = DateTime.now();

    final grouped = _groupLinii(job.liniiPlanificate);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15 * PdfPageFormat.mm),
        build: (ctx) => [
          _buildHeader(branding, fonts, 'DEVIZ DE LUCRĂRI', job, now),
          pw.SizedBox(height: 12),
          _buildSubtitle(fonts, job),
          pw.SizedBox(height: 12),
          if (job.liniiPlanificate.isEmpty)
            pw.Center(
              child: pw.Text('Nu există articole în deviz.',
                  style: pw.TextStyle(
                      font: fonts.base, fontSize: 10, color: _darkText)),
            )
          else ...[
            for (final cat in _categoriiOrdine)
              if (grouped[cat]?.isNotEmpty == true) ...[
                _buildCategorySection(cat, grouped[cat]!, fonts,
                    useReala: false),
                pw.SizedBox(height: 6),
              ],
            _buildTotalSection(
              job.liniiPlanificate,
              fonts,
              useReala: false,
              regiePercent: job.regiePercent,
              profitPercent: job.profitPercent,
              vatPercent: job.vatPercent,
            ),
          ],
          pw.SizedBox(height: 16),
          _buildNoteSection(fonts),
          pw.SizedBox(height: 20),
          _buildSemnaturi(fonts, branding),
        ],
      ),
    );

    return _saveDoc(doc, 'deviz_planificat_${_safe(job.jobCode)}');
  }

  // ── SITUAȚIE DE LUCRĂRI ────────────────────────────────────────────────────

  Future<String> generateSituatieLucrari(
    JobRecord job,
    DocumentBrandingData branding,
  ) async {
    final fonts = await PdfFontBundle.load();
    final doc = pw.Document(theme: fonts.theme);
    final now = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15 * PdfPageFormat.mm),
        build: (ctx) => [
          _buildHeader(
              branding, fonts, 'SITUAȚIE DE LUCRĂRI', job, now),
          pw.SizedBox(height: 12),
          _buildSubtitle(fonts, job),
          pw.SizedBox(height: 12),
          if (job.liniiPlanificate.isEmpty)
            pw.Center(
              child: pw.Text(
                'Nu există articole (deviz planificat necompletat).',
                style: pw.TextStyle(
                    font: fonts.base, fontSize: 10, color: _darkText),
              ),
            )
          else ...[
            _buildTabelComparativ(job.liniiPlanificate, fonts),
            pw.SizedBox(height: 12),
            _buildSumarSituatie(job, fonts),
          ],
          pw.SizedBox(height: 20),
          _buildAvizare(fonts, branding),
        ],
      ),
    );

    return _saveDoc(doc, 'situatie_lucrari_${_safe(job.jobCode)}');
  }

  // ── WIDGET-URI COMUNE ──────────────────────────────────────────────────────

  pw.Widget _buildHeader(
    DocumentBrandingData branding,
    PdfFontBundle fonts,
    String titluDoc,
    JobRecord job,
    DateTime now,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                branding.companyName,
                style: pw.TextStyle(
                    font: fonts.bold, fontSize: 14, color: _red),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'CUI: ${branding.cui}  |  Reg. Com.: ${branding.tradeRegister}',
                style:
                    pw.TextStyle(font: fonts.base, fontSize: 8, color: _darkText),
              ),
              pw.Text(
                branding.fullAddress,
                style:
                    pw.TextStyle(font: fonts.base, fontSize: 8, color: _darkText),
              ),
              pw.Text(
                'Tel: ${branding.phone}  |  ${branding.email}',
                style:
                    pw.TextStyle(font: fonts.base, fontSize: 8, color: _darkText),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              titluDoc,
              style: pw.TextStyle(
                  font: fonts.bold, fontSize: 16, color: _red),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Nr. ${job.jobCode}',
              style: pw.TextStyle(
                  font: fonts.bold, fontSize: 11, color: _darkText),
            ),
            pw.Text(
              'Data: ${_fmtDate.format(DateTime.now())}',
              style:
                  pw.TextStyle(font: fonts.base, fontSize: 9, color: _darkText),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSubtitle(PdfFontBundle fonts, JobRecord job) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _lightGray,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (job.title.isNotEmpty)
            _kv('Lucrare', job.title, fonts),
          if (job.location.isNotEmpty)
            _kv('Obiectiv', job.location, fonts),
          if (job.clientId.isNotEmpty)
            _kv('Client', job.title.isNotEmpty ? '' : job.clientId, fonts),
          if (job.sourceOfferNumber.isNotEmpty)
            _kv('Ref. ofertă', job.sourceOfferNumber, fonts),
        ],
      ),
    );
  }

  pw.Widget _kv(String label, String value, PdfFontBundle fonts) {
    if (value.isEmpty) return pw.SizedBox.shrink();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(children: [
        pw.SizedBox(
          width: 80,
          child: pw.Text(
            '$label:',
            style:
                pw.TextStyle(font: fonts.bold, fontSize: 9, color: _darkText),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style:
                pw.TextStyle(font: fonts.base, fontSize: 9, color: _darkText),
          ),
        ),
      ]),
    );
  }

  pw.Widget _buildCategorySection(
    String categorie,
    List<JobLine> linii,
    PdfFontBundle fonts, {
    required bool useReala,
  }) {
    final label = _catLabel(categorie).toUpperCase();
    final catTotal = linii.fold(
        0.0,
        (s, l) => s +
            (useReala
                ? l.cantitateReala * l.pretUnitarReal
                : l.cantitateOferta * l.pretUnitarOferta));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          color: _red,
          child: pw.Text(
            label,
            style: pw.TextStyle(
                font: fonts.bold, fontSize: 9, color: PdfColors.white),
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: _lightGray, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(22),
            1: pw.FlexColumnWidth(4),
            2: pw.FixedColumnWidth(28),
            3: pw.FixedColumnWidth(40),
            4: pw.FixedColumnWidth(55),
            5: pw.FixedColumnWidth(55),
          },
          children: [
            _tableHeaderRow(fonts),
            ...linii.asMap().entries.map((e) {
              final l = e.value;
              final cant = useReala ? l.cantitateReala : l.cantitateOferta;
              final pret = useReala ? l.pretUnitarReal : l.pretUnitarOferta;
              final val = cant * pret;
              return pw.TableRow(
                children: [
                  _cell('${e.key + 1}', fonts.base, 8, align: pw.Alignment.center),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(l.denumire,
                            style: pw.TextStyle(font: fonts.base, fontSize: 8, color: _darkText)),
                        if (l.observatii.isNotEmpty)
                          pw.Text(l.observatii,
                              style: pw.TextStyle(
                                  font: fonts.base,
                                  fontSize: 7,
                                  color: const PdfColor(0.4, 0.4, 0.4),
                                  fontStyle: pw.FontStyle.italic)),
                      ],
                    ),
                  ),
                  _cell(l.um, fonts.base, 8, align: pw.Alignment.center),
                  _cell(
                    cant.toStringAsFixed(cant == cant.roundToDouble() ? 0 : 2),
                    fonts.base, 8, align: pw.Alignment.centerRight,
                  ),
                  _cell(_fmtNum.format(pret), fonts.base, 8, align: pw.Alignment.centerRight),
                  _cell(_fmtNum.format(val), fonts.base, 8, align: pw.Alignment.centerRight),
                ],
              );
            }),
            _tableTotalRow(catTotal, fonts),
          ],
        ),
      ],
    );
  }

  pw.TableRow _tableHeaderRow(PdfFontBundle fonts) {
    const headers = [
      'Nr.',
      'Denumire',
      'UM',
      'Cantitate',
      'Preț/UM',
      'Valoare'
    ];
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _lightGray),
      children: headers
          .map((h) => _cell(h, fonts.bold, 8, align: pw.Alignment.center))
          .toList(),
    );
  }

  pw.TableRow _tableTotalRow(double total, PdfFontBundle fonts) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
          color: _lightGray),
      children: [
        _cell('', fonts.bold, 8),
        _cell('TOTAL CATEGORIE', fonts.bold, 8),
        _cell('', fonts.bold, 8),
        _cell('', fonts.bold, 8),
        _cell('', fonts.bold, 8),
        _cell(_fmtNum.format(total), fonts.bold, 9,
            align: pw.Alignment.centerRight),
      ],
    );
  }

  pw.Widget _cell(String text, pw.Font font, double size,
      {pw.Alignment align = pw.Alignment.centerLeft}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Align(
        alignment: align,
        child: pw.Text(text,
            style: pw.TextStyle(font: font, fontSize: size, color: _darkText)),
      ),
    );
  }

  pw.Widget _buildTotalSection(
    List<JobLine> linii,
    PdfFontBundle fonts, {
    required bool useReala,
    double regiePercent = 0,
    double profitPercent = 0,
    double vatPercent = 21,
  }) {
    final subtotalDirect = linii.fold(
        0.0,
        (s, l) => s +
            (useReala
                ? l.cantitateReala * l.pretUnitarReal
                : l.cantitateOferta * l.pretUnitarOferta));
    final regieValue = subtotalDirect * regiePercent / 100;
    final profitValue = subtotalDirect * profitPercent / 100;
    final totalFaraTva = _roundUpToTen(subtotalDirect + regieValue + profitValue);
    final tva = totalFaraTva * vatPercent / 100;
    final totalCuTva = _roundUpToTen(totalFaraTva + tva);

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        child: pw.Column(
          children: [
            pw.Divider(color: _red, thickness: 1),
            if (regiePercent > 0 || profitPercent > 0) ...[
              _totalRow(
                  'Subtotal direct:', _fmtNum.format(subtotalDirect), fonts),
              if (regiePercent > 0)
                _totalRow(
                    'Regie ${regiePercent.toStringAsFixed(1)}%:',
                    _fmtNum.format(regieValue),
                    fonts),
              if (profitPercent > 0)
                _totalRow(
                    'Profit ${profitPercent.toStringAsFixed(1)}%:',
                    _fmtNum.format(profitValue),
                    fonts),
              pw.Divider(color: _lightGray, thickness: 0.5),
            ],
            _totalRow('Total fără TVA:', _fmtNum.format(totalFaraTva), fonts),
            _totalRow(
                'TVA ${vatPercent.toStringAsFixed(0)}%:',
                _fmtNum.format(tva),
                fonts),
            pw.Divider(color: _red, thickness: 0.5),
            _totalRow(
              'TOTAL cu TVA:',
              '${_fmtNum.format(totalCuTva)} RON',
              fonts,
              bold: true,
              color: _red,
            ),
          ],
        ),
      ),
    );
  }

  static double _roundUpToTen(double v) {
    if (v <= 0) return v;
    return ((v / 10).ceil() * 10).toDouble();
  }

  pw.Widget _totalRow(String label, String value, PdfFontBundle fonts,
      {bool bold = false, PdfColor? color}) {
    final style = pw.TextStyle(
      font: bold ? fonts.bold : fonts.base,
      fontSize: bold ? 11 : 9,
      color: color ?? _darkText,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  pw.Widget _buildNoteSection(PdfFontBundle fonts) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _lightGray, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Condiții și observații:',
            style: pw.TextStyle(
                font: fonts.bold, fontSize: 9, color: _red),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Prețurile sunt orientative și pot varia în funcție de condițiile de teren.',
            style:
                pw.TextStyle(font: fonts.base, fontSize: 8, color: _darkText),
          ),
          pw.Text(
            'Valabilitate deviz: 30 zile de la data emiterii.',
            style:
                pw.TextStyle(font: fonts.base, fontSize: 8, color: _darkText),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSemnaturi(PdfFontBundle fonts, DocumentBrandingData branding) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _semnatura('Întocmit', branding.contactName, fonts),
        _semnatura('Verificat', '', fonts),
        _semnatura('Client', '', fonts),
      ],
    );
  }

  pw.Widget _buildAvizare(PdfFontBundle fonts, DocumentBrandingData branding) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _semnatura('Beneficiar', '', fonts, extraLine: 'Semnătură'),
        _semnatura('PRO TERM SRL', branding.contactName, fonts,
            extraLine: 'Semnătură'),
        _semnatura('Data recepție', '', fonts, extraLine: '____.____.______'),
      ],
    );
  }

  pw.Widget _semnatura(String titlu, String nume, PdfFontBundle fonts,
      {String? extraLine}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(titlu,
            style: pw.TextStyle(
                font: fonts.bold, fontSize: 9, color: _darkText)),
        pw.SizedBox(height: 4),
        if (extraLine != null)
          pw.Text(extraLine,
              style: pw.TextStyle(
                  font: fonts.base, fontSize: 8, color: _darkText)),
        pw.SizedBox(height: 20),
        pw.Container(
          width: 100,
          decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _darkText))),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          nume.isNotEmpty ? nume : '________________________',
          style:
              pw.TextStyle(font: fonts.base, fontSize: 8, color: _darkText),
        ),
      ],
    );
  }

  // ── TABEL COMPARATIV (pentru situație lucrări) ─────────────────────────────

  pw.Widget _buildTabelComparativ(List<JobLine> linii, PdfFontBundle fonts) {
    const headers = [
      'Nr.',
      'Denumire',
      'UM',
      'Cant.\nOfertă',
      'Preț\nOfertă',
      'Val.\nOfertă',
      'Cant.\nReal',
      'Preț\nReal',
      'Val.\nReal',
      'Diferență',
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _lightGray, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(18),
        1: pw.FlexColumnWidth(3),
        2: pw.FixedColumnWidth(22),
        3: pw.FixedColumnWidth(35),
        4: pw.FixedColumnWidth(42),
        5: pw.FixedColumnWidth(48),
        6: pw.FixedColumnWidth(35),
        7: pw.FixedColumnWidth(42),
        8: pw.FixedColumnWidth(48),
        9: pw.FixedColumnWidth(48),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _red),
          children: headers
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 3, vertical: 4),
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                          font: fonts.bold,
                          fontSize: 7,
                          color: PdfColors.white),
                      textAlign: pw.TextAlign.center,
                    ),
                  ))
              .toList(),
        ),
        // Linii
        ...linii.asMap().entries.map((entry) {
          final i = entry.key;
          final l = entry.value;
          final dif = l.diferenta;
          final difColor = dif == 0
              ? _darkText
              : (dif > 0 ? _orange : _green);

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color:
                  i.isEven ? PdfColors.white : const PdfColor(0.98, 0.98, 0.98),
            ),
            children: [
              _cell('${i + 1}', fonts.base, 7.5),
              _cell(l.denumire, fonts.base, 7.5),
              _cell(l.um, fonts.base, 7.5, align: pw.Alignment.center),
              _cell(
                l.cantitateOferta.toStringAsFixed(
                    l.cantitateOferta == l.cantitateOferta.roundToDouble() ? 0 : 2),
                fonts.base,
                7.5,
                align: pw.Alignment.centerRight,
              ),
              _cell(_fmtNum.format(l.pretUnitarOferta), fonts.base, 7.5,
                  align: pw.Alignment.centerRight),
              _cell(_fmtNum.format(l.totalOferta), fonts.base, 7.5,
                  align: pw.Alignment.centerRight),
              _cell(
                l.cantitateReala.toStringAsFixed(
                    l.cantitateReala == l.cantitateReala.roundToDouble() ? 0 : 2),
                fonts.base,
                7.5,
                align: pw.Alignment.centerRight,
              ),
              _cell(_fmtNum.format(l.pretUnitarReal), fonts.base, 7.5,
                  align: pw.Alignment.centerRight),
              _cell(_fmtNum.format(l.totalReal), fonts.base, 7.5,
                  align: pw.Alignment.centerRight),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 3, vertical: 3),
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    '${dif >= 0 ? '+' : ''}${_fmtNum.format(dif)}',
                    style: pw.TextStyle(
                        font: fonts.bold, fontSize: 7.5, color: difColor),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildSumarSituatie(JobRecord job, PdfFontBundle fonts) {
    // Calcul planificat (din ofertă, cu regie+profit înghețate)
    final directPlan = job.subtotalDirectPlanificat;
    final regiePlan = directPlan * job.regiePercent / 100;
    final profitPlan = directPlan * job.profitPercent / 100;
    final subtotalPlan = _roundUpToTen(directPlan + regiePlan + profitPlan);
    final tvaPlan = subtotalPlan * job.vatPercent / 100;
    final totalPlanCuTva = _roundUpToTen(subtotalPlan + tvaPlan);

    // Calcul realizat (cantitati reale × prețuri din ofertă, același regie/profit %)
    final directReal = job.subtotalDirectReal;
    final regieReal = directReal * job.regiePercent / 100;
    final profitReal = directReal * job.profitPercent / 100;
    final subtotalReal = _roundUpToTen(directReal + regieReal + profitReal);
    final tvaReal = subtotalReal * job.vatPercent / 100;
    final totalRealCuTva = _roundUpToTen(subtotalReal + tvaReal);

    // Diferența finală (cu TVA)
    final dif = totalRealCuTva - totalPlanCuTva;
    final procent = totalPlanCuTva > 0 ? (dif / totalPlanCuTva * 100) : 0.0;

    final hasRegieProfit = job.regiePercent > 0 || job.profitPercent > 0;

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 300,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _lightGray,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── PLANIFICAT (Ofertă) ──
            pw.Text(
              'PLANIFICAT (Ofertă)',
              style: pw.TextStyle(
                  font: fonts.bold, fontSize: 8, color: _darkText),
            ),
            pw.SizedBox(height: 3),
            if (hasRegieProfit) ...[
              _totalRow('Subtotal direct:', _fmtNum.format(directPlan), fonts),
              if (job.regiePercent > 0)
                _totalRow('Regie ${job.regiePercent.toStringAsFixed(1)}%:',
                    _fmtNum.format(regiePlan), fonts),
              if (job.profitPercent > 0)
                _totalRow('Profit ${job.profitPercent.toStringAsFixed(1)}%:',
                    _fmtNum.format(profitPlan), fonts),
            ],
            _totalRow('Total fără TVA:', _fmtNum.format(subtotalPlan), fonts),
            _totalRow(
                'TVA ${job.vatPercent.toStringAsFixed(0)}%:',
                _fmtNum.format(tvaPlan),
                fonts),
            _totalRow('TOTAL cu TVA:',
                '${_fmtNum.format(totalPlanCuTva)} RON', fonts,
                bold: true),
            pw.Divider(color: _darkText, thickness: 0.5),
            // ── REALIZAT ──
            pw.Text(
              'REALIZAT (Situație)',
              style: pw.TextStyle(
                  font: fonts.bold, fontSize: 8, color: _darkText),
            ),
            pw.SizedBox(height: 3),
            if (hasRegieProfit) ...[
              _totalRow('Subtotal direct:', _fmtNum.format(directReal), fonts),
              if (job.regiePercent > 0)
                _totalRow('Regie ${job.regiePercent.toStringAsFixed(1)}%:',
                    _fmtNum.format(regieReal), fonts),
              if (job.profitPercent > 0)
                _totalRow('Profit ${job.profitPercent.toStringAsFixed(1)}%:',
                    _fmtNum.format(profitReal), fonts),
            ],
            _totalRow('Total fără TVA:', _fmtNum.format(subtotalReal), fonts),
            _totalRow(
                'TVA ${job.vatPercent.toStringAsFixed(0)}%:',
                _fmtNum.format(tvaReal),
                fonts),
            _totalRow('TOTAL cu TVA:',
                '${_fmtNum.format(totalRealCuTva)} RON', fonts,
                bold: true),
            pw.Divider(color: _darkText, thickness: 0.5),
            // ── DIFERENȚĂ ──
            _totalRow(
              'Diferență (+/-):', '${dif >= 0 ? '+' : ''}${_fmtNum.format(dif)} RON',
              fonts,
              bold: true,
              color: dif >= 0 ? _orange : _green,
            ),
            _totalRow(
              dif >= 0 ? 'Depășire:' : 'Economie:',
              '${procent.abs().toStringAsFixed(1)}%',
              fonts,
              color: dif >= 0 ? _orange : _green,
            ),
          ],
        ),
      ),
    );
  }

  // ── UTILITARE ──────────────────────────────────────────────────────────────

  static const _categoriiOrdine = ['material', 'manopera', 'transport', 'altul'];

  Map<String, List<JobLine>> _groupLinii(List<JobLine> linii) {
    final map = <String, List<JobLine>>{};
    for (final l in linii) {
      final cat = l.categorie.isNotEmpty ? l.categorie : 'altul';
      map.putIfAbsent(cat, () => []).add(l);
    }
    return map;
  }

  String _catLabel(String cat) {
    switch (cat) {
      case 'material':   return 'Materiale';
      case 'manopera':   return 'Manoperă';
      case 'transport':  return 'Transport';
      default:           return 'Altele';
    }
  }

  String _safe(String s) =>
      s.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_').toLowerCase();

  Future<String> _saveDoc(pw.Document doc, String baseName) async {
    final bytes = Uint8List.fromList(await doc.save());
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/$baseName.pdf');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
