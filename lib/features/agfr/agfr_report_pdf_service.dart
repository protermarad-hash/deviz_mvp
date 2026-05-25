import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/company_profile.dart';
import '../../core/pdf/pdf_font_helper.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import '../clients/client_models.dart';
import '../jobs/job_models.dart';
import 'agfr_models.dart';

class AgfrReportPdfService {
  const AgfrReportPdfService._();

  static Future<Uint8List> buildPdfBytes({
    required CompanyProfile company,
    required AgfrReportRecord report,
    required AgfrEquipmentRecord equipment,
    required AgfrInterventionRecord intervention,
    AgfrWeighingReportRecord? weighingReport,
    ClientRecord? client,
    JobRecord? job,
  }) async {
    await PdfFontHelper.initialize();
    final doc = pw.Document(theme: PdfFontHelper.theme);
    final logo = _tryDecodeBase64(company.logoBase64);
    final clientSignature = _tryDecodeBase64(report.clientSignatureBase64);
    final technicianSignature =
        _tryDecodeBase64(report.technicianSignatureBase64);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _header(
            logo: logo,
            company: company,
            report: report,
            intervention: intervention,
          ),
          pw.SizedBox(height: 10),
          _section(
            'OBIECTUL INTERVENTIEI',
            [
              _paragraph(_operationSummary(intervention)),
            ],
          ),
          pw.SizedBox(height: 14),
          _section(
            'DATE GENERALE',
            [
              _row('Beneficiar / proprietar instalatie', equipment.clientName),
              _row(
                'Amplasament / adresa instalatiei',
                _resolvedLocation(equipment: equipment, client: client),
              ),
              _row(
                'Societatea executanta',
                company.companyName.trim().isEmpty
                    ? _missingValueLabel
                    : company.companyName.trim(),
              ),
              _row(
                'Nr. autorizatie / certificare F-GAS societate',
                _resolvedValue(
                  report.companyFgasAuthorizationNumber,
                  fallback: intervention.companyFgasAuthorizationNumber,
                ),
              ),
              if (job != null)
                _row('Lucrare / referinta interna', _jobLabel(job)),
            ],
          ),
          pw.SizedBox(height: 10),
          _section(
            'IDENTIFICAREA INSTALATIEI',
            [
              _row('Categorie instalatie', equipment.equipmentCategory.label),
              _row('Tip instalatie / echipament', equipment.equipmentType),
              _row('Producator', equipment.brand),
              _row('Model', equipment.model),
              _row('Serie / numar identificare', equipment.serialNumber),
              _row('Locul instalarii', equipment.location),
            ],
          ),
          pw.SizedBox(height: 10),
          _section(
            'RESPONSABILI CU OPERATIUNEA',
            [
              _row(
                'Reprezentant beneficiar',
                report.beneficiaryRepresentative,
              ),
              _row(
                'Tehnician F-GAS',
                _resolvedValue(
                  report.technicianName,
                  fallback: intervention.technicianName,
                ),
              ),
              _row(
                'Nr. certificat F-GAS tehnician',
                _resolvedValue(
                  report.technicianCertificateNumber,
                  fallback: intervention.technicianCertificateNumber,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          _section(
            'DETALII AGENT FRIGORIFIC',
            [
              _row(
                'Tip agent frigorific',
                _resolvedValue(
                  intervention.refrigerantType,
                  fallback: equipment.refrigerantType,
                ),
              ),
              _row('GWP', _formatNumber(equipment.gwp, decimals: 0)),
              _row(
                'Incarcatura initiala declarata',
                '${equipment.factoryChargeKg.toStringAsFixed(2)} kg',
              ),
              _row(
                'Incarcatura suplimentara',
                '${equipment.additionalChargeKg.toStringAsFixed(2)} kg',
              ),
              _row(
                'Masa totala estimata in sistem',
                '${_resolvedTotalInSystem(equipment, intervention).toStringAsFixed(2)} kg',
              ),
              _row(
                'Echivalent CO2',
                '${_resolvedCo2(equipment, intervention).toStringAsFixed(3)} t',
              ),
              _row(
                'Frecventa orientativa a verificarilor de etanseitate',
                _recommendedCheckFrequency(
                    _resolvedCo2(equipment, intervention)),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          _section(
            'OPERATIUNI EFECTUATE CU AGENTUL FRIGORIFIC SI VERIFICARI F-GAS',
            _operationSectionRows(equipment, intervention),
          ),
          pw.SizedBox(height: 10),
          _section(
            'CONSTATARI GENERALE / OBSERVATII',
            [
              _paragraph(_resolvedObservations(report, intervention)),
            ],
          ),
          pw.SizedBox(height: 10),
          _section(
            'CONCLUZII',
            [
              _paragraph(_resolvedConclusions(report, intervention)),
            ],
          ),
          pw.SizedBox(height: 14),
          _signatures(
            clientSignature: clientSignature,
            technicianSignature: technicianSignature,
            beneficiaryRepresentative: report.beneficiaryRepresentative,
            technicianName: _resolvedValue(
              report.technicianName,
              fallback: intervention.technicianName,
            ),
          ),
          pw.SizedBox(height: 10),
          _section(
            'ANEXE SI METADATE DOCUMENT',
            [
              _row(
                'Anexa A - Documente de certificare F-GAS',
                _attachmentSummary(
                  companyPath: report.companyCertificateAttachmentPath,
                  technicianPath: report.technicianCertificateAttachmentPath,
                ),
              ),
              _row(
                'Anexa B - Raport de cantarire agent frigorific',
                weighingReport == null
                    ? 'Nu este asociat, in acest moment, un raport de cantarire.'
                    : 'Anexa este intocmita pe baza raportului ${weighingReport.sourceType.label.toLowerCase()}${weighingReport.sourceFileName.trim().isEmpty ? '' : ', fisier ${weighingReport.sourceFileName.trim()}'}',
              ),
              _row(
                'Referință Registratură',
                report.registryEntryId.trim().isEmpty
                    ? 'Nealocat'
                    : report.registryEntryId.trim(),
              ),
            ],
          ),
        ],
      ),
    );

    await _appendCertificateAnnexes(
      doc,
      report: report,
    );
    _appendWeighingAnnex(doc, weighingReport: weighingReport);
    return doc.save();
  }

  static Future<String> export({
    required AppDataRepository repository,
    required CompanyProfile company,
    required AgfrReportRecord report,
    required AgfrEquipmentRecord equipment,
    required AgfrInterventionRecord intervention,
    AgfrWeighingReportRecord? weighingReport,
    ClientRecord? client,
    JobRecord? job,
    String outputDirectory = '',
    bool saveAs = false,
  }) async {
    final bytes = await buildPdfBytes(
      company: company,
      report: report,
      equipment: equipment,
      intervention: intervention,
      weighingReport: weighingReport,
      client: client,
      job: job,
    );
    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: _fileName(report),
      category: PdfDocumentCategory.other,
      outputDirectory: outputDirectory,
      forceSaveAs: saveAs,
    );
  }

  static Future<void> share({
    required CompanyProfile company,
    required AgfrReportRecord report,
    required AgfrEquipmentRecord equipment,
    required AgfrInterventionRecord intervention,
    AgfrWeighingReportRecord? weighingReport,
    ClientRecord? client,
    JobRecord? job,
  }) async {
    final bytes = await buildPdfBytes(
      company: company,
      report: report,
      equipment: equipment,
      intervention: intervention,
      weighingReport: weighingReport,
      client: client,
      job: job,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: _fileName(report),
    );
  }

  static pw.Widget _header({
    required pw.MemoryImage? logo,
    required CompanyProfile company,
    required AgfrReportRecord report,
    required AgfrInterventionRecord intervention,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logo != null)
          pw.Container(
            width: 76,
            height: 54,
            margin: const pw.EdgeInsets.only(right: 14),
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (company.companyName.trim().isNotEmpty)
                pw.Text(
                  company.companyName.trim(),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              if (company.address.trim().isNotEmpty)
                pw.Text(company.address.trim()),
              if (company.phone.trim().isNotEmpty)
                pw.Text('Tel: ${company.phone.trim()}'),
              if (company.email.trim().isNotEmpty)
                pw.Text('Email: ${company.email.trim()}'),
              if (company.cui.trim().isNotEmpty)
                pw.Text('CUI: ${company.cui.trim()}'),
            ],
          ),
        ),
        pw.Container(
          width: 220,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey500),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PROCES-VERBAL DE VERIFICARE SI MANEVRARE AGENTI FRIGORIFICI',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'intocmit in conformitate cu Regulamentele (UE) 2024/573 si 2024/590, precum si cu cerintele nationale aplicabile in domeniul gazelor fluorurate',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                  'Nr. document / inregistrare: ${_documentNumber(report)}'),
              pw.Text(
                  'Data efectuarii operatiunii: ${_date(report.operationDate)}'),
              pw.Text(
                'Tip interventie: ${_operationTypeTitle(intervention.operationType)}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _section(String title, List<pw.Widget> children) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
            ),
          ),
          pw.SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  static pw.Widget _subsection(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  static pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 190,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.trim().isEmpty ? _missingValueLabel : value.trim(),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _paragraph(String value) {
    final text = value.trim().isEmpty ? _missingValueLabel : value.trim();
    return pw.Text(text);
  }

  static pw.Widget _signatures({
    required pw.MemoryImage? clientSignature,
    required pw.MemoryImage? technicianSignature,
    required String beneficiaryRepresentative,
    required String technicianName,
  }) {
    pw.Widget box({
      required String title,
      required String subtitle,
      required pw.MemoryImage? image,
    }) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(subtitle.trim().isEmpty ? '-' : subtitle.trim()),
          pw.SizedBox(height: 8),
          pw.Container(
            height: 90,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            alignment: pw.Alignment.center,
            child: image == null
                ? pw.Text('Semnătură neaplicată')
                : pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Image(image, fit: pw.BoxFit.contain),
                  ),
          ),
        ],
      );
    }

