import '../../core/pdf/pdf_font_helper.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'hr_payroll_accounting_report_models.dart';
import 'hr_payroll_payment_models.dart';

class HrPayrollAccountingReportPdfService {
  const HrPayrollAccountingReportPdfService._();

  static Future<String> export({
    required AppDataRepository repository,
    required HrPayrollAccountingReport report,
    Map<String, List<HrPayrollPayment>> paymentsByEmployee = const {},
    String generatedByLabel = '',
    String outputDirectory = '',
  }) async {
    await PdfFontHelper.initialize();
    final doc = pw.Document(theme: PdfFontHelper.theme);

    String textOrDash(String value) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? '-' : trimmed;
    }

    String dateTimeLabel(DateTime? value) {
      if (value == null) return '-';
      final d = value.day.toString().padLeft(2, '0');
      final m = value.month.toString().padLeft(2, '0');
      final y = value.year.toString().padLeft(4, '0');
      final hh = value.hour.toString().padLeft(2, '0');
      final mm = value.minute.toString().padLeft(2, '0');
      return '$d.$m.$y $hh:$mm';
    }

    String monthLabel(DateTime value) =>
        '${value.month.toString().padLeft(2, '0')}.${value.year.toString().padLeft(4, '0')}';

    String money(dynamic raw) {
      final value = raw is num
          ? raw.toDouble()
          : double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
      return value.toStringAsFixed(2);
    }

    // ── Calcule plăți per angajat ─────────────────────────────────────────────
    final luna = report.payrollMonth;

    double avansForEmployee(String employeeId) {
      final plati = paymentsByEmployee[employeeId.trim()] ?? const [];
      return plati
          .where((p) =>
              p.payrollMonth.year == luna.year &&
              p.payrollMonth.month == luna.month &&
              p.paymentType == 'avans')
          .fold(0.0, (s, p) => s + p.amount);
    }

    double salariuForEmployee(String employeeId) {
      final plati = paymentsByEmployee[employeeId.trim()] ?? const [];
      return plati
          .where((p) =>
              p.payrollMonth.year == luna.year &&
              p.payrollMonth.month == luna.month &&
              p.paymentType == 'salariu')
          .fold(0.0, (s, p) => s + p.amount);
    }

    double popririlePlatiteForEmployee(String employeeId) {
      final plati = paymentsByEmployee[employeeId.trim()] ?? const [];
      return plati
          .where((p) =>
              p.payrollMonth.year == luna.year &&
              p.payrollMonth.month == luna.month &&
              p.paymentType == 'poprire')
          .fold(0.0, (s, p) => s + p.amount);
    }

    // ── Totale plăți ──────────────────────────────────────────────────────────
    var totalAvans = 0.0;
    var totalSalariu = 0.0;
    var totalPopririlePlatite = 0.0;
    for (final item in report.lineItems) {
      final eid = (item['employee_id'] ?? '').toString();
      totalAvans += avansForEmployee(eid);
      totalSalariu += salariuForEmployee(eid);
      totalPopririlePlatite += popririlePlatiteForEmployee(eid);
    }

    double sumTotals(String key) {
      final v = report.totals[key];
      return v is num ? v.toDouble() : 0.0;
    }

    final totalNetFinal = sumTotals('net_final');
    final totalRest = (totalNetFinal - totalAvans - totalSalariu)
        .clamp(0.0, double.infinity);
    final totalPopRetinute = sumTotals('garnishment_reserved_total');
    final totalPopRest =
        (totalPopRetinute - totalPopririlePlatite).clamp(0.0, double.infinity);

    // ── Page setup: A4 landscape, 8mm margini ────────────────────────────────
    // Utilizabil: 297-16=281mm
    // Coloane (mm): Angajat=28, Functie=20, Ore=7, Brut=13, CAS=11, CASS=11,
    //   Impozit=11, Ded.pers=10, Tichete=11, Net/TM=12, NET FINAL=12,
    //   Avans=11, S.plătit=11, Rest=12, Pop.ret=11, Pop.pl=10, Status=10
    // Total = 28+20+7+13+11+11+11+10+11+12+12+11+11+12+11+10+10 = 222mm ✓
    const pageFormat = PdfPageFormat(
      297 * PdfPageFormat.mm,
      210 * PdfPageFormat.mm,
      marginAll: 8 * PdfPageFormat.mm,
    );

    // factor pt → mm: 1pt ≈ 0.353mm, deci 1mm ≈ 2.8346pt
    const double mm = PdfPageFormat.mm;

