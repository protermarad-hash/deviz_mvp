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

/// Aruncată de `PontajFisaPdfService.export()` când numărul total de rânduri
/// (propriu + partener) depășește `PontajFisaPdfService.maxTotalRows` — mesaj
/// clar către utilizator în loc de generare foarte lentă/blocantă (vezi
/// comentariul de la `maxTotalRows`).
class PontajFisaTooManyRowsException implements Exception {
  const PontajFisaTooManyRowsException(this.rowCount, this.limit);

  final int rowCount;
  final int limit;

  @override
  String toString() =>
      'Perioada selectată conține prea multe înregistrări ($rowCount) pentru '
      'un singur PDF (limită: $limit). Restrânge perioada sau generează fișa '
      'per lucrare / pentru o singură persoană.';
}

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

  /// Plasă de siguranță: peste acest număr TOTAL de rânduri (propriu +
  /// partener), generarea se oprește cu mesaj clar în loc să continue.
  /// Ales conservator sub pragul măsurat real (`test/pontaj_fisa_pdf_perf_test.dart`):
  /// 500 rânduri s-au generat corect în 3.5s; 1000 rânduri au depășit
  /// `maxPages` (vezi mai jos). 600 lasă marjă confortabilă pentru fișele
  /// reale (multi-săptămână/multi-lucrare), fără riscul de generare foarte
  /// lentă/blocantă pe volume neașteptat de mari.
  static const int maxTotalRows = 600;

  /// `pw.MultiPage.maxPages` — cap intern de siguranță al pachetului `pdf`
  /// (implicit 20, verificat DOAR prin `assert()`, deci activ în debug/test,
  /// dar NU în build-uri release — acolo generarea peste 20 pagini pentru
  /// ACELAȘI widget de nivel superior continuă, doar foarte lent, ceea ce se
  /// manifestă ca blocaj vizual, nu ca eroare). Ridicat aici la o valoare
  /// generoasă, cu MULTĂ marjă peste `maxTotalRows` de mai sus (confirmat
  /// empiric: 500 rânduri nu au avut nevoie de 20 pagini), ca plasă de
  /// siguranță suplimentară — comportament identic (eroare curată, nu
  /// blocaj tăcut) și în debug, și în release.
  static const int _multiPageMaxPages = 200;

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
    final totalRows = ownRows.length + partnerRows.length;
    if (totalRows > maxTotalRows) {
      throw PontajFisaTooManyRowsException(totalRows, maxTotalRows);
    }

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

    // Titlu de secțiune, ca widget INDEPENDENT (nu în același Container ca
    // tabelul) — vezi `_buildPaginatedTable` mai jos pentru motiv.
    pw.Widget buildSectionTitle(String title) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: ProTermPdfTemplate.primaryRed,
            ),
          ),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        maxPages: _multiPageMaxPages,
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
          buildSectionTitle('Personal propriu (${ownRows.length})'),
          if (ownRows.isEmpty)
            buildEmpty('Nicio înregistrare de manoperă proprie în perioada selectată.')
          else
            _buildPaginatedTable(
              headers: headers(isPartner: false),
              rows: ownRows.map((r) => rowCells(r, isPartner: false)).toList(growable: false),
            ),
          if (ownRows.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            _buildSectionTotal('Total personal propriu', '${_money(ownTotal)} $currency'),
          ],
          pw.SizedBox(height: 12),
          buildSectionTitle('Personal partener (${partnerRows.length})'),
          if (partnerRows.isEmpty)
            buildEmpty('Nicio înregistrare de personal partener în perioada selectată.')
          else
            _buildPaginatedTable(
              headers: headers(isPartner: true),
              rows: partnerRows.map((r) => rowCells(r, isPartner: true)).toList(growable: false),
            ),
          if (partnerRows.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            _buildSectionTotal('Total personal partener', '${_money(partnerTotal)} $currency'),
          ],
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

  /// Tabel PAGINABIL pentru volume mari de rânduri (fișă cross-lucrare /
  /// toți partenerii — poate acumula sute de rânduri din tot istoricul de
  /// lucrări). Spre deosebire de `ProTermPdfTemplate.buildTable()`
  /// (`pw.Container(child: pw.Column(...))`, un SINGUR widget monolitic,
  /// NEsplitabil pe pagini de `pw.MultiPage`), aici se folosește
  /// `pw.TableHelper.fromTextArray()`, care întoarce un `pw.Table` — singurul
  /// widget din pachetul `pdf` (^3.11/^3.12) care implementează splitare
  /// nativă între pagini (antet repetat automat, `TableRow(repeat: true)`
  /// intern la `headers`). Returnat NEÎNFĂȘURAT într-un `Container`/`Column`
  /// suplimentar (spre deosebire de `buildSection()`), ca `pw.MultiPage` să
  /// primească direct widget-ul splitabil — un `Container` peste el ar putea
  /// anula splitarea.
  ///
  /// Confirmat prin test de performanță cu date sintetice
  /// (`test/pontaj_fisa_pdf_perf_test.dart`): varianta veche
  /// (`ProTermPdfTemplate.buildTable`) arunca `TooManyPagesException` încă de
  /// la 20 de rânduri; această variantă generează corect PDF-ul până la
  /// 2000+ rânduri.
  static pw.Widget _buildPaginatedTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: ProTermPdfTemplate.borderGray, width: 0.5),
      headerDecoration: const pw.BoxDecoration(color: ProTermPdfTemplate.primaryRed),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        color: ProTermPdfTemplate.headerText,
      ),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      cellStyle: const pw.TextStyle(fontSize: 9, color: ProTermPdfTemplate.darkText),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      oddRowDecoration: pw.BoxDecoration(color: ProTermPdfTemplate.altRow),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  /// Bara de total per secțiune — widget mic, INDEPENDENT de tabel (nu mai
  /// face parte din `buildTable`), ca să nu reintroducă un widget monolitic
  /// mare; un singur rând nu are niciodată problema de paginare de mai sus.
  static pw.Widget _buildSectionTotal(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: pw.BoxDecoration(
        color: ProTermPdfTemplate.lightRed,
        border: pw.Border(top: pw.BorderSide(color: ProTermPdfTemplate.primaryRed, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: ProTermPdfTemplate.primaryRed,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: ProTermPdfTemplate.primaryRed,
            ),
          ),
        ],
      ),
    );
  }
}
