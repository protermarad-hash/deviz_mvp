import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'app_models.dart';
import 'pdf_export_settings.dart';
import 'pdf_save_service.dart';
import 'repositories/local_app_data_repository.dart';

class PdfService {
  Future<Uint8List> buildOfferPdf({
    required Map<String, dynamic> offer,
    required List<DraftMaterialLine> lines,
    required List<OfferEmployeeAssignment> employees,
    required List<OfferVehicleAssignment> vehicles,
    required CompanySettings company,
    required String documentLabel,
  }) async {
    final pdf = pw.Document();
    final fonts = await _PdfFontSet.load();
    final savedDocumentType =
        valueText(offer['document_type'], fallback: documentLabel);
    final isClientOffer = savedDocumentType != 'DEVIZ_INTERN';
    final currency = valueText(offer['currency'], fallback: 'RON');
    final eurRate = parseDouble(offer['eur_rate'], fallback: 5);
    final materials = parseDouble(offer['material_total']);
    final labor = parseDouble(offer['labor_total']);
    final laborInternalCost = parseDouble(offer['labor_internal_cost']);
    final vehiclesTotal = parseDouble(offer['vehicle_total']);
    final overhead = parseDouble(offer['overhead_total']);
    final profit = parseDouble(offer['profit_total']);
    final totalNoVat = parseDouble(offer['total_no_vat']);
    final vat = parseDouble(offer['vat_total']);
    final total = parseDouble(offer['grand_total']);
    final logoBytes = company.logoBytes;
    final storedOverheadPercent = parseDouble(offer['overhead_percent']);
    final clientCommercialLabor = labor + vehiclesTotal;
    final rawPriceDisplayMode =
        valueText(offer['price_display_mode'] ?? offer['priceDisplayMode'])
            .toLowerCase()
            .replaceAll('_', '')
            .replaceAll('-', '')
            .replaceAll(' ', '');
    final withoutVatOnly =
        rawPriceDisplayMode == 'withoutvat' || rawPriceDisplayMode == 'faratva';
    final withVatOnly =
        rawPriceDisplayMode == 'withvat' || rawPriceDisplayMode == 'cutva';
    final showBothVatModes = !withoutVatOnly && !withVatOnly;

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: fonts.base, bold: fonts.bold),
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoBytes != null) ...[
                      pw.Container(
                        width: 82,
                        height: 82,
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Image(
                          pw.MemoryImage(logoBytes),
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                      pw.SizedBox(width: 16),
                    ],
                    pw.Expanded(
                      flex: 2,
                      child: _buildCompanyBlock(company),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              isClientOffer ? 'OFERTĂ CLIENT' : 'DEVIZ INTERN',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            _infoRow(
                              'Numar',
                              valueText(offer['number']),
                              maxLines: 1,
                            ),
                            _infoRow('Data', valueText(offer['offer_date'])),
                            _infoRow('Moneda', currency),
                            _infoRow(
                              'TVA',
                              '${parseDouble(offer['vat_percent']).toStringAsFixed(2)}%',
                            ),
                            _infoRow(
                              'Profit',
                              '${parseDouble(offer['profit_percent']).toStringAsFixed(2)}%',
                            ),
                            _infoRow(
                              'Regie',
                              '${storedOverheadPercent.toStringAsFixed(2)}%',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (valueText(offer['titlu_oferta']).trim().isNotEmpty ||
                    valueText(offer['locatie_lucrare']).trim().isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey50,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (valueText(offer['titlu_oferta']).trim().isNotEmpty)
                          _detailBlock(
                            'Titlu ofertă',
                            valueText(offer['titlu_oferta']),
                          ),
                        if (valueText(offer['locatie_lucrare'])
                            .trim()
                            .isNotEmpty)
                          _detailBlock(
                            'Locație lucrare',
                            valueText(offer['locatie_lucrare']),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Emitent: ${AppDefaults.issuerName}',
            style: const pw.TextStyle(color: PdfColors.grey700),
          ),
          if (valueText(offer['client_name']).trim().isNotEmpty ||
              valueText(offer['client_contact_person']).trim().isNotEmpty ||
              valueText(offer['client_phone']).trim().isNotEmpty ||
              valueText(offer['client_email']).trim().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Client',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  if (valueText(offer['client_name']).trim().isNotEmpty)
                    pw.Text(valueText(offer['client_name'])),
                  if (valueText(offer['client_contact_person'])
                      .trim()
                      .isNotEmpty)
                    pw.Text(
                      'Persoană contact: ${valueText(offer['client_contact_person'])}',
                    ),
                  if (valueText(offer['client_phone']).trim().isNotEmpty)
                    pw.Text('Telefon: ${valueText(offer['client_phone'])}'),
                  if (valueText(offer['client_email']).trim().isNotEmpty)
                    pw.Text('Email: ${valueText(offer['client_email'])}'),
                ],
              ),
            ),
          ],
          if (valueText(offer['notes']).trim().isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text('Observații: ${offer['notes']}'),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Text(
            'Lista materiale',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Material', 'UM', 'Cant.', 'Pret', 'Total'],
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            data: lines
                .map(
                  (line) => [
                    line.materialName,
                    line.unit,
                    line.quantity.toStringAsFixed(2),
                    _money(line.unitPrice, currency, eurRate),
                    _money(line.total, currency, eurRate),
                  ],
                )
                .toList(),
          ),
          if (!isClientOffer && employees.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'Resurse umane',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const ['Nume', 'Rol', 'Ore', 'Zile', 'Tarif', 'Total'],
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              data: employees
                  .map(
                    (item) => [
                      item.name,
                      item.role,
                      item.workedHours.toStringAsFixed(2),
                      item.workedDays.toStringAsFixed(2),
                      _money(item.hourlyRate, currency, eurRate),
                      _money(item.laborCost, currency, eurRate),
                    ],
                  )
                  .toList(),
            ),
          ],
          if (!isClientOffer && vehicles.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'Autoturisme',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Masina',
                'Nr.',
                'Km',
                'Zile',
                'Cost/km',
                'Total'
              ],
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              data: vehicles
                  .map(
                    (item) => [
                      item.name,
                      item.plateNumber,
                      item.kilometers.toStringAsFixed(2),
                      item.workedDays.toStringAsFixed(2),
                      _money(item.costPerKm, currency, eurRate),
                      _money(item.totalCost, currency, eurRate),
                    ],
                  )
                  .toList(),
            ),
          ],
          if (!isClientOffer) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Detalii interne',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _summaryRow(
                    'Cost intern manoperă',
                    _money(laborInternalCost, currency, eurRate),
                  ),
                  _summaryRow(
                    'Mod regie',
                    valueText(offer['overhead_mode'], fallback: '-'),
                  ),
                  _summaryRow(
                    'Regie procent fix',
                    '${storedOverheadPercent.toStringAsFixed(2)}%',
                  ),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Rezumat financiar',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      _summaryRow(
                        isClientOffer ? 'Materiale' : 'Subtotal materiale',
                        _money(materials, currency, eurRate),
                      ),
                      if ((isClientOffer && clientCommercialLabor > 0) ||
                          (!isClientOffer && labor > 0))
                        _summaryRow(
                          isClientOffer
                              ? 'Manoperă generală'
                              : 'Subtotal manoperă',
                          _money(
                            isClientOffer ? clientCommercialLabor : labor,
                            currency,
                            eurRate,
                          ),
                        ),
                      if (!isClientOffer && vehiclesTotal > 0)
                        _summaryRow(
                          'Subtotal autoturisme',
                          _money(vehiclesTotal, currency, eurRate),
                        ),
                      _summaryRow(
                        isClientOffer
                            ? 'Regie (${storedOverheadPercent.toStringAsFixed(2)}%)'
                            : 'Regie',
                        _money(overhead, currency, eurRate),
                      ),
                      _summaryRow(
                        isClientOffer
                            ? 'Profit (${parseDouble(offer['profit_percent']).toStringAsFixed(2)}%)'
                            : 'Profit',
                        _money(profit, currency, eurRate),
                      ),
                      _summaryRow(
                        showBothVatModes
                            ? 'Total fără TVA'
                            : withoutVatOnly
                                ? 'Total fără TVA'
                                : 'Preț ofertat',
                        _money(
                          withoutVatOnly || showBothVatModes
                              ? totalNoVat
                              : total,
                          currency,
                          eurRate,
                        ),
                      ),
                      if (showBothVatModes)
                        _summaryRow(
                          'TVA (${parseDouble(offer['vat_percent']).toStringAsFixed(2)}%)',
                          _money(vat, currency, eurRate),
                        ),
                      pw.Divider(color: PdfColors.grey400),
                      _summaryRow(
                        withoutVatOnly
                            ? 'Total fără TVA'
                            : showBothVatModes
                                ? 'Total cu TVA'
                                : 'Total',
                        _money(
                          withoutVatOnly ? totalNoVat : total,
                          currency,
                          eurRate,
                        ),
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<String> exportPdf({
    required Uint8List bytes,
    required String filename,
  }) async {
    return PdfSaveService.savePdf(
      repository: LocalAppDataRepository(),
      bytes: bytes,
      fileName: filename,
      category: PdfDocumentCategory.offers,
    );
  }

  pw.Widget _buildCompanyBlock(CompanySettings company) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          company.companyNameOrFallback,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        if (company.companyAddress.isNotEmpty) pw.Text(company.companyAddress),
        if (company.companyPhone.isNotEmpty)
          pw.Text('Telefon: ${company.companyPhone}'),
        if (company.companyEmail.isNotEmpty)
          pw.Text('Email: ${company.companyEmail}'),
        if (company.companyCui.isNotEmpty)
          pw.Text('CUI: ${company.companyCui}'),
        if (company.companyTradeRegister.isNotEmpty)
          pw.Text('Reg. com.: ${company.companyTradeRegister}'),
        if (company.companyBank.isNotEmpty)
          pw.Text('Banca: ${company.companyBank}'),
        if (company.companyIban.isNotEmpty)
          pw.Text('IBAN: ${company.companyIban}'),
        if (company.companyContactName.isNotEmpty)
          pw.Text('Persoana contact: ${company.companyContactName}'),
      ],
    );
  }

  pw.Widget _infoRow(String label, String value, {int? maxLines}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 62,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              maxLines: maxLines,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _detailBlock(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$label:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(value),
        ],
      ),
    );
  }

  pw.Widget _summaryRow(String label, String value, {bool emphasize = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: emphasize
                ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)
                : const pw.TextStyle(),
          ),
          pw.Text(
            value,
            style: emphasize
                ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)
                : const pw.TextStyle(),
          ),
        ],
      ),
    );
  }

  String _money(double amount, String currency, double eurRate) {
    return formatMoney(amount, currency: currency, eurRate: eurRate);
  }
}

class _PdfFontSet {
  final pw.Font base;
  final pw.Font bold;

  const _PdfFontSet({
    required this.base,
    required this.bold,
  });

  static Future<_PdfFontSet> load() async {
    final regular = await rootBundle.load('assets/fonts/arial.ttf');
    final bold = await rootBundle.load('assets/fonts/arialbd.ttf');
    return _PdfFontSet(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    );
  }
}
