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
import '../master/master_local_store.dart';
import 'appointment_models.dart';
import '../../core/widgets/help_button.dart';
import '../../core/help_content.dart';

// ---------------------------------------------------------------------------
// Perioadă
// ---------------------------------------------------------------------------

enum _Perioada {
  saptamanaAceasta,
  ultimaSaptamana,
  ultimele2Saptamani,
  lunaCurenta,
  lunaTrecuta,
  personalizata;

  String get label {
    switch (this) {
      case _Perioada.saptamanaAceasta:
        return 'Săpt. curentă';
      case _Perioada.ultimaSaptamana:
        return 'Ultima săpt.';
      case _Perioada.ultimele2Saptamani:
        return 'Ultimele 2 săpt.';
      case _Perioada.lunaCurenta:
        return 'Luna curentă';
      case _Perioada.lunaTrecuta:
        return 'Luna trecută';
      case _Perioada.personalizata:
        return 'Personalizat';
    }
  }

  DateTimeRange get builtInInterval {
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
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case _Perioada.lunaTrecuta:
        final firstCurenta = DateTime(now.year, now.month, 1);
        final lastTrecuta = firstCurenta.subtract(const Duration(seconds: 1));
        return DateTimeRange(
          start: DateTime(lastTrecuta.year, lastTrecuta.month, 1),
          end: lastTrecuta,
        );
      case _Perioada.personalizata:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
    }
  }

  bool get isBuiltInMonthly =>
      this == _Perioada.lunaCurenta || this == _Perioada.lunaTrecuta;
}

// ---------------------------------------------------------------------------
// Model agregate per material
// ---------------------------------------------------------------------------

class _MaterialAgregate {
  _MaterialAgregate({
    required this.key,
    required this.name,
    required this.unit,
    this.materialId = '',
  });

  final String key;
  final String materialId;
  final String name;
  final String unit;
  double totalQuantity = 0;
  double totalCost = 0;
  int nrProgramari = 0;

  String get quantityLabel {
    final q = totalQuantity;
    if (q == q.truncateToDouble()) return '${q.toInt()} $unit';
    return '${q.toStringAsFixed(2)} $unit';
  }
}

// ---------------------------------------------------------------------------
// Bucket grafic
// ---------------------------------------------------------------------------

class _CostBucket {
  const _CostBucket({required this.label, required this.cost});
  final String label;
  final double cost;
  bool get hasData => cost > 0;
}

// ---------------------------------------------------------------------------
// Pagina principală
// ---------------------------------------------------------------------------

class ProgramariConsumMaterialePage extends StatefulWidget {
  const ProgramariConsumMaterialePage({
    super.key,
    required this.appointments,
  });

  final List<Appointment> appointments;

  @override
  State<ProgramariConsumMaterialePage> createState() =>
      _ProgramariConsumMaterialePageState();
}

