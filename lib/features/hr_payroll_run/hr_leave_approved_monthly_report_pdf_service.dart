import '../../core/pdf/pdf_font_helper.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../hr_leave/hr_leave_models.dart';

class HrLeaveApprovedMonthlyReportPdfService {
  const HrLeaveApprovedMonthlyReportPdfService._();

  static Future<String> export({
    required AppDataRepository repository,
    required DateTime month,
    required List<HrLeaveRequest> requests,
    required Map<String, String> employeeNamesById,
    String outputDirectory = '',
  }) async {
    await PdfFontHelper.initialize();
    final doc = pw.Document(theme: PdfFontHelper.theme);

    String textOrDash(String value) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? '-' : trimmed;
    }

    String dateLabel(DateTime value) {
      final d = value.day.toString().padLeft(2, '0');
      final m = value.month.toString().padLeft(2, '0');
      final y = value.year.toString().padLeft(4, '0');
      return '$d.$m.$y';
    }

    String monthLabel(DateTime value) {
      final m = value.month.toString().padLeft(2, '0');
      final y = value.year.toString().padLeft(4, '0');
      return '$m.$y';
    }

    String money(double value) => value.toStringAsFixed(2);

    final rows = requests
        .where((item) => item.status.trim().toLowerCase() == 'approved')
        .toList(growable: false)
      ..sort((a, b) {
        final byName = (employeeNamesById[a.employeeId] ?? a.employeeId)
            .compareTo(employeeNamesById[b.employeeId] ?? b.employeeId);
        if (byName != 0) return byName;
        return a.startDate.compareTo(b.startDate);
      });

    final totalCalendarDays =
        rows.fold<double>(0, (sum, item) => sum + item.calendarDays);
    final totalWorkingDays =
        rows.fold<double>(0, (sum, item) => sum + item.workingDays);
    final affectedEmployees =
        rows.map((item) => item.employeeId.trim()).where((e) => e.isNotEmpty).toSet();

    final workingDaysByType = <String, double>{};
    for (final item in rows) {
      final key = item.leaveTypeCode.trim().isEmpty ? '-' : item.leaveTypeCode.trim();
      workingDaysByType[key] = (workingDaysByType[key] ?? 0) + item.workingDays;
    }

    pw.Widget infoLine(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 170,
              child: pw.Text(
                label,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Expanded(child: pw.Text(textOrDash(value))),
          ],
        ),
      );
    }

    pw.Widget signatureBox(String title) {
      return pw.Container(
        height: 72,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Spacer(),
            pw.Container(height: 1, color: PdfColors.grey500),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(
            'Raport intern concedii aprobate',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          infoLine('Luna selectata', monthLabel(month)),
          infoLine('Total concedii aprobate', '${rows.length}'),
          infoLine('Total zile calendaristice', money(totalCalendarDays)),
          infoLine('Total zile lucratoare', money(totalWorkingDays)),
          infoLine('Angajati afectati', '${affectedEmployees.length}'),
          pw.SizedBox(height: 12),
          if (rows.isEmpty)
            pw.Text('Nu exista concedii approved pentru luna selectata.')
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              headers: const [
                'Nume angajat',
                'Tip concediu',
                'Perioada',
                'Zile calendaristice',
                'Zile lucratoare',
                'Status',
                'Cod medical',
                'Document referinta',
              ],
              data: rows
                  .map(
                    (item) => [
                      textOrDash(employeeNamesById[item.employeeId] ?? item.employeeId),
                      textOrDash(item.leaveTypeCode),
                      '${dateLabel(item.startDate)} - ${dateLabel(item.endDate)}',
                      money(item.calendarDays),
                      money(item.workingDays),
                      textOrDash(item.status),
                      textOrDash(item.medicalCode),
                      textOrDash(item.documentRef),
                    ],
                  )
                  .toList(growable: false),
            ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Total zile lucratoare pe tipuri',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          if (workingDaysByType.isEmpty)
            pw.Text('-')
          else
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: workingDaysByType.entries
                  .map(
                    (entry) => pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text('${entry.key}: ${money(entry.value)}'),
                    ),
                  )
                  .toList(growable: false),
            ),
          pw.SizedBox(height: 18),
          pw.Text('Observații', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Container(
            height: 54,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(6),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: signatureBox('Verificat de')),
              pw.SizedBox(width: 16),
              pw.Expanded(child: signatureBox('Semnătură')),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final fileName = _fileName(month);
    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: fileName,
      category: PdfDocumentCategory.leaveRequests,
      outputDirectory: outputDirectory,
    );
  }

  static String _fileName(DateTime month) {
    final dateKey =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    return 'raport_concedii_aprobate_$dateKey.pdf';
  }

}
