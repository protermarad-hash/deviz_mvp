import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/pdf/pdf_font_helper.dart';
import '../../core/pdf/pro_term_pdf_template.dart';
import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'job_models.dart';
import 'job_site_document_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PDF Service pentru PV montaj / PIF — folosește ProTermPdfTemplate
// Aliniat vizual cu PV-ul din modulul Reclamații (headere roșii #C62828)
// ─────────────────────────────────────────────────────────────────────────────

class JobSiteDocumentPdfService {
  const JobSiteDocumentPdfService._();

  static final _dateFmt = DateFormat('dd.MM.yyyy', 'ro_RO');
  static String _fmt(DateTime dt) => _dateFmt.format(dt);
  static String _safe(String? s) =>
      (s ?? '').trim().isEmpty ? '-' : (s ?? '').trim();

  // ── Culori brand (identice cu repair_report_pdf_service) ────────────────────
  static const _primaryRed = PdfColor(0.7765, 0.1569, 0.1569); // #C62828
  static const _lightGray = PdfColor(0.9608, 0.9608, 0.9608);  // #F5F5F5
  static const _borderGray = PdfColor(0.8, 0.8, 0.8);

  /// Generează PDF și salvează pe disc. Returnează calea fișierului.
  static Future<String> export({
    required AppDataRepository repository,
    required JobSiteDocumentRecord document,
    List<JobLine>? liniiPlanificate,
    bool saveAs = false,
  }) async {
    await PdfFontHelper.initialize();
    final profile = await repository.loadCompanyProfile();
    final branding = DocumentBrandingData.fromCompanyProfile(profile);
    final bytes = await _buildPdfBytes(document, branding, liniiPlanificate ?? []);
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
    List<JobLine> linii,
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
    final contentWidgets = _buildContent(doc, linii);

    return ProTermPdfTemplate.generateDocument(
      branding: branding,
      documentTitle: doc.documentType.label,
      documentSubtitle:
          doc.documentSubtitle.trim().isNotEmpty ? doc.documentSubtitle : null,
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

  // ── Secțiune cu header roșu (stil Reclamații PV) ────────────────────────────

  static pw.Widget _redSection(String title, List<pw.Widget> children) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGray, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: const pw.BoxDecoration(
              color: _primaryRed,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                topRight: pw.Radius.circular(4),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tabel linii planificate (cantități, fără prețuri) ───────────────────────

  static pw.Widget? _buildLiniiTable(List<JobLine> linii) {
    if (linii.isEmpty) return null;
    final rows = linii.map((l) {
      final obs = l.observatii.trim();
      final denumire = obs.isEmpty ? l.denumire : '${l.denumire}\n($obs)';
      return [
        denumire,
        l.um,
        l.cantitateOferta > 0
            ? l.cantitateOferta.toStringAsFixed(2)
            : '-',
        l.cantitateReala > 0
            ? l.cantitateReala.toStringAsFixed(2)
            : '-',
      ];
    }).toList();

    return _redSection('Lucrări executate conform ofertei', [
      pw.SizedBox(height: 4),
      pw.Text(
        'Cantitățile sunt preluate din situația de lucrări. Prețurile unitare nu sunt afișate în prezentul document.',
        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
      ),
      pw.SizedBox(height: 6),
      ProTermPdfTemplate.buildTable(
        headers: ['Denumire / Specificație', 'UM', 'Cantit. ofertată', 'Cantit. executată'],
        rows: rows,
        columnWidths: [0.50, 0.10, 0.20, 0.20],
      ),
    ]);
  }

  // ── Conținut specific pe tip de document ───────────────────────────────────

  static List<pw.Widget> _buildContent(
      JobSiteDocumentRecord doc, List<JobLine> linii) {
    switch (doc.documentType) {
      case JobSiteDocumentType.pvMontaj:
        return _contentPvMontaj(doc, linii);
      case JobSiteDocumentType.pif:
        return _contentPif(doc, linii);
    }
  }

  // ── Text standard pentru fiecare tip ────────────────────────────────────────

  static pw.Widget _antetText(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        color: _lightGray,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: _borderGray, width: 0.5),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 8.5),
        textAlign: pw.TextAlign.justify,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PV MONTAJ / EXECUȚIE LUCRĂRI
  // ─────────────────────────────────────────────────────────────────────────

  static List<pw.Widget> _contentPvMontaj(
      JobSiteDocumentRecord doc, List<JobLine> linii) {
    final widgets = <pw.Widget>[];

    // Antet profesional
    widgets.add(_antetText(
      'Prezentul Proces-Verbal atestă recepția lucrărilor de montaj și execuție efectuate de executant '
      'la obiectivul menționat, în conformitate cu oferta/comanda acceptată de beneficiar. '
      'Lucrările au fost realizate respectând normele tehnice și standardele în vigoare. '
      'Prin semnarea prezentului document, beneficiarul confirmă că lucrările sunt conforme cu '
      'specificațiile convenite și că nu există obiecții semnificative la momentul recepției.',
    ));

    // Informații document
    widgets.add(ProTermPdfTemplate.buildSection('Informații document', [
      ProTermPdfTemplate.buildInfoRow(
          'Număr document', _safe(doc.documentNumber)),
      ProTermPdfTemplate.buildInfoRow(
          'Dată document', _fmt(doc.documentDate)),
      ProTermPdfTemplate.buildInfoRow('Status', _safe(doc.status)),
      if (doc.functionalStatus.trim().isNotEmpty)
        ProTermPdfTemplate.buildInfoRow(
            'Status funcțional', doc.functionalStatus),
    ]));
    widgets.add(pw.SizedBox(height: 8));

    // Tabel linii planificate (cantități)
    final liniiWidget = _buildLiniiTable(linii);
    if (liniiWidget != null) {
      widgets.add(liniiWidget);
      widgets.add(pw.SizedBox(height: 8));
    }

    // Verificări tehnice ca tabel
    if (doc.checkItems.isNotEmpty) {
      final checkRows = doc.checkItems
          .map((item) => [
                item.value ? '✓' : '✗',
                item.label,
                item.notes.trim().isEmpty ? '-' : item.notes,
              ])
          .toList();
      widgets.add(_redSection('Verificări tehnice', [
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
                m.value.trim().isEmpty
                    ? '-'
                    : '${m.value} ${m.unit}'.trim(),
                m.notes.trim().isEmpty ? '-' : m.notes,
              ])
          .toList();
      widgets.add(_redSection('Măsurători și probe', [
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
    _appendGarantieSection(widgets);
    _appendAnnexes(doc, widgets);

    return widgets;
  }

  static List<pw.Widget> _contentPif(
      JobSiteDocumentRecord doc, List<JobLine> linii) {
    final widgets = <pw.Widget>[];

    widgets.add(_antetText(
      'Prezentul Proces-Verbal de Punere în Funcțiune atestă că sistemul VRF / de climatizare '
      'menționat a fost instalat, reglat și testat în conformitate cu specificațiile tehnice '
      'ale producătorului, prescripțiile normativelor în vigoare și proiectul de execuție aprobat. '
      'Probele tehnice au fost efectuate cu rezultate conforme, parametrii de funcționare '
      'ai unităților interioare și exterioare corespund valorilor proiectate, sistemul de control '
      'a fost configurat și testat, iar utilizatorul a fost instruit cu privire la exploatarea corectă.',
    ));

    widgets.add(ProTermPdfTemplate.buildSection('Date sistem VRF / Climatizare', [
      ProTermPdfTemplate.buildInfoRow('Număr PIF', _safe(doc.documentNumber)),
      ProTermPdfTemplate.buildInfoRow(
          'Dată punere în funcțiune', _fmt(doc.documentDate)),
      ProTermPdfTemplate.buildInfoRow('Tip sistem', 'VRF / Climatizare'),
      ProTermPdfTemplate.buildInfoRow(
          'Status funcțional', _safe(doc.functionalStatus)),
      if (doc.preparedForNextStep.trim().isNotEmpty)
        ProTermPdfTemplate.buildInfoRow(
            'Pregătit pentru etapa următoare', doc.preparedForNextStep),
    ]));
    widgets.add(pw.SizedBox(height: 8));

    // Linii planificate
    final liniiWidget = _buildLiniiTable(linii);
    if (liniiWidget != null) {
      widgets.add(liniiWidget);
      widgets.add(pw.SizedBox(height: 8));
    }

    // Probe tehnice (grupate pe secțiuni)
    if (doc.checkItems.isNotEmpty) {
      final grouped = <String, List<JobSiteDocumentCheckItem>>{};
      for (final item in doc.checkItems) {
        grouped.putIfAbsent(item.sectionKey, () => []).add(item);
      }
      for (final entry in grouped.entries) {
        final sectionTitle =
            entry.key.trim().isEmpty ? 'Probe tehnice' : entry.key;
        final rows = entry.value
            .map((item) => [
                  item.value ? '✓' : '✗',
                  item.label,
                  item.notes.trim().isEmpty ? '-' : item.notes,
                ])
            .toList();
        widgets.add(_redSection(sectionTitle, [
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
          .map((m) => [
                m.label,
                m.value.trim().isEmpty
                    ? '-'
                    : '${m.value} ${m.unit}'.trim(),
                m.notes.trim().isEmpty ? '-' : m.notes,
              ])
          .toList();
      widgets.add(_redSection('Măsurători sistem', [
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
      widgets.add(_redSection('Sumar probe VRF', [
        pw.Text(_safe(doc.probesSummary),
            style: const pw.TextStyle(fontSize: 9)),
      ]));
      widgets.add(pw.SizedBox(height: 8));
    }

    if (doc.trainingProvided) {
      widgets.add(_redSection('Instruire utilizator', [
        pw.Text(
          'Instrucțiunile de utilizare au fost prezentate și explicate reprezentantului '
          'beneficiarului. Utilizatorul a confirmat că a înțeles modul de operare, '
          'procedurile de întreținere periodică și condițiile de garanție.',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ]));
      widgets.add(pw.SizedBox(height: 8));
    }

    _appendCommonSections(doc, widgets);
    _appendGarantieSection(widgets);
    _appendAnnexes(doc, widgets);

    return widgets;
  }

  // ── Tabel poziții lucrare verificate (selectate manual cu status) ───────────

  static String _wlText(dynamic raw) => '${raw ?? ''}'.trim();

  static String _wlQty(dynamic raw) {
    if (raw is num) return raw.toStringAsFixed(2);
    final parsed = double.tryParse('${raw ?? ''}'.replaceAll(',', '.'));
    return parsed != null ? parsed.toStringAsFixed(2) : _wlText(raw);
  }

  static pw.Widget? _buildSelectedWorkLinesTable(JobSiteDocumentRecord doc) {
    if (doc.selectedWorkLines.isEmpty) return null;
    var index = 0;
    final rows = doc.selectedWorkLines.map((line) {
      index++;
      return [
        '$index',
        _wlText(line['denumire']).isEmpty ? '-' : _wlText(line['denumire']),
        _wlText(line['um']).isEmpty ? '-' : _wlText(line['um']),
        _wlQty(line['cantitate']),
        _wlText(line['status']).isEmpty ? '-' : _wlText(line['status']),
        _wlText(line['observatii']).isEmpty ? '-' : _wlText(line['observatii']),
      ];
    }).toList();

    return _redSection('Poziții lucrare verificate', [
      pw.SizedBox(height: 4),
      ProTermPdfTemplate.buildTable(
        headers: ['Nr', 'Descriere', 'UM', 'Cantitate', 'Status', 'Observații'],
        rows: rows,
        columnWidths: [0.06, 0.36, 0.08, 0.13, 0.17, 0.20],
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Secțiuni comune (observații, concluzii, termen remediere)
  // ─────────────────────────────────────────────────────────────────────────

  static void _appendCommonSections(
      JobSiteDocumentRecord doc, List<pw.Widget> out) {
    final selectedWorkLinesWidget = _buildSelectedWorkLinesTable(doc);
    if (selectedWorkLinesWidget != null) {
      out.add(selectedWorkLinesWidget);
      out.add(pw.SizedBox(height: 8));
    }
    if (doc.observations.trim().isNotEmpty) {
      out.add(_redSection('Observații', [
        pw.Text(_safe(doc.observations),
            style: const pw.TextStyle(fontSize: 9)),
      ]));
      out.add(pw.SizedBox(height: 8));
    }
    if (doc.conclusions.trim().isNotEmpty) {
      out.add(_redSection('Concluzii', [
        pw.Text(_safe(doc.conclusions),
            style: const pw.TextStyle(fontSize: 9)),
      ]));
      out.add(pw.SizedBox(height: 8));
    }
    if (doc.remediationDeadline != null) {
      out.add(ProTermPdfTemplate.buildSection('Termen remediere', [
        ProTermPdfTemplate.buildInfoRow(
            'Termen stabilit', _fmt(doc.remediationDeadline!)),
      ]));
      out.add(pw.SizedBox(height: 8));
    }
  }

  // ── Secțiune garanție standard ───────────────────────────────────────────────

  static void _appendGarantieSection(List<pw.Widget> out) {
    out.add(_redSection('Condiții de garanție', [
      pw.Text(
        'Executantul acordă garanție pentru lucrările executate conform prevederilor legale '
        'în vigoare și condițiilor contractuale. Garanția acoperă viciile ascunse și defecțiunile '
        'datorate execuției necorespunzătoare, descoperite în termenul de garanție, cu condiția '
        'utilizării corecte a instalației și efectuării reviziilor periodice recomandate. '
        'Garanția nu acoperă defecțiunile cauzate de utilizare necorespunzătoare, intervenții '
        'neautorizate, calamități naturale sau forță majoră.',
        style: const pw.TextStyle(fontSize: 8.5),
        textAlign: pw.TextAlign.justify,
      ),
    ]));
    out.add(pw.SizedBox(height: 8));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Anexe
  // ─────────────────────────────────────────────────────────────────────────

  static void _appendAnnexes(
      JobSiteDocumentRecord doc, List<pw.Widget> out) {
    if (doc.annexes.isEmpty) return;
    for (final annex in doc.annexes) {
      final annexWidgets = <pw.Widget>[];
      if (annex.description.trim().isNotEmpty) {
        annexWidgets.add(pw.Text(annex.description,
            style: const pw.TextStyle(fontSize: 9)));
        annexWidgets.add(pw.SizedBox(height: 4));
      }
      if (annex.items.isNotEmpty) {
        final rows = annex.items.take(50).map((item) => [
              item.label,
              item.quantity.trim().isEmpty
                  ? '-'
                  : '${item.quantity} ${item.unit}'.trim(),
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
              style: pw.TextStyle(
                  fontSize: 8, color: ProTermPdfTemplate.mediumText),
            ),
          ));
        }
      }
      if (annex.summary.trim().isNotEmpty) {
        annexWidgets.add(pw.SizedBox(height: 4));
        annexWidgets.add(pw.Text(annex.summary,
            style: const pw.TextStyle(fontSize: 9)));
      }
      out.add(
          _redSection('Anexă: ${annex.title}', annexWidgets));
      out.add(pw.SizedBox(height: 8));
    }
  }
}
