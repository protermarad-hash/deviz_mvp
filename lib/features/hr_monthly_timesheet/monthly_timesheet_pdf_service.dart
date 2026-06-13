import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/pdf/pdf_font_helper.dart';
import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'monthly_timesheet_models.dart';

class MonthlyTimesheetPdfService {
  const MonthlyTimesheetPdfService._();

  // A4 landscape 8mm margini — toate zilele pe o singură pagină
  static const _pageFormat = PdfPageFormat(
    297 * PdfPageFormat.mm,
    210 * PdfPageFormat.mm,
    marginAll: 8 * PdfPageFormat.mm,
  );

  static Future<String> export({
    required AppDataRepository repository,
    required MonthlyTimesheetRecord record,
    String outputDirectory = '',
    bool saveAs = false,
  }) async {
    await PdfFontHelper.initialize();
    final doc = pw.Document(theme: PdfFontHelper.theme);
    final companyProfile = await repository.loadCompanyProfile();
    final branding = DocumentBrandingData.fromCompanyProfile(companyProfile);
    final generatedAt = DateTime.now();
    final days = List<int>.generate(record.daysInMonth, (i) => i + 1);

    String monthLabel() =>
        '${record.month.toString().padLeft(2, '0')}.${record.year}';

    String dateLabel(DateTime v) {
      final d = v.day.toString().padLeft(2, '0');
      final m = v.month.toString().padLeft(2, '0');
      return '$d.$m.${v.year}';
    }

    String textOrDash(String v) {
      final t = v.trim();
      return t.isEmpty ? '-' : t;
    }

    String money(double v) => v.toStringAsFixed(2);

    // ── Header-uri coloane ────────────────────────────────────────────────────
    final headers = <String>[
      'Angajat',
      'Echipă',
      'TM',
      'TM/zi',
      ...days.map((d) => d.toString()),
      'Ore',
      ...MonthlyTimesheetCodeOption.defaults.map((o) => o.code),
    ];

    // ── Rânduri date ──────────────────────────────────────────────────────────
    final dataRows = record.rows.map((row) {
      final eligibleDays = _eligibleDays(record, row);
      final tmPerDay = (row.mealTicketBudgetRon > 0 && eligibleDays > 0)
          ? row.mealTicketBudgetRon / eligibleDays
          : 0.0;
      return <String>[
        textOrDash(row.employeeName),
        textOrDash(row.teamName),
        money(row.mealTicketBudgetRon),
        money(tmPerDay),
        ...days.map((day) => textOrDash(row.dayValues['$day'] ?? '')),
        row.totalWorkedHours.toStringAsFixed(0),
        ...MonthlyTimesheetCodeOption.defaults
            .map((opt) => row.countCode(opt.code).toString()),
      ];
    }).toList(growable: false);

    // ── Rând totale ───────────────────────────────────────────────────────────
    final totalRow = <String>[
      'TOTAL',
      '',
      money(record.rows.fold<double>(0, (s, r) => s + r.mealTicketBudgetRon)),
      '',
      ...days.map((_) => ''),
      record.totalWorkedHours.toStringAsFixed(0),
      ...MonthlyTimesheetCodeOption.defaults
          .map((opt) => record.totalCodeCount(opt.code).toString()),
    ];

    final allRows = [...dataRows, totalRow];
    final totalRowIndex = allRows.length - 1;

    // ── Lățimi coloane (pt) ───────────────────────────────────────────────────
    // Angajat=79, Echipă=40, TM=34, TM/zi=28, zile=13×31=403, Ore=23, 8×coduri=14×8=112
    // Total=719pt < 796pt (281mm × 2.835) ✓
    final int dayStart = 4;
    final int oreIndex = dayStart + days.length;
    final int codesStart = oreIndex + 1;

    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(79),
      1: const pw.FixedColumnWidth(40),
      2: const pw.FixedColumnWidth(34),
      3: const pw.FixedColumnWidth(28),
      for (var i = dayStart; i < oreIndex; i++)
        i: const pw.FixedColumnWidth(13),
      oreIndex: const pw.FixedColumnWidth(23),
      for (var i = codesStart; i < codesStart + 8; i++)
        i: const pw.FixedColumnWidth(14),
    };

    doc.addPage(
      pw.Page(
        pageFormat: _pageFormat,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Antet compact ────────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.5),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    branding.companyName,
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'PONTAJ LUNAR TABELAR — ${monthLabel()}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Angajați: ${record.rows.length}  |  '
                    'Total ore: ${record.totalWorkedHours.toStringAsFixed(0)}  |  '
                    'Generat: ${dateLabel(generatedAt)}',
                    style: const pw.TextStyle(fontSize: 6),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            if (dataRows.isEmpty)
              pw.Expanded(
                child: pw.Center(
                  child: pw.Text(
                    'Nu există rânduri de pontaj pentru luna selectată.',
                  ),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.3,
                ),
                headerStyle: pw.TextStyle(
                  fontSize: 5.5,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 5.0),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellDecoration: (index, data, rowNum) {
                  if (rowNum == totalRowIndex) {
                    return const pw.BoxDecoration(color: PdfColors.grey200);
                  }
                  if (rowNum % 2 == 1) {
                    return const pw.BoxDecoration(color: PdfColors.grey100);
                  }
                  return const pw.BoxDecoration();
                },
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 1,
                  vertical: 1.5,
                ),
                cellAlignment: pw.Alignment.center,
                cellAlignments: const {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                },
                headers: headers,
                data: allRows,
                columnWidths: columnWidths,
              ),
          ],
        ),
      ),
    );

    final fileName =
        'pontaj_lunar_${record.year}_${record.month.toString().padLeft(2, '0')}.pdf';
    return PdfSaveService.savePdf(
      repository: repository,
      bytes: await doc.save(),
      fileName: fileName,
      category: PdfDocumentCategory.attendanceReports,
      outputDirectory: outputDirectory,
      forceSaveAs: saveAs,
    );
  }

  static int _eligibleDays(
    MonthlyTimesheetRecord record,
    MonthlyTimesheetEmployeeRow row,
  ) {
    var count = 0;
    for (var day = 1; day <= record.daysInMonth; day++) {
      if (_isWeekend(record.year, record.month, day)) continue;
      final value = row.dayValues['$day'] ?? '';
      if (MonthlyTimesheetValueParser.hoursFromValue(value) > 0) count++;
    }
    return count;
  }

  static bool _isWeekend(int year, int month, int day) {
    final date = DateTime(year, month, day);
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }
}
