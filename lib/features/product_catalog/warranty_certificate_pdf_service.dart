import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/pdf/pdf_font_helper.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'product_sales_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Certificat garanție — 2 pagini A4 portrait, margini 8mm
//   Pagina 1: date document (rânduri 1-6) + 3 taloane intervenție
//   Pagina 2: condiții complete garanție OG 21/1992
// ─────────────────────────────────────────────────────────────────────────────

class WarrantyCertificatePdfService {
  const WarrantyCertificatePdfService._();

  static const _red = PdfColor(0.7765, 0.1569, 0.1569);
  static const _grayBg = PdfColor(0.90, 0.90, 0.90);
  static const _bSide = pw.BorderSide(color: PdfColors.black, width: 0.5);

  // Margini 8mm = 22.68pt → 23pt
  static const double _margin = 23;
  // Padding celule: 3pt
  static const double _pad = 3;
  // Coloana dreaptă semnătură în rânduri 2-4
  static const double _sigW = 140;
  // Spațiu semnătură rânduri 2-4: 30pt ≈ 10.6mm
  static const double _sigH = 30;
  // Spațiu semnătură taloane: 40pt ≈ 14mm
  static const double _talonSigH = 40;

  // ─── Generare bytes (fără salvare pe disc) ────────────────────────────────

  static Future<Uint8List> generateBytes(
      WarrantyCertificateRecord certificate) async {
    await PdfFontHelper.initialize();
    final doc = pw.Document(theme: PdfFontHelper.theme);
    doc.addPage(_pageDataAndTalone(certificate));
    doc.addPage(_pageConditions());
    return doc.save();
  }

  // ─── Export cu salvare pe disc ────────────────────────────────────────────

