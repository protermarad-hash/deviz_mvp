import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/pdf/pdf_font_helper.dart';
import '../../core/pdf/pro_term_pdf_template.dart';
import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONTRACT DE PRESTĂRI SERVICII — generat cu ProTermPdfTemplate
// Articole 1–15 precompletate din datele lucrării
// ─────────────────────────────────────────────────────────────────────────────

class ContractData {
  const ContractData({
    required this.contractNumber,
    required this.contractDate,
    required this.clientName,
    this.clientAddress = '',
    this.clientCui = '',
    this.clientPhone = '',
    required this.jobCode,
    required this.jobTitle,
    required this.location,
    this.teamName = '',
    this.teamMembers = '',
    required this.materialTotal,
    required this.laborTotal,
    required this.vatPercent,
    this.currency = 'RON',
    this.executionTerm = '-',
    this.paymentTerm = '-',
    this.advance = '-',
    this.installments = '-',
    this.penalties = '-',
    this.materialsProvider = 'de stabilit',
    this.logistics = 'de stabilit',
    this.receptionClause = '-',
    this.observations = '',
  });

  final String contractNumber;
  final String contractDate;
  final String clientName;
  final String clientAddress;
  final String clientCui;
  final String clientPhone;
  final String jobCode;
  final String jobTitle;
  final String location;
  final String teamName;
  final String teamMembers;
  final double materialTotal;
  final double laborTotal;
  final double vatPercent;
  final String currency;
  final String executionTerm;
  final String paymentTerm;
  final String advance;
  final String installments;
  final String penalties;
  final String materialsProvider;
  final String logistics;
  final String receptionClause;
  final String observations;

  double get subtotal => materialTotal + laborTotal;
  double get vatAmount => subtotal * vatPercent / 100;
  double get totalWithVat => subtotal + vatAmount;
}

class ContractPdfService {
  const ContractPdfService._();

  static final _moneyFmt = NumberFormat('#,##0.00', 'ro_RO');
  static String _fmt(double v) => _moneyFmt.format(v);
  static String _s(String v) => v.trim().isEmpty ? '-' : v.trim();

  /// Generează PDF și salvează pe disc. Returnează calea fișierului.
  static Future<String> export({
    required AppDataRepository repository,
    required ContractData data,
    bool saveAs = false,
  }) async {
    await PdfFontHelper.initialize();
    final profile = await repository.loadCompanyProfile();
    final branding = DocumentBrandingData.fromCompanyProfile(profile);
    final bytes = await _buildPdfBytes(data, branding);
    final fileName = 'CONTRACT'
        '_${data.contractNumber.trim().isNotEmpty ? data.contractNumber.replaceAll('/', '-') : data.jobCode}'
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
    ContractData d,
    DocumentBrandingData branding,
  ) async {
    return ProTermPdfTemplate.generateDocument(
      branding: branding,
      documentTitle: 'CONTRACT DE PRESTĂRI SERVICII',
      documentNumber: d.contractNumber,
      documentDate: d.contractDate,
      clientName: d.clientName.trim().isEmpty ? null : d.clientName,
      clientAddress: d.clientAddress.trim().isEmpty ? null : d.clientAddress,
      clientCui: d.clientCui.trim().isEmpty ? null : d.clientCui,
      clientPhone: d.clientPhone.trim().isEmpty ? null : d.clientPhone,
      jobCode: d.jobCode,
      jobTitle: d.jobTitle,
      location: d.location,
      teamName: d.teamName.trim().isEmpty ? null : d.teamName,
      technicians: d.teamMembers.trim().isEmpty ? null : d.teamMembers,
      includePartiesSection: true,
      includeJobInfoSection: true,
      includeSignatureSection: true,
      contentWidgets: _buildArticles(d),
    );
  }