    pw.Widget infoLine(String label, String value,
        {bool bold = false, PdfColor? color}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 145,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  fontSize: 7,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  fontSize: 7,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        build: (_) => [
          // ── Header ──────────────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Centralizator salarizare — contabilitate',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Luna: ${monthLabel(report.payrollMonth)}  |  '
                    'Angajați: ${report.employeeCount}  |  '
                    '${report.currency}',
                    style: const pw.TextStyle(fontSize: 6.5),
                  ),
                  pw.Text(
                    'Generat: ${dateTimeLabel(report.generatedAt)}'
                    '${generatedByLabel.isNotEmpty ? "  de $generatedByLabel" : ""}',
                    style: const pw.TextStyle(fontSize: 6.5),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),

          // ── Tabel principal ──────────────────────────────────────────────────
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6),
            cellStyle: const pw.TextStyle(fontSize: 6.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            oddRowDecoration:
                const pw.BoxDecoration(color: PdfColors.grey100),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 2,
              vertical: 1.5,
            ),
            headers: const [
              'Angajat',
              'Funcție',
              'Ore',
              'Brut',
              'CAS',
              'CASS',
              'Impozit',
              'Ded.pers.',
              'Tichete',
              'Net/TM',
              'NET FINAL',
              'Avans',
              'S.plătit',
              'Rest',
              'Pop.ret.',
              'Pop.pl.',
              'Status',
            ],
            columnWidths: <int, pw.TableColumnWidth>{
              0: pw.FixedColumnWidth(28 * mm),
              1: pw.FixedColumnWidth(20 * mm),
              2: pw.FixedColumnWidth(7 * mm),
              3: pw.FixedColumnWidth(13 * mm),
              4: pw.FixedColumnWidth(11 * mm),
              5: pw.FixedColumnWidth(11 * mm),
              6: pw.FixedColumnWidth(11 * mm),
              7: pw.FixedColumnWidth(10 * mm),
              8: pw.FixedColumnWidth(11 * mm),
              9: pw.FixedColumnWidth(12 * mm),
              10: pw.FixedColumnWidth(12 * mm),
              11: pw.FixedColumnWidth(11 * mm),
              12: pw.FixedColumnWidth(11 * mm),
              13: pw.FixedColumnWidth(12 * mm),
              14: pw.FixedColumnWidth(11 * mm),
              15: pw.FixedColumnWidth(10 * mm),
              16: pw.FixedColumnWidth(10 * mm),
            },
            headerAlignments: <int, pw.Alignment>{
              for (var i = 0; i <= 16; i++)
                i: i < 2 ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
              16: pw.Alignment.centerLeft,
            },
            cellAlignments: <int, pw.Alignment>{
              for (var i = 0; i <= 16; i++)
                i: i < 2 ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
              16: pw.Alignment.centerLeft,
            },
            data: report.lineItems.map((item) {
              final eid = (item['employee_id'] ?? '').toString();
              final netF = (item['net_final'] is num)
                  ? (item['net_final'] as num).toDouble()
                  : 0.0;
              final avans = avansForEmployee(eid);
              final sal = salariuForEmployee(eid);
              final popPl = popririlePlatiteForEmployee(eid);
              final garnRet = (item['garnishment_reserved_total'] is num)
                  ? (item['garnishment_reserved_total'] as num).toDouble()
                  : 0.0;
              final rest = (netF - avans - sal).clamp(0.0, double.infinity);
              final statusLabel = rest < 0.01 ? 'Achitat ✓' : 'Rest: ${rest.toStringAsFixed(0)}';

              return [
                textOrDash((item['employee_name'] ?? '').toString()),
                textOrDash((item['job_title'] ?? '').toString()),
                money(item['worked_hours']),
                money(item['gross_total']),
                money(item['cas_amount']),
                money(item['cass_amount']),
                money(item['income_tax_amount']),
                money(item['personal_deduction_amount']),
                money(item['meal_ticket_total']),
                money(item['net_without_tm']),
                money(item['net_final']),
                money(avans),
                money(sal),
                money(rest),
                money(garnRet),
                money(popPl),
                statusLabel,
              ];
            }).toList(growable: false),
          ),

          // ── Rând totale ──────────────────────────────────────────────────────
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6),
            cellStyle: pw.TextStyle(
              fontSize: 6.5,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey400),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 2,
              vertical: 1.5,
            ),
            headers: const [''],
            columnWidths: <int, pw.TableColumnWidth>{
              0: const pw.FlexColumnWidth(),
            },
            data: const [
              [''],
            ],
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: <int, pw.TableColumnWidth>{
              0: pw.FixedColumnWidth(28 * mm),
              1: pw.FixedColumnWidth(20 * mm),
              2: pw.FixedColumnWidth(7 * mm),
              3: pw.FixedColumnWidth(13 * mm),
              4: pw.FixedColumnWidth(11 * mm),
              5: pw.FixedColumnWidth(11 * mm),
              6: pw.FixedColumnWidth(11 * mm),
              7: pw.FixedColumnWidth(10 * mm),
              8: pw.FixedColumnWidth(11 * mm),
              9: pw.FixedColumnWidth(12 * mm),
              10: pw.FixedColumnWidth(12 * mm),
              11: pw.FixedColumnWidth(11 * mm),
              12: pw.FixedColumnWidth(11 * mm),
              13: pw.FixedColumnWidth(12 * mm),
              14: pw.FixedColumnWidth(11 * mm),
              15: pw.FixedColumnWidth(10 * mm),
              16: pw.FixedColumnWidth(10 * mm),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _totCell('TOTAL', mm, bold: true, left: true),
                  _totCell('', mm, bold: true, left: true),
                  _totCell('', mm, bold: true),
                  _totCell(money(sumTotals('gross_total')), mm, bold: true),
                  _totCell(money(sumTotals('cas_amount')), mm, bold: true),
                  _totCell(money(sumTotals('cass_amount')), mm, bold: true),
                  _totCell(money(sumTotals('income_tax_amount')), mm, bold: true),
                  _totCell('', mm, bold: true),
                  _totCell(money(sumTotals('meal_ticket_total')), mm, bold: true),
                  _totCell(money(sumTotals('net_without_tm')), mm, bold: true),
                  _totCell(money(totalNetFinal), mm, bold: true),
                  _totCell(money(totalAvans), mm, bold: true),
                  _totCell(money(totalSalariu), mm, bold: true),
                  _totCell(money(totalRest), mm,
                      bold: true,
                      color: totalRest > 0.01 ? PdfColors.red700 : PdfColors.green700),
                  _totCell(money(totalPopRetinute), mm, bold: true),
                  _totCell(money(totalPopririlePlatite), mm, bold: true),
                  _totCell('', mm, bold: true, left: true),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 10),

          // ── Sumar financiar ──────────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Sumar salarizare',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      infoLine(
                        'Total fond salarii brut:',
                        '${money(sumTotals('gross_total'))} ${report.currency}',
                      ),
                      infoLine(
                        'Total CAS (25%):',
                        '${money(sumTotals('cas_amount'))} ${report.currency}',
                      ),
                      infoLine(
                        'Total CASS (10%):',
                        '${money(sumTotals('cass_amount'))} ${report.currency}',
                      ),
                      infoLine(
                        'Total impozit (10%):',
                        '${money(sumTotals('income_tax_amount'))} ${report.currency}',
                      ),
                      infoLine(
                        'Total tichete de masă:',
                        '${money(sumTotals('meal_ticket_total'))} ${report.currency}',
                      ),
                      infoLine(
                        'Total rețineri:',
                        '${money(sumTotals('deduction_total'))} ${report.currency}',
                      ),
                      pw.Divider(color: PdfColors.grey400),
                      infoLine(
                        'Total net fără TM:',
                        '${money(sumTotals('net_without_tm'))} ${report.currency}',
                      ),
                      infoLine(
                        'TOTAL NET DE PLATĂ:',
                        '${money(totalNetFinal)} ${report.currency}',
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Situație plăți',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      infoLine(
                        'Total avansuri plătite:',
                        '${money(totalAvans)} ${report.currency}',
                      ),
                      infoLine(
                        'Total salarii plătite:',
                        '${money(totalSalariu)} ${report.currency}',
                      ),
                      pw.Divider(color: PdfColors.grey400),
                      infoLine(
                        'TOTAL REST DE PLATĂ:',
                        '${money(totalRest)} ${report.currency}',
                        bold: true,
                        color: totalRest > 0.01
                            ? PdfColors.red700
                            : PdfColors.green700,
                      ),
                      pw.Divider(color: PdfColors.grey400),
                      infoLine(
                        'Total popriri reținute:',
                        '${money(totalPopRetinute)} ${report.currency}',
                      ),
                      infoLine(
                        'Total popriri plătite:',
                        '${money(totalPopririlePlatite)} ${report.currency}',
                      ),
                      infoLine(
                        'Popriri rest de plătit:',
                        '${money(totalPopRest)} ${report.currency}',
                        bold: totalPopRest > 0.01,
                        color: totalPopRest > 0.01
                            ? PdfColors.red700
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 12),

          // ── Bloc semnături ───────────────────────────────────────────────────
          pw.Row(
            children: [
              _sigBox('Întocmit de', 70 * mm),
              pw.SizedBox(width: 4 * mm),
              _sigBox('Verificat de', 70 * mm),
              pw.SizedBox(width: 4 * mm),
              _sigBox('Aprobat de', 70 * mm),
              pw.SizedBox(width: 4 * mm),
              _sigBox('Semnătură', 70 * mm),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final fileName = _fileName(report.payrollMonth);
    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: fileName,
      category: PdfDocumentCategory.hrAccountingReports,
      outputDirectory: outputDirectory,
    );
  }

  static pw.Widget _totCell(
    String text,
    double mm, {
    bool bold = false,
    bool left = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 6.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
        textAlign: left ? pw.TextAlign.left : pw.TextAlign.right,
      ),
    );
  }

  static pw.Widget _sigBox(String label, double width) {
    return pw.SizedBox(
      width: width,
      height: 36,
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(2),
        ),
        padding: const pw.EdgeInsets.all(4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 6)),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey400),
          ],
        ),
      ),
    );
  }

  static String _fileName(DateTime payrollMonth) {
    final monthKey =
        '${payrollMonth.year.toString().padLeft(4, '0')}-${payrollMonth.month.toString().padLeft(2, '0')}';
    return 'centralizator_payroll_contabilitate_$monthKey.pdf';
  }
}
