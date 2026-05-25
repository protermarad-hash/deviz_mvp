import '../../core/pdf/pdf_font_helper.dart';
import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import '../product_catalog/product_catalog_models.dart';
import 'field_sales_models.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class FieldSalesQuotePdfProductRow {
  const FieldSalesQuotePdfProductRow({
    required this.name,
    this.details = '',
    this.quantity = 1,
    this.unit = 'buc',
    this.unitPrice = 0,
    this.lineTotal = 0,
    this.currency = 'RON',
    this.stockStatus = ProductStockStatus.inStock,
    this.deliveryLeadTimeText = '',
  });

  final String name;
  final String details;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double lineTotal;
  final String currency;
  final ProductStockStatus stockStatus;
  final String deliveryLeadTimeText;
}

class FieldSalesQuotePdfService {
  const FieldSalesQuotePdfService._();

  static Future<String> export({
    required AppDataRepository repository,
    required FieldSalesRequestRecord request,
    required DocumentBrandingData branding,
    required PdfVisualTemplate template,
    required String agentLabel,
    FieldLeadRecord? lead,
    List<FieldSalesQuotePdfProductRow> productRows =
        const <FieldSalesQuotePdfProductRow>[],
    String outputDirectory = '',
    bool saveAs = false,
  }) async {
    await PdfFontHelper.initialize();
    final doc = pw.Document(theme: PdfFontHelper.theme);
    final currency = request.currency.trim().isEmpty ? 'RON' : request.currency;
    final products = productRows;
    final services = request.requestedServicePresets;
    final generatedAt = DateTime.now();

    String dateLabel(DateTime value) {
      final d = value.day.toString().padLeft(2, '0');
      final m = value.month.toString().padLeft(2, '0');
      return '$d.$m.${value.year}';
    }

    String dateTimeLabel(DateTime value) {
      final h = value.hour.toString().padLeft(2, '0');
      final min = value.minute.toString().padLeft(2, '0');
      return '${dateLabel(value)} $h:$min';
    }

    String money(double value, String rowCurrency) {
      final normalized = rowCurrency.trim().isEmpty ? currency : rowCurrency;
      return '${value.toStringAsFixed(2)} $normalized';
    }

    String productAvailability(FieldSalesQuotePdfProductRow row) {
      final values = <String>[row.stockStatus.label];
      final leadTime = row.deliveryLeadTimeText.trim();
      if (leadTime.isNotEmpty) {
        values.add('Livrare: $leadTime');
      }
      return values.join(' | ');
    }

    pw.Widget sectionTitle(String title) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 11.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
      );
    }

    pw.Widget infoCard(String title, List<MapEntry<String, String>> entries) {
      pw.Widget line(String label, String value) {
        final normalized = value.trim().isEmpty ? '-' : value.trim();
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 90,
                child: pw.Text(
                  label,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8.8,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  normalized,
                  style: const pw.TextStyle(fontSize: 8.8),
                ),
              ),
            ],
          ),
        );
      }

      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            ...entries.map((entry) => line(entry.key, entry.value)),
          ],
        ),
      );
    }

    final metadata = <MapEntry<String, String>>[
      MapEntry('Referinta', _documentReference(request)),
      MapEntry('Data generarii', dateTimeLabel(generatedAt)),
      MapEntry('Agent', agentLabel.trim().isEmpty ? '-' : agentLabel.trim()),
      MapEntry('Status cerere', request.approvalStatus.label),
    ];

    final clientEntries = <MapEntry<String, String>>[
      MapEntry(
        'Client / lead',
        _resolveClientLabel(request, lead),
      ),
      if ((lead?.phone.trim() ?? '').isNotEmpty)
        MapEntry('Telefon', lead!.phone.trim()),
      if ((lead?.email.trim() ?? '').isNotEmpty)
        MapEntry('Email', lead!.email.trim()),
      if ((lead?.address.trim() ?? '').isNotEmpty)
        MapEntry('Adresa', lead!.address.trim()),
      if (request.requestedPriceListId.trim().isNotEmpty)
        MapEntry('Lista comerciala', request.requestedPriceListId.trim()),
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 20, 24, 20),
        build: (_) => [
          buildClassicDocumentHeader(
            branding: branding,
            documentTitle: 'OFERTA RAPIDA',
            metadata: metadata,
            template: template,
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: infoCard('Client / context', clientEntries),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: infoCard(
                  'Rezumat comercial',
                  <MapEntry<String, String>>[
                    MapEntry(
                      'Subtotal',
                      money(request.requestedSubtotalValue, currency),
                    ),
                    if (request.requestedDiscountPercent > 0) ...[
                      MapEntry(
                        'Discount',
                        '${request.requestedDiscountPercent.toStringAsFixed(2)}%',
                      ),
                      MapEntry(
                        'Valoare discount',
                        money(request.requestedDiscountValue, currency),
                      ),
                    ],
                    MapEntry(
                      'Total propus',
                      money(request.requestedTotalValue, currency),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (products.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            sectionTitle('Produse'),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8.5,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8.3),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 5,
              ),
              headers: const <String>[
                'Produs',
                'Cant.',
                'Pret unitar',
                'Total',
                'Stoc / livrare',
              ],
              columnWidths: <int, pw.TableColumnWidth>{
                0: const pw.FlexColumnWidth(3.4),
                1: const pw.FixedColumnWidth(44),
                2: const pw.FixedColumnWidth(78),
                3: const pw.FixedColumnWidth(78),
                4: const pw.FlexColumnWidth(2.5),
              },
              data: products.map((row) {
                final name = row.details.trim().isEmpty
                    ? row.name.trim()
                    : '${row.name.trim()}\n${row.details.trim()}';
                return <String>[
                  name,
                  '${row.quantity.toStringAsFixed(2)} ${row.unit}',
                  money(row.unitPrice, row.currency),
                  money(row.lineTotal, row.currency),
                  productAvailability(row),
                ];
              }).toList(growable: false),
            ),
          ],
          if (services.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            sectionTitle('Servicii presetate'),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8.5,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8.3),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 5,
              ),
              headers: const <String>[
                'Serviciu',
                'Cant.',
                'Pret unitar',
                'Total',
              ],
              columnWidths: <int, pw.TableColumnWidth>{
                0: const pw.FlexColumnWidth(3.6),
                1: const pw.FixedColumnWidth(50),
                2: const pw.FixedColumnWidth(78),
                3: const pw.FixedColumnWidth(78),
              },
              data: services.map((row) {
                final details = <String>[
                  row.label.trim().isEmpty ? 'Serviciu' : row.label.trim(),
                  if (row.includedServices.trim().isNotEmpty)
                    'Inclus: ${row.includedServices.trim()}',
                  if (row.notes.trim().isNotEmpty)
                    'Conditii: ${row.notes.trim()}',
                ].join('\n');
                return <String>[
                  details,
                  '${row.quantity.toStringAsFixed(2)} ${row.unit}',
                  money(row.unitPrice, row.currency),
                  money(row.lineTotal, row.currency),
                ];
              }).toList(growable: false),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 220,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _totalLine('Subtotal',
                      money(request.requestedSubtotalValue, currency)),
                  if (request.requestedDiscountPercent > 0)
                    _totalLine(
                      'Discount ${request.requestedDiscountPercent.toStringAsFixed(2)}%',
                      '- ${money(request.requestedDiscountValue, currency)}',
                    ),
                  pw.Divider(color: PdfColors.grey400),
                  _totalLine(
                    'Total final',
                    money(request.requestedTotalValue, currency),
                    emphasize: true,
                  ),
                ],
              ),
            ),
          ),
          if (request.notes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            sectionTitle('Observații'),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                request.notes.trim(),
                style: const pw.TextStyle(fontSize: 8.8),
              ),
            ),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: _fileName(request),
      category: PdfDocumentCategory.other,
      outputDirectory: outputDirectory,
      forceSaveAs: saveAs,
    );
  }

  static pw.Widget _totalLine(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    final style = pw.TextStyle(
      fontSize: emphasize ? 10.2 : 9,
      fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.SizedBox(width: 10),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  static String _resolveClientLabel(
    FieldSalesRequestRecord request,
    FieldLeadRecord? lead,
  ) {
    final values = <String>[
      request.clientName.trim(),
      lead?.clientName.trim() ?? '',
      lead?.contactName.trim() ?? '',
    ];
    for (final value in values) {
      if (value.isNotEmpty) {
        return value;
      }
    }
    return request.requestType.label;
  }

  static String _documentReference(FieldSalesRequestRecord request) {
    final raw = request.id.trim();
    if (raw.isEmpty) {
      return 'FSQ-${request.createdAt.millisecondsSinceEpoch}';
    }
    return raw;
  }

  static String _fileName(FieldSalesRequestRecord request) {
    final seed = _documentReference(request)
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final normalized = seed.isEmpty ? 'field_quote' : seed;
    return 'mini_oferta_teren_$normalized.pdf';
  }
}
