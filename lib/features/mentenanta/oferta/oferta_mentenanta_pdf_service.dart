import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/company_profile.dart';
import '../../../core/pdf/pdf_font_helper.dart';
import '../../../core/pdf_export_settings.dart';
import '../../../core/pdf_save_service.dart';
import '../../../core/repositories/app_data_repository.dart';
import '../mentenanta_models.dart';

/// Generează PDF-ul ofertei tabelare de service & mentenanță.
///
/// Tabel grupat pe categorii (header + subtotal per categorie), total general,
/// TVA 21% și total cu TVA. Stil consistent cu documentele PV/PIF.
class OfertaMentenantaPdfService {
  const OfertaMentenantaPdfService._();

  // Brand PRO TERM SRL.
  static const PdfColor _primaryRed = PdfColor(0.7765, 0.1569, 0.1569);
  static const PdfColor _lightRed = PdfColor(1.0, 0.9216, 0.9333);
  static const PdfColor _lightGray = PdfColor(0.9608, 0.9608, 0.9608);
  static const PdfColor _grey = PdfColor.fromInt(0xFF757575);
  static const PdfColor _white = PdfColors.white;
  static const PdfColor _black = PdfColors.black;

  static Future<String> export({
    required AppDataRepository repository,
    required ContractMentenanta contract,
    bool forceSaveAs = false,
    String outputDirectory = '',
  }) async {
    await PdfFontHelper.initialize();

    CompanyProfile profile;
    try {
      profile = await repository.loadCompanyProfile();
    } catch (_) {
      profile = const CompanyProfile();
    }

    final doc = pw.Document(theme: PdfFontHelper.theme);
    final fmt = NumberFormat('#,##0.00', 'ro_RO');
    final dateFmt = DateFormat('dd.MM.yyyy');
    final regular = PdfFontHelper.regular;
    final bold = PdfFontHelper.bold;

    pw.TextStyle ts({double size = 8, PdfColor color = _black, bool b = false}) =>
        pw.TextStyle(font: b ? bold : regular, fontSize: size, color: color);

    // ── Header firmă ─────────────────────────────────────────────
    pw.Widget buildHeader() {
      final lines = <String>[];
      if (profile.address.isNotEmpty) lines.add(profile.address);
      final loc = [profile.city, profile.county]
          .where((s) => s.isNotEmpty)
          .join(', ');
      if (loc.isNotEmpty) lines.add(loc);
      if (profile.cui.isNotEmpty) lines.add('CUI: ${profile.cui}');
      if (profile.phone.isNotEmpty) lines.add('Tel: ${profile.phone}');

      return pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(
              bottom: pw.BorderSide(color: _primaryRed, width: 2)),
        ),
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                      profile.companyName.isEmpty
                          ? 'PRO TERM SRL'
                          : profile.companyName,
                      style: ts(size: 13, color: _primaryRed, b: true)),
                  ...lines.map((l) => pw.Text(l, style: ts(size: 8, color: _grey))),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('SITUAȚIE SERVICII SERVICE ȘI MENTENANȚĂ',
                    style: ts(size: 11, color: _primaryRed, b: true)),
                if (contract.numar.isNotEmpty)
                  pw.Text('Nr. ${contract.numar}',
                      style: ts(size: 10, b: true)),
                pw.Text('Data: ${dateFmt.format(DateTime.now())}',
                    style: ts(size: 8)),
              ],
            ),
          ],
        ),
      );
    }

    // ── Subtitlu ─────────────────────────────────────────────────
    pw.Widget buildSubtitle() {
      final interv = contract.interventiiPlanificate;
      final intervLabel =
          interv == 1 ? '1 intervenție/an' : '$interv intervenții/an';
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 8, bottom: 6),
        padding: const pw.EdgeInsets.all(6),
        color: _lightRed,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
                'Contract anual – Igienizare + Revizie tehnică ($intervLabel) | '
                'Echipamente climatizare & ventilație',
                style: ts(size: 9, b: true)),
            if (contract.clientName.isNotEmpty)
              pw.Text('Beneficiar: ${contract.clientName}',
                  style: ts(size: 9)),
            pw.Text(
                'Perioadă: ${dateFmt.format(contract.dataStart)} – '
                '${dateFmt.format(contract.dataEnd)}',
                style: ts(size: 8, color: _grey)),
          ],
        ),
      );
    }

    // ── Tabel principal ──────────────────────────────────────────
    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(0.5), // Nr
      1: const pw.FlexColumnWidth(2.2), // Tip
      2: const pw.FlexColumnWidth(2.4), // Model
      3: const pw.FlexColumnWidth(0.6), // UM
      4: const pw.FlexColumnWidth(0.7), // Cant
      5: const pw.FlexColumnWidth(1.1), // Igienizare
      6: const pw.FlexColumnWidth(1.1), // Revizie
      7: const pw.FlexColumnWidth(1.1), // Total unit
      8: const pw.FlexColumnWidth(1.2), // Valoare
      9: const pw.FlexColumnWidth(1.6), // Observatii
    };

    pw.Widget cell(String text,
        {pw.TextStyle? style, pw.Alignment align = pw.Alignment.centerLeft, PdfColor? bg}) {
      return pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        alignment: align,
        child: pw.Text(text, style: style ?? ts()),
      );
    }

    pw.TableRow headerRow() {
      pw.Widget h(String t, {pw.Alignment a = pw.Alignment.center}) =>
          cell(t, style: ts(size: 7.5, color: _white, b: true), align: a, bg: _primaryRed);
      return pw.TableRow(children: [
        h('Nr'),
        h('Tip echipament', a: pw.Alignment.centerLeft),
        h('Model / Descriere', a: pw.Alignment.centerLeft),
        h('UM'),
        h('Cant'),
        h('Preț unit.\nIgienizare'),
        h('Preț unit.\nRevizie teh.'),
        h('Preț unit.\nTOTAL'),
        h('Valoare\nTOTAL'),
        h('Observații', a: pw.Alignment.centerLeft),
      ]);
    }

    pw.TableRow categoryRow(CategorieMentenanta cat) {
      return pw.TableRow(
        decoration: const pw.BoxDecoration(color: _lightGray),
        children: [
          cell('── SISTEM ${cat.label.toUpperCase()} ──',
              style: ts(size: 8, b: true, color: _primaryRed),
              bg: _lightGray),
          for (var i = 0; i < 9; i++) cell('', bg: _lightGray),
        ],
      );
    }

    pw.TableRow dataRow(EchipamentMentenanta e) {
      final r = ts(size: 7.5);
      return pw.TableRow(children: [
        cell('${e.nrCrt}', style: r, align: pw.Alignment.center),
        cell(e.tipEchipament, style: r),
        cell(e.model, style: r),
        cell(e.um, style: r, align: pw.Alignment.center),
        cell(fmt.format(e.cantitate), style: r, align: pw.Alignment.center),
        cell(fmt.format(e.pretIgienizare), style: r, align: pw.Alignment.centerRight),
        cell(fmt.format(e.pretRevizie), style: r, align: pw.Alignment.centerRight),
        cell(fmt.format(e.pretTotal), style: r, align: pw.Alignment.centerRight),
        cell(fmt.format(e.valoareTotala),
            style: ts(size: 7.5, b: true), align: pw.Alignment.centerRight),
        cell(e.necesitaLogFGas
            ? (e.observatii.isEmpty ? 'Log F-Gas' : '${e.observatii} • Log F-Gas')
            : e.observatii,
            style: r),
      ]);
    }

    pw.TableRow subtotalRow(CategorieMentenanta cat, double subtotal) {
      return pw.TableRow(
        decoration: const pw.BoxDecoration(color: _lightRed),
        children: [
          cell('', bg: _lightRed),
          cell('Subtotal ${cat.label}',
              style: ts(size: 7.5, b: true), bg: _lightRed),
          for (var i = 0; i < 6; i++) cell('', bg: _lightRed),
          cell(fmt.format(subtotal),
              style: ts(size: 7.5, b: true),
              align: pw.Alignment.centerRight, bg: _lightRed),
          cell('', bg: _lightRed),
        ],
      );
    }

    pw.Widget buildTable() {
      final rows = <pw.TableRow>[headerRow()];
      final grupate = contract.echipamenteGrupate;
      grupate.forEach((cat, items) {
        rows.add(categoryRow(cat));
        for (final e in items) {
          rows.add(dataRow(e));
        }
        final subtotal =
            items.fold<double>(0, (s, e) => s + e.valoareTotala);
        rows.add(subtotalRow(cat, subtotal));
      });
      return pw.Table(
        columnWidths: colWidths,
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        children: rows,
      );
    }

    // ── Totaluri ─────────────────────────────────────────────────
    pw.Widget buildTotals() {
      pw.Widget line(String label, String value, {bool big = false}) {
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(color: big ? _primaryRed : null),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: ts(
                      size: big ? 11 : 9,
                      b: true,
                      color: big ? _white : _black)),
              pw.Text(value,
                  style: ts(
                      size: big ? 11 : 9,
                      b: true,
                      color: big ? _white : _black)),
            ],
          ),
        );
      }

      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        alignment: pw.Alignment.centerRight,
        child: pw.SizedBox(
          width: 260,
          child: pw.Column(children: [
            line('Total fără TVA',
                '${fmt.format(contract.totalFaraTVA)} RON'),
            line('TVA 21%', '${fmt.format(contract.tva)} RON'),
            line('TOTAL CU TVA', '${fmt.format(contract.totalCuTVA)} RON',
                big: true),
          ]),
        ),
      );
    }

    // ── Notă F-Gas ───────────────────────────────────────────────
    pw.Widget buildNote() {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Notă:', style: ts(size: 8, b: true)),
            pw.Text(
                'Echipamentele marcate „Log F-Gas" conțin agent frigorific peste '
                'pragul de raportare și necesită completarea registrului F-Gas '
                '(verificări periodice de etanșeitate, conform Reg. UE 517/2014).',
                style: ts(size: 7.5, color: _grey)),
            if (contract.observatii.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text('Observații contract: ${contract.observatii}',
                  style: ts(size: 7.5, color: _grey)),
            ],
          ],
        ),
      );
    }

    // ── Asamblare ────────────────────────────────────────────────
    final docTitle =
        'Ofertă mentenanță ${contract.numar.isEmpty ? '' : contract.numar}'.trim();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(docTitle, style: ts(size: 7, color: _grey))),
        footer: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(docTitle, style: ts(size: 7, color: _grey)),
              pw.Text('Pagina ${ctx.pageNumber} din ${ctx.pagesCount}',
                  style: ts(size: 7, color: _grey)),
              pw.Text(dateFmt.format(DateTime.now()),
                  style: ts(size: 7, color: _grey)),
            ],
          ),
        ),
        build: (ctx) => [
          buildHeader(),
          buildSubtitle(),
          buildTable(),
          buildTotals(),
          buildNote(),
        ],
      ),
    );

    final bytes = await doc.save();
    final numarSafe = contract.numar.isEmpty
        ? 'CM'
        : contract.numar.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    // Timestamp anti-cache (evită cache viewer Windows) — ca la PV/PIF.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'Oferta_Mentenanta_${numarSafe}_$stamp.pdf';

    return PdfSaveService.savePdf(
      repository: repository,
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
      category: PdfDocumentCategory.offers,
      outputDirectory: outputDirectory,
      forceSaveAs: forceSaveAs,
    );
  }
}
