import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/pdf_font_bundle.dart';
import '../../core/pdf_save_service.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/repositories/local_app_data_repository.dart';
import 'appointment_models.dart';

// ---------------------------------------------------------------------------
// Perioadă selector
// ---------------------------------------------------------------------------

enum _Perioada {
  saptamanaAceasta,
  ultimaSaptamana,
  ultimele2Saptamani,
  lunaCurenta,
  lunaTrecuta;

  String get label {
    switch (this) {
      case _Perioada.saptamanaAceasta:
        return 'Săptămâna curentă';
      case _Perioada.ultimaSaptamana:
        return 'Ultima săptămână';
      case _Perioada.ultimele2Saptamani:
        return 'Ultimele 2 săptămâni';
      case _Perioada.lunaCurenta:
        return 'Luna curentă';
      case _Perioada.lunaTrecuta:
        return 'Luna trecută';
    }
  }

  DateTimeRange get interval {
    final now = DateTime.now();
    switch (this) {
      case _Perioada.saptamanaAceasta:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(monday.year, monday.month, monday.day);
        return DateTimeRange(start: start, end: now);
      case _Perioada.ultimaSaptamana:
        final thisMonday = now.subtract(Duration(days: now.weekday - 1));
        final lastMonday = thisMonday.subtract(const Duration(days: 7));
        final lastSunday = thisMonday.subtract(const Duration(seconds: 1));
        return DateTimeRange(start: lastMonday, end: lastSunday);
      case _Perioada.ultimele2Saptamani:
        final start = now.subtract(const Duration(days: 14));
        return DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: now,
        );
      case _Perioada.lunaCurenta:
        final start = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: start, end: now);
      case _Perioada.lunaTrecuta:
        final firstZiCurenta = DateTime(now.year, now.month, 1);
        final lastZiTrecuta =
            firstZiCurenta.subtract(const Duration(seconds: 1));
        final start =
            DateTime(lastZiTrecuta.year, lastZiTrecuta.month, 1);
        return DateTimeRange(start: start, end: lastZiTrecuta);
    }
  }

  bool get isMonthly =>
      this == _Perioada.lunaCurenta || this == _Perioada.lunaTrecuta;
}

// ---------------------------------------------------------------------------
// Date pentru grafic
// ---------------------------------------------------------------------------

class _ChartBucket {
  const _ChartBucket({
    required this.label,
    required this.income,
    required this.materialCost,
  });

  final String label;
  final double income;
  final double materialCost;

  double get profit => income - materialCost;
  bool get hasData => income > 0 || materialCost > 0;
}

// ---------------------------------------------------------------------------
// Pagina principală
// ---------------------------------------------------------------------------

class ProgramariProfitabilitatePage extends StatefulWidget {
  final List<Appointment> appointments;
  final Future<void> Function(Appointment updated)? onAppointmentSaved;

  const ProgramariProfitabilitatePage({
    super.key,
    required this.appointments,
    this.onAppointmentSaved,
  });

  @override
  State<ProgramariProfitabilitatePage> createState() =>
      _ProgramariProfitabilitatePageState();
}