    return _section(
      'SEMNATURI',
      [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: box(
                title: 'Beneficiar / reprezentant beneficiar',
                subtitle: beneficiaryRepresentative,
                image: clientSignature,
              ),
            ),
            pw.SizedBox(width: 18),
            pw.Expanded(
              child: box(
                title: 'Tehnician autorizat F-GAS',
                subtitle: technicianName,
                image: technicianSignature,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Future<void> _appendCertificateAnnexes(
    pw.Document doc, {
    required AgfrReportRecord report,
  }) async {
    final annexes = <_AttachmentAnnex>[
      await _loadAttachment(
        title: 'Certificat F-GAS societate',
        path: report.companyCertificateAttachmentPath,
      ),
      await _loadAttachment(
        title: 'Certificat F-GAS tehnician',
        path: report.technicianCertificateAttachmentPath,
      ),
    ];

    final available =
        annexes.where((item) => item.hasReference).toList(growable: false);
    if (available.isEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (context) => _annexPlaceholder(
            'ANEXA A - CERTIFICATE F-GAS',
            'La data generarii documentului nu sunt atasate copii ale certificatelor F-GAS. Anexa ramane rezervata pentru includerea documentelor de certificare ale societatii si ale tehnicianului.',
          ),
        ),
      );
      return;
    }

    for (final annex in available) {
      if (annex.image != null) {
        // Image annex
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(28),
            build: (context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ANEXA A - CERTIFICATE F-GAS',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    annex.title,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Document atasat: ${annex.path}'),
                  pw.SizedBox(height: 12),
                  pw.Expanded(
                    child: pw.Container(
                      width: double.infinity,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Image(annex.image!, fit: pw.BoxFit.contain),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      } else if (annex.pdfBytes != null) {
        // PDF annex - add reference page
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(28),
            build: (context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ANEXA A - CERTIFICATE F-GAS',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    annex.title,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      border: pw.Border.all(color: PdfColors.blue400),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text(
                              '📄 Fisier PDF atasat',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'Calea: ${annex.path}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Marime: ${(annex.pdfBytes!.length / 1024).toStringAsFixed(1)} KB',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'Aceasta anexa contine o copie a certificatului F-GAS in format PDF. Poate fi extrasa din arhiva acestui document.',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.justify,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      } else {
        // No content - placeholder
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(28),
            build: (context) {
              return _annexPlaceholder(
                'ANEXA A - CERTIFICATE F-GAS',
                '${annex.title}\nDocument atasat: ${annex.path}\nFisierul nu poate fi randat direct in aceasta versiune a documentului, insa referinta lui este pastrata ca anexa justificativa.',
              );
            },
          ),
        );
      }
    }
  }

  static void _appendWeighingAnnex(
    pw.Document doc, {
    AgfrWeighingReportRecord? weighingReport,
  }) {
    if (weighingReport == null) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (context) => _annexPlaceholder(
            'ANEXA B - RAPORT DE CANTARIRE AGENT FRIGORIFIC',
            'Nu este asociat, la acest moment, un raport de cantarire pentru prezentul proces-verbal. Sectiunea ramane rezervata pentru completare manuala sau pentru importul unui raport generat din Testo Smart.',
          ),
        ),
      );
      return;
    }
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => _section(
          'ANEXA B - RAPORT DE CANTARIRE AGENT FRIGORIFIC',
          [
            _row('Originea datelor', weighingReport.sourceType.label),
            _row(
              'Fisier importat / referinta',
              _resolvedValue(
                weighingReport.sourceFileName,
                fallback: weighingReport.sourceFilePath,
              ),
            ),
            _row(
              'Data importului',
              weighingReport.sourceImportedAt == null
                  ? '-'
                  : _dateTime(weighingReport.sourceImportedAt!),
            ),
            _row('Dispozitiv / cantar utilizat',
                weighingReport.sourceDeviceInfo),
            _row(
              'Identificare aparat de cantarire',
              weighingReport.scaleIdentifier,
            ),
            _row(
              'Identificare recipient / butelie',
              weighingReport.cylinderIdentifier,
            ),
            _row(
              'Data si ora masuratorii',
              weighingReport.measurementTimestamp == null
                  ? '-'
                  : _dateTime(weighingReport.measurementTimestamp!),
            ),
            _row(
              'Greutate initiala inregistrata',
              '${weighingReport.initialWeightKg.toStringAsFixed(2)} kg',
            ),
            _row(
              'Greutate finala inregistrata',
              '${weighingReport.finalWeightKg.toStringAsFixed(2)} kg',
            ),
            _row(
              'Cantitate incarcata',
              '${weighingReport.chargedKg.toStringAsFixed(2)} kg',
            ),
            _row(
              'Cantitate recuperata',
              '${weighingReport.recoveredKg.toStringAsFixed(2)} kg',
            ),
            _row(
              'Cantitate neta rezultata',
              '${weighingReport.netQuantityKg.toStringAsFixed(2)} kg',
            ),
            _row(
              'Document original Testo',
              _resolvedValue(
                weighingReport.originalPdfAttachmentFileName,
                fallback: weighingReport.originalPdfAttachmentPath,
              ),
            ),
            _row(
              'Observatie privind dovada originala',
              weighingReport.originalPdfAttachmentPath.trim().isEmpty
                  ? 'Nu este atasat, in prezent, un PDF original Testo.'
                  : 'Documentul original generat in Testo Smart este pastrat ca anexa justificativa: ${weighingReport.originalPdfAttachmentPath.trim()}',
            ),
            _row(
              'Date brute de import',
              weighingReport.sourceRawPayload.trim().isEmpty
                  ? 'Nestocate'
                  : 'Stocate pentru trasabilitate si pentru verificari ulterioare.',
            ),
            if (weighingReport.notes.trim().isNotEmpty)
              _row('Mentiuni suplimentare', weighingReport.notes),
          ],
        ),
      ),
    );
  }

  static pw.Widget _annexPlaceholder(String title, String text) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 16,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(text),
        ),
      ],
    );
  }

  static Future<_AttachmentAnnex> _loadAttachment({
    required String title,
    required String path,
  }) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      return _AttachmentAnnex(title: title, path: normalizedPath, isPdf: false);
    }

    try {
      final file = File(normalizedPath);

      // Check if file exists
      if (!file.existsSync()) {
        debugPrint('[AGFR][PDF] Certificate file not found: $normalizedPath');
        return _AttachmentAnnex(
            title: title, path: normalizedPath, isPdf: false);
      }

      // Check file extension
      final extension = normalizedPath.split('.').last.toLowerCase();
      final isPdf = extension == 'pdf';
      final isImage = const <String>{'png', 'jpg', 'jpeg', 'webp', 'gif'}
          .contains(extension);

      if (!isPdf && !isImage) {
        debugPrint(
            '[AGFR][PDF] Unsupported certificate file type: $extension for $normalizedPath');
        return _AttachmentAnnex(
            title: title, path: normalizedPath, isPdf: false);
      }

      // Read file bytes
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        debugPrint('[AGFR][PDF] Certificate file is empty: $normalizedPath');
        return _AttachmentAnnex(
            title: title, path: normalizedPath, isPdf: isPdf);
      }

      // For images, convert to MemoryImage; for PDFs, store as binary
      if (isImage) {
        return _AttachmentAnnex(
          title: title,
          path: normalizedPath,
          image: pw.MemoryImage(bytes),
          isPdf: false,
        );
      } else {
        // PDF: store bytes for later embedding
        return _AttachmentAnnex(
          title: title,
          path: normalizedPath,
          pdfBytes: bytes,
          isPdf: true,
        );
      }
    } catch (error) {
      debugPrint('[AGFR][PDF] Error loading certificate $path: $error');
      return _AttachmentAnnex(title: title, path: normalizedPath, isPdf: false);
    }
  }

  static String _fileName(AgfrReportRecord report) {
    final safe =
        _documentNumber(report).replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
    return 'proces_verbal_agfr_$safe.pdf';
  }

  static String _documentNumber(AgfrReportRecord report) {
    final number = report.reportNumber.trim();
    return number.isEmpty ? report.id : number;
  }

  static String _date(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  static String _dateTime(DateTime value) {
    return '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  static String _formatNumber(double value, {int decimals = 2}) {
    if (value == 0) {
      return '-';
    }
    return value.toStringAsFixed(decimals);
  }

  static String _resolvedValue(String value, {String fallback = ''}) {
    final primary = value.trim();
    if (primary.isNotEmpty) {
      return primary;
    }
    final backup = fallback.trim();
    return backup.isEmpty ? _missingValueLabel : backup;
  }

  static String _resolvedLocation({
    required AgfrEquipmentRecord equipment,
    ClientRecord? client,
  }) {
    if (equipment.location.trim().isNotEmpty) {
      return equipment.location.trim();
    }
    if (client == null) {
      return _missingValueLabel;
    }
    final addressParts = <String>[
      client.address.trim(),
      client.city.trim(),
      client.county.trim(),
    ].where((item) => item.isNotEmpty).toList(growable: false);
    return addressParts.isEmpty ? _missingValueLabel : addressParts.join(', ');
  }

  static String _jobLabel(JobRecord job) {
    final parts = <String>[
      job.jobCode.trim(),
      job.title.trim(),
    ].where((item) => item.isNotEmpty).toList(growable: false);
    return parts.isEmpty ? job.id : parts.join(' - ');
  }

  static double _resolvedTotalInSystem(
    AgfrEquipmentRecord equipment,
    AgfrInterventionRecord intervention,
  ) {
    if (intervention.totalInSystemKg > 0) {
      return intervention.totalInSystemKg;
    }
    return equipment.totalChargeKg;
  }

  static double _resolvedCo2(
    AgfrEquipmentRecord equipment,
    AgfrInterventionRecord intervention,
  ) {
    final total = _resolvedTotalInSystem(equipment, intervention);
    if (total <= 0 || equipment.gwp <= 0) {
      return equipment.co2EquivalentTons;
    }
    return total * equipment.gwp / 1000;
  }

  static String _recommendedCheckFrequency(double co2Tons) {
    if (co2Tons >= 500) {
      return 'Verificare cel putin la 3 luni sau la 6 luni daca este instalat un sistem fix de detectie.';
    }
    if (co2Tons >= 50) {
      return 'Verificare cel putin la 6 luni sau la 12 luni daca este instalat un sistem fix de detectie.';
    }
    if (co2Tons >= 5) {
      return 'Verificare cel putin la 12 luni sau la 24 luni daca este instalat un sistem fix de detectie.';
    }
    return 'Sub pragul de 5 t CO2 echivalent pentru obligatia periodica standard de verificare a etanseitatii.';
  }

  static String _nitrogenBrazingLabel(AgfrInterventionRecord intervention) {
    if (intervention.operationType == AgfrInterventionType.instalare ||
        intervention.operationType == AgfrInterventionType.punereInFunctiune) {
      return 'Operatiune specifica fluxului de instalare / punere in functiune; detaliile se consemneaza, dupa caz, la observatii.';
    }
    return 'Neconsemnat explicit in datele disponibile ale interventiei.';
  }

  static String _pressureTestLabel(AgfrInterventionRecord intervention) {
    if (intervention.pressureTestBar <= 0 &&
        intervention.pressureTestDurationHours <= 0) {
      return _missingValueLabel;
    }
    final parts = <String>[];
    if (intervention.pressureTestBar > 0) {
      parts.add('${intervention.pressureTestBar.toStringAsFixed(2)} bar');
    }
    if (intervention.pressureTestDurationHours > 0) {
      parts.add(
        '${intervention.pressureTestDurationHours.toStringAsFixed(2)} ore',
      );
    }
    return parts.join(' | ');
  }

  static String _vacuumLabel(AgfrInterventionRecord intervention) {
    if (intervention.vacuumMicrons <= 0 &&
        intervention.vacuumDurationHours <= 0) {
      return _missingValueLabel;
    }
    final parts = <String>[];
    if (intervention.vacuumMicrons > 0) {
      parts.add('${intervention.vacuumMicrons.toStringAsFixed(0)} microni');
    }
    if (intervention.vacuumDurationHours > 0) {
      parts.add('${intervention.vacuumDurationHours.toStringAsFixed(2)} ore');
    }
    return parts.join(' | ');
  }

  static String _recoveredAgentDestination(
      AgfrInterventionRecord intervention) {
    if (intervention.recoveredKg <= 0) {
      return 'Nu a fost consemnata recuperare de agent frigorific.';
    }
    if (intervention.notes.trim().isNotEmpty) {
      return 'Conform mentiunilor din observatii: ${intervention.notes.trim()}';
    }
    return 'Destinatia agentului recuperat nu a fost consemnata explicit.';
  }

  static String _attachmentSummary({
    required String companyPath,
    required String technicianPath,
  }) {
    final parts = <String>[];
    if (companyPath.trim().isNotEmpty) {
      parts.add('certificat societate atasat');
    }
    if (technicianPath.trim().isNotEmpty) {
      parts.add('certificat tehnician atasat');
    }
    if (parts.isEmpty) {
      return 'Nu sunt atasate documente de certificare';
    }
    return 'Sunt disponibile: ${parts.join(', ')}.';
  }

  static String _resolvedObservations(
    AgfrReportRecord report,
    AgfrInterventionRecord intervention,
  ) {
    final text = report.observations.trim();
    if (text.isNotEmpty) {
      return text;
    }
    final notes = intervention.notes.trim();
    switch (intervention.operationType) {
      case AgfrInterventionType.instalare:
      case AgfrInterventionType.punereInFunctiune:
        if (notes.isNotEmpty) {
          return 'Cu ocazia lucrarilor de instalare / punere in functiune s-au consemnat urmatoarele aspecte tehnice: $notes';
        }
        return 'Au fost consemnate operatiunile specifice montajului si punerii in functiune, cu verificarile tehnice aferente etapei de executie.';
      case AgfrInterventionType.service:
      case AgfrInterventionType.mentenanta:
        if (notes.isNotEmpty) {
          return 'In cadrul operatiunii de service / mentenanta s-au constatat urmatoarele: $notes';
        }
        return 'Interventia a vizat verificarea starii de functionare si efectuarea operatiunilor curente de service / mentenanta, in limita datelor consemnate.';
      case AgfrInterventionType.verificareEtanseitate:
        if (notes.isNotEmpty) {
          return 'In urma verificarii de etanseitate au fost consemnate urmatoarele observatii: $notes';
        }
        return 'A fost efectuata verificarea etanseitatii circuitului frigorific, conform metodei mentionate in prezentul document.';
      case AgfrInterventionType.incarcare:
      case AgfrInterventionType.completare:
        if (notes.isNotEmpty) {
          return 'Cu ocazia operatiunii de incarcare / completare agent frigorific s-au consemnat urmatoarele: $notes';
        }
        return 'Interventia a vizat introducerea unei cantitati de agent frigorific in instalatie si verificarea comportarii acesteia dupa operatiune.';
      case AgfrInterventionType.recuperare:
        if (notes.isNotEmpty) {
          return 'Cu ocazia operatiunii de recuperare a agentului frigorific s-au consemnat urmatoarele: $notes';
        }
        return 'A fost efectuata recuperarea agentului frigorific, cu consemnarea cantitatii extrase si a destinatiei declarate a agentului recuperat.';
      case AgfrInterventionType.dezafectare:
        if (notes.isNotEmpty) {
          return 'In cadrul operatiunii de scoatere din functiune / dezafectare s-au consemnat urmatoarele: $notes';
        }
        return 'Interventia a avut ca obiect scoaterea din functiune a echipamentului si gestionarea agentului frigorific aferent, in limita datelor disponibile.';
    }
  }

  static String _resolvedConclusions(
    AgfrReportRecord report,
    AgfrInterventionRecord intervention,
  ) {
    final text = report.conclusions.trim();
    if (text.isNotEmpty) {
      return text;
    }
    final leakResult = intervention.leakCheckResult;
    if (leakResult == AgfrLeakCheckResult.faraScurgeri) {
      return 'Pe baza verificarilor consemnate, instalatia poate continua exploatarea in conditiile respectarii cerintelor de utilizare si de monitorizare periodica aplicabile.';
    }
    if (leakResult == AgfrLeakCheckResult.scurgeriDepistate) {
      return 'In urma verificarilor efectuate au fost constatate neconformitati privind etanseitatea, fiind necesare masuri corective si reverificare dupa remediere.';
    }
    if (leakResult == AgfrLeakCheckResult.necesitaMonitorizare) {
      return 'Situatia constatata impune monitorizare ulterioara si efectuarea verificarilor de etanseitate conform periodicitatii aplicabile.';
    }
    switch (intervention.operationType) {
      case AgfrInterventionType.instalare:
        return 'Pe baza operatiunilor consemnate, instalatia este declarata montata, urmand etapele de verificare si exploatare conform documentatiei tehnice aplicabile.';
      case AgfrInterventionType.punereInFunctiune:
        return 'Pe baza operatiunilor efectuate, instalatia poate fi considerata apta pentru punere in functiune, in conditiile respectarii parametrilor tehnici si a instructiunilor de exploatare.';
      case AgfrInterventionType.service:
        return 'Prezentul proces-verbal consemneaza interventia de service si starea echipamentului la data verificarii, in baza datelor tehnice disponibile.';
      case AgfrInterventionType.mentenanta:
        return 'Operatiunea de mentenanta a fost consemnata in prezentul proces-verbal, cu mentinerea obligatiei de monitorizare si de verificare periodica, dupa caz.';
      case AgfrInterventionType.verificareEtanseitate:
        return 'Prezentul document certifica efectuarea verificarii de etanseitate si rezultatul constatat la data interventiei, in limitele metodei utilizate.';
      case AgfrInterventionType.incarcare:
        return 'Cantitatea de agent frigorific introdusa a fost consemnata in prezentul proces-verbal, interventia fiind finalizata in baza datelor disponibile la momentul operatiunii.';
      case AgfrInterventionType.completare:
        return 'Completarea agentului frigorific a fost consemnata in prezentul proces-verbal, cu recomandarea monitorizarii ulterioare a instalatiei, dupa caz.';
      case AgfrInterventionType.recuperare:
        return 'Operatiunea de recuperare a agentului frigorific a fost consemnata in prezentul proces-verbal, cu mentinerea obligatiei de gestionare ulterioara conform cerintelor aplicabile.';
      case AgfrInterventionType.dezafectare:
        return 'Prezentul proces-verbal consemneaza scoaterea din functiune / dezafectarea echipamentului si gestionarea agentului frigorific, in limita datelor inscrise.';
    }
  }

  static List<pw.Widget> _operationSectionRows(
    AgfrEquipmentRecord equipment,
    AgfrInterventionRecord intervention,
  ) {
    switch (intervention.operationType) {
      case AgfrInterventionType.instalare:
      case AgfrInterventionType.punereInFunctiune:
        return <pw.Widget>[
          _subsection('A. Operatiuni de instalare / punere in functiune'),
          _row(
            'Brazare sub flux de azot',
            _nitrogenBrazingLabel(intervention),
          ),
          _row('Proba de presiune', _pressureTestLabel(intervention)),
          _row('Vacuumare', _vacuumLabel(intervention)),
          _row(
            'Cantitate agent introdusa la punerea in functiune',
            '${intervention.chargedKg.toStringAsFixed(2)} kg',
          ),
          pw.SizedBox(height: 8),
          _subsection('B. Verificari efectuate'),
          _row(
            'Control etanseitate',
            _verificationPerformedLabel(intervention),
          ),
          _row(
            'Observații tehnice',
            _installationTechnicalRemark(equipment, intervention),
          ),
        ];
      case AgfrInterventionType.service:
      case AgfrInterventionType.mentenanta:
        return <pw.Widget>[
          _subsection('A. Operatiuni de service / mentenanta'),
          _row(
            'Scopul interventiei',
            intervention.operationType == AgfrInterventionType.service
                ? 'Interventie de service asupra instalatiei frigorifice.'
                : 'Operatiune de mentenanta planificata / preventiva.',
          ),
          _row('Cantitate agent completata / introdusa',
              '${intervention.chargedKg.toStringAsFixed(2)} kg'),
          _row('Cantitate agent recuperata',
              '${intervention.recoveredKg.toStringAsFixed(2)} kg'),
          pw.SizedBox(height: 8),
          _subsection('B. Verificari si controale efectuate'),
          _row(
            'Metoda utilizata pentru controlul etanseitatii',
            intervention.leakCheckMethod?.label ?? _missingValueLabel,
          ),
          _row(
            'Rezultatul controlului',
            intervention.leakCheckResult?.label ?? _missingValueLabel,
          ),
          _row(
            'Starea consemnata a instalatiei',
            _serviceStatusRemark(intervention),
          ),
        ];
      case AgfrInterventionType.verificareEtanseitate:
        return <pw.Widget>[
          _subsection('A. Verificare etanseitate circuit frigorific'),
          _row(
            'Metoda utilizata',
            intervention.leakCheckMethod?.label ?? _missingValueLabel,
          ),
          _row(
            'Rezultat constatat',
            intervention.leakCheckResult?.label ?? _missingValueLabel,
          ),
          _row(
            'Periodicitate orientativa a verificarilor',
            _recommendedCheckFrequency(_resolvedCo2(equipment, intervention)),
          ),
          pw.SizedBox(height: 8),
          _subsection('B. Mentiuni privind agentul frigorific'),
          _row(
            'Cantitate aflata in sistem la data verificarii',
            '${_resolvedTotalInSystem(equipment, intervention).toStringAsFixed(2)} kg',
          ),
          _row(
            'Consemnari suplimentare',
            _verificationPerformedLabel(intervention),
          ),
        ];
      case AgfrInterventionType.incarcare:
      case AgfrInterventionType.completare:
        return <pw.Widget>[
          _subsection(
              'A. Operatiune de incarcare / completare agent frigorific'),
          _row(
            'Tipul operatiunii',
            intervention.operationType == AgfrInterventionType.incarcare
                ? 'Incarcare agent frigorific'
                : 'Completare agent frigorific',
          ),
          _row(
            'Cantitate introdusa in instalatie',
            '${intervention.chargedKg.toStringAsFixed(2)} kg',
          ),
          _row(
            'Cantitate rezultata in sistem dupa interventie',
            '${_resolvedTotalInSystem(equipment, intervention).toStringAsFixed(2)} kg',
          ),
          pw.SizedBox(height: 8),
          _subsection('B. Verificari ulterioare operatiunii'),
          _row(
            'Control etanseitate dupa incarcare',
            _verificationPerformedLabel(intervention),
          ),
          _row(
            'Rezultatul controlului',
            intervention.leakCheckResult?.label ?? _missingValueLabel,
          ),
        ];
      case AgfrInterventionType.recuperare:
        return <pw.Widget>[
          _subsection('A. Operatiune de recuperare agent frigorific'),
          _row(
            'Cantitate recuperata',
            '${intervention.recoveredKg.toStringAsFixed(2)} kg',
          ),
          _row(
            'Recipient / mijloc de preluare',
            _recoveredContainerLabel(intervention),
          ),
          _row(
            'Destinatia agentului recuperat',
            _recoveredAgentDestination(intervention),
          ),
          pw.SizedBox(height: 8),
          _subsection('B. Mentiuni privind siguranta operatiunii'),
          _row(
            'Observații de execuție',
            _recoveryExecutionRemark(intervention),
          ),
        ];
      case AgfrInterventionType.dezafectare:
        return <pw.Widget>[
          _subsection('A. Scoatere din functiune / dezafectare'),
          _row(
            'Starea echipamentului la data interventiei',
            'Echipamentul a fost consemnat pentru scoatere din functiune / dezafectare.',
          ),
          _row(
            'Cantitate recuperata anterior dezafectarii',
            '${intervention.recoveredKg.toStringAsFixed(2)} kg',
          ),
          _row(
            'Destinatia agentului frigorific',
            _recoveredAgentDestination(intervention),
          ),
          pw.SizedBox(height: 8),
          _subsection('B. Mențiuni privind închiderea operațiunii'),
          _row(
            'Consemnare finala',
            _decommissioningRemark(intervention),
          ),
        ];
    }
  }

  static String _operationSummary(AgfrInterventionRecord intervention) {
    switch (intervention.operationType) {
      case AgfrInterventionType.instalare:
        return 'Prezentul proces-verbal consemneaza operatiunile executate cu ocazia montajului instalatiei si a manipularii agentului frigorific, in limitele datelor tehnice disponibile.';
      case AgfrInterventionType.punereInFunctiune:
        return 'Prezentul proces-verbal consemneaza operatiunile executate pentru punerea in functiune a instalatiei si pentru verificarea parametrilor initiali de lucru.';
      case AgfrInterventionType.service:
        return 'Prezentul proces-verbal consemneaza operatiunea de service efectuata asupra instalatiei frigorifice si lucrarile privind agentul frigorific, dupa caz.';
      case AgfrInterventionType.mentenanta:
        return 'Prezentul proces-verbal consemneaza operatiunea de mentenanta efectuata asupra instalatiei frigorifice si verificarile asociate circuitului de agent frigorific.';
      case AgfrInterventionType.verificareEtanseitate:
        return 'Prezentul proces-verbal consemneaza verificarea etanseitatii instalatiei frigorifice si rezultatele obtinute prin metoda mentionata.';
      case AgfrInterventionType.incarcare:
        return 'Prezentul proces-verbal consemneaza operatiunea de incarcare a instalatiei cu agent frigorific si verificarile efectuate ulterior.';
      case AgfrInterventionType.completare:
        return 'Prezentul proces-verbal consemneaza operatiunea de completare a agentului frigorific si verificarile efectuate in urma interventiei.';
      case AgfrInterventionType.recuperare:
        return 'Prezentul proces-verbal consemneaza operatiunea de recuperare a agentului frigorific din instalatie si datele tehnice disponibile privind preluarea acestuia.';
      case AgfrInterventionType.dezafectare:
        return 'Prezentul proces-verbal consemneaza scoaterea din functiune / dezafectarea instalatiei si gestionarea agentului frigorific aferent.';
    }
  }

  static String _operationTypeTitle(AgfrInterventionType type) {
    switch (type) {
      case AgfrInterventionType.instalare:
        return 'Instalare';
      case AgfrInterventionType.punereInFunctiune:
        return 'Punere in functiune';
      case AgfrInterventionType.service:
        return 'Service';
      case AgfrInterventionType.mentenanta:
        return 'Mentenanta';
      case AgfrInterventionType.verificareEtanseitate:
        return 'Verificare etanseitate';
      case AgfrInterventionType.incarcare:
        return 'Incarcare agent frigorific';
      case AgfrInterventionType.completare:
        return 'Completare agent frigorific';
      case AgfrInterventionType.recuperare:
        return 'Recuperare agent frigorific';
      case AgfrInterventionType.dezafectare:
        return 'Dezafectare';
    }
  }

  static String _verificationPerformedLabel(
    AgfrInterventionRecord intervention,
  ) {
    if (intervention.leakCheckMethod != null &&
        intervention.leakCheckResult != null) {
      return 'Control efectuat prin metoda ${intervention.leakCheckMethod!.label.toLowerCase()}, cu rezultat: ${intervention.leakCheckResult!.label.toLowerCase()}.';
    }
    if (intervention.leakCheckMethod != null) {
      return 'Control consemnat prin metoda ${intervention.leakCheckMethod!.label.toLowerCase()}.';
    }
    if (intervention.leakCheckResult != null) {
      return 'Rezultatul consemnat al controlului este: ${intervention.leakCheckResult!.label.toLowerCase()}.';
    }
    return 'Nu sunt consemnate explicit date privind un control distinct al etanseitatii.';
  }

  static String _installationTechnicalRemark(
    AgfrEquipmentRecord equipment,
    AgfrInterventionRecord intervention,
  ) {
    final total = _resolvedTotalInSystem(equipment, intervention);
    if (total > 0) {
      return 'Cantitatea totala consemnata in sistem dupa operatiune este de ${total.toStringAsFixed(2)} kg agent frigorific.';
    }
    return 'Cantitatea finala de agent frigorific in sistem nu este consemnata explicit.';
  }

  static String _serviceStatusRemark(AgfrInterventionRecord intervention) {
    if (intervention.notes.trim().isNotEmpty) {
      return 'Aspectele constatate sunt mentionate la observatii.';
    }
    return 'Starea instalatiei a fost evaluata in limitele operatiunii de service / mentenanta consemnate.';
  }

  static String _recoveredContainerLabel(AgfrInterventionRecord intervention) {
    if (intervention.notes.trim().isNotEmpty) {
      return 'Conform mentiunilor din observatii / documente asociate.';
    }
    return 'Recipientul de recuperare nu este identificat explicit in datele disponibile.';
  }

  static String _recoveryExecutionRemark(AgfrInterventionRecord intervention) {
    if (intervention.recoveredKg > 0) {
      return 'Recuperarea agentului frigorific a fost consemnata inaintea gestionarii ulterioare a acestuia.';
    }
    return 'Nu este consemnata cantitatea recuperata in datele disponibile ale interventiei.';
  }

  static String _decommissioningRemark(AgfrInterventionRecord intervention) {
    if (intervention.recoveredKg > 0) {
      return 'Scoaterea din functiune a fost consemnata impreuna cu operatiunea de recuperare a agentului frigorific.';
    }
    return 'Dezafectarea a fost consemnata, fara detalii complete privind recuperarea agentului frigorific.';
  }

  static const String _missingValueLabel = 'Necompletat';

  static pw.MemoryImage? _tryDecodeBase64(String value) {
    if (value.trim().isEmpty) {
      return null;
    }
    try {
      final bytes = UriData.parse(value).contentAsBytes();
      return pw.MemoryImage(bytes);
    } catch (_) {
      try {
        final bytes = Uint8List.fromList(const Base64Decoder().convert(value));
        return pw.MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
  }
}

class _AttachmentAnnex {
  const _AttachmentAnnex({
    required this.title,
    required this.path,
    this.image,
    this.pdfBytes,
    required this.isPdf,
  });

  final String title;
  final String path;
  final pw.MemoryImage? image;
  final Uint8List? pdfBytes;
  final bool isPdf;

  bool get hasReference => path.trim().isNotEmpty;
  bool get isLoaded => image != null || pdfBytes != null;
}
