import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/company_profile.dart';
import '../../../core/pdf/pdf_font_helper.dart';
import '../../../core/pdf/pro_term_pdf_template.dart';
import '../../../core/pdf_document_branding.dart';
import '../../../core/pdf_export_settings.dart';
import '../../../core/pdf_save_service.dart';
import '../../../core/repositories/app_data_repository.dart';
import '../../clients/client_models.dart';
import '../mentenanta_models.dart';
import 'contract_clauze.dart';

/// Generează PDF-ul complet al contractului de prestări servicii mentenanță.
///
/// Folosește același sistem de template ca documentele PV/PIF
/// (ProTermPdfTemplate: header cu logo, headere secțiuni roșii #C62828,
/// footer per pagină, semnături pe 2 coloane).
/// Pagina 1 = contractul (11 secțiuni + semnături), Pagina 2 = Anexa 1
/// (lista echipamentelor, identică cu oferta).
class ContractPdfService {
  const ContractPdfService._();

  static const PdfColor _primaryRed = PdfColor(0.7765, 0.1569, 0.1569);
  static const PdfColor _lightGray = PdfColor(0.9608, 0.9608, 0.9608);
  static const PdfColor _borderGray = PdfColor(0.8, 0.8, 0.8);
  static const PdfColor _lightRed = PdfColor(1.0, 0.9216, 0.9333);
  static const PdfColor _grey = PdfColor.fromInt(0xFF757575);

  static final NumberFormat _money = NumberFormat('#,##0.00', 'ro_RO');
  static final DateFormat _dateFmt = DateFormat('dd.MM.yyyy');

  /// Prag de siguranță pentru logo. Headerul se redesenează pe FIECARE pagină
  /// (callback `header:`) și MultiPage face mai multe treceri de layout — un
  /// logo prea mare se re-decodează de multe ori și poate epuiza memoria.
  /// Dacă logoul depășește pragul, este omis din contract (documentul se
  /// generează oricum, fără logo).
  static const int _maxLogoBytes = 300 * 1024;

  static Future<String> export({
    required AppDataRepository repository,
    required ContractMentenanta contract,
    bool forceSaveAs = false,
    String outputDirectory = '',
  }) async {
    await PdfFontHelper.initialize();

    CompanyProfile profile;
    try {
      profile = await repository.loadCompanyProfile();
    } catch (_) {
      profile = const CompanyProfile();
    }
    final branding = DocumentBrandingData.fromCompanyProfile(profile);

    // Date beneficiar (best-effort din lista de clienți).
    ClientRecord? client;
    try {
      final clients = await repository.listClients();
      client =
          clients.where((c) => c.id == contract.clientId).firstOrNull;
    } catch (_) {
      client = null;
    }

    final bytes = await _buildBytes(contract, branding, client);

    final numarSafe = contract.numar.isEmpty
        ? 'CM'
        : contract.numar.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'Contract_Mentenanta_${numarSafe}_$stamp.pdf';

    return PdfSaveService.savePdf(
      repository: repository,
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
      category: PdfDocumentCategory.offers,
      outputDirectory: outputDirectory,
      forceSaveAs: forceSaveAs,
    );
  }

  // ── Construire document ───────────────────────────────────────────────────

