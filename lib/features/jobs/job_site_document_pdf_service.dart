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

    // Titlu explicit per tip de document
    final title = doc.documentType == JobSiteDocumentType.pif
        ? 'PROCES-VERBAL DE PUNERE ÎN FUNCȚIUNE (P.I.F.)'
        : 'PROCES-VERBAL DE MONTAJ ȘI EXECUȚIE LUCRĂRI';

    return ProTermPdfTemplate.generateDocument(
      branding: branding,
      documentTitle: title,
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
      // Secțiunile părți/proiect sunt randate explicit în conținut (1. Date...),
      // deci dezactivăm secțiunile automate ale template-ului pentru a evita duplicarea.
      includePartiesSection: false,
      includeJobInfoSection: false,
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

    // 1. Date proiect
    widgets.add(ProTermPdfTemplate.buildSection('1. Date proiect', [
      ProTermPdfTemplate.buildInfoRow(
          'Beneficiar', _safe(doc.beneficiaryRepresentative)),
      ProTermPdfTemplate.buildInfoRow(
          'Executant', _safe(doc.executorRepresentative)),
      ProTermPdfTemplate.buildInfoRow('Proiect / Obiectiv', _safe(doc.projectName)),
      ProTermPdfTemplate.buildInfoRow('Adresă / Locație', _safe(doc.location)),
    ]));
    widgets.add(pw.SizedBox(height: 8));

    // 2. Participanți
    widgets.add(ProTermPdfTemplate.buildSection('2. Participanți', [
      ProTermPdfTemplate.buildInfoRow(
          'Reprezentant Beneficiar', _safe(doc.beneficiaryRepresentative)),
      ProTermPdfTemplate.buildInfoRow(
          'Reprezentant Executant', _safe(doc.executorRepresentative)),
    ]));
    widgets.add(pw.SizedBox(height: 8));

    // 3. Obiectul procesului-verbal
    widgets.add(_redSection('3. Obiectul procesului-verbal', [
      pw.Text(_safe(doc.observations), style: const pw.TextStyle(fontSize: 9)),
    ]));
    widgets.add(pw.SizedBox(height: 8));

    // 4. Verificări efectuate
    final verificariWidgets = <pw.Widget>[
      pw.Text(_safe(doc.probesSummary), style: const pw.TextStyle(fontSize: 9)),
    ];
    if (doc.checkItems.isNotEmpty) {
      verificariWidgets.add(pw.SizedBox(height: 6));
      verificariWidgets.add(ProTermPdfTemplate.buildTable(
        headers: ['Status', 'Verificare', 'Observații'],
        rows: doc.checkItems
            .map((item) => [
                  item.value ? '✓' : '✗',
                  item.label,
                  item.notes.trim().isEmpty ? '-' : item.notes,
                ])
            .toList(),
        columnWidths: [0.08, 0.60, 0.32],
      ));
    }
    widgets.add(_redSection('4. Verificări efectuate', verificariWidgets));
    widgets.add(pw.SizedBox(height: 8));

    // 5. Constatări / Deficiențe
    final constatariWidgets = <pw.Widget>[
      pw.Text(_safe(doc.conclusions), style: const pw.TextStyle(fontSize: 9)),
    ];
    if (doc.remediationDeadline != null) {
      constatariWidgets.add(pw.SizedBox(height: 6));
      constatariWidgets.add(ProTermPdfTemplate.buildInfoRow(
          'Termen remediere', _fmt(doc.remediationDeadline!)));
    }
    widgets.add(_redSection('5. Constatări / Deficiențe', constatariWidgets));
    widgets.add(pw.SizedBox(height: 8));

    // Anexă — lista materiale / echipamente montate (poziții selectate)
    final workLinesTable = _buildSelectedWorkLinesTable(
      doc,
      sectionTitle: 'Anexă — lista materiale / echipamente montate',
      statusHeader: 'Stare Montaj',
    );
    if (workLinesTable != null) {
      widgets.add(workLinesTable);
      widgets.add(pw.SizedBox(height: 8));
    }

    _appendGarantieSection(widgets);

    return widgets;
  }

  static List<pw.Widget> _contentPif(
      JobSiteDocumentRecord doc, List<JobLine> linii) {
    final widgets = <pw.Widget>[];

    widgets.add(_antetText(
      'Prezentul Proces-Verbal de Punere în Funcțiune atestă că sistemul menționat a fost '
      'instalat, reglat și testat în conformitate cu specificațiile tehnice ale producătorului, '
      'prescripțiile normativelor în vigoare și proiectul de execuție aprobat. Probele tehnice '
      'au fost efectuate cu rezultate conforme, parametrii de funcționare corespund valorilor '
      'proiectate, iar utilizatorul a fost instruit cu privire la exploatarea corectă.',
    ));

    // 1. Date generale
    widgets.add(ProTermPdfTemplate.buildSection('1. Date generale', [
      ProTermPdfTemplate.buildInfoRow(
          'Beneficiar', _safe(doc.beneficiaryRepresentative)),
      ProTermPdfTemplate.buildInfoRow(
          'Executant', _safe(doc.executorRepresentative)),
      ProTermPdfTemplate.buildInfoRow('Proiect / Obiectiv', _safe(doc.projectName)),
      ProTermPdfTemplate.buildInfoRow('Adresă / Locație', _safe(doc.location)),
    ]));
    widgets.add(pw.SizedBox(height: 8));

    // 2. Comisia de punere în funcțiune
    widgets.add(
        ProTermPdfTemplate.buildSection('2. Comisia de punere în funcțiune', [
      ProTermPdfTemplate.buildInfoRow(
          'Reprezentant Beneficiar', _safe(doc.beneficiaryRepresentative)),
      ProTermPdfTemplate.buildInfoRow(
          'Reprezentant Executant', _safe(doc.executorRepresentative)),
      if (doc.otherParticipants.trim().isNotEmpty)
        ProTermPdfTemplate.buildInfoRow(
            'Alți participanți', doc.otherParticipants),
    ]));
    widgets.add(pw.SizedBox(height: 8));

    // 3. Obiectul probelor
    widgets.add(_redSection('3. Obiectul probelor', [
      pw.Text(_safe(doc.observations), style: const pw.TextStyle(fontSize: 9)),
    ]));
    widgets.add(pw.SizedBox(height: 8));

    // 4. Etape și teste / Probe și măsurători
    final probeWidgets = <pw.Widget>[
      pw.Text(_safe(doc.probesSummary), style: const pw.TextStyle(fontSize: 9)),
    ];
    if (doc.checkItems.isNotEmpty) {
      final grouped = <String, List<JobSiteDocumentCheckItem>>{};
      for (final item in doc.checkItems) {
        grouped.putIfAbsent(item.sectionKey, () => []).add(item);
      }
      for (final entry in grouped.entries) {
        probeWidgets.add(pw.SizedBox(height: 6));
        probeWidgets.add(pw.Text(
          entry.key.trim().isEmpty ? 'Verificări' : entry.key,
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
        ));
        probeWidgets.add(pw.SizedBox(height: 2));
        probeWidgets.add(ProTermPdfTemplate.buildTable(
          headers: ['Rezultat', 'Verificare', 'Observații'],
          rows: entry.value
              .map((item) => [
                    item.value ? '✓' : '✗',
                    item.label,
                    item.notes.trim().isEmpty ? '-' : item.notes,
                  ])
              .toList(),
          columnWidths: [0.08, 0.60, 0.32],
        ));
      }
    }
    if (doc.measurements.isNotEmpty) {
      probeWidgets.add(pw.SizedBox(height: 6));
      probeWidgets.add(pw.Text('Măsurători',
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)));
      probeWidgets.add(pw.SizedBox(height: 2));
      probeWidgets.add(ProTermPdfTemplate.buildTable(
        headers: ['Parametru', 'Valoare', 'Observații'],
        rows: doc.measurements
            .map((m) => [
                  m.label,
                  m.value.trim().isEmpty ? '-' : '${m.value} ${m.unit}'.trim(),
                  m.notes.trim().isEmpty ? '-' : m.notes,
                ])
            .toList(),
        columnWidths: [0.45, 0.25, 0.30],
      ));
    }
    widgets.add(
        _redSection('4. Etape și teste / Probe și măsurători', probeWidgets));
    widgets.add(pw.SizedBox(height: 8));

    // 5. Instruirea personalului
    widgets.add(ProTermPdfTemplate.buildSection('5. Instruirea personalului', [
      ProTermPdfTemplate.buildInfoRow(
          'Instruire personal beneficiar', doc.trainingProvided ? 'Da' : 'Nu'),
    ]));
    widgets.add(pw.SizedBox(height: 8));

    // 6. Constatări / Observații
    final constatariWidgets = <pw.Widget>[
      pw.Text(_safe(doc.conclusions), style: const pw.TextStyle(fontSize: 9)),
    ];
    if (doc.functionalStatus.trim().isNotEmpty) {
      constatariWidgets.add(pw.SizedBox(height: 6));
      constatariWidgets.add(ProTermPdfTemplate.buildInfoRow(
          'Status funcțional sistem', doc.functionalStatus));
    }
    if (doc.remediationDeadline != null) {
      constatariWidgets.add(pw.SizedBox(height: 4));
      constatariWidgets.add(ProTermPdfTemplate.buildInfoRow(
          'Termen remediere', _fmt(doc.remediationDeadline!)));
    }
    widgets.add(_redSection('6. Constatări / Observații', constatariWidgets));
    widgets.add(pw.SizedBox(height: 8));

    // 7. Concluzii
    widgets.add(_redSection('7. Concluzii', [
      pw.Text(
        'Pe baza verificărilor și probelor efectuate, sistemul este pus în funcțiune și poate fi '
        'exploatat în regim normal, cu respectarea instrucțiunilor de utilizare și a programului de '
        'mentenanță. Eventualele deficiențe constatate vor fi remediate în termenul stabilit.',
        style: const pw.TextStyle(fontSize: 9),
      ),
    ]));
    widgets.add(pw.SizedBox(height: 8));

    // Anexă — echipamente / materiale puse în funcțiune (poziții selectate)
    final workLinesTable = _buildSelectedWorkLinesTable(
      doc,
      sectionTitle: 'Anexă — echipamente / materiale puse în funcțiune',
      statusHeader: 'Status PIF',
    );
    if (workLinesTable != null) {
      widgets.add(workLinesTable);
      widgets.add(pw.SizedBox(height: 8));
    }

    _appendGarantieSection(widgets);

    return widgets;
  }

  // ── Tabel poziții lucrare verificate (selectate manual cu status) ───────────

  static String _wlText(dynamic raw) => '${raw ?? ''}'.trim();

  static String _wlQty(dynamic raw) {
    if (raw is num) return raw.toStringAsFixed(2);
    final parsed = double.tryParse('${raw ?? ''}'.replaceAll(',', '.'));
    return parsed != null ? parsed.toStringAsFixed(2) : _wlText(raw);
  }

  static pw.Widget? _buildSelectedWorkLinesTable(
    JobSiteDocumentRecord doc, {
    required String sectionTitle,
    required String statusHeader,
  }) {
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

    return _redSection(sectionTitle, [
      pw.SizedBox(height: 4),
      ProTermPdfTemplate.buildTable(
        headers: ['Nr', 'Denumire', 'UM', 'Cantitate', statusHeader, 'Observații'],
        rows: rows,
        columnWidths: [0.06, 0.36, 0.08, 0.13, 0.17, 0.20],
      ),
    ]);
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

}