  static Future<String> export({
    required AppDataRepository repository,
    required WarrantyCertificateRecord certificate,
    String outputDirectory = '',
    bool saveAs = false,
  }) async {
    final bytes = await generateBytes(certificate);

    final safeNum = certificate.fullCertificateNumber
        .replaceAll(RegExp(r'[^A-Za-z0-9_\- ]+'), '_')
        .replaceAll(' ', '_');
    final safeId = certificate.id
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .substring(0, certificate.id.length.clamp(0, 8));
    final baseName =
        safeNum.isEmpty ? safeId : '${safeNum}_$safeId';
    final fileName = 'certificat_garantie_$baseName.pdf';

    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: fileName,
      category: PdfDocumentCategory.other,
      outputDirectory: outputDirectory,
      forceSaveAs: saveAs,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGINA 1 — date document + 3 taloane
  // ─────────────────────────────────────────────────────────────────────────

  static pw.Page _pageDataAndTalone(WarrantyCertificateRecord c) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(_margin),
      build: (_) {
        final bold = PdfFontHelper.bold;
        final reg = PdfFontHelper.regular;

        final certNum = c.fullCertificateNumber.trim().isEmpty
            ? '-'
            : c.fullCertificateNumber.trim();
        final year = (c.documentDate?.year ??
                c.saleDate?.year ??
                DateTime.now().year)
            .toString();

        final sellerName = c.sellerName.trim().isEmpty
            ? 'S.C PRO TERM S.R.L'
            : c.sellerName.trim();
        final sellerAddr = c.sellerAddress.trim().isEmpty
            ? 'ARAD, ALEEA NEPTUN Nr.4, Bl.Y3, Ap.31'
            : c.sellerAddress.trim();
        final sellerCui = c.sellerTaxId.trim().isEmpty
            ? 'RO11355602'
            : c.sellerTaxId.trim();
        final sellerEmail = c.sellerEmail.trim().isEmpty
            ? 'proterm.arad@gmail.com'
            : c.sellerEmail.trim();
        final sellerPhone = c.sellerPhone.trim().isEmpty
            ? '0749025610'
            : c.sellerPhone.trim();
        final installerCui = c.installerTaxId.trim().isEmpty
            ? 'RO'
            : c.installerTaxId.trim();

        pw.TextStyle ts8(pw.Font f) =>
            pw.TextStyle(font: f, fontSize: 8);

        pw.Widget r1(String label, String value,
            {bool boldVal = false}) {
          return pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: label, style: ts8(bold)),
              pw.TextSpan(
                  text: value.trim().isEmpty ? '-' : value.trim(),
                  style: ts8(boldVal ? bold : reg)),
            ]),
          );
        }

        pw.Widget r2(String l1, String v1, String l2, String v2) {
          return pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: l1, style: ts8(bold)),
              pw.TextSpan(
                  text: v1.trim().isEmpty ? '-' : v1.trim(),
                  style: ts8(reg)),
              pw.TextSpan(text: l2, style: ts8(bold)),
              pw.TextSpan(
                  text: v2.trim().isEmpty ? '-' : v2.trim(),
                  style: ts8(reg)),
            ]),
          );
        }

        pw.Widget r3(String l1, String v1, String l2, String v2,
            String l3, String v3) {
          return pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: l1, style: ts8(bold)),
              pw.TextSpan(
                  text: v1.trim().isEmpty ? '-' : v1.trim(),
                  style: ts8(reg)),
              pw.TextSpan(text: l2, style: ts8(bold)),
              pw.TextSpan(
                  text: v2.trim().isEmpty ? '-' : v2.trim(),
                  style: ts8(reg)),
              pw.TextSpan(text: l3, style: ts8(bold)),
              pw.TextSpan(
                  text: v3.trim().isEmpty ? '-' : v3.trim(),
                  style: ts8(reg)),
            ]),
          );
        }

        pw.Widget sigRight(String firstLine) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(_pad),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(firstLine, style: ts8(reg)),
                pw.SizedBox(height: 2),
                pw.Text('Semnatura/Stampila:', style: ts8(reg)),
                pw.SizedBox(height: _sigH),
              ],
            ),
          );
        }

        const colWidths = <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(1),
          1: pw.FixedColumnWidth(_sigW),
        };
        const borderFull = pw.TableBorder(
          top: _bSide,
          left: _bSide,
          right: _bSide,
          bottom: _bSide,
        );
        const borderMid = pw.TableBorder(
          left: _bSide,
          right: _bSide,
          bottom: _bSide,
          verticalInside: _bSide,
        );
        const borderNoTop = pw.TableBorder(
          left: _bSide,
          right: _bSide,
          bottom: _bSide,
        );

        final tickets = c.warrantyServiceTickets;
        final t3 = tickets.length > 2 ? tickets[2] : null;
        final t2 = tickets.length > 1 ? tickets[1] : null;
        final t1 = tickets.isNotEmpty ? tickets[0] : null;

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.SizedBox(
                  width: 120,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('S.C PRO TERM S.R.L',
                          style: pw.TextStyle(font: bold, fontSize: 9)),
                      pw.Text('www.frigoterm.ro',
                          style: pw.TextStyle(font: reg, fontSize: 7.5)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    'CERTIFICAT DE GARANTIE SERIA PRO, NR. $certNum / $year',
                    style: pw.TextStyle(
                        font: bold, fontSize: 11, color: _red),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(width: 120),
              ],
            ),
            pw.SizedBox(height: 3),
            pw.Container(height: 1.5, color: _red),
            pw.SizedBox(height: 3),

            // ── Rand 1: Echipament ────────────────────────────────────
            pw.Table(
              border: borderFull,
              children: [
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(_pad),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        r1('1. Echipament: ', c.equipmentType,
                            boldVal: true),
                        pw.SizedBox(height: 1),
                        r2('Serie UI: ', c.serialNumberIndoor,
                            '   Factura/bon nr.: ', c.invoiceNumber),
                        pw.SizedBox(height: 1),
                        r3('Marca: ', c.brand,
                            '   Serie UE: ', c.serialNumberOutdoor,
                            '   Din data: ', _dl(c.saleDate)),
                        pw.SizedBox(height: 1),
                        r2('Model: ', c.model,
                            '   Garantie (luni): ',
                            '${c.warrantyMonths} UI+UE compresor'),
                      ],
                    ),
                  ),
                ]),
              ],
            ),

            // ── Rand 2: Vanzator ──────────────────────────────────────
            pw.Table(
              border: borderMid,
              columnWidths: colWidths,
              children: [
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(_pad),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        r1('2. Vanzator   ', sellerName, boldVal: true),
                        pw.SizedBox(height: 1),
                        r1('Adresa: ', sellerAddr),
                        pw.SizedBox(height: 1),
                        r2('Email: ', sellerEmail,
                            '   Tel: ', sellerPhone),
                      ],
                    ),
                  ),
                  sigRight('CUI: $sellerCui'),
                ]),
              ],
            ),

            // ── Rand 3: Cumparator ────────────────────────────────────
            pw.Table(
              border: borderMid,
              columnWidths: colWidths,
              children: [
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(_pad),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        r1('3. Cumparator   ', c.buyerName,
                            boldVal: true),
                        pw.SizedBox(height: 1),
                        r1('Adresa: ', c.buyerAddress),
                        pw.SizedBox(height: 1),
                        r1('Telefon/Fax: ', c.buyerPhone),
                      ],
                    ),
                  ),
                  sigRight(
                      'CUI/CNP: ${c.buyerTaxOrCnp.trim().isEmpty ? "-" : c.buyerTaxOrCnp.trim()}'),
                ]),
              ],
            ),

            // ── Rand 4: Instalator ────────────────────────────────────
            pw.Table(
              border: borderMid,
              columnWidths: colWidths,
              children: [
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(_pad),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                            '4. Instalator/Centru service in garantie:',
                            style: ts8(bold)),
                        pw.SizedBox(height: 1),
                        r2('Adresa: ', c.installerAddress,
                            '   Email: ', c.installerEmail),
                        pw.SizedBox(height: 1),
                        r1('Tel: ', c.installerPhone),
                      ],
                    ),
                  ),
                  sigRight('CUI: $installerCui'),
                ]),
              ],
            ),

            // ── Rand 5: Persoane instalare ────────────────────────────
            pw.Table(
              border: borderMid,
              columnWidths: colWidths,
              children: [
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(_pad),
                    child: pw.Text(
                      'Numele persoanelor care au efectuat instalarea/reparatia:'
                      ' 1________ 2________',
                      style: ts8(reg),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(_pad),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                            '(se completeaza de client) Data instalarii: ............',
                            style: pw.TextStyle(font: reg, fontSize: 7)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                            'Cumparatorul va solicite instalatorului'
                            ' nr. de inregistrare pentru programare.',
                            style: pw.TextStyle(font: reg, fontSize: 6.5)),
                      ],
                    ),
                  ),
                ]),
              ],
            ),

            // ── Rand 6: Text legal ────────────────────────────────────
            pw.Table(
              border: borderNoTop,
              children: [
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(_pad),
                    child: pw.Text(
                      _legalText,
                      style: pw.TextStyle(font: reg, fontSize: 6.5),
                    ),
                  ),
                ]),
              ],
            ),

            pw.SizedBox(height: 3),

            // ── 3 Taloane de interventie ──────────────────────────────
            _talonWidget(bold, reg, 3, t3, c),
            pw.SizedBox(height: 3),
            _dottedLine(reg),
            pw.SizedBox(height: 3),
            _talonWidget(bold, reg, 2, t2, c),
            pw.SizedBox(height: 3),
            _dottedLine(reg),
            pw.SizedBox(height: 3),
            _talonWidget(bold, reg, 1, t1, c),
          ],
        );
      },
    );
  }

  static pw.Widget _dottedLine(pw.Font reg) {
    return pw.Text(
      '- - - - - - - - - - - - - - - - - - - - - - - - - - - - '
      '- - - - - - - - - - - - - - - - - - - - - - - - - - - -',
      style: pw.TextStyle(
          font: reg, fontSize: 7, color: PdfColors.grey600),
    );
  }

  static pw.Widget _talonWidget(
    pw.Font bold,
    pw.Font reg,
    int nr,
    WarrantyServiceTicketRecord? ticket,
    WarrantyCertificateRecord c,
  ) {
    final sellerName = c.sellerName.trim().isEmpty
        ? 'S.C PRO TERM S.R.L'
        : c.sellerName.trim();
    final model = [c.brand.trim(), c.model.trim()]
        .where((s) => s.isNotEmpty)
        .join(' ');

    String slot(String? v) =>
        (v == null || v.trim().isEmpty) ? '......' : v.trim();

    String dateSl(DateTime? d) {
      if (d == null) return 'Ziua...... Luna...... An......';
      return 'Ziua ${d.day.toString().padLeft(2, '0')} '
          'Luna ${d.month.toString().padLeft(2, '0')} An ${d.year}';
    }

    pw.TextStyle ts(double sz) =>
        pw.TextStyle(font: reg, fontSize: sz);

    pw.Widget line(String text) =>
        pw.Text(text, style: ts(7.5));

    return pw.Table(
      border: const pw.TableBorder(
        top: _bSide,
        left: _bSide,
        right: _bSide,
        bottom: _bSide,
        verticalInside: _bSide,
      ),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _grayBg),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: _pad, vertical: 2),
              child: pw.Text('Talon nr. $nr',
                  style:
                      pw.TextStyle(font: bold, fontSize: 8)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: _pad, vertical: 2),
              child: pw.Text(
                  'Talon de interventie in garantie nr. $nr',
                  style:
                      pw.TextStyle(font: bold, fontSize: 8)),
            ),
          ],
        ),
        // Continut
        pw.TableRow(children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(_pad),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                line('Data primirii: ${dateSl(ticket?.receivedDate)}'),
                pw.SizedBox(height: 2),
                line('Data terminarii: ${dateSl(ticket?.completedDate)}'),
                pw.SizedBox(height: 2),
                line('Defect: ${slot(ticket?.defect)}'),
                pw.SizedBox(height: 2),
                line('Descriere: .................................'),
                pw.SizedBox(height: 2),
                line('Nr. fisa service: ${slot(ticket?.repairReportNumber)}'),
                pw.SizedBox(height: 2),
                line('Semnatura si stampila service:'),
                pw.SizedBox(height: _talonSigH),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(_pad),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                line('Model aparat: ${model.isEmpty ? "........................." : model}'),
                pw.SizedBox(height: 2),
                line('Nr. A .......................'),
                pw.SizedBox(height: 2),
                line('Serie: UI ${slot(c.serialNumberIndoor.isEmpty ? null : c.serialNumberIndoor)}'
                    '  UE ${slot(c.serialNumberOutdoor.isEmpty ? null : c.serialNumberOutdoor)}'),
                pw.SizedBox(height: 2),
                line('Data vanzarii: ${dateSl(c.saleDate)}'),
                pw.SizedBox(height: 2),
                line('Vanzator: $sellerName'),
                pw.SizedBox(height: 2),
                line('Semnatura si stampila service:'),
                pw.SizedBox(height: _talonSigH),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGINA 2 — condiții de garanție
  // ─────────────────────────────────────────────────────────────────────────

  static pw.Page _pageConditions() {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(_margin),
      build: (_) {
        final bold = PdfFontHelper.bold;
        final reg = PdfFontHelper.regular;

        pw.Widget para(String text, {bool isBold = false}) =>
            pw.Text(text,
                style: pw.TextStyle(
                    font: isBold ? bold : reg, fontSize: 7.5));

        final sp = pw.SizedBox(height: 3);

        return pw.Table(
          border: const pw.TableBorder(
            top: _bSide,
            left: _bSide,
            right: _bSide,
            bottom: _bSide,
            horizontalInside: _bSide,
          ),
          children: [
            // Titlu
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _grayBg),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: _pad, vertical: 4),
                  child: pw.Text(
                    'CONDITII DE GARANTIE',
                    style:
                        pw.TextStyle(font: bold, fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
            // Continut
            pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(_pad + 1),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    para('Conditiile de garantie se asigura in conformitate cu prevederile OG 21/1992 modificata si Legea 449/12.11.2003 republicata, privind securitatea produselor, a HG 394/1995 republicata si cu prevederile Legii 449/2003.'),
                    sp,
                    para('Produsele au fost proiectate si fabricate pentru a fi utilizate exclusiv in scopul prevazut in documentatia tehnica, in conditii climatice normale specifice zonei geografice in care au fost cumparate.'),
                    sp,
                    para('Garantia nu este acordata in cazul in care nu se vor respecta datele obtinute in urma calculului termic (valoarea puterii termice necesara incalzirii sau racirii unui spatiu calculata la temperatura exterioara de proiect de catre personal autorizat), iar produsul achizitionat nu corespunde cu datele obtinute.'),
                    sp,
                    para('Cumparatorul are obligatia de a pastra certificatul de garantie pe toata durata perioadei de garantie. In caz de necesitate (service in garantie), cumparatorul va prezenta atat cartea tehnica a echipamentului, cat si prezentul certificat de garantie. In lipsa acestora garantia nu este valabila.'),
                    sp,
                    para('Durata medie de utilizare a produsului este de 5 ani.'),
                    sp,
                    para('Urmatoarele situatii duc in mod express la pierderea garantiei: interventii sau reparatii executate de persoane neautorizate de importator; deteriorarea termica, chimica sau mecanica a produsului; neasigurarea curatarii sau intretinerii; nerespectarea conditiilor de transport, manipulare sau instalare; utilizarea produsului in alte scopuri decat cele destinate sau in conditii de temperatura sau umiditate mai mari decat cele admise; utilizarea de accesorii neomologate de catre producator; deteriorarile provocate de animale, rozatoare, insecte sau alte fiinte vii; daune cauzate de calamitati naturale sau de factori externi (fulgere, inundatii, incendii, cataclisme, etc.); reconditionate sau la care seria a fost indepartata sau modificata.'),
                    sp,
                    para('Importatorul va asigura cumparatorului atat pe durata de fabricatie, cat si dupa incetarea fabricatiei, pentru o perioada de 5 ani de la data incetarii fabricatiei produsului, disponibilitatea pieselor de schimb si asigurarea serviciilor de reparatii.'),
                    sp,
                    para('Realizarea garantiei se face prin modalitatea reparatiei in primul rand, sau daca acest lucru nu este posibil prin inlocuire sau returnarea contravalorii produsului.'),
                    sp,
                    para(
                      'Cererile de service in urma carora se vor constata urmatoarele situatii: echipament nealimentat, baterii de la telecomanda lipsa, filtru infundat, erori de utilizare, defecte care nu sunt acoperite de garantie, etc. vor fi tratate ca interventii nefondate. Cumparatorul va achita costul interventiei nefondate. Costul interventiei nefondate este de 180 RON cu TVA inclus in cazul in care necesita deplasare in afara municipiului Arad se taxeaza deplasarea cu 2.4 ron/km dus intors.',
                      isBold: true,
                    ),
                    sp,
                    para('Intretinerea periodica este obligatorie in garantie se face de catre cumparator conform instructiunilor de utilizare (curatarea filtrelor unitatii interioare si a unitatii exterioare atunci cand este cazul este in sarcina cumparatorului si se face pe cheltuiala acestuia).'),
                    sp,
                    para('Garantia acordata de catre producator este precizata pe verso iar garantia pentru montaj este de 1 an de la data la care echipamentul a fost instalat. In perioada de garantie interventiile service asupra echipamentului se executa numai de catre societatea care a efectuat instalarea.'),
                    sp,
                    para('Prin prezenta, S.C PRO TERM S.R.L precizeaza ca prezentul certificat de garantie cuprinde mentiunile prevazute de lege cu privire la drepturile cumparatorului, modul de exercitare a acestora, caracteristicile produsului, garantia comerciala, modul de acordare a garantiei si durata medie de functionare a produsului, conform prevederilor OG 21/1992 modificata si completata.'),
                  ],
                ),
              ),
            ]),
            // Footer
            pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: _pad, vertical: 3),
                child: pw.Text(
                  'Garantia poate fi semnata si stampilata de catre oricare'
                  ' dintre colaboratorii SC PRO TERM SRL',
                  style: pw.TextStyle(font: bold, fontSize: 7.5),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ]),
          ],
        );
      },
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static String _dl(DateTime? v) {
    if (v == null) return '-';
    return '${v.day.toString().padLeft(2, '0')}.'
        '${v.month.toString().padLeft(2, '0')}.${v.year}';
  }

  static const String _legalText =
      'Cumparatorului nu i se ingradeste dreptul de a alege instalatorul si/sau centrul service '
      'in garantie, cu conditia ca instalatorul ales sa fie autorizat de catre importator/producator. '
      'Cumparatorul nu pierde garantia in situatia in care alege un instalator autorizat diferit de vanzator. '
      'Orice reparatie sau interventie in perioada de garantie poate fi efectuata numai de catre unitati '
      'de service autorizate de catre importator/producator. Garantia produsului ramane valabila cu '
      'conditia respectarii instructiunilor de utilizare si pastrarii prezentului certificat de garantie.';
}
