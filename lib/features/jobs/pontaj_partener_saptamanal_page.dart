import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/app_data_repository.dart';
import 'services/pontaj_fisa_all_partners_service.dart';
import 'services/pontaj_fisa_weekly_grouping.dart';

/// Raport READ-ONLY: pontaj muncitori parteneri (JobPartnerWorker), agregat
/// pe TOATE lucrările active, grupat pe săptămână calendaristică
/// (luni-duminică), cu total per muncitor și per partener.
///
/// NU modifică nimic — nu scrie în Firestore, nu atinge
/// `Appointment`/`assignedEmployeeIds`/`employee_financial_*`. Consumă
/// exclusiv `buildPontajFisaAllPartnerRows()` +
/// `groupPontajFisaRowsByWeek()`.
class PontajPartenerSaptamanalPage extends StatefulWidget {
  const PontajPartenerSaptamanalPage({super.key, required this.repository});

  final AppDataRepository repository;

  @override
  State<PontajPartenerSaptamanalPage> createState() =>
      _PontajPartenerSaptamanalPageState();
}

class _PontajPartenerSaptamanalPageState
    extends State<PontajPartenerSaptamanalPage> {
  final _fmt = NumberFormat('#,##0.00', 'ro_RO');
  final _dateFmt = DateFormat('dd.MM.yyyy');

  bool _loading = true;
  String? _error;
  int _jobsScanned = 0;
  List<PontajFisaWeeklyGroup> _groups = const [];

  late DateTimeRange _period;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final thisMonday = startOfWeekMonday(now);
    // Implicit: ultimele 4 săptămâni calendaristice (inclusiv săptămâna curentă).
    final start = thisMonday.subtract(const Duration(days: 21));
    final end = thisMonday.add(const Duration(days: 6));
    _period = DateTimeRange(start: start, end: end);
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await buildPontajFisaAllPartnerRows(
        repository: widget.repository,
        periodStart: _period.start,
        periodEnd: _period.end,
      );
      if (!mounted) return;
      setState(() {
        _groups = groupPontajFisaRowsByWeek(result.rows);
        _jobsScanned = result.jobsScanned;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickPeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _period,
      helpText: 'Alege intervalul',
      cancelText: 'Anulează',
      confirmText: 'Aplică',
      saveText: 'Aplică',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _period = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day),
      );
    });
    await _load();
  }

  double get _totalGeneral =>
      _groups.fold<double>(0, (s, g) => s + g.totalCost);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pontaj parteneri — săptămânal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            tooltip: 'Alege interval',
            onPressed: _loading ? null : _pickPeriod,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? _buildErrorState()
                  : _groups.isEmpty
                      ? _buildEmptyState()
                      : _buildContent(),
            ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.error_outline, size: 40, color: Colors.red.shade700),
        const SizedBox(height: 12),
        Text('Eroare la încărcare: $_error'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Reîncarcă'),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.summarize_outlined, size: 40, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Niciun pontaj partener în intervalul selectat.',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            '${_dateFmt.format(_period.start)} – ${_dateFmt.format(_period.end)} · '
            '$_jobsScanned lucrări scanate',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reîncarcă'),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeaderSummary()),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _buildWeekCard(_groups[i]),
            childCount: _groups.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _buildHeaderSummary() {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interval: ${_dateFmt.format(_period.start)} – ${_dateFmt.format(_period.end)}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${_groups.length} săptămâni · $_jobsScanned lucrări scanate',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total general',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_fmt.format(_totalGeneral)} RON',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekCard(PontajFisaWeeklyGroup group) {
    final theme = Theme.of(context);
    final label =
        'Săpt. ${_dateFmt.format(group.weekStart)} – ${_dateFmt.format(group.weekEnd)}';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ExpansionTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${group.parteneri.length} parteneri',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          '${_fmt.format(group.totalCost)} RON',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: theme.colorScheme.primary,
          ),
        ),
        children: group.parteneri.map(_buildPartnerTile).toList(),
      ),
    );
  }

  Widget _buildPartnerTile(PontajFisaPartnerWeeklyTotal partner) {
    final name = partner.partnerNume.trim().isEmpty
        ? partner.partnerId
        : partner.partnerNume.trim();
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
      child: ExpansionTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          '${partner.muncitori.length} muncitori',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          '${_fmt.format(partner.totalCost)} RON',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        children: partner.muncitori.map(_buildWorkerTile).toList(),
      ),
    );
  }

  Widget _buildWorkerTile(PontajFisaWorkerWeeklyTotal worker) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 24, right: 16),
      leading: const Icon(Icons.person_outline, size: 20),
      title: Row(
        children: [
          Flexible(
            child: Text(
              worker.displayName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (worker.areRandSpansMultipleWeeks) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Conține o intrare pe interval ce trece peste '
                  'granița săptămânii — atribuită integral acestei '
                  'săptămâni (data de început).',
              child: Icon(
                Icons.call_split,
                size: 14,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${_fmt.format(worker.totalOre)} ore · ${worker.numarRanduri} '
        'intrări',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Text(
        '${_fmt.format(worker.totalCost)} RON',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
