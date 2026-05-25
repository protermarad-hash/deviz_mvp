import '../../core/pdf/pdf_font_helper.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../hr_attendance/hr_attendance_models.dart';

class HrAttendanceReportPdfService {
  const HrAttendanceReportPdfService._();

  static Future<String> export({
    required AppDataRepository repository,
    required String employeeName,
    required DateTime month,
    required List<HrAttendanceEntry> entries,
    String teamName = '',
    String outputDirectory = '',
  }) async {
    await PdfFontHelper.initialize();
    final doc = pw.Document(theme: PdfFontHelper.theme);

    String textOrDash(String value) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? '-' : trimmed;
    }

    String dateLabel(DateTime? value) {
      if (value == null) return '-';
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

    pw.Widget line(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 150,
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

    final rows = entries.toList(growable: false)
      ..sort((a, b) => a.date.compareTo(b.date));

    final totalWorked =
        rows.fold<double>(0, (sum, item) => sum + item.workedHours);
    final totalOvertime =
        rows.fold<double>(0, (sum, item) => sum + item.overtimeHours);
    final totalNight =
        rows.fold<double>(0, (sum, item) => sum + item.nightHours);
    final totalLeave = rows.fold<double>(0, (sum, item) => sum + item.leaveHours);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(
            'Raport intern de pontaj',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          line('Nume angajat', employeeName),
          line('Luna', monthLabel(month)),
          line('Echipa', teamName),
          pw.SizedBox(height: 12),
          if (rows.isEmpty)
            pw.Text('Nu exista intrari de pontaj pentru luna selectata.')
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              headers: const [
                'Data',
                'Sursa',
                'Ore lucrate',
                'Ore suplimentare',
                'Ore noapte',
                'Ore concediu',
                'Status',
              ],
              data: rows
                  .map(
                    (item) => [
                      dateLabel(item.date),
                      textOrDash(item.sourceType),
                      money(item.workedHours),
                      money(item.overtimeHours),
                      money(item.nightHours),
                      money(item.leaveHours),
                      textOrDash(item.status),
                    ],
                  )
                  .toList(growable: false),
            ),
          pw.SizedBox(height: 16),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text('Total ore lucrate: ${money(totalWorked)}'),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text('Total ore suplimentare: ${money(totalOvertime)}'),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text('Total ore noapte: ${money(totalNight)}'),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text('Total ore concediu: ${money(totalLeave)}'),
              ),
            ],
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
    final fileName = _fileName(employeeName, month);
    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: fileName,
      category: PdfDocumentCategory.attendanceReports,
      outputDirectory: outputDirectory,
    );
  }

  static String _fileName(String employeeName, DateTime month) {
    final safeEmployee = employeeName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final namePart = safeEmployee.isEmpty ? 'angajat' : safeEmployee;
    final dateKey =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    return 'raport_pontaj_${namePart}_$dateKey.pdf';
  }

}