  static Future<Uint8List> _buildBytes(
    ContractMentenanta contract,
    DocumentBrandingData branding,
    ClientRecord? client,
  ) async {
    final doc = pw.Document(theme: PdfFontHelper.theme);
    final dateStr = _dateFmt.format(DateTime.now());
    final footerTitle =
        'CONTRACT PRESTĂRI SERVICII ${contract.numar}'.trim();

    // Branding sigur pentru header: dacă logoul e prea mare sau invalid,
    // îl omitem ca să nu fie re-decodat pe fiecare pagină → risc OOM.
    final headerBranding = _safeBrandingForHeader(branding);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        header: (_) => pw.Column(children: [
          ProTermPdfTemplate.buildHeader(
            branding: headerBranding,
            documentTitle: 'CONTRACT DE PRESTĂRI SERVICII',
            documentNumber: contract.numar,
            documentDate: dateStr,
          ),
          pw.SizedBox(height: 8),
        ]),
        footer: (ctx) => ProTermPdfTemplate.buildPageFooter(
          documentTitle: footerTitle,
          pageNumber: ctx.pageNumber,
          totalPages: ctx.pagesCount,
          date: dateStr,
        ),
        build: (_) => [
          ..._contractContent(contract, branding, client, dateStr),
          pw.NewPage(),
          ..._anexaContent(contract),
        ],
      ),
    );

    return doc.save();
  }

  /// Returnează un branding cu logoul păstrat doar dacă este valid și sub prag.
  /// Altfel logoul este eliminat (header fără logo), pentru a evita re-decodarea
  /// repetată a unei imagini mari pe fiecare pagină (cauză de Out of Memory).
  static DocumentBrandingData _safeBrandingForHeader(
    DocumentBrandingData b,
  ) {
    final logo = b.logoBytes;
    if (logo == null || logo.lengthInBytes <= _maxLogoBytes) {
      return b;
    }
    return DocumentBrandingData(
      companyName: b.companyName,
      address: b.address,
      city: b.city,
      county: b.county,
      phone: b.phone,
      email: b.email,
      contactEmail: b.contactEmail,
      website: b.website,
      cui: b.cui,
      tradeRegister: b.tradeRegister,
      bank: b.bank,
      iban: b.iban,
      contactName: b.contactName,
      currency: b.currency,
      logoBytes: null,
    );
  }

  // ── PAGINA 1 — Contractul ─────────────────────────────────────────────────

  static List<pw.Widget> _contractContent(
    ContractMentenanta contract,
    DocumentBrandingData branding,
    ClientRecord? client,
    String dateStr,
  ) {
    // IMPORTANT: secțiunile sunt emise ca widget-uri INDIVIDUALE (header roșu +
    // paragrafe/bullet-uri separate), NU împachetate într-un pw.Container cu
    // bordură. Un Container/Column decorat este ATOMIC pentru pw.MultiPage —
    // nu poate fi împărțit între pagini. Dacă o secțiune cu text juridic lung
    // (5, 6, 7, 8) depășește înălțimea unei pagini, MultiPage intră în buclă de
    // layout și consumă memoria exponențial → "Out of Memory". Emise plat,
    // MultiPage poate insera page-break între orice paragraf.
    final w = <pw.Widget>[];

    // 1. Părți contractante
    w.add(_sectionHeader('1. PĂRȚI CONTRACTANTE'));
    w.add(_partiesRow(branding, contract, client));
    w.add(_gap());

    // 2. Obiectul contractului
    w.add(_sectionHeader('2. OBIECTUL CONTRACTULUI'));
    w.add(_para(ContractClauze.obiect));
    w.add(_gap());

    // 3. Durata contractului
    final interv = contract.interventiiPlanificate;
    w.add(_sectionHeader('3. DURATA CONTRACTULUI'));
    w.add(_para(
        'Prezentul contract se încheie pe o perioadă de 12 luni, începând '
        'cu ${_dateFmt.format(contract.dataStart)} și până la '
        '${_dateFmt.format(contract.dataEnd)}.'));
    w.add(_para(ContractClauze.durataPrelungire));
    w.add(_para('Număr intervenții planificate: $interv/an.'));
    w.add(_gap());

    // 4. Prețul și modalitatea de plată
    w.add(_sectionHeader('4. PREȚUL ȘI MODALITATEA DE PLATĂ'));
    w.add(_totaluri(contract));
    w.add(pw.SizedBox(height: 6));
    w.add(_para(ContractClauze.plata));
    w.add(_gap());

    // 5. Obligațiile Prestatorului
    w.add(_sectionHeader('5. OBLIGAȚIILE PRESTATORULUI'));
    w.addAll(_bullets(ContractClauze.obligatiiPrestator));
    w.add(_gap());

    // 6. Obligațiile Beneficiarului
    w.add(_sectionHeader('6. OBLIGAȚIILE BENEFICIARULUI'));
    w.addAll(_bullets(ContractClauze.obligatiiBeneficiar));
    w.add(_gap());

    // 7. Clauze speciale echipamente vechi
    w.add(_sectionHeader('7. CLAUZE SPECIALE ECHIPAMENTE VECHI'));
    w.addAll(ContractClauze.clauzeSpeciale.map(_para));
    w.add(_gap());

    // 8. Răspundere și forță majoră
    w.add(_sectionHeader('8. RĂSPUNDERE ȘI FORȚĂ MAJORĂ'));
    w.addAll(ContractClauze.raspundere.map(_para));
    w.add(_gap());

    // 9. Confidențialitate și GDPR
    w.add(_sectionHeader('9. CONFIDENȚIALITATE ȘI GDPR'));
    w.add(_para(ContractClauze.confidentialitate));
    w.add(_gap());

    // 10. Litigii
    w.add(_sectionHeader('10. LITIGII'));
    w.add(_para(ContractClauze.litigii));
    w.add(_gap());

    // 11. Dispoziții finale
    w.add(_sectionHeader('11. DISPOZIȚII FINALE'));
    w.add(_para(ContractClauze.dispozitiiFinale));
    w.add(pw.SizedBox(height: 16));

    // Semnături (identic cu PV/PIF)
    w.add(ProTermPdfTemplate.buildSignatureSection(
      executantName: branding.companyName.isEmpty
          ? ContractClauze.prestatorNume
          : branding.companyName,
      clientName: contract.clientName.isEmpty ? '—' : contract.clientName,
      date: dateStr,
    ));

    return w;
  }

  // ── Bloc părți (2 coloane: Prestator | Beneficiar) ────────────────────────

  static pw.Widget _partiesRow(
    DocumentBrandingData branding,
    ContractMentenanta contract,
    ClientRecord? client,
  ) {
    final prestator = <String>[
      branding.companyName.isEmpty
          ? ContractClauze.prestatorNume
          : branding.companyName,
      'CUI: ${branding.cui.isEmpty ? ContractClauze.prestatorCui : branding.cui}',
      'RC: ${branding.tradeRegister.isEmpty ? ContractClauze.prestatorRc : branding.tradeRegister}',
      'Sediu: ${branding.fullAddress.isEmpty ? ContractClauze.prestatorSediu : branding.fullAddress}',
      'Tel: ${branding.phone.isEmpty ? ContractClauze.prestatorTel : branding.phone}',
      'Email: ${branding.email.isEmpty ? ContractClauze.prestatorEmail : branding.email}',
      'Reprezentant: ${branding.contactName.isEmpty ? ContractClauze.prestatorReprezentant : branding.contactName}',
    ];

    final benef = <String>[
      contract.clientName.isEmpty ? '—' : contract.clientName,
      if (client != null && client.cui.trim().isNotEmpty)
        'CUI/CNP: ${client.cui}',
      if (client != null && client.regCom.trim().isNotEmpty)
        'RC: ${client.regCom}',
      if (client != null && _clientAddress(client).isNotEmpty)
        'Sediu: ${_clientAddress(client)}',
      if (client != null && client.allPhoneNumbers.isNotEmpty)
        'Tel: ${client.allPhoneNumbers.first}',
      if (client != null && client.email.trim().isNotEmpty)
        'Email: ${client.email}',
    ];

    // pw.Table (nu pw.Row cu CrossAxisAlignment.stretch): un Row cu `stretch`
    // plasat direct în lista build: a unui MultiPage primește înălțime
    // nemărginită → copiii (în special divider-ul fără înălțime) cer înălțime
    // Infinity → "Widget won't fit ... height (Infinity)". Tabelul are înălțime
    // finită, egalizează automat cele două celule și păstrează caseta +
    // divider-ul vertical prin TableBorder.
    return pw.Table(
      border: pw.TableBorder.all(color: _borderGray, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(children: [
          _partyCol('PRESTATOR', prestator),
          _partyCol('BENEFICIAR', benef),
        ]),
      ],
    );
  }

  static pw.Widget _partyCol(String title, List<String> lines) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: _primaryRed)),
          pw.SizedBox(height: 3),
          ...lines.map((l) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 1.5),
                child: pw.Text(l, style: const pw.TextStyle(fontSize: 8.5)),
              )),
        ],
      ),
    );
  }

  static String _clientAddress(ClientRecord c) {
    return [c.address, c.city, c.county]
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  // ── Totaluri (secțiunea 4) ────────────────────────────────────────────────

  static pw.Widget _totaluri(ContractMentenanta contract) {
    pw.Widget row(String label, String value, {bool big = false}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: pw.BoxDecoration(color: big ? _primaryRed : null),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: big ? 10 : 9,
                    color: big ? PdfColors.white : PdfColors.black)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: big ? 10 : 9,
                    color: big ? PdfColors.white : PdfColors.black)),
          ],
        ),
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGray, width: 0.5),
      ),
      child: pw.Column(children: [
        row('Total servicii fără TVA',
            '${_money.format(contract.totalFaraTVA)} RON'),
        row('TVA 21%', '${_money.format(contract.tva)} RON'),
        row('TOTAL CU TVA', '${_money.format(contract.totalCuTVA)} RON',
            big: true),
      ]),
    );
  }

  // ── PAGINA 2 — Anexa 1 (lista echipamentelor) ─────────────────────────────

  static List<pw.Widget> _anexaContent(ContractMentenanta contract) {
    final w = <pw.Widget>[
      pw.Text('ANEXA 1 la Contractul nr. ${contract.numar} / '
          '${_dateFmt.format(DateTime.now())}',
          style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, fontSize: 12, color: _primaryRed)),
      pw.SizedBox(height: 2),
      pw.Text('Lista echipamentelor care fac obiectul contractului',
          style: const pw.TextStyle(fontSize: 9, color: _grey)),
      pw.SizedBox(height: 8),
    ];
    w.addAll(_anexaTable(contract));
    w.add(pw.SizedBox(height: 10));
    w.add(pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(width: 260, child: _totaluri(contract)),
    ));
    return w;
  }

  // Lățimi coloane (identice cu oferta_mentenanta_pdf_service).
  static final Map<int, pw.TableColumnWidth> _colWidths = {
    0: const pw.FlexColumnWidth(0.5),
    1: const pw.FlexColumnWidth(2.2),
    2: const pw.FlexColumnWidth(2.4),
    3: const pw.FlexColumnWidth(0.6),
    4: const pw.FlexColumnWidth(0.7),
    5: const pw.FlexColumnWidth(1.1),
    6: const pw.FlexColumnWidth(1.1),
    7: const pw.FlexColumnWidth(1.1),
    8: const pw.FlexColumnWidth(1.2),
    9: const pw.FlexColumnWidth(1.6),
  };

  static pw.Widget _tcell(String text,
      {bool bold = false,
      PdfColor color = PdfColors.black,
      double size = 7.5,
      pw.Alignment align = pw.Alignment.centerLeft,
      PdfColor? bg}) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      alignment: align,
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: size,
              color: color,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  static List<pw.Widget> _anexaTable(ContractMentenanta contract) {
    pw.TableRow headerRow() {
      pw.Widget h(String t, {pw.Alignment a = pw.Alignment.center}) =>
          _tcell(t, bold: true, color: PdfColors.white, size: 7.5, align: a, bg: _primaryRed);
      return pw.TableRow(children: [
        h('Nr'),
        h('Tip echipament', a: pw.Alignment.centerLeft),
        h('Model / Descriere', a: pw.Alignment.centerLeft),
        h('UM'),
        h('Cant'),
        h('Preț unit.\nIgienizare'),
        h('Preț unit.\nRevizie teh.'),
        h('Preț unit.\nTOTAL'),
        h('Valoare\nTOTAL'),
        h('Observații', a: pw.Alignment.centerLeft),
      ]);
    }

    pw.TableRow dataRow(EchipamentMentenanta e) {
      return pw.TableRow(children: [
        _tcell('${e.nrCrt}', align: pw.Alignment.center),
        _tcell(e.tipEchipament),
        _tcell(e.model),
        _tcell(e.um, align: pw.Alignment.center),
        _tcell(_money.format(e.cantitate), align: pw.Alignment.center),
        _tcell(_money.format(e.pretIgienizare), align: pw.Alignment.centerRight),
        _tcell(_money.format(e.pretRevizie), align: pw.Alignment.centerRight),
        _tcell(_money.format(e.pretTotal), align: pw.Alignment.centerRight),
        _tcell(_money.format(e.valoareTotala),
            bold: true, align: pw.Alignment.centerRight),
        _tcell(e.necesitaLogFGas
            ? (e.observatii.isEmpty ? 'Log F-Gas' : '${e.observatii} • Log F-Gas')
            : e.observatii),
      ]);
    }

    pw.TableRow subtotalRow(CategorieMentenanta cat, double subtotal) {
      return pw.TableRow(
        decoration: const pw.BoxDecoration(color: _lightRed),
        children: [
          _tcell('', bg: _lightRed),
          _tcell('Subtotal ${cat.label}', bold: true, bg: _lightRed),
          for (var i = 0; i < 6; i++) _tcell('', bg: _lightRed),
          _tcell(_money.format(subtotal),
              bold: true, align: pw.Alignment.centerRight, bg: _lightRed),
          _tcell('', bg: _lightRed),
        ],
      );
    }

    // Banner categorie pe toată lățimea (nu rupt litera-cu-litera).
    pw.Widget categoryBanner(CategorieMentenanta cat) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: pw.BoxDecoration(
          color: _lightGray,
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
        alignment: pw.Alignment.center,
        child: pw.Text('── SISTEM ${cat.label.toUpperCase()} ──',
            style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _primaryRed)),
      );
    }

    final widgets = <pw.Widget>[
      pw.Table(
        columnWidths: _colWidths,
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        children: [headerRow()],
      ),
    ];
    contract.echipamenteGrupate.forEach((cat, items) {
      widgets.add(categoryBanner(cat));
      final rows = <pw.TableRow>[];
      for (final e in items) {
        rows.add(dataRow(e));
      }
      final subtotal = items.fold<double>(0, (s, e) => s + e.valoareTotala);
      rows.add(subtotalRow(cat, subtotal));
      widgets.add(pw.Table(
        columnWidths: _colWidths,
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        children: rows,
      ));
    });
    return widgets;
  }

  // ── Helpers UI ────────────────────────────────────────────────────────────

  static pw.Widget _gap() => pw.SizedBox(height: 8);

  /// Bară de titlu secțiune (header roșu full-width, stil PV/PIF).
  /// Emisă ca widget INDEPENDENT — conținutul secțiunii urmează ca paragrafe
  /// separate, ca MultiPage să poată insera page-break oriunde. NU împacheta
  /// conținutul secțiunii într-un Container cu bordură (devine atomic → OOM).
  static pw.Widget _sectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const pw.BoxDecoration(
        color: _primaryRed,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(title,
          style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9)),
    );
  }

  static pw.Widget _para(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Text(text,
          style: const pw.TextStyle(fontSize: 9),
          textAlign: pw.TextAlign.justify),
    );
  }

  static List<pw.Widget> _bullets(List<String> items) {
    return items
        .map((t) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('•  ', style: const pw.TextStyle(fontSize: 9)),
                  pw.Expanded(
                    child: pw.Text(t,
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.justify),
                  ),
                ],
              ),
            ))
        .toList();
  }
}
