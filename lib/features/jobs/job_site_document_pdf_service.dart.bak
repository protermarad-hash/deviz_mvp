import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/pdf/pdf_font_helper.dart';
import '../../core/pdf/pro_term_pdf_template.dart';
import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'job_site_document_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PDF Service pentru PV montaj / PIF — folosește ProTermPdfTemplate
// ─────────────────────────────────────────────────────────────────────────────

class JobSiteDocumentPdfService {
  const JobSiteDocumentPdfService._();

  static final _dateFmt = DateFormat('dd.MM.yyyy', 'ro_RO');
  static String _fmt(DateTime dt) => _dateFmt.format(dt);
  static String _safe(String? s) => (s ?? '').trim().isEmpty ? '-' : (s ?? '').trim();

  /// Generează PDF și salvează pe disc. Returnează calea fișierului.
  static Future<String> export({
    required AppDataRepository repository,
    required JobSiteDocumentRecord document,
    bool saveAs = false,
  }) async {
    await PdfFontHelper.initialize();
    final profile = await repository.loadCompanyProfile();
    final branding = DocumentBrandingData.fromCompanyProfile(profile);
    final bytes = await _buildPdfBytes(document, branding);
    final fileName = '${document.documentType.shortCode}'
        '_${document.documentNumber.isEmpty ? document.id : document.documentNumber}'
        '.pdf';
    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: fileName,
      category: PdfDocumentCategory.jobs,
      forceSaveAs: saveAs,
    );
  }

  static Future<Uint8List> _buildPdfBytes(
    JobSiteDocumentRecord doc,
    DocumentBrandingData branding,
  ) async {
    // Semnătură electronică client (din base64)
    Uint8List? sigBytes;
    if (doc.clientSignatureBase64.trim().isNotEmpty) {
      try {
        sigBytes = base64Decode(doc.clientSignatureBase64.trim());
      } catch (_) {
        sigBytes = null;
      }
    }

    final dateStr = _fmt(doc.documentDate);

    // Conținut specific fiecărui tip de document
    final contentWidgets = _buildContent(doc);

    return ProTermPdfTemplate.generateDocument(
      branding: branding,
      documentTitle: doc.documentType.label,
      documentSubtitle: doc.documentSubtitle.trim().isNotEmpty ? doc.documentSubtitle : null,
      documentNumber: doc.documentNumber,
      documentDate: dateStr,
      contentWidgets: contentWidgets,
      clientName: doc.beneficiaryRepresentative.trim().isNotEmpty
          ? doc.beneficiaryRepresentative
          : null,
      jobCode: doc.projectName,
      jobTitle: doc.documentTitle,
      location: doc.location,
      includePartiesSection: true,
      includeJobInfoSection: true,
      includeSignatureSection: true,
      electronicSignatureBytes: sigBytes,
    );
  }

  // ── Conținut specific pe tip de document ───────────────────────────────────

  static List<pw.Widget> _buildContent(JobSiteDocumentRecord doc) {
    switch (doc.documentType) {
      case JobSiteDocumentType.montajExecutie:
        return _contentPvMontaj(doc);
      case JobSiteDocumentType.pifVentilatieRecuperator:
        return _contentPifVentilatie(doc);
      case JobSiteDocumentType.pifVrfClimatizare:
        return _contentPifVrf(doc);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PV MONTAJ / EXECUȚIE LUCRĂRI
  // ─────────────────────────────────────────────────────────────────────────

  static List<pw.Widget> _contentPvMontaj(JobSiteDocumentRecord doc) {
    final widgets = <pw.Widget>[];

    // Informații document
    widgets.add(ProTermPdfTemplate.buildSection('Informații document', [
      ProTermPdfTemplate.buildInfoRow('Număr document', _safe(doc.documentNumber)),
      ProTermPdfTemplate.buildInfoRow('Dată document', _fmt(doc.documentDate)),
      ProTermPdfTemplate.buildInfoRow('Status', _safe(doc.status)),
      if (doc.functionalStatus.trim().isNotEmpty)
        ProTermPdfTemplate.buildInfoRow('Status funcțional', doc.functionalStatus),
    ]));
    widgets.add(pw.SizedBox(height: 8));

    // Verificări tehnice ca tabel
    if (doc.checkItems.isNotEmpty) {
      final checkRows = doc.checkItems
          .map((item) => [
                item.value ? '✓' : '✗',
                item.label,
                item.notes.trim().isEmpty ? '-' : item.notes,
              ])
          .toList();
      widgets.add(ProTermPdfTemplate.buildSection('Verificări tehnice', [
        pw.SizedBox(height: 4),
        ProTermPdfTemplate.buildTable(
          headers: ['Status', 'Verificare', 'Observații'],
          rows: checkRows,
          columnWidths: [0.08, 0.60, 0.32],
        ),
      ]));
      widgets.add(pw.SizedBox(height: 8));
    }

    // Măsurători
    if (doc.measurements.isNotEmpty) {
      final measRows = doc.measurements
          .map((m) => [
                m.label,
                m.value.trim().isEmpty ? '-' : '${m.value} ${m.unit}'.trim(),
                m.notes.trim().isEmpty ? '-' : m.notes,
              ])
          .toList();
      widgets.add(ProTermPdfTemplate.buildSection('Măsurători și probe', [
        pw.SizedBox(height: 4),
        ProTermPdfTemplate.buildTable(
          headers: ['Parametru', 'Valoare', 'Observații'],
          rows: measRows,
          columnWidths: [0.45, 0.25, 0.30],
        ),
      ]));
      widgets.add(pw.SizedBox(height: 8));
    }

    _appendCommonSections(doc, widgets);
    _appendAnnexes(doc, widgets);

    return widgets;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PIF VENTILAȚIE / RECUPERATOR
  // ─────────────────────────────────────────────────────────────────────────

  static List<pw.Widget> _contentPifVentilatie(JobSiteDocumentRecord doc) {
    final widgets = <pw.Widget>[];

    widgets.add(ProTermPdfTemplate.buildSection('Date echipament', [
      ProTermPdfTemplate.buildInfoRow('Număr PIF', _safe(doc.documentNumber)),
      ProTermPdfTemplate.buildInfoRow('Dată punere în funcțiune', _fmt(doc.documentDate)),
      ProTermPdfTemplate.buildInfoRow('Tip echipament', 'Ventilație / Recuperator de căldură'),
      ProTermPdfTemplate.buildInfoRow('Status funcțional', _safe(doc.functionalStatus)),
    ]));
    widgets.add(pw.SizedBox(height: 8));

    // Probe și verificări ca tabel
    if (doc.checkItems.isNotEmpty) {
      final checkRows = doc.checkItems
          .map((item) => [item.value ? '✓' : '✗', item.label, item.notes.trim().isEmpty ? '-' : item.notes])
          .toList();
      widgets.add(ProTermPdfTemplate.buildSection('Probe și verificări', [
        pw.SizedBox(height: 4),
        ProTermPdfTemplate.buildTable(
          headers: ['Rezultat', 'Verificare', 'Observații'],
          rows: checkRows,
          columnWidths: [0.08, 0.60, 0.32],
        ),
      ]));
      widgets.add(pw.SizedBox(height: 8));
    }

    // Măsurători debit/presiune
    if (doc.measurements.isNotEmpty) {
      final measRows = doc.measurements
          .map((m) => [m.label, m.value.trim().isEmpty ? '-' : '${m.value} ${m.unit}'.trim(), m.notes.trim().isEmpty ? '-' : m.notes])
          .toList();
      widgets.add(ProTermPdfTemplate.buildSection('Măsurători debit / presiune', [
        pw.SizedBox(height: 4),
        ProTermPdfTemplate.buildTable(
          headers: ['Parametru', 'Valoare', 'Observații'],
          rows: measRows,
          columnWidths: [0.45, 0.25, 0.30],
        ),
      ]));
      widgets.add(pw.SizedBox(height: 8));
    }

    if (doc.probesSummary.trim().isNotEmpty) {
      widgets.add(ProTermPdfTemplate.buildSection('Sumar probe ventilație', [
        pw.Text(_safe(doc.probesSummary), style: const pw.TextStyle(fontSize: 9)),
      ]));
      widgets.add(pw.SizedBox(height: 8));
    }

    _appendCommonSections(doc, widgets);
    _appendAnnexes(doc, widgets);

    return widgets;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PIF VRF / CLIMATIZARE
  // ─────────────────────────────────────────────────────────────────────────

  static List<pw.Widget> _contentPifVrf(JobSiteDocumentRecord doc) {
    final widgets = <pw.Widget>[];

    widgets.add(ProTermPdfTemplate.buildSection('Date sistem VRF / Climatizare', [
      ProTermPdfTemplate.buildInfoRow('Număr PIF', _safe(doc.documentNumber)),
      ProTermPdfTemplate.buildInfoRow('Dată punere în funcțiune', _fmt(doc.documentDate)),
      ProTermPdfTemplate.buildInfoRow('Tip sistem', 'VRF / Climatizare'),
      ProTermPdfTemplate.buildInfoRow('Status funcțional', _safe(doc.functionalStatus)),
      if (doc.preparedForNextStep.trim().isNotEmpty)
        ProTermPdfTemplate.buildInfoRow('Pregătit pentru etapa următoare', doc.preparedForNextStep),
    ]));
    widgets.add(pw.SizedBox(height: 8));

    // Probe tehnice
    if (doc.checkItems.isNotEmpty) {
      final grouped = <String, List<JobSiteDocumentCheckItem>>{};
      for (final item in doc.checkItems) {
        grouped.putIfAbsent(item.sectionKey, () => []).add(item);
      }
      for (final entry in grouped.entries) {
        final sectionTitle = entry.key.trim().isEmpty ? 'Probe tehnice' : entry.key;
        final rows = entry.value
            .map((item) => [item.value ? '✓' : '✗', item.label, item.notes.trim().isEmpty ? '-' : item.notes])
            .toList();
        widgets.add(ProTermPdfTemplate.buildSection(sectionTitle, [
          pw.SizedBox(height: 4),
          ProTermPdfTemplate.buildTable(
            headers: ['Rezultat', 'Verificare', 'Observații'],
            rows: rows,
            columnWidths: [0.08, 0.60, 0.32],
          ),
        ]));
        widgets.add(pw.SizedBox(height: 8));
      }
    }

    // Măsurători
    if (doc.measurements.isNotEmpty) {
      final measRows = doc.measurements
          .map((m) => [m.label, m.value.trim().isEmpty ? '-' : '${m.value} ${m.unit}'.trim(), m.notes.trim().isEmpty ? '-' : m.notes])
          .toList();
      widgets.add(ProTermPdfTemplate.buildSection('Măsurători sistem', [
        pw.SizedBox(height: 4),
        ProTermPdfTemplate.buildTable(
          headers: ['Parametru', 'Valoare', 'Observații'],
          rows: measRows,
          columnWidths: [0.45, 0.25, 0.30],
        ),
      ]));
      widgets.add(pw.SizedBox(height: 8));
    }

    if (doc.probesSummary.trim().isNotEmpty) {
      widgets.add(ProTermPdfTemplate.buildSection('Sumar probe VRF', [
        pw.Text(_safe(doc.probesSummary), style: const pw.TextStyle(fontSize: 9)),
      ]));
      widgets.add(pw.SizedBox(height: 8));
    }

    if (doc.trainingProvided) {
      widgets.add(ProTermPdfTemplate.buildSection('Instruire utilizator', [
        pw.Text(
          'Instrucțiunile de utilizare au fost prezentate și explicate reprezentantului beneficiarului.',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ]));
      widgets.add(pw.SizedBox(height: 8));
    }

    _appendCommonSections(doc, widgets);
    _appendAnnexes(doc, widgets);

    return widgets;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Secțiuni comune (observații, concluzii, termen remediere)
  // ─────────────────────────────────────────────────────────────────────────

  static void _appendCommonSections(JobSiteDocumentRecord doc, List<pw.Widget> out) {
    if (doc.observations.trim().isNotEmpty) {
      out.add(ProTermPdfTemplate.buildSection('Observații', [
        pw.Text(_safe(doc.observations), style: const pw.TextStyle(fontSize: 9)),
      ]));
      out.add(pw.SizedBox(height: 8));
    }
    if (doc.conclusions.trim().isNotEmpty) {
      out.add(ProTermPdfTemplate.buildSection('Concluzii', [
        pw.Text(_safe(doc.conclusions), style: const pw.TextStyle(fontSize: 9)),
      ]));
      out.add(pw.SizedBox(height: 8));
    }
    if (doc.remediationDeadline != null) {
      out.add(ProTermPdfTemplate.buildSection('Termen remediere', [
        ProTermPdfTemplate.buildInfoRow('Termen stabilit', _fmt(doc.remediationDeadline!)),
      ]));
      out.add(pw.SizedBox(height: 8));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Anexe
  // ─────────────────────────────────────────────────────────────────────────

  static void _appendAnnexes(JobSiteDocumentRecord doc, List<pw.Widget> out) {
    if (doc.annexes.isEmpty) return;
    for (final annex in doc.annexes) {
      final annexWidgets = <pw.Widget>[];
      if (annex.description.trim().isNotEmpty) {
        annexWidgets.add(pw.Text(annex.description, style: const pw.TextStyle(fontSize: 9)));
        annexWidgets.add(pw.SizedBox(height: 4));
      }
      if (annex.items.isNotEmpty) {
        final rows = annex.items.take(50).map((item) => [
              item.label,
              item.quantity.trim().isEmpty ? '-' : '${item.quantity} ${item.unit}'.trim(),
              item.details.trim().isEmpty ? '-' : item.details,
            ]).toList();
        annexWidgets.add(ProTermPdfTemplate.buildTable(
          headers: ['Descriere', 'Cantitate', 'Detalii'],
          rows: rows,
          columnWidths: [0.55, 0.20, 0.25],
        ));
        if (annex.items.length > 50) {
          annexWidgets.add(pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              '... și ${annex.items.length - 50} poziții suplimentare.',
              style: pw.TextStyle(fontSize: 8, color: ProTermPdfTemplate.mediumText),
            ),
          ));
        }
      }
      if (annex.summary.trim().isNotEmpty) {
        annexWidgets.add(pw.SizedBox(height: 4));
        annexWidgets.add(pw.Text(annex.summary, style: const pw.TextStyle(fontSize: 9)));
      }
      out.add(ProTermPdfTemplate.buildSection('Anexă: ${annex.title}', annexWidgets));
      out.add(pw.SizedBox(height: 8));
    }
  }
}