class _ProgramariConsumMaterialePageState
    extends State<ProgramariConsumMaterialePage> {
  _Perioada _perioada = _Perioada.lunaCurenta;
  DateTimeRange? _customRange;
  bool _exportingPdf = false;
  String _sortBy = 'cost'; // 'cost' | 'qty' | 'name'

  // Filtre echipă / angajat
  String _filtruTeamId = '';
  String _filtruEmployeeId = '';

  // Date încărcate asincron
  List<MasterTeam> _teams = const [];
  List<MasterEmployee> _employees = const [];
  Map<String, MasterMaterial> _materialeById = const {};
  bool _loadingMeta = true;

  final _fmtShort = DateFormat('dd.MM.yy');

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final teams = await MasterLocalStore.readTeams();
    final employees = await MasterLocalStore.readEmployees();
    final materiale = await MasterLocalStore.readMaterials();
    final materialeMap = <String, MasterMaterial>{
      for (final m in materiale) m.id: m,
    };
    if (!mounted) return;
    setState(() {
      _teams = teams;
      _employees = employees;
      _materialeById = materialeMap;
      _loadingMeta = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Rezolvare interval
  // ---------------------------------------------------------------------------

  DateTimeRange get _interval {
    if (_perioada == _Perioada.personalizata) {
      return _customRange ?? _Perioada.lunaCurenta.builtInInterval;
    }
    return _perioada.builtInInterval;
  }

  bool get _isMonthlyView {
    if (_perioada == _Perioada.personalizata) {
      final r = _customRange;
      if (r == null) return false;
      return r.end.difference(r.start).inDays > 14;
    }
    return _perioada.isBuiltInMonthly;
  }

  String get _intervalLabel {
    if (_perioada == _Perioada.personalizata && _customRange != null) {
      return '${_fmtShort.format(_customRange!.start)} – ${_fmtShort.format(_customRange!.end)}';
    }
    return _perioada.label;
  }

  // ---------------------------------------------------------------------------
  // Date filtrate
  // ---------------------------------------------------------------------------

  List<Appointment> get _filtratePerioada {
    final interval = _interval;
    return widget.appointments.where((a) {
      final dt = a.effectiveStartDateTime;
      if (dt.isBefore(interval.start) || dt.isAfter(interval.end)) {
        return false;
      }
      // Filtru echipă
      if (_filtruTeamId.isNotEmpty && a.teamId != _filtruTeamId) return false;
      // Filtru angajat
      if (_filtruEmployeeId.isNotEmpty &&
          !a.assignedEmployeeIds.contains(_filtruEmployeeId)) {
        return false;
      }
      return true;
    }).toList()
      ..sort(
        (a, b) =>
            b.effectiveStartDateTime.compareTo(a.effectiveStartDateTime),
      );
  }

  List<Appointment> get _cuMateriale =>
      _filtratePerioada.where((a) => a.materialUsage.lines.isNotEmpty).toList();

  double get _totalCostMateriale =>
      _filtratePerioada.fold(0.0, (s, a) => s + a.estimatedMaterialsCost);

  List<_MaterialAgregate> _computeAgregate() {
    final map = <String, _MaterialAgregate>{};
    for (final app in _filtratePerioada) {
      final Set<String> usedKeysThisApp = {};
      for (final line in app.materialUsage.lines) {
        if (line.name.trim().isEmpty) continue;
        final key = line.materialId.trim().isNotEmpty
            ? line.materialId
            : '${line.name.trim()}__${line.unit.trim()}';
        map.putIfAbsent(
          key,
          () => _MaterialAgregate(
            key: key,
            materialId: line.materialId.trim(),
            name: line.name,
            unit: line.unit,
          ),
        );
        map[key]!.totalQuantity += line.quantity;
        map[key]!.totalCost += line.totalCost;
        if (!usedKeysThisApp.contains(key)) {
          map[key]!.nrProgramari++;
          usedKeysThisApp.add(key);
        }
      }
    }

    final list = map.values.toList();
    switch (_sortBy) {
      case 'cost':
        list.sort((a, b) => b.totalCost.compareTo(a.totalCost));
      case 'qty':
        list.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
      case 'name':
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  // Materiale cu stoc scăzut față de consum în perioadă
  List<_MaterialAgregate> _stocScazut(List<_MaterialAgregate> agregate) {
    return agregate.where((ag) {
      if (ag.materialId.isEmpty) return false;
      final mat = _materialeById[ag.materialId];
      if (mat == null) return false;
      return mat.isLowStock;
    }).toList();
  }

  List<_CostBucket> _computeBuckets() {
    final all = _filtratePerioada;
    final interval = _interval;

    if (_isMonthlyView) {
      final buckets = <_CostBucket>[];
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
            _CostBucket(
              label: 'S$weekNr\n${DateFormat('dd.MM').format(overlapStart)}',
              cost: apps.fold(0.0, (s, a) => s + a.estimatedMaterialsCost),
            ),
          );
        }
        weekStart = weekStart.add(const Duration(days: 7));
        weekNr++;
      }
      return buckets;
    } else {
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
        return _CostBucket(
          label: DateFormat('EEE\ndd', 'ro_RO').format(day),
          cost: apps.fold(0.0, (s, a) => s + a.estimatedMaterialsCost),
        );
      });
    }
  }

  static DateTime _mondayOf(DateTime dt) =>
      dt.subtract(Duration(days: dt.weekday - 1));

  // ---------------------------------------------------------------------------
  // Date picker custom
  // ---------------------------------------------------------------------------

  Future<void> _openCustomDatePicker() async {
    final initial = _customRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 30)),
          end: DateTime.now(),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: initial,
      locale: const Locale('ro'),
      helpText: 'Selectează perioada',
      cancelText: 'Anulează',
      confirmText: 'Aplică',
      saveText: 'Aplică',
    );
    if (picked != null && mounted) {
      setState(() {
        _customRange = picked;
        _perioada = _Perioada.personalizata;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Export PDF
  // ---------------------------------------------------------------------------

  Future<void> _exportPdf() async {
    setState(() => _exportingPdf = true);
    try {
      final fonts = await PdfFontBundle.load();
      final doc = pw.Document();
      final agregate = _computeAgregate();
      final fmtDate = DateFormat('dd.MM.yyyy');
      final now = DateTime.now();
      final cuMat = _cuMateriale;

      doc.addPage(
        pw.MultiPage(
          theme: fonts.theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
          build: (pw.Context ctx) => [
            pw.Text(
              'Raport Consum Materiale',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Perioadă: $_intervalLabel',
              style: const pw.TextStyle(fontSize: 11),
            ),
            if (_filtruTeamId.isNotEmpty || _filtruEmployeeId.isNotEmpty)
              pw.Text(
                'Filtru: ${_filtruTeamId.isNotEmpty ? 'Echipă: ${_teamNameById(_filtruTeamId)}' : ''}'
                '${_filtruEmployeeId.isNotEmpty ? 'Angajat: ${_employeeNameById(_filtruEmployeeId)}' : ''}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            pw.Text(
              'Generat: ${fmtDate.format(now)}',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Sumar',
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
                _pdfRow(
                  'Cost total materiale',
                  '${_totalCostMateriale.toStringAsFixed(2)} RON',
                  bold: true,
                ),
                _pdfRow('Materiale distincte', '${agregate.length}'),
                _pdfRow('Programări cu materiale', '${cuMat.length}'),
                _pdfRow(
                  'Total programări în perioadă',
                  '${_filtratePerioada.length}',
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            if (agregate.isNotEmpty) ...[
              pw.Text(
                'Detaliu materiale consumate',
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
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FixedColumnWidth(55),
                  2: const pw.FixedColumnWidth(72),
                  3: const pw.FixedColumnWidth(80),
                  4: const pw.FixedColumnWidth(50),
                  5: const pw.FixedColumnWidth(55),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      'Material',
                      'U.M.',
                      'Cantitate',
                      'Cost total',
                      'Progr.',
                      'Stoc',
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
                  ...agregate.map(
                    (item) {
                      final mat = item.materialId.isNotEmpty
                          ? _materialeById[item.materialId]
                          : null;
                      final stocText = mat == null
                          ? '—'
                          : mat.isLowStock
                              ? '⚠ ${mat.quantityInStock.toStringAsFixed(1)}'
                              : mat.quantityInStock.toStringAsFixed(1);
                      return pw.TableRow(
                        children: [
                          item.name,
                          item.unit,
                          item.totalQuantity ==
                                  item.totalQuantity.truncateToDouble()
                              ? '${item.totalQuantity.toInt()}'
                              : item.totalQuantity.toStringAsFixed(2),
                          '${item.totalCost.toStringAsFixed(2)} RON',
                          '${item.nrProgramari}',
                          stocText,
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
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      );

      final bytes = await doc.save();
      final fileName =
          'consum_materiale_${DateFormat('yyyyMMdd').format(now)}.pdf';
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
            action: SnackBarAction(label: 'OK', onPressed: () {}),
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
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers lookups
  // ---------------------------------------------------------------------------

  String _teamNameById(String id) {
    if (id.isEmpty) return '';
    return _teams.firstWhere(
      (t) => t.id == id,
      orElse: () => MasterTeam(
        id: id,
        name: id,
        notes: '',
        memberIds: const [],
      ),
    ).name;
  }

  String _employeeNameById(String id) {
    if (id.isEmpty) return '';
    return _employees.firstWhere(
      (e) => e.id == id,
      orElse: () => MasterEmployee(
        id: id,
        name: id,
        role: '',
        active: true,
      ),
    ).name;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loadingMeta) {
      return Scaffold(
        appBar: AppBar(title: const Text('Consum materiale')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final agregate = _computeAgregate();
    final buckets = _computeBuckets();
    final cuMat = _cuMateriale;
    final stocScazutList = _stocScazut(agregate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consum materiale'),
        actions: [
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
          HelpButton(content: AppHelp.consumMateriale),
        ],
      ),
      body: Column(
        children: [
          _buildPerioadaSelector(),
          _buildFiltruEchipaAngajat(),
          _buildSumarCards(agregate, cuMat),
          if (stocScazutList.isNotEmpty) _buildAlertaStoc(stocScazutList),
          _buildGrafic(buckets),
          _buildSortBar(),
          const Divider(height: 1),
          Expanded(
            child: agregate.isEmpty
                ? const Center(
                    child: Text(
                      'Nu există materiale consumate în perioada selectată.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: agregate.length,
                    itemBuilder: (context, index) => _buildRandMaterial(
                      agregate[index],
                      _totalCostMateriale,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Selector perioadă
  // ---------------------------------------------------------------------------

  Widget _buildPerioadaSelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: 6,
          children: [
            ..._Perioada.values
                .where((p) => p != _Perioada.personalizata)
                .map(
                  (p) => ChoiceChip(
                    label: Text(p.label),
                    selected: _perioada == p,
                    onSelected: (_) => setState(() => _perioada = p),
                  ),
                ),
            // Chip personalizat cu dată picker
            ChoiceChip(
              avatar: const Icon(Icons.date_range_outlined, size: 16),
              label: Text(
                _perioada == _Perioada.personalizata && _customRange != null
                    ? '${_fmtShort.format(_customRange!.start)} – ${_fmtShort.format(_customRange!.end)}'
                    : 'Personalizat',
              ),
              selected: _perioada == _Perioada.personalizata,
              onSelected: (_) => _openCustomDatePicker(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filtru echipă / angajat
  // ---------------------------------------------------------------------------

  Widget _buildFiltruEchipaAngajat() {
    if (_teams.isEmpty && _employees.isEmpty) return const SizedBox.shrink();

    final activeTeams = _teams.where((t) => t.name.isNotEmpty).toList();
    final activeEmployees =
        _employees.where((e) => e.active && e.name.isNotEmpty).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        spacing: 6,
        children: [
          Icon(
            Icons.filter_list_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.outline,
          ),
          // Echipe
          if (activeTeams.isNotEmpty) ...[
            FilterChip(
              avatar: const Icon(Icons.groups_outlined, size: 14),
              label: const Text('Toate echipele'),
              selected: _filtruTeamId.isEmpty && _filtruEmployeeId.isEmpty,
              onSelected: (_) => setState(() {
                _filtruTeamId = '';
                _filtruEmployeeId = '';
              }),
            ),
            ...activeTeams.map(
              (t) => FilterChip(
                label: Text(t.name),
                selected: _filtruTeamId == t.id,
                onSelected: (_) => setState(() {
                  _filtruTeamId = _filtruTeamId == t.id ? '' : t.id;
                  _filtruEmployeeId = '';
                }),
              ),
            ),
          ],
          // Separator vizual
          if (activeTeams.isNotEmpty && activeEmployees.isNotEmpty)
            Container(
              width: 1,
              height: 24,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
          // Angajați
          ...activeEmployees.map(
            (e) => FilterChip(
              avatar: const Icon(Icons.person_outlined, size: 14),
              label: Text(e.name),
              selected: _filtruEmployeeId == e.id,
              onSelected: (_) => setState(() {
                _filtruEmployeeId = _filtruEmployeeId == e.id ? '' : e.id;
                _filtruTeamId = '';
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Carduri sumar
  // ---------------------------------------------------------------------------

  Widget _buildSumarCards(
    List<_MaterialAgregate> agregate,
    List<Appointment> cuMat,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final c1 = _SumarCard(
          label: 'Cost total',
          value: '${_totalCostMateriale.toStringAsFixed(2)} RON',
          icon: Icons.payments_outlined,
          color: Colors.orange.shade700,
          sub: '${_filtratePerioada.length} progr.',
        );
        final c2 = _SumarCard(
          label: 'Materiale distincte',
          value: '${agregate.length}',
          icon: Icons.inventory_2_outlined,
          color: colorScheme.primary,
          sub: '${cuMat.length} cu mat.',
        );
        final c3 = _SumarCard(
          label: 'Cost mediu',
          value: cuMat.isEmpty
              ? '— RON'
              : '${(_totalCostMateriale / cuMat.length).toStringAsFixed(2)} RON',
          icon: Icons.calculate_outlined,
          color: colorScheme.secondary,
          sub: '/ programare',
        );
        if (isMobile) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Column(
              children: [c1, const SizedBox(height: 8), c2, const SizedBox(height: 8), c3],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
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

  // ---------------------------------------------------------------------------
  // Alertă stoc scăzut
  // ---------------------------------------------------------------------------

  Widget _buildAlertaStoc(List<_MaterialAgregate> stocScazut) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined,
                  size: 16, color: Colors.red.shade700),
              const SizedBox(width: 6),
              Text(
                'Stoc scăzut — ${stocScazut.length} ${stocScazut.length == 1 ? 'material' : 'materiale'}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...stocScazut.map(
            (ag) {
              final mat = _materialeById[ag.materialId]!;
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ag.name,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Stoc: ${mat.quantityInStock.toStringAsFixed(1)} ${mat.unit}'
                      ' (min: ${mat.minQuantityAlert.toStringAsFixed(1)})',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.red.shade700,
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Grafic
  // ---------------------------------------------------------------------------

  Widget _buildGrafic(List<_CostBucket> buckets) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Evoluție cost materiale',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                _Legenda(
                  color: Colors.orange.shade600,
                  label: 'Cost materiale',
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 130,
              child: _CostBarChart(buckets: buckets),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sortare
  // ---------------------------------------------------------------------------

  Widget _buildSortBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        spacing: 6,
        children: [
          const Text('Sortare:'),
          ChoiceChip(
            label: const Text('Cost ↓'),
            selected: _sortBy == 'cost',
            onSelected: (_) => setState(() => _sortBy = 'cost'),
          ),
          ChoiceChip(
            label: const Text('Cantitate ↓'),
            selected: _sortBy == 'qty',
            onSelected: (_) => setState(() => _sortBy = 'qty'),
          ),
          ChoiceChip(
            label: const Text('Nume A–Z'),
            selected: _sortBy == 'name',
            onSelected: (_) => setState(() => _sortBy = 'name'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rând material
  // ---------------------------------------------------------------------------

  Widget _buildRandMaterial(
    _MaterialAgregate item,
    double totalCostPeriod,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final pondere =
        totalCostPeriod > 0 ? (item.totalCost / totalCostPeriod * 100) : 0.0;

    // Info stoc din catalog
    final mat = item.materialId.isNotEmpty
        ? _materialeById[item.materialId]
        : null;
    final hasLowStock = mat != null && mat.isLowStock;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (hasLowStock)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Tooltip(
                      message:
                          'Stoc scăzut: ${mat.quantityInStock.toStringAsFixed(1)} ${mat.unit} '
                          '(min: ${mat.minQuantityAlert.toStringAsFixed(1)})',
                      child: Icon(
                        Icons.warning_amber_outlined,
                        size: 16,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color:
                              hasLowStock ? Colors.red.shade700 : null,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${item.totalCost.toStringAsFixed(2)} RON',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            // Stoc info inline
            if (mat != null) ...[
              const SizedBox(height: 4),
              Text(
                'Stoc curent: ${mat.quantityInStock.toStringAsFixed(1)} ${mat.unit}'
                '${mat.minQuantityAlert > 0 ? ' (min: ${mat.minQuantityAlert.toStringAsFixed(1)})' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: hasLowStock
                          ? Colors.red.shade600
                          : colorScheme.outline,
                    ),
              ),
            ],
            const SizedBox(height: 6),
            // Bara de pondere vizuală
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (pondere / 100).clamp(0.0, 1.0),
                backgroundColor:
                    colorScheme.outline.withValues(alpha: 0.15),
                color: Colors.orange.shade400,
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _StatChip(
                  label: 'Cantitate',
                  value: item.quantityLabel,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                _StatChip(
                  label: 'Pondere',
                  value: '${pondere.toStringAsFixed(1)}%',
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                _StatChip(
                  label: 'Progr.',
                  value: '${item.nrProgramari}',
                  color: colorScheme.secondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grafic bare cost (CustomPainter)
// ---------------------------------------------------------------------------

class _CostBarChart extends StatelessWidget {
  const _CostBarChart({required this.buckets});

  final List<_CostBucket> buckets;

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
      painter: _CostChartPainter(
        buckets: buckets,
        barColor: Colors.orange.shade600,
        neutralColor: colorScheme.outline.withValues(alpha: 0.3),
        labelColor: colorScheme.onSurface.withValues(alpha: 0.6),
        gridColor: colorScheme.outline.withValues(alpha: 0.15),
      ),
      size: Size.infinite,
    );
  }
}

class _CostChartPainter extends CustomPainter {
  const _CostChartPainter({
    required this.buckets,
    required this.barColor,
    required this.neutralColor,
    required this.labelColor,
    required this.gridColor,
  });

  final List<_CostBucket> buckets;
  final Color barColor;
  final Color neutralColor;
  final Color labelColor;
  final Color gridColor;

  static const double _labelHeight = 28.0;
  static const double _topPadding = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;

    final chartHeight = size.height - _labelHeight - _topPadding;
    final n = buckets.length;
    final slotWidth = size.width / n;
    final barWidth = (slotWidth * 0.55).clamp(4.0, 28.0);
    final maxCost = buckets.map((b) => b.cost).reduce(max);
    if (maxCost <= 0) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = _topPadding + chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 0; i < n; i++) {
      final bucket = buckets[i];
      final centerX = slotWidth * i + slotWidth / 2;
      final barLeft = centerX - barWidth / 2;

      if (!bucket.hasData) {
        canvas.drawCircle(
          Offset(centerX, _topPadding + chartHeight),
          2,
          Paint()..color = neutralColor,
        );
      } else {
        final fraction = bucket.cost / maxCost;
        final barH = (chartHeight * fraction).clamp(2.0, chartHeight);
        final barTop = _topPadding + chartHeight - barH;
        final rect = Rect.fromLTWH(barLeft, barTop, barWidth, barH);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
        canvas.drawRRect(rrect, Paint()..color = barColor);
      }

      final lines = bucket.label.split('\n');
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
  bool shouldRepaint(_CostChartPainter old) => old.buckets != buckets;
}

// ---------------------------------------------------------------------------
// Widget-uri ajutătoare
// ---------------------------------------------------------------------------

class _Legenda extends StatelessWidget {
  const _Legenda({required this.color, required this.label});

  final Color color;
  final String label;

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
  const _SumarCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub = '',
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
