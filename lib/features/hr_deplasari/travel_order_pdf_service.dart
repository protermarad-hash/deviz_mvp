import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/lookup_models.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'trip_models.dart';

class TravelOrderPdfService {
  const TravelOrderPdfService._();

  static Future<String> export({
    required AppDataRepository repository,
    required TravelOrder order,
    Trip? trip,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    required String companyEmail,
    String companyCui = '',
    String companyTradeRegister = '',
    String companyBank = '',
    String companyIban = '',
    String companyContactName = '',
    String companyLogoBase64 = '',
    EmployeeLookup? employee,
    LookupItem? team,
    LookupItem? vehicle,
    String assigneeName = '',
    String vehicleName = '',
    String clientName = '',
    String sourceLabel = '',
    String outputDirectory = '',
    PdfVisualTemplate template = PdfVisualTemplate.classic,
  }) async {
    final fonts = await _FontSet.load();
    final logo = _tryDecodeBase64(companyLogoBase64);

    final periodText =
        '${_dateTime(order.periodStart)} – ${_dateTime(order.periodEnd)}';
    final companyLocation = companyAddress.trim().isNotEmpty
        ? companyAddress.trim()
        : companyName.trim();
    final originLocation =
        _resolve(order.originLocation, fallback: companyLocation);
    final destinationLocation = _resolve(order.destinationLocation);
    final teamName = team?.name ?? '';
    final targetText = employee != null
        ? '${employee.name}${employee.role.isEmpty ? '' : ' (${employee.role})'}'
        : (teamName.trim().isNotEmpty
            ? 'Echipa: $teamName'
            : assigneeName.trim());
    final vehicleText = (vehicle?.name ?? vehicleName).trim();

    pw.Document doc;
    switch (template) {
      case PdfVisualTemplate.modern:
        doc = await _buildModern(
          fonts: fonts,
          logo: logo,
          order: order,
          trip: trip,
          companyName: companyName,
          companyAddress: companyAddress,
          companyPhone: companyPhone,
          companyEmail: companyEmail,
          companyCui: companyCui,
          targetText: targetText,
          vehicleText: vehicleText,
          clientName: clientName,
          periodText: periodText,
          originLocation: originLocation,
          destinationLocation: destinationLocation,
        );
        break;
      case PdfVisualTemplate.minimal:
        doc = await _buildMinimal(
          fonts: fonts,
          logo: logo,
          order: order,
          trip: trip,
          companyName: companyName,
          companyAddress: companyAddress,
          companyPhone: companyPhone,
          companyEmail: companyEmail,
          companyCui: companyCui,
          targetText: targetText,
          vehicleText: vehicleText,
          clientName: clientName,
          periodText: periodText,
          originLocation: originLocation,
          destinationLocation: destinationLocation,
        );
        break;
      default:
        doc = await _buildClassic(
          fonts: fonts,
          logo: logo,
          order: order,
          trip: trip,
          companyName: companyName,
          companyAddress: companyAddress,
          companyPhone: companyPhone,
          companyEmail: companyEmail,
          companyCui: companyCui,
          targetText: targetText,
          vehicleText: vehicleText,
          clientName: clientName,
          periodText: periodText,
          originLocation: originLocation,
          destinationLocation: destinationLocation,
        );
    }

    final bytes = await doc.save();
    final safeNumber =
        order.orderNumber.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: 'ordin_deplasare_$safeNumber.pdf',
      category: PdfDocumentCategory.travelOrders,
      outputDirectory: outputDirectory,
    );
  }

  // ─── TEMPLATE CLASIC ────────────────────────────────────────────────────────

  static Future<pw.Document> _buildClassic({
    required _FontSet fonts,
    required pw.MemoryImage? logo,
    required TravelOrder order,
    Trip? trip,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    required String companyEmail,
    required String companyCui,
    required String targetText,
    required String vehicleText,
    required String clientName,
    required String periodText,
    required String originLocation,
    required String destinationLocation,
  }) async {
    final doc = pw.Document();
    const accent = PdfColor(0.12, 0.24, 0.49); // #1E3D7D navy
    const lightGrey = PdfColor(0.95, 0.95, 0.95);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
      build: (ctx) => [
        // ── Header ──
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Container(
                width: 58,
                height: 40,
                margin: const pw.EdgeInsets.only(right: 10),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (companyName.trim().isNotEmpty)
                    pw.Text(companyName,
                        style: pw.TextStyle(
                            font: fonts.bold,
                            fontSize: 12,
                            color: accent)),
                  pw.SizedBox(height: 2),
                  if (companyAddress.trim().isNotEmpty)
                    _infoText('Adresă: $companyAddress', fonts),
                  if (companyPhone.trim().isNotEmpty)
                    _infoText('Tel: $companyPhone', fonts),
                  if (companyEmail.trim().isNotEmpty)
                    _infoText('Email: $companyEmail', fonts),
                  if (companyCui.trim().isNotEmpty)
                    _infoText('CUI: $companyCui', fonts),
                ],
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: accent,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('ORDIN DE DEPLASARE',
                      style: pw.TextStyle(
                          font: fonts.bold,
                          fontSize: 9,
                          color: PdfColors.white)),
                  pw.SizedBox(height: 3),
                  pw.Text('Nr: ${order.orderNumber}',
                      style: pw.TextStyle(
                          font: fonts.regular,
                          fontSize: 8,
                          color: PdfColors.white)),
                  pw.Text('Data: ${_date(order.issueDate)}',
                      style: pw.TextStyle(
                          font: fonts.regular,
                          fontSize: 8,
                          color: PdfColors.white)),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 10),
        pw.Divider(color: accent, thickness: 1),
        pw.SizedBox(height: 8),

        // ── Secțiunea Deplasare ──
        _classicSection(
          title: 'DETALII DEPLASARE',
          accent: accent,
          lightGrey: lightGrey,
          fonts: fonts,
          rows: [
            _row('Persoană', targetText, fonts),
            if (clientName.trim().isNotEmpty)
              _row('Client', clientName, fonts),
            _row('Traseu',
                '$originLocation → $destinationLocation', fonts),
            _row('Perioadă', periodText, fonts),
            _row(
                'Durată',
                '${order.resolvedPerDiemDays} zile  |  ${order.resolvedLodgingNights} nopți',
                fonts),
            _row('Scop',
                order.purpose.isEmpty ? '-' : order.purpose, fonts),
            if (order.transportType.trim().isNotEmpty)
              _row('Transport', order.transportType, fonts),
            if (vehicleText.isNotEmpty)
              _row('Vehicul', vehicleText, fonts),
            if (order.estimatedKm > 0)
              _row('Km estimați',
                  order.estimatedKm.toStringAsFixed(1), fonts),
          ],
        ),

        pw.SizedBox(height: 8),

        // ── Costuri ──
        _classicSection(
          title: 'COSTURI (LEI)',
          accent: accent,
          lightGrey: lightGrey,
          fonts: fonts,
          rows: [
            _row('Diurnă/zi',
                order.perDiemPerDay.toStringAsFixed(2), fonts),
            _row('Total diurnă',
                order.totalPerDiemCost.toStringAsFixed(2), fonts),
            _row('Cazare',
                order.totalLodgingCost.toStringAsFixed(2), fonts),
            _row('Avans',
                order.advanceAmount.toStringAsFixed(2), fonts),
            _rowBold('TOTAL ESTIMAT',
                '${order.totalEstimatedCost.toStringAsFixed(2)} lei',
                fonts),
          ],
        ),

        if (order.hasDetailedLodgings && order.lodgings.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _classicSection(
            title: 'CAZĂRI',
            accent: accent,
            lightGrey: lightGrey,
            fonts: fonts,
            rows: order.lodgings
                .take(4)
                .map((l) => _row(
                      l.location.isEmpty ? 'Cazare' : l.location,
                      '${l.nights} nopți – ${l.resolvedTotalCost.toStringAsFixed(2)} lei',
                      fonts,
                    ))
                .toList(),
          ),
        ],

        if (trip != null && trip.notes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _classicSection(
            title: 'NOTE',
            accent: accent,
            lightGrey: lightGrey,
            fonts: fonts,
            rows: [
              pw.Text(
                trip.notes.length > 200
                    ? '${trip.notes.substring(0, 200)}...'
                    : trip.notes,
                style: pw.TextStyle(font: fonts.regular, fontSize: 8),
              ),
            ],
          ),
        ],

        pw.SizedBox(height: 10),
        _classicSection(
          title: 'APROBĂRI',
          accent: accent,
          lightGrey: lightGrey,
          fonts: fonts,
          rows: [
            _row('Emis de', order.resolvedIssuedBy, fonts),
            _row('Aprobat de', order.resolvedApprovedBy, fonts),
            _row('Status', order.status.label, fonts),
          ],
        ),

        pw.SizedBox(height: 16),
        _signatureRow(fonts),
      ],
    ));
    return doc;
  }

  // ─── TEMPLATE MODERN ────────────────────────────────────────────────────────

  static Future<pw.Document> _buildModern({
    required _FontSet fonts,
    required pw.MemoryImage? logo,
    required TravelOrder order,
    Trip? trip,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    required String companyEmail,
    required String companyCui,
    required String targetText,
    required String vehicleText,
    required String clientName,
    required String periodText,
    required String originLocation,
    required String destinationLocation,
  }) async {
    final doc = pw.Document();
    const headerBg = PdfColor(0.07, 0.13, 0.30); // #12224D deep navy
    const accentBar = PdfColor(0.18, 0.53, 0.80); // #2E87CC blue
    const sectionBg = PdfColor(0.96, 0.97, 0.99);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
      build: (ctx) => [
        // ── Header bar ──
        pw.Container(
          width: double.infinity,
          color: headerBg,
          padding: const pw.EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null)
                pw.Container(
                  width: 52,
                  height: 36,
                  margin: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (companyName.trim().isNotEmpty)
                      pw.Text(companyName,
                          style: pw.TextStyle(
                              font: fonts.bold,
                              fontSize: 13,
                              color: PdfColors.white)),
                    if (companyAddress.trim().isNotEmpty)
                      pw.Text(companyAddress,
                          style: pw.TextStyle(
                              font: fonts.regular,
                              fontSize: 7.5,
                              color: PdfColors.white.shade(0.6))),
                    if (companyCui.trim().isNotEmpty)
                      pw.Text('CUI: $companyCui',
                          style: pw.TextStyle(
                              font: fonts.regular,
                              fontSize: 7,
                              color: PdfColors.white.shade(0.6))),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: accentBar,
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Text('ORDIN DE DEPLASARE',
                        style: pw.TextStyle(
                            font: fonts.bold,
                            fontSize: 9,
                            color: PdfColors.white)),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Nr. ${order.orderNumber}',
                      style: pw.TextStyle(
                          font: fonts.bold,
                          fontSize: 9,
                          color: PdfColors.white)),
                  pw.Text(_date(order.issueDate),
                      style: pw.TextStyle(
                          font: fonts.regular,
                          fontSize: 8,
                          color: PdfColors.white.shade(0.6))),
                ],
              ),
            ],
          ),
        ),

        pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Grid info ──
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: _modernSection(
                      title: 'DETALII DEPLASARE',
                      accentBar: accentBar,
                      bg: sectionBg,
                      fonts: fonts,
                      rows: [
                        _row('Persoană', targetText, fonts),
                        if (clientName.trim().isNotEmpty)
                          _row('Client', clientName, fonts),
                        _row('Traseu',
                            '$originLocation → $destinationLocation',
                            fonts),
                        _row('Perioadă', periodText, fonts),
                        _row(
                            'Durată',
                            '${order.resolvedPerDiemDays} zile  |  ${order.resolvedLodgingNights} nopți',
                            fonts),
                        _row('Scop',
                            order.purpose.isEmpty ? '-' : order.purpose,
                            fonts),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      children: [
                        _modernSection(
                          title: 'TRANSPORT',
                          accentBar: accentBar,
                          bg: sectionBg,
                          fonts: fonts,
                          rows: [
                            if (order.transportType.trim().isNotEmpty)
                              _row('Tip', order.transportType, fonts),
                            if (vehicleText.isNotEmpty)
                              _row('Vehicul', vehicleText, fonts),
                            if (order.estimatedKm > 0)
                              _row('Km est.',
                                  order.estimatedKm.toStringAsFixed(1),
                                  fonts),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        _modernSection(
                          title: 'COSTURI (LEI)',
                          accentBar: accentBar,
                          bg: sectionBg,
                          fonts: fonts,
                          rows: [
                            _row('Diurnă/zi',
                                order.perDiemPerDay.toStringAsFixed(2),
                                fonts),
                            _row('Total diurnă',
                                order.totalPerDiemCost.toStringAsFixed(2),
                                fonts),
                            _row('Cazare',
                                order.totalLodgingCost.toStringAsFixed(2),
                                fonts),
                            _row('Avans',
                                order.advanceAmount.toStringAsFixed(2),
                                fonts),
                            _rowBold(
                                'TOTAL',
                                '${order.totalEstimatedCost.toStringAsFixed(2)} lei',
                                fonts),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (order.hasDetailedLodgings && order.lodgings.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                _modernSection(
                  title: 'CAZĂRI DETALIATE',
                  accentBar: accentBar,
                  bg: sectionBg,
                  fonts: fonts,
                  rows: order.lodgings
                      .take(4)
                      .map((l) => _row(
                            l.location.isEmpty ? 'Cazare' : l.location,
                            '${l.nights} nopți – ${l.resolvedTotalCost.toStringAsFixed(2)} lei',
                            fonts,
                          ))
                      .toList(),
                ),
              ],

              if (trip != null && trip.notes.trim().isNotEmpty) ...[
                pw.SizedBox(height: 8),
                _modernSection(
                  title: 'NOTE',
                  accentBar: accentBar,
                  bg: sectionBg,
                  fonts: fonts,
                  rows: [
                    pw.Text(
                      trip.notes.length > 200
                          ? '${trip.notes.substring(0, 200)}...'
                          : trip.notes,
                      style:
                          pw.TextStyle(font: fonts.regular, fontSize: 8),
                    ),
                  ],
                ),
              ],

              pw.SizedBox(height: 8),
              _modernSection(
                title: 'APROBĂRI',
                accentBar: accentBar,
                bg: sectionBg,
                fonts: fonts,
                rows: [
                  _row('Emis de', order.resolvedIssuedBy, fonts),
                  _row('Aprobat de', order.resolvedApprovedBy, fonts),
                  _row('Status', order.status.label, fonts),
                ],
              ),

              pw.SizedBox(height: 16),
              _signatureRow(fonts),
            ],
          ),
        ),
      ],
    ));
    return doc;
  }

  // ─── TEMPLATE MINIMAL ───────────────────────────────────────────────────────

  static Future<pw.Document> _buildMinimal({
    required _FontSet fonts,
    required pw.MemoryImage? logo,
    required TravelOrder order,
    Trip? trip,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    required String companyEmail,
    required String companyCui,
    required String targetText,
    required String vehicleText,
    required String clientName,
    required String periodText,
    required String originLocation,
    required String destinationLocation,
  }) async {
    final doc = pw.Document();
    const dark = PdfColor(0.10, 0.10, 0.10);
    const mid = PdfColor(0.40, 0.40, 0.40);
    const light = PdfColor(0.80, 0.80, 0.80);
    const accentLine = PdfColor(0.13, 0.53, 0.76); // teal accent

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
      build: (ctx) => [
        // ── Header minimal ──
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (logo != null)
              pw.Container(
                width: 44,
                height: 30,
                margin: const pw.EdgeInsets.only(right: 10),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (companyName.trim().isNotEmpty)
                    pw.Text(companyName,
                        style: pw.TextStyle(
                            font: fonts.bold, fontSize: 11, color: dark)),
                  pw.Text(
                    [
                      if (companyAddress.trim().isNotEmpty) companyAddress,
                      if (companyCui.trim().isNotEmpty) 'CUI: $companyCui',
                    ].join('  ·  '),
                    style: pw.TextStyle(
                        font: fonts.regular, fontSize: 7, color: mid),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('ORDIN DE DEPLASARE',
                    style: pw.TextStyle(
                        font: fonts.bold,
                        fontSize: 10,
                        color: accentLine,
                        letterSpacing: 0.5)),
                pw.SizedBox(height: 2),
                pw.Text('${order.orderNumber}  ·  ${_date(order.issueDate)}',
                    style: pw.TextStyle(
                        font: fonts.regular, fontSize: 8, color: mid)),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 4),
        pw.Container(height: 1.5, color: accentLine),
        pw.SizedBox(height: 12),

        // ── Detalii deplasare ──
        _minSection('Detalii deplasare', accentLine, light, fonts),
        pw.SizedBox(height: 5),
        _minGrid(fonts, [
          _minCell('Persoană', targetText, fonts),
          if (clientName.trim().isNotEmpty)
            _minCell('Client', clientName, fonts),
          _minCell('Traseu',
              '$originLocation → $destinationLocation', fonts),
          _minCell('Perioadă', periodText, fonts),
          _minCell(
              'Durată',
              '${order.resolvedPerDiemDays} zile  |  ${order.resolvedLodgingNights} nopți',
              fonts),
          _minCell(
              'Scop',
              order.purpose.isEmpty ? '–' : order.purpose,
              fonts),
          if (order.transportType.trim().isNotEmpty)
            _minCell('Transport', order.transportType, fonts),
          if (vehicleText.isNotEmpty)
            _minCell('Vehicul', vehicleText, fonts),
          if (order.estimatedKm > 0)
            _minCell('Km estimați',
                order.estimatedKm.toStringAsFixed(1), fonts),
        ]),

        pw.SizedBox(height: 12),

        // ── Costuri ──
        _minSection('Costuri (lei)', accentLine, light, fonts),
        pw.SizedBox(height: 5),
        _minGrid(fonts, [
          _minCell('Diurnă/zi',
              order.perDiemPerDay.toStringAsFixed(2), fonts),
          _minCell('Total diurnă',
              order.totalPerDiemCost.toStringAsFixed(2), fonts),
          _minCell('Cazare',
              order.totalLodgingCost.toStringAsFixed(2), fonts),
          _minCell('Avans',
              order.advanceAmount.toStringAsFixed(2), fonts),
          _minCellBold('TOTAL ESTIMAT',
              '${order.totalEstimatedCost.toStringAsFixed(2)} lei', fonts),
        ]),

        if (order.hasDetailedLodgings && order.lodgings.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _minSection('Cazări detaliate', accentLine, light, fonts),
          pw.SizedBox(height: 5),
          _minGrid(
            fonts,
            order.lodgings
                .take(4)
                .map((l) => _minCell(
                      l.location.isEmpty ? 'Cazare' : l.location,
                      '${l.nights} nopți – ${l.resolvedTotalCost.toStringAsFixed(2)} lei',
                      fonts,
                    ))
                .toList(),
          ),
        ],

        if (trip != null && trip.notes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _minSection('Note', accentLine, light, fonts),
          pw.SizedBox(height: 5),
          pw.Text(
            trip.notes.length > 200
                ? '${trip.notes.substring(0, 200)}...'
                : trip.notes,
            style: pw.TextStyle(
                font: fonts.regular, fontSize: 8, color: mid),
          ),
        ],

        pw.SizedBox(height: 12),
        _minSection('Aprobări', accentLine, light, fonts),
        pw.SizedBox(height: 5),
        _minGrid(fonts, [
          _minCell('Emis de', order.resolvedIssuedBy, fonts),
          _minCell('Aprobat de', order.resolvedApprovedBy, fonts),
          _minCell('Status', order.status.label, fonts),
        ]),

        pw.SizedBox(height: 20),
        _signatureRow(fonts),
      ],
    ));
    return doc;
  }

  // ─── WIDGET HELPERS ─────────────────────────────────────────────────────────

  static pw.Widget _classicSection({
    required String title,
    required PdfColor accent,
    required PdfColor lightGrey,
    required _FontSet fonts,
    required List<pw.Widget> rows,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: pw.BoxDecoration(
              color: lightGrey,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                topRight: pw.Radius.circular(4),
              ),
            ),
            child: pw.Text(title,
                style: pw.TextStyle(
                    font: fonts.bold, fontSize: 8.5, color: accent)),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: rows,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _modernSection({
    required String title,
    required PdfColor accentBar,
    required PdfColor bg,
    required _FontSet fonts,
    required List<pw.Widget> rows,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border(
          left: pw.BorderSide(color: accentBar, width: 3),
        ),
      ),
      padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  font: fonts.bold, fontSize: 8, color: accentBar)),
          pw.SizedBox(height: 4),
          ...rows,
        ],
      ),
    );
  }

  static pw.Widget _minSection(
    String title,
    PdfColor accent,
    PdfColor light,
    _FontSet fonts,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title.toUpperCase(),
            style: pw.TextStyle(
                font: fonts.bold,
                fontSize: 8,
                color: accent,
                letterSpacing: 0.8)),
        pw.SizedBox(height: 2),
        pw.Container(height: 0.5, color: light),
      ],
    );
  }

  static pw.Widget _minGrid(_FontSet fonts, List<pw.Widget> cells) {
    final rows = <pw.Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      final right = i + 1 < cells.length ? cells[i + 1] : pw.SizedBox();
      rows.add(pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: cells[i]),
          pw.SizedBox(width: 10),
          pw.Expanded(child: right),
        ],
      ));
      rows.add(pw.SizedBox(height: 3));
    }
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows);
  }

  static pw.Widget _minCell(
      String label, String value, _FontSet fonts) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                font: fonts.regular,
                fontSize: 7,
                color: PdfColors.grey600)),
        pw.Text(value.trim().isEmpty ? '–' : value,
            style: pw.TextStyle(font: fonts.regular, fontSize: 8.5)),
      ],
    );
  }

  static pw.Widget _minCellBold(
      String label, String value, _FontSet fonts) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                font: fonts.bold,
                fontSize: 7,
                color: PdfColors.grey600)),
        pw.Text(value.trim().isEmpty ? '–' : value,
            style: pw.TextStyle(font: fonts.bold, fontSize: 9)),
      ],
    );
  }

  static pw.Widget _row(String label, String value, _FontSet fonts) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 82,
            child: pw.Text(label,
                style: pw.TextStyle(
                    font: fonts.regular,
                    fontSize: 7.5,
                    color: PdfColors.grey600)),
          ),
          pw.Expanded(
            child: pw.Text(value.trim().isEmpty ? '–' : value,
                style:
                    pw.TextStyle(font: fonts.regular, fontSize: 7.5)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _rowBold(
      String label, String value, _FontSet fonts) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 3, bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 82,
            child: pw.Text(label,
                style: pw.TextStyle(font: fonts.bold, fontSize: 8)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(font: fonts.bold, fontSize: 8)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoText(String text, _FontSet fonts) {
    return pw.Text(text,
        style: pw.TextStyle(
            font: fonts.regular,
            fontSize: 7.5,
            color: PdfColors.grey600));
  }

  static pw.Widget _signatureRow(_FontSet fonts) {
    const labels = ['Angajat', 'Emitent', 'Aprobator'];
    return pw.Row(
      children: labels
          .expand((label) sync* {
            yield pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Container(height: 0.5, color: PdfColors.grey500),
                  pw.SizedBox(height: 3),
                  pw.Text(label,
                      style: pw.TextStyle(
                          font: fonts.regular, fontSize: 7.5)),
                  pw.SizedBox(height: 28),
                ],
              ),
            );
            if (label != 'Aprobator') yield pw.SizedBox(width: 20);
          })
          .toList(),
    );
  }

  // ─── UTILITY ────────────────────────────────────────────────────────────────

  static String _date(DateTime v) =>
      '${v.day.toString().padLeft(2, '0')}.${v.month.toString().padLeft(2, '0')}.${v.year}';

  static String _dateTime(DateTime v) {
    final d = _date(v);
    final t =
        '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }

  static String _resolve(String value, {String fallback = '–'}) {
    final t = value.trim();
    if (t.isNotEmpty) return t;
    final f = fallback.trim();
    return f.isEmpty ? '–' : f;
  }

  static pw.MemoryImage? _tryDecodeBase64(String value) {
    if (value.trim().isEmpty) return null;
    try {
      return pw.MemoryImage(UriData.parse(value).contentAsBytes());
    } catch (_) {
      try {
        final clean = value.replaceAll(RegExp(r'\s'), '');
        return pw.MemoryImage(base64Decode(clean));
      } catch (_) {
        return null;
      }
    }
  }
}

class _FontSet {
  final pw.Font regular;
  final pw.Font bold;
  const _FontSet({required this.regular, required this.bold});

  static Future<_FontSet> load() async {
    final r = await rootBundle.load('assets/fonts/arial.ttf');
    final b = await rootBundle.load('assets/fonts/arialbd.ttf');
    return _FontSet(regular: pw.Font.ttf(r), bold: pw.Font.ttf(b));
  }
}