class _ProgramariProfitabilitatePageState
    extends State<ProgramariProfitabilitatePage> {
  _Perioada _perioada = _Perioada.lunaCurenta;
  AppointmentFinancialStatus? _filtruStatus;
  bool _exportingPdf = false;
  bool _selectMode = false;
  final Set<String> _selectate = {};

  // Programări locale (pot fi actualizate după încasări în bulk)
  late List<Appointment> _localAppointments;

  @override
  void initState() {
    super.initState();
    _localAppointments = List.from(widget.appointments);
  }

  // Toate programările din perioadă (fără filtru status — pentru grafic și totale)
  List<Appointment> get _filtratePerioada {
    final interval = _perioada.interval;
    return _localAppointments.where((a) {
      final dt = a.effectiveStartDateTime;
      return !dt.isBefore(interval.start) && !dt.isAfter(interval.end);
    }).toList()
      ..sort(
        (a, b) =>
            b.effectiveStartDateTime.compareTo(a.effectiveStartDateTime),
      );
  }

  // Programări filtrate și după status (pentru lista de jos)
  List<Appointment> get _filtrate {
    final list = _filtratePerioada;
    if (_filtruStatus == null) return list;
    return list.where((a) => a.adminFinancialStatus == _filtruStatus).toList();
  }

  // Suma totală selectată (folosind interventionPrice dacă nu există adminCollectedAmount)
  double get _totalSelectat {
    return _selectate.fold(0.0, (sum, id) {
      final a = _localAppointments.firstWhere(
        (x) => x.id == id,
        orElse: () => throw StateError(''),
      );
      if (a.interventionPrice > 0) return sum + a.interventionPrice;
      return sum + a.adminCollectedAmount;
    });
  }

  Future<void> _saveUpdated(Appointment updated) async {
    setState(() {
      final idx = _localAppointments.indexWhere((a) => a.id == updated.id);
      if (idx >= 0) _localAppointments[idx] = updated;
    });
    await widget.onAppointmentSaved?.call(updated);
  }

  Future<void> _showBulkCollectionDialog() async {
    if (_selectate.isEmpty || !mounted) return;
    final selected = _localAppointments
        .where((a) => _selectate.contains(a.id))
        .toList();
    var method = 'Cash';
    var status = AppointmentFinancialStatus.incasata;
    var date = DateTime.now();

    final totalDeIncasat = selected.fold<double>(
      0,
      (s, a) => s + (a.interventionPrice > 0 ? a.interventionPrice : a.adminCollectedAmount),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setS) => AlertDialog(
          title: Text('Încasare în bloc — ${selected.length} programări'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sumar selecție
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total de înregistrat: ${totalDeIncasat.toStringAsFixed(2)} RON',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        ...selected.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${a.clientName.isNotEmpty ? a.clientName : a.title} — ${DateFormat('dd.MM').format(a.effectiveStartDateTime)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                a.interventionPrice > 0
                                    ? '${a.interventionPrice.toStringAsFixed(2)} RON'
                                    : '—',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'Modalitate încasare'),
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'Card', child: Text('Card')),
                      DropdownMenuItem(value: 'Transfer', child: Text('Transfer bancar')),
                    ],
                    onChanged: (v) => setS(() => method = v ?? 'Cash'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AppointmentFinancialStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status de aplicat pe toate'),
                    items: AppointmentFinancialStatus.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                        .toList(),
                    onChanged: (v) => setS(() => status = v ?? AppointmentFinancialStatus.incasata),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: DateFormat('dd.MM.yyyy').format(date),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Data încasării',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setS(() => date = picked);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Salvează ${selected.length} programări'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    for (final a in selected) {
      final amount = a.interventionPrice > 0 ? a.interventionPrice : a.adminCollectedAmount;
      final updated = a.copyWith(
        adminCollectedAmount: amount,
        adminCollectedCurrency: a.adminCollectedCurrency.isNotEmpty ? a.adminCollectedCurrency : 'RON',
        adminFinancialStatus: status,
        adminDueDate: date,
      );
      await _saveUpdated(updated);
    }

    setState(() {
      _selectate.clear();
      _selectMode = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Încasat în bloc: ${selected.length} programări — ${totalDeIncasat.toStringAsFixed(2)} RON',
          ),
        ),
      );
    }
  }

  double get _totalIncasat =>
      _filtratePerioada.fold(0, (s, a) => s + a.adminCollectedAmount);

  double get _totalCostMateriale =>
      _filtratePerioada.fold(0, (s, a) => s + a.estimatedMaterialsCost);

  double get _totalProfit =>
      _filtratePerioada.fold(0, (s, a) => s + a.estimatedProfit);

  int get _nrCuIncasare =>
      _filtratePerioada.where((a) => a.adminCollectedAmount > 0).length;

  // Calcul bucketuri pentru grafic
  List<_ChartBucket> _computeBuckets() {
    final all = _filtratePerioada;
    final interval = _perioada.interval;

    if (_perioada.isMonthly) {
      // Grupare săptămânală
      final buckets = <_ChartBucket>[];
      var weekStart = _mondayOf(interval.start);
      int weekNr = 1;
      while (!weekStart.isAfter(interval.end)) {
        final weekEnd = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day + 6,
          23,
          59,
          59,
        );
        final overlapStart =
            weekStart.isBefore(interval.start) ? interval.start : weekStart;
        final overlapEnd =
            weekEnd.isAfter(interval.end) ? interval.end : weekEnd;

        if (!overlapStart.isAfter(overlapEnd)) {
          final apps = all.where((a) {
            final d = a.effectiveStartDateTime;
            return !d.isBefore(weekStart) && !d.isAfter(weekEnd);
          }).toList();
          buckets.add(
            _ChartBucket(
              label: 'S$weekNr\n${DateFormat('dd.MM').format(overlapStart)}',
              income: apps.fold(0.0, (s, a) => s + a.adminCollectedAmount),
              materialCost:
                  apps.fold(0.0, (s, a) => s + a.estimatedMaterialsCost),
            ),
          );
        }
        weekStart = weekStart.add(const Duration(days: 7));
        weekNr++;
      }
      return buckets;
    } else {
      // Grupare zilnică
      final days = interval.end.difference(interval.start).inDays + 1;
      return List.generate(days, (i) {
        final day = DateTime(
          interval.start.year,
          interval.start.month,
          interval.start.day + i,
        );
        final apps = all.where((a) {
          final d = a.effectiveStartDateTime;
          return d.year == day.year &&
              d.month == day.month &&
              d.day == day.day;
        }).toList();
        return _ChartBucket(
          label: DateFormat('EEE\ndd', 'ro_RO').format(day),
          income: apps.fold(0.0, (s, a) => s + a.adminCollectedAmount),
          materialCost:
              apps.fold(0.0, (s, a) => s + a.estimatedMaterialsCost),
        );
      });
    }
  }

  static DateTime _mondayOf(DateTime dt) =>
      dt.subtract(Duration(days: dt.weekday - 1));

  // ---------------------------------------------------------------------------
  // Export PDF
  // ---------------------------------------------------------------------------

  Future<void> _exportPdf() async {
    setState(() => _exportingPdf = true);
    try {
      final fonts = await PdfFontBundle.load();
      final doc = pw.Document();
      final filtrate = _filtratePerioada;
      final fmtDate = DateFormat('dd.MM.yyyy');
      final now = DateTime.now();

      doc.addPage(
        pw.MultiPage(
          theme: fonts.theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
          build: (pw.Context ctx) => [
            // Titlu
            pw.Text(
              'Raport Profitabilitate Programări',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Perioadă: ${_perioada.label}',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.Text(
              'Generat: ${fmtDate.format(now)}',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 16),

            // Sumar
            pw.Text(
              'Sumar financiar',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.5,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
              },
              children: [
                _pdfRow('Total încasat',
                    '${_totalIncasat.toStringAsFixed(2)} RON',
                    bold: true),
                _pdfRow('Cost materiale',
                    '${_totalCostMateriale.toStringAsFixed(2)} RON'),
                _pdfRow('Profit net',
                    '${_totalProfit.toStringAsFixed(2)} RON',
                    bold: true,
                    valueColor: _totalProfit >= 0
                        ? PdfColors.green800
                        : PdfColors.red),
                _pdfRow('Programări cu încasare', '$_nrCuIncasare'),
                _pdfRow('Total programări în perioadă',
                    '${filtrate.length}'),
              ],
            ),
            pw.SizedBox(height: 20),

            // Tabel programări
            if (filtrate.isNotEmpty) ...[
              pw.Text(
                'Detaliu programări',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(64),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FixedColumnWidth(72),
                  4: const pw.FixedColumnWidth(64),
                  5: const pw.FixedColumnWidth(72),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      'Data',
                      'Client',
                      'Status',
                      'Încasat',
                      'Materiale',
                      'Profit',
                    ]
                        .map(
                          (h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              h,
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  ...filtrate.map(
                    (item) => pw.TableRow(
                      children: [
                        fmtDate.format(item.effectiveStartDateTime),
                        item.clientName.isNotEmpty
                            ? item.clientName
                            : item.title,
                        item.adminFinancialStatus.label,
                        item.adminCollectedAmount > 0
                            ? '${item.adminCollectedAmount.toStringAsFixed(2)} ${item.adminCollectedCurrency}'
                            : '—',
                        item.estimatedMaterialsCost > 0
                            ? '${item.estimatedMaterialsCost.toStringAsFixed(2)} RON'
                            : '—',
                        item.adminCollectedAmount > 0
                            ? '${item.estimatedProfit.toStringAsFixed(2)} ${item.adminCollectedCurrency}'
                            : '—',
                      ]
                          .map(
                            (cell) => pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                cell,
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );

      final bytes = await doc.save();
      final fileName =
          'profitabilitate_${DateFormat('yyyyMMdd').format(now)}.pdf';
      final savedPath = await PdfSaveService.savePdf(
        repository: LocalAppDataRepository(),
        bytes: bytes,
        fileName: fileName,
        category: PdfDocumentCategory.other,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF salvat: $savedPath'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare la export: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  static pw.TableRow _pdfRow(
    String label,
    String value, {
    bool bold = false,
    PdfColor? valueColor,
  }) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : null,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : null,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final filtrate = _filtrate;
    final fmt = DateFormat('dd.MM.yyyy');
    final buckets = _computeBuckets();
    final canSave = widget.onAppointmentSaved != null;
    final hasSelection = _selectate.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profitabilitate programări'),
        actions: [
          if (canSave)
            IconButton(
              tooltip: _selectMode ? 'Ieși din selecție' : 'Selectează pentru încasare în bloc',
              onPressed: () => setState(() {
                _selectMode = !_selectMode;
                _selectate.clear();
              }),
              icon: Icon(_selectMode ? Icons.close : Icons.checklist_outlined),
            ),
          if (_exportingPdf)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Exportă PDF',
              onPressed: _exportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          // Banner selecție activă
          if (_selectMode)
            Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasSelection
                            ? '${_selectate.length} selectate — ${_totalSelectat.toStringAsFixed(2)} RON'
                            : 'Bifează programările de încasat în bloc',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (hasSelection) ...[
                      TextButton(
                        onPressed: () => setState(() => _selectate.clear()),
                        child: const Text('Deselectează'),
                      ),
                      FilledButton.icon(
                        onPressed: _showBulkCollectionDialog,
                        icon: const Icon(Icons.payments_outlined, size: 18),
                        label: Text('Încasează (${_selectate.length})'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          _buildPerioadaSelector(),
          _buildSumarCards(),
          _buildGrafic(buckets),
          _buildFiltruStatus(),
          const Divider(height: 1),
          Expanded(
            child: filtrate.isEmpty
                ? const Center(
                    child: Text('Nu există programări în perioada selectată.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: filtrate.length,
                    itemBuilder: (context, index) =>
                        _buildRandProgramare(filtrate[index], fmt),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerioadaSelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: 6,
          children: _Perioada.values
              .map(
                (p) => ChoiceChip(
                  label: Text(p.label),
                  selected: _perioada == p,
                  onSelected: (_) => setState(() => _perioada = p),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSumarCards() {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final c1 = _SumarCard(
          label: 'Încasat',
          value: '${_totalIncasat.toStringAsFixed(2)} RON',
          icon: Icons.payments_outlined,
          color: colorScheme.primary,
          sub: '$_nrCuIncasare programări',
        );
        final c2 = _SumarCard(
          label: 'Cost materiale',
          value: '${_totalCostMateriale.toStringAsFixed(2)} RON',
          icon: Icons.inventory_2_outlined,
          color: colorScheme.secondary,
          sub: '${_filtratePerioada.length} total',
        );
        final c3 = _SumarCard(
          label: 'Profit net',
          value: '${_totalProfit.toStringAsFixed(2)} RON',
          icon: Icons.trending_up_outlined,
          color: _totalProfit >= 0 ? Colors.green.shade700 : Colors.red,
          sub: _totalCostMateriale > 0 && _totalIncasat > 0
              ? 'Marjă: ${((_totalProfit / _totalIncasat) * 100).toStringAsFixed(1)}%'
              : '',
        );
        if (isMobile) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [c1, const SizedBox(height: 8), c2, const SizedBox(height: 8), c3],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(child: c1),
              const SizedBox(width: 8),
              Expanded(child: c2),
              const SizedBox(width: 8),
              Expanded(child: c3),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrafic(List<_ChartBucket> buckets) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Evoluție profit',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                _Legenda(color: Colors.green.shade600, label: 'Profit'),
                const SizedBox(width: 10),
                _Legenda(color: Colors.red.shade400, label: 'Pierdere'),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: _ProfitBarChart(buckets: buckets),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltruStatus() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        spacing: 6,
        children: [
          FilterChip(
            label: const Text('Toate'),
            selected: _filtruStatus == null,
            onSelected: (_) => setState(() => _filtruStatus = null),
          ),
          ...AppointmentFinancialStatus.values.map(
            (s) => FilterChip(
              label: Text(s.label),
              selected: _filtruStatus == s,
              onSelected: (_) => setState(
                () => _filtruStatus = _filtruStatus == s ? null : s,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRandProgramare(Appointment item, DateFormat fmt) {
    final hasIncome = item.adminCollectedAmount > 0;
    final profit = item.estimatedProfit;
    final profitColor = !hasIncome
        ? Colors.grey
        : profit > 0
            ? Colors.green.shade700
            : profit < 0
                ? Colors.red
                : Colors.grey;
    final isSelected = _selectate.contains(item.id);
    final canSave = widget.onAppointmentSaved != null;
    final neincasata = item.adminFinancialStatus == AppointmentFinancialStatus.neincasata ||
        item.adminFinancialStatus == AppointmentFinancialStatus.partial;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _selectMode
            ? () => setState(() {
                  if (isSelected) {
                    _selectate.remove(item.id);
                  } else {
                    _selectate.add(item.id);
                  }
                })
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectMode)
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => setState(() {
                        if (isSelected) {
                          _selectate.remove(item.id);
                        } else {
                          _selectate.add(item.id);
                        }
                      }),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title.isNotEmpty ? item.title : '(fără titlu)',
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.clientName.isNotEmpty)
                          Text(
                            item.clientName,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fmt.format(item.effectiveStartDateTime),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatChip(
                    label: 'Încasat',
                    value: hasIncome
                        ? '${item.adminCollectedAmount.toStringAsFixed(2)} ${item.adminCollectedCurrency}'
                        : '—',
                    color: hasIncome ? Colors.blue.shade700 : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  _StatChip(
                    label: 'Materiale',
                    value: item.estimatedMaterialsCost > 0
                        ? '${item.estimatedMaterialsCost.toStringAsFixed(2)} RON'
                        : '—',
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 6),
                  _StatChip(
                    label: 'Profit',
                    value: hasIncome
                        ? '${profit.toStringAsFixed(2)} ${item.adminCollectedCurrency}'
                        : '—',
                    color: profitColor,
                  ),
                  const Spacer(),
                  _StatusBadge(status: item.adminFinancialStatus),
                ],
              ),
              if (item.interventionPrice > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'De încasat: ${item.interventionPrice.toStringAsFixed(2)} ${item.interventionPriceCurrency}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: neincasata
                                ? Colors.orange.shade700
                                : Theme.of(context).colorScheme.outline,
                            fontWeight: neincasata ? FontWeight.w600 : null,
                          ),
                    ),
                    if (hasIncome && item.interventionPrice > item.adminCollectedAmount) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Rest: ${(item.interventionPrice - item.adminCollectedAmount).toStringAsFixed(2)} RON',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ],
              // Buton rapid încasare (când nu ești în mod selecție)
              if (!_selectMode && canSave && neincasata) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showSingleCollectionDialog(item),
                    icon: const Icon(Icons.payments_outlined, size: 16),
                    label: const Text('Înregistrează încasare'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSingleCollectionDialog(Appointment item) async {
    var method = 'Cash';
    var status = AppointmentFinancialStatus.incasata;
    var date = DateTime.now();
    final amountCtrl = TextEditingController(
      text: item.interventionPrice > 0
          ? item.interventionPrice.toStringAsFixed(2)
          : item.adminCollectedAmount > 0
              ? item.adminCollectedAmount.toStringAsFixed(2)
              : '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setS) => AlertDialog(
          title: Text(
            item.clientName.isNotEmpty ? 'Încasare — ${item.clientName}' : 'Înregistrare încasare',
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.interventionPrice > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Preț intervenție: ${item.interventionPrice.toStringAsFixed(2)} ${item.interventionPriceCurrency}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Sumă încasată',
                      suffixText: 'RON',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'Modalitate'),
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'Card', child: Text('Card')),
                      DropdownMenuItem(value: 'Transfer', child: Text('Transfer bancar')),
                    ],
                    onChanged: (v) => setS(() => method = v ?? 'Cash'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AppointmentFinancialStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: AppointmentFinancialStatus.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                        .toList(),
                    onChanged: (v) => setS(() => status = v ?? AppointmentFinancialStatus.incasata),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: DateFormat('dd.MM.yyyy').format(date),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Data încasării',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setS(() => date = picked);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Anulează')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Salvează')),
          ],
        ),
      ),
    );

    amountCtrl.dispose();
    if (confirmed != true || !mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? item.interventionPrice;
    final updated = item.copyWith(
      adminCollectedAmount: amount,
      adminFinancialStatus: status,
      adminDueDate: date,
      adminCollectedCurrency: 'RON',
    );
    await _saveUpdated(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Înregistrat: ${amount.toStringAsFixed(2)} RON — $method')),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Grafic profit cu CustomPainter
// ---------------------------------------------------------------------------

class _ProfitBarChart extends StatelessWidget {
  final List<_ChartBucket> buckets;

  const _ProfitBarChart({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (buckets.isEmpty || !buckets.any((b) => b.hasData)) {
      return Center(
        child: Text(
          'Nu există date pentru grafic.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return CustomPaint(
      painter: _ChartPainter(
        buckets: buckets,
        positiveColor: Colors.green.shade600,
        negativeColor: Colors.red.shade400,
        neutralColor: colorScheme.outline.withValues(alpha: 0.3),
        labelColor: colorScheme.onSurface.withValues(alpha: 0.6),
        gridColor: colorScheme.outline.withValues(alpha: 0.15),
        zeroLineColor: colorScheme.outline.withValues(alpha: 0.5),
      ),
      size: Size.infinite,
    );
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter({
    required this.buckets,
    required this.positiveColor,
    required this.negativeColor,
    required this.neutralColor,
    required this.labelColor,
    required this.gridColor,
    required this.zeroLineColor,
  });

  final List<_ChartBucket> buckets;
  final Color positiveColor;
  final Color negativeColor;
  final Color neutralColor;
  final Color labelColor;
  final Color gridColor;
  final Color zeroLineColor;

  static const double _labelHeight = 28.0;
  static const double _topPadding = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;

    final chartHeight = size.height - _labelHeight - _topPadding;
    final n = buckets.length;
    final slotWidth = size.width / n;
    final barWidth = (slotWidth * 0.55).clamp(4.0, 28.0);

    final profits = buckets.map((b) => b.profit).toList();
    final maxVal = profits.reduce(max);
    final minVal = profits.reduce(min);

    // Gamă cu cel puțin puțin padding
    final rangeMax = maxVal <= 0 ? 1.0 : maxVal * 1.1;
    final rangeMin = minVal >= 0 ? 0.0 : minVal * 1.1;
    final range = rangeMax - rangeMin;

    // Poziție y=0 relativă la axă
    final zeroFraction = (rangeMax - 0.0) / range;
    final zeroY = _topPadding + chartHeight * zeroFraction.clamp(0.0, 1.0);

    // Grid — 4 linii
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = _topPadding + chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Linie zero
    final zeroPaint = Paint()
      ..color = zeroLineColor
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), zeroPaint);

    // Bare
    for (int i = 0; i < n; i++) {
      final bucket = buckets[i];
      final profit = bucket.profit;
      final centerX = slotWidth * i + slotWidth / 2;
      final barLeft = centerX - barWidth / 2;

      if (!bucket.hasData) {
        // Punct gri la zero
        canvas.drawCircle(
          Offset(centerX, zeroY),
          2,
          Paint()..color = neutralColor,
        );
      } else {
        final topFraction = (rangeMax - max(profit, 0)) / range;
        final bottomFraction = (rangeMax - min(profit, 0)) / range;
        final barTop = _topPadding + chartHeight * topFraction.clamp(0.0, 1.0);
        final barBottom =
            _topPadding + chartHeight * bottomFraction.clamp(0.0, 1.0);
        final barH = (barBottom - barTop).abs();

        if (barH < 1) continue;

        final barPaint = Paint()
          ..color = profit >= 0 ? positiveColor : negativeColor;
        final rect = Rect.fromLTWH(barLeft, barTop, barWidth, barH);
        final rrect =
            RRect.fromRectAndRadius(rect, const Radius.circular(2));
        canvas.drawRRect(rrect, barPaint);
      }

      // Etichetă
      final rawLabel = bucket.label;
      final lines = rawLabel.split('\n');
      double labelY = size.height - _labelHeight + 4;
      for (final line in lines) {
        _drawLabel(canvas, line, Offset(centerX, labelY), slotWidth);
        labelY += 11;
      }
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset center, double maxW) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 8.5),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxW);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.buckets != buckets;
}

// ---------------------------------------------------------------------------
// Widget-uri ajutătoare
// ---------------------------------------------------------------------------

class _Legenda extends StatelessWidget {
  final Color color;
  final String label;

  const _Legenda({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _SumarCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  const _SumarCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub = '',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AppointmentFinancialStatus status;

  const _StatusBadge({required this.status});

  Color _color(BuildContext context) {
    switch (status) {
      case AppointmentFinancialStatus.incasata:
        return Colors.green.shade700;
      case AppointmentFinancialStatus.partial:
        return Colors.orange.shade700;
      case AppointmentFinancialStatus.neincasata:
        return Colors.red.shade700;
      case AppointmentFinancialStatus.facturareLunara:
      case AppointmentFinancialStatus.conformContract:
        return Colors.blue.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color(context).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _color(context),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
