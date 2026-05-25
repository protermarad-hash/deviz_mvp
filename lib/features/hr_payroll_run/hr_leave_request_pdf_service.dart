import '../../core/pdf_export_settings.dart';
import '../../core/pdf_font_bundle.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../hr_leave/hr_leave_models.dart';

class HrLeaveRequestPdfService {
  const HrLeaveRequestPdfService._();

  static Future<String> export({
    required AppDataRepository repository,
    required HrLeaveRequest request,
    String employeeName = '',
    String jobTitle = '',
    String teamName = '',
    String leaveTypeName = '',
    String outputDirectory = '',
  }) async {
    final pdfFonts = await PdfFontBundle.load();
    final doc = pw.Document(theme: pdfFonts.theme);

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

    pw.Widget line(String label, String value) {
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
        height: 90,
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
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Cerere de concediu',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            line('Nume angajat', employeeName),
            line('Functie', jobTitle),
            line('Echipa / departament', teamName),
            line('Tip concediu', leaveTypeName),
            line(
              'Perioada solicitata',
              '${dateLabel(request.startDate)} - ${dateLabel(request.endDate)}',
            ),
            line(
              'Numar zile',
              '${request.workingDays.toStringAsFixed(0)} lucratoare / ${request.calendarDays.toStringAsFixed(0)} calendaristice',
            ),
            line('Data generarii', dateLabel(DateTime.now())),
            line('Cod medical', request.medicalCode),
            line('Document referinta', request.documentRef),
            line('Status', request.status),
            if (request.notes.trim().isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                'Note',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(request.notes.trim()),
            ],
            pw.Spacer(),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: signatureBox('Semnătura angajatului'),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: signatureBox('Aprobare / semnatura superior'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    final fileName = _fileName(employeeName, request.startDate);
    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: fileName,
      category: PdfDocumentCategory.leaveRequests,
      outputDirectory: outputDirectory,
    );
  }

  static String _fileName(String employeeName, DateTime startDate) {
    final safeEmployee = employeeName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final namePart = safeEmployee.isEmpty ? 'angajat' : safeEmployee;
    final dateKey =
        '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    return 'cerere_concediu_${namePart}_$dateKey.pdf';
  }
}
