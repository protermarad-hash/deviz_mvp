import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_font_bundle.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'product_catalog_service.dart';
import 'product_sales_models.dart';

class WarrantyCertificatePdfService {
  const WarrantyCertificatePdfService._();

  static Future<String> export({
    required AppDataRepository repository,
    required WarrantyCertificateRecord certificate,
    String outputDirectory = '',
    bool saveAs = false,
  }) async {
    final pdfFonts = await PdfFontBundle.load();
    final doc = pw.Document(theme: pdfFonts.theme);
    final companyProfile = await repository.loadCompanyProfile();
    final branding = DocumentBrandingData.fromCompanyProfile(companyProfile);
    final service = ProductCatalogService();

    String dateLabel(DateTime? value) {
      if (value == null) return '-';
      final d = value.day.toString().padLeft(2, '0');
      final m = value.month.toString().padLeft(2, '0');
      return '$d.$m.${value.year}';
    }

    pw.Widget infoLine(String label, String value, {double width = 118}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: width,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8.7,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value.trim().isEmpty ? '-' : value.trim(),
                style: const pw.TextStyle(fontSize: 8.7),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget block(String title, List<pw.Widget> children) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey500),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            ...children,
          ],
        ),
      );
    }

    pw.Widget coupon(String title, WarrantyServiceTicketRecord? ticket) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey500),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
            ),
            pw.SizedBox(height: 8),
            infoLine(
              'Data primire',
              ticket == null
                  ? '................................'
                  : dateLabel(ticket.receivedDate),
              width: 70,
            ),
            infoLine(
              'Finalizare',
              ticket == null
                  ? '................................'
                  : dateLabel(ticket.completedDate),
              width: 70,
            ),
            infoLine(
              'Defect',
              ticket == null
                  ? '................................'
                  : ticket.defect,
              width: 70,
            ),
            infoLine(
              'Fisa service',
              ticket == null
                  ? '................................'
                  : ticket.repairReportNumber,
              width: 70,
            ),
            infoLine(
              'Service',
              ticket == null
                  ? '................................'
                  : ticket.serviceSignatureLabel,
              width: 70,
            ),
          ],
        ),
      );
    }

    final coverage = service.coverageStatusForCertificate(certificate);
    final warrantyStart = service.effectiveWarrantyStartDate(certificate);
    final warrantyEnd = service.effectiveWarrantyEndDate(certificate);
    final tickets = certificate.warrantyServiceTickets;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          buildClassicDocumentHeader(
            branding: branding,
            documentTitle: 'CERTIFICAT DE GARANTIE',
            template: companyProfile.pdfExportSettings.visualTemplate,
            metadata: <MapEntry<String, String>>[
              MapEntry<String, String>(
                'Numar',
                certificate.fullCertificateNumber,
              ),
              MapEntry<String, String>(
                'Data document',
                dateLabel(certificate.documentDate),
              ),
              MapEntry<String, String>(
                'Factura',
                certificate.invoiceNumber,
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: block(
                  'Date document',
                  [
                    infoLine('Serie', certificate.certificateSeries),
                    infoLine('Numar', certificate.certificateNumber),
                    infoLine(
                        'Data document', dateLabel(certificate.documentDate)),
                    infoLine('Factura', certificate.invoiceNumber),
                    infoLine('Data vanzare', dateLabel(certificate.saleDate)),
                    infoLine(
                      'Perioada garantie',
                      '${certificate.warrantyMonths} luni',
                    ),
                    infoLine('Start garantie', dateLabel(warrantyStart)),
                    infoLine('Sfarsit garantie', dateLabel(warrantyEnd)),
                    infoLine('Status garantie', coverage.label),
                  ],
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: block(
                  'Echipament',
                  [
                    infoLine('Tip echipament', certificate.equipmentType),
                    infoLine('Brand', certificate.brand),
                    infoLine('Model', certificate.model),
                    infoLine('Serie UI', certificate.serialNumberIndoor),
                    infoLine('Serie UE', certificate.serialNumberOutdoor),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: block(
                  'Vanzator',
                  [
                    infoLine('Denumire', certificate.sellerName),
                    infoLine('Adresa', certificate.sellerAddress),
                    infoLine('Email', certificate.sellerEmail),
                    infoLine('Telefon', certificate.sellerPhone),
                    infoLine('CUI / CIF', certificate.sellerTaxId),
                  ],
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: block(
                  'Cumparator',
                  [
                    infoLine('Nume', certificate.buyerName),
                    infoLine('Adresa', certificate.buyerAddress),
                    infoLine('Telefon', certificate.buyerPhone),
                    infoLine('CUI / CNP', certificate.buyerTaxOrCnp),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          block(
            'Instalator / centru service autorizat',
            [
              infoLine('Denumire', certificate.installerName),
              infoLine('Adresa', certificate.installerAddress),
              infoLine('Email', certificate.installerEmail),
              infoLine('Telefon', certificate.installerPhone),
              infoLine('CUI / CIF', certificate.installerTaxId),
              infoLine('Persoane instalare', certificate.installerPersons),
              infoLine(
                'Data instalare / punere in functiune',
                dateLabel(certificate.installationDate),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          block(
            'Condiții de garanție',
            [
              pw.Text(
                certificate.termsText.trim().isEmpty
                    ? '-'
                    : certificate.termsText.trim(),
                style: const pw.TextStyle(fontSize: 8.3, lineSpacing: 2),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Taloane service / interventii',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                  child: coupon(
                      'Talon 1', tickets.isNotEmpty ? tickets[0] : null)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child:
                    coupon('Talon 2', tickets.length > 1 ? tickets[1] : null),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          coupon('Talon 3', tickets.length > 2 ? tickets[2] : null),
        ],
      ),
    );

    final safeNumber = certificate.fullCertificateNumber
        .replaceAll(RegExp(r'[^A-Za-z0-9_\- ]+'), '_')
        .replaceAll(' ', '_');

    return PdfSaveService.savePdf(
      repository: repository,
      bytes: await doc.save(),
      fileName: 'certificat_garantie_$safeNumber.pdf',
      category: PdfDocumentCategory.other,
      outputDirectory: outputDirectory,
      forceSaveAs: saveAs,
    );
  }
}