  static List<pw.Widget> _buildArticles(ContractData d) {
    final widgets = <pw.Widget>[];

    // ── Art. 1 — Obiectul contractului ──────────────────────────────────────
    widgets.add(ProTermPdfTemplate.buildSection(
      'Art. 1 — Obiectul contractului',
      [
        _para('1.1 Executantul se obligă să execute în favoarea Beneficiarului următoarele lucrări:'),
        _indented('${_s(d.jobTitle)} (Cod: ${_s(d.jobCode)})'),
        _indented('Locație: ${_s(d.location)}'),
        if (d.teamName.trim().isNotEmpty) _indented('Echipă alocată: ${d.teamName}'),
        if (d.teamMembers.trim().isNotEmpty) _indented('Tehnicieni: ${d.teamMembers}'),
      ],
    ));
    widgets.add(pw.SizedBox(height: 6));

    // ── Art. 2 — Prețul contractului ─────────────────────────────────────────
    widgets.add(ProTermPdfTemplate.buildSection(
      'Art. 2 — Prețul contractului',
      [
        _para('2.1 Prețul total convenit pentru execuția lucrărilor este:'),
        pw.SizedBox(height: 4),
        ProTermPdfTemplate.buildTable(
          headers: ['Categorie', 'Valoare (${d.currency})'],
          rows: [
            ['Materiale', _fmt(d.materialTotal)],
            ['Manoperă', _fmt(d.laborTotal)],
            ['Subtotal fără TVA', _fmt(d.subtotal)],
            ['TVA (${d.vatPercent.toStringAsFixed(0)}%)', _fmt(d.vatAmount)],
          ],
          columnWidths: [0.65, 0.35],
          showTotal: true,
          totalLabel: 'TOTAL CU TVA',
          totalValue: '${_fmt(d.totalWithVat)} ${d.currency}',
        ),
        pw.SizedBox(height: 4),
        _para('2.2 Prețul este ferm și nu se poate modifica unilateral.'),
      ],
    ));
    widgets.add(pw.SizedBox(height: 6));

    // ── Art. 3 — Termene și modalități de plată ──────────────────────────────
    widgets.add(ProTermPdfTemplate.buildSection(
      'Art. 3 — Termene și modalități de plată',
      [
        _kv('Avans', _s(d.advance)),
        _kv('Tranșe de plată', _s(d.installments)),
        _kv('Termen de plată', _s(d.paymentTerm)),
        _para('3.1 Plata se efectuează pe baza facturii emise de Executant.'),
      ],
    ));
    widgets.add(pw.SizedBox(height: 6));

    // ── Art. 4 — Durata de execuție ──────────────────────────────────────────
    widgets.add(ProTermPdfTemplate.buildSection(
      'Art. 4 — Durata de execuție',
      [
        _kv('Termen de execuție', _s(d.executionTerm)),
        _para('4.1 Termenele pot fi prelungite prin acord scris al ambelor părți.'),
      ],
    ));
    widgets.add(pw.SizedBox(height: 6));

    // ── Art. 5 — Obligațiile executantului ───────────────────────────────────
    widgets.add(ProTermPdfTemplate.buildSection(
      'Art. 5 — Obligațiile executantului',
      [
        _bullet('Să execute lucrările conform standardelor tehnice aplicabile.'),
        _bullet('Să asigure personal calificat pentru execuția lucrărilor.'),
        _bullet('Să remedieze, pe propria cheltuială, eventualele deficiențe tehnice constatate la recepție.'),
        _bullet('Să respecte normele de protecția muncii și PSI în perioada execuției.'),
        _bullet('Să elibereze documentele de garanție conform legislației în vigoare.'),
      ],
    ));
    widgets.add(pw.SizedBox(height: 6));

    // ── Art. 6 — Obligațiile beneficiarului ─────────────────────────────────
    widgets.add(ProTermPdfTemplate.buildSection(
      'Art. 6 — Obligațiile beneficiarului',
      [
        _bullet('Să asigure accesul Executantului la locul de muncă la termenele convenite.'),
        _bullet('Să achite prețul contractului la termenele stabilite.'),
        _bullet('Să participe la recepția lucrărilor și să semneze documentele aferente.'),
        _bullet('Să nu efectueze intervenții neautorizate asupra instalațiilor executate.'),
      ],
    ));
    widgets.add(pw.SizedBox(height: 6));

    // ── Art. 7 — Materiale, utilaje și logistică ─────────────────────────────
    widgets.add(ProTermPdfTemplate.buildSection(
      'Art. 7 — Materiale, utilaje și logistică',
      [
        _kv('Asigurare materiale', _s(d.materialsProvider)),
        _kv('Utilaje / nacelă / schele', _s(d.logistics)),
        _para('7.1 Orice modificare față de cele de mai sus necesită acord scris.'),
      ],
    ));
    widgets.add(pw.SizedBox(height: 6));

    // ── Art. 8 — Recepția lucrărilor ─────────────────────────────────────────
    widgets.add(ProTermPdfTemplate.buildSection(
      'Art. 8 — Recepția lucrărilor',
      [
        _kv('Clauze recepție', _s(d.receptionClause)),
        _para('8.1 Recepția se consemnează în Procesul-verbal de recepție / PIF semnat de ambele părți.'),
        _para('8.2 Garanția lucrărilor este de 12 luni de la data recepției, dacă nu se convine altfel.'),
      ],
    ));
    widgets.add(pw.SizedBox(height: 6));

    // ── Art. 9 — Forța majoră ────────────────────────────────────────────────
    widgets.add(ProTermPdfTemplate.buildSection(
      'Art. 9 — Forța majoră',
      [
        _para(
          '9.1 Nici una din părți nu răspunde de neexecutarea la termen sau de '
          'executarea în condiții necorespunzătoare a obligațiilor asumate dacă '
          'aceasta se datorează unui caz de forță majoră, confirmat de autoritatea competentă.',
        ),
      ],
    ));
    widgets.add(pw.SizedBox(height: 6));

    // ── Art. 10 — Penalități ─────────────────────────────────────────────────
    widgets.add(ProTermPdfTemplate.buildSection(
      'Art. 10 — Penalități',
      [
        _kv('Clauze penalități', _s(d.penalties)),
        _para(
          '10.1 În cazul nerespectării termenelor de plată, Beneficiarul datorează penalități '
          'de întârziere de 0,1%/zi din suma restantă, dacă nu se convine altfel în scris.',
        ),
      ],
    ));
    widgets.add(pw.SizedBox(height: 6));

    // ── Art. 11 — Modificarea și încetarea contractului ──────────────────────
    widgets.add(ProTermPdfTemplate.buildSection(
      'Art. 11 — Modificarea și încetarea contractului',
      [
        _para('11.1 Contractul poate fi modificat numai prin act adițional semnat de ambele părți.'),
        _para('11.2 Contractul poate înceta prin acordul scris al ambelor părți sau prin reziliere cu notificare prealabilă de 15 zile.'),
      ],
    ));
    widgets.add(pw.SizedBox(height: 6));

    // ── Art. 12 — Litigii ────────────────────────────────────────────────────
    widgets.add(ProTermPdfTemplate.buildSection(
      'Art. 12 — Litigii',
      [
        _para(
          '12.1 Litigiile ivite în legătură cu executarea prezentului contract se soluționează '
          'pe cale amiabilă. În caz de neînțelegere, competența revine instanțelor judecătorești '
          'de la sediul Executantului.',
        ),
      ],
    ));
    widgets.add(pw.SizedBox(height: 6));

    // ── Art. 13 — Dispoziții finale ──────────────────────────────────────────
    widgets.add(ProTermPdfTemplate.buildSection(
      'Art. 13 — Dispoziții finale',
      [
        _para('13.1 Prezentul contract a fost încheiat în două exemplare originale, câte unul pentru fiecare parte.'),
        _para('13.2 Prevederile prezentului contract se completează cu dispozițiile Codului Civil.'),
        if (d.observations.trim().isNotEmpty) ...[
          pw.SizedBox(height: 4),
          _kv('Observații suplimentare', d.observations.trim()),
        ],
      ],
    ));

    return widgets;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static pw.Widget _para(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  static pw.Widget _indented(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 12, bottom: 2),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _bullet(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('• ', style: const pw.TextStyle(fontSize: 9)),
          pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 9))),
        ],
      ),
    );
  }

  static pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 160,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }
}
