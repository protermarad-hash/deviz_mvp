import '../../core/pdf/pdf_font_helper.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../hr_variable_payroll/hr_variable_payroll_models.dart';
import 'hr_payroll_payment_models.dart';
import 'hr_payroll_run_models.dart';

// Layout compact pe o singură pagină A4 portrait
class HrPayslipPdfService {
  const HrPayslipPdfService._();

  static Future<String> export({
    required AppDataRepository repository,
    required HrPayslip payslip,
    String employeeName = '',
    String outputDirectory = '',
    bool saveAs = false,
    List<HrGarnishment> garnishments = const [],
    List<HrPayrollPayment> payments = const [],
  }) async {
    await PdfFontHelper.initialize();
    final doc = pw.Document(theme: PdfFontHelper.theme);
    final grossComponents = (payslip.breakdown['gross_components'] as Map?)
            ?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final contract =
        (payslip.breakdown['contract'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final mealTickets =
        (payslip.breakdown['meal_tickets'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final salaryTaxPct =
        (payslip.breakdown['salary_tax_percentages'] as Map?)
                ?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    String textOrDash(String value) {
      final t = value.trim();
      return t.isEmpty ? '-' : t;
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

    String dateLabel(DateTime v) {
      final d = v.day.toString().padLeft(2, '0');
      final m = v.month.toString().padLeft(2, '0');
      return '$d.$m.${v.year}';
    }

    String monthLabel(DateTime v) =>
        '${v.month.toString().padLeft(2, '0')}.${v.year.toString().padLeft(4, '0')}';

    String money(double v) => '${v.toStringAsFixed(2)} ${payslip.currency}';

    double asDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
    }

    Map<String, bool> boolMap(dynamic raw) {
      if (raw is! Map) return const <String, bool>{};
      return {for (final e in raw.entries) e.key.toString(): e.value == true};
    }

    Map<String, double> doubleMap(dynamic raw) {
      if (raw is! Map) return const <String, double>{};
      return {
        for (final e in raw.entries) e.key.toString(): asDouble(e.value),
      };
    }

    String ticketRuleLabel(String code) {
      switch (code) {
        case 'worked_hours':
          return 'zile lucrate';
        default:
          return code;
      }
    }

    String ticketRulesSummary(Map<String, bool> rules) {
      if (rules.isEmpty) return '-';
      final inc = rules.entries.where((e) => e.value).map((e) => ticketRuleLabel(e.key));
      final exc = rules.entries.where((e) => !e.value).map((e) => ticketRuleLabel(e.key));
      return 'Inc: ${inc.isEmpty ? "-" : inc.join(", ")} | Exc: ${exc.isEmpty ? "-" : exc.join(", ")}';
    }

    String ticketBreakdownSummary(Map<String, double> bd) {
      final parts = bd.entries
          .where((e) => e.value > 0)
          .map((e) => '${ticketRuleLabel(e.key)} ${e.value.toStringAsFixed(0)}');
      return parts.isEmpty ? '-' : parts.join(', ');
    }

    // ── Valori calculate ──────────────────────────────────────────────────────
    final venitNet = asDouble(salaryTaxPct['venit_net']);
    final personalDeduction = asDouble(salaryTaxPct['personal_deduction_amount']);
    final taxableBase = asDouble(salaryTaxPct['taxable_base_for_income_tax']);
    final mealTicketTotal = asDouble(salaryTaxPct['meal_ticket_total']);
    final netWithoutTm = asDouble(salaryTaxPct['net_without_tm']);

    final totalAvansuri = payments
        .where((p) => p.paymentType == 'avans')
        .fold<double>(0.0, (s, p) => s + p.amount);
    final totalSalariu = payments
        .where((p) => p.paymentType == 'salariu')
        .fold<double>(0.0, (s, p) => s + p.amount);
    final totalAchitat = payments.fold<double>(0.0, (s, p) => s + p.amount);
    final restDePlata = payslip.netFinal - totalAchitat;

    final resolvedBaseSalary = () {
      final fromGross = asDouble(grossComponents['base_salary_gross']);
      if (fromGross > 0) return fromGross;
      final fromContract = asDouble(contract['base_salary_gross']);
      if (fromContract > 0) return fromContract;
      return payslip.grossTotal;
    }();

    final jobTitleAndType = () {
      final title = (contract['job_title'] ?? '').toString().trim();
      final type = (contract['contract_type'] ?? '').toString().trim();
      if (title.isEmpty) return type;
      if (type.isEmpty) return title;
      return '$title / $type';
    }();

    // ── Widgeturi helper ──────────────────────────────────────────────────────
    // Label width per coloană: ~90pt (jumătate din lățimea disponibilă pe coloana compusă)
    pw.Widget row(String label, String value, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 90,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: bold ? pw.FontWeight.bold : null,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                textOrDash(value),
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: bold ? pw.FontWeight.bold : null,
                ),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget sectionHeader(String title) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 6),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Divider(color: PdfColors.grey400, height: 3),
          pw.SizedBox(height: 2),
        ],
      );
    }

    // ── Conținut coloane principale ────────────────────────────────────────────
    final leftColumn = <pw.Widget>[
      sectionHeader('Date generale'),
      row('Angajat', textOrDash(employeeName)),
      row('Luna', monthLabel(payslip.payrollMonth)),
      row('Funcție/contract', textOrDash(jobTitleAndType)),
      row('Status', textOrDash(payslip.status)),
      row('Data generării', dateTimeLabel(payslip.generatedAt)),
      sectionHeader('Venituri'),
      row('Salariu brut', money(resolvedBaseSalary)),
      row('Bonusuri taxabile', money(asDouble(grossComponents['bonuses_taxable']))),
      row('Indemnizații taxabile', money(asDouble(grossComponents['allowances_taxable']))),
      row('Indemnizații netaxabile', money(asDouble(grossComponents['allowances_non_taxable']))),
      row('BRUT TOTAL', money(payslip.grossTotal), bold: true),
      sectionHeader('Rețineri'),
      row('Rețineri diverse', money(payslip.deductionTotal)),
      row('Recuperări avans', money(payslip.advanceRecoveryTotal)),
      row('Popriri rezervate', money(payslip.garnishmentReservedTotal)),
    ];

    final rightColumn = <pw.Widget>[
      sectionHeader('Contribuții și taxe'),
      row('CAS (25%)', money(payslip.casAmount)),
      row('CASS (10%)', money(payslip.cassAmount)),
      row(
        'Venit net',
        money(venitNet > 0
            ? venitNet
            : payslip.grossTotal - payslip.casAmount - payslip.cassAmount +
                asDouble(mealTickets['total_value'])),
      ),
      row('Deducere personală', money(personalDeduction > 0 ? personalDeduction : 0)),
      row(
        'Bază calc. impozit',
        money(taxableBase > 0
            ? taxableBase
            : (venitNet - personalDeduction).clamp(0, double.infinity)),
      ),
      row('Impozit venit (10%)', money(payslip.incomeTaxAmount)),
      sectionHeader('Tichete de masă'),
      row('Activ', (mealTickets['enabled'] ?? false) == true ? 'da' : 'nu'),
      row('Zile eligibile', asDouble(mealTickets['eligible_days']).toStringAsFixed(0)),
      row('Valoare/zi', money(asDouble(mealTickets['value_per_day']))),
      row('Total tichete', money(asDouble(mealTickets['total_value']))),
      row('Regulă eligibilitate', ticketRulesSummary(boolMap(mealTickets['eligibility_rules']))),
      row('Detaliere coduri', ticketBreakdownSummary(doubleMap(mealTickets['eligibility_breakdown']))),
      sectionHeader('Net final'),
      if (netWithoutTm > 0) ...[
        row('Net fără tichete', money(netWithoutTm)),
        row('Tichete de masă', money(mealTicketTotal)),
      ],
      row('NET FINAL', money(payslip.netFinal), bold: true),
    ];

    // ── Secțiuni opționale (popriri, plăți, referințe) ───────────────────────
    final bottomWidgets = <pw.Widget>[];

    if (payslip.garnishmentReservedTotal > 0 || garnishments.isNotEmpty) {
      bottomWidgets.add(sectionHeader('Detaliu popriri'));
      if (garnishments.isEmpty) {
        bottomWidgets.add(row('Total popriri', money(payslip.garnishmentReservedTotal)));
      } else {
        for (final g in garnishments) {
          final typeLabel = () {
            switch (g.garnishmentType.toLowerCase()) {
              case 'pension':
              case 'pensie':
                return 'Pensie alimentară';
              case 'credit':
                return 'Credit';
              case 'tax':
              case 'fiscal':
                return 'Fiscal';
              default:
                return g.garnishmentType;
            }
          }();
          final amountLabel = g.amountType == 'percent'
              ? '${g.amountValue.toStringAsFixed(0)}%'
              : money(g.amountValue);
          bottomWidgets.add(row(
            'P${g.legalPriority} – $typeLabel',
            '$amountLabel${g.sourceDoc.isNotEmpty ? ' (${g.sourceDoc})' : ''}',
          ));
        }
        if (garnishments.length > 1) {
          bottomWidgets.add(row('Total reținut', money(payslip.garnishmentReservedTotal)));
        }
      }
    }

    if (payments.isNotEmpty) {
      bottomWidgets.add(sectionHeader('Plăți înregistrate'));
      for (final p in payments) {
        final typeLabel = p.paymentType == 'avans' ? 'Avans' : 'Salariu';
        final metodaLabel = () {
          switch (p.metodaPlata) {
            case 'virament':
              return 'virament bancar';
            case 'card':
              return 'card';
            default:
              return 'numerar';
          }
        }();
        bottomWidgets.add(row(
          '$typeLabel – ${dateLabel(p.paymentDate)}',
          '${money(p.amount)} ($metodaLabel)'
              '${p.note.trim().isNotEmpty ? " – ${p.note.trim()}" : ""}',
        ));
      }
      if (totalAvansuri > 0) bottomWidgets.add(row('Total avansuri', money(totalAvansuri)));
      if (totalSalariu > 0) bottomWidgets.add(row('Total salariu achitat', money(totalSalariu)));
      bottomWidgets.add(row('Total achitat', money(totalAchitat)));
      bottomWidgets.add(row(
        restDePlata <= 0.01 ? 'ACHITAT INTEGRAL' : 'REST DE PLATĂ',
        money(restDePlata.abs()),
        bold: true,
      ));
    }

    bottomWidgets.add(sectionHeader('Referințe'));
    bottomWidgets.add(row(
      'Rulare salarizare',
      textOrDash((payslip.sourceRefs['payroll_run_id'] ?? '').toString()),
    ));
    bottomWidgets.add(row(
      'Rezultat calcul',
      textOrDash((payslip.sourceRefs['calculation_result_id'] ?? '').toString()),
    ));

    // ── Document ──────────────────────────────────────────────────────────────
    doc.addPage(
      pw.MultiPage(
        pageFormat: const PdfPageFormat(
          210 * PdfPageFormat.mm,
          297 * PdfPageFormat.mm,
          marginAll: 10 * PdfPageFormat.mm,
        ),
        build: (_) => [
          // Header document
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
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
                  'FLUTURAȘI SALARIU',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      textOrDash(employeeName),
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Luna: ${monthLabel(payslip.payrollMonth)}  |  Status: ${textOrDash(payslip.status)}',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          // Două coloane principale
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: leftColumn,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: rightColumn,
                ),
              ),
            ],
          ),
          // Secțiuni opționale la baza paginii
          ...bottomWidgets,
        ],
      ),
    );

    final bytes = await doc.save();
    final fileName = _fileName(employeeName, payslip.payrollMonth);
    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: fileName,
      category: PdfDocumentCategory.hrPayslips,
      outputDirectory: outputDirectory,
      forceSaveAs: saveAs,
    );
  }

  static String _fileName(String employeeName, DateTime payrollMonth) {
    final safeEmployee = employeeName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final namePart = safeEmployee.isEmpty ? 'angajat' : safeEmployee;
    final monthKey =
        '${payrollMonth.year.toString().padLeft(4, '0')}-${payrollMonth.month.toString().padLeft(2, '0')}';
    return 'fluturas_salariu_${namePart}_$monthKey.pdf';
  }
}
