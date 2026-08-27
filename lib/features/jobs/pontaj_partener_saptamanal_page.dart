import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/app_data_repository.dart';
import 'services/partner_weekly_payment_repository.dart';
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

/// Cele două ierarhii de grupare (Faza 4) — construite din ACELEAȘI date
/// (`_groups`), fără nicio citire separată. Vezi `regroupByPartnerAcrossWeeks()`.
enum _ViewMode { saptamanal, perPartener }

class _PontajPartenerSaptamanalPageState
    extends State<PontajPartenerSaptamanalPage> {
  final _fmt = NumberFormat('#,##0.00', 'ro_RO');
  final _dateFmt = DateFormat('dd.MM.yyyy');

  final _paymentRepo = PartnerWeeklyPaymentRepository();

  bool _loading = true;
  String? _error;
  int _jobsScanned = 0;
  List<PontajFisaWeeklyGroup> _groups = const [];
  Map<String, PartnerWeeklyPayment> _payments = {};
  _ViewMode _viewMode = _ViewMode.saptamanal;

  /// Vederea Partener→Săptămână — reorganizare LOCALĂ a `_groups` (Faza 1),
  /// nu o citire nouă. Recalculată la fiecare `build()`, dar pe un set mic
  /// de date deja în memorie (ieftin — vezi `regroupByPartnerAcrossWeeks`).
  List<PontajFisaPartnerAcrossWeeks> get _partnersAcrossWeeks =>
      regroupByPartnerAcrossWeeks(_groups);

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
      List<PartnerWeeklyPayment> payments = const [];
      try {
        payments = await _paymentRepo.listPaymentsForPeriod(
            _period.start, _period.end);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _groups = groupPontajFisaRowsByWeek(result.rows);
        _jobsScanned = result.jobsScanned;
        _payments = {for (final p in payments) p.id: p};
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
        start:
            DateTime(picked.start.year, picked.start.month, picked.start.day),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<_ViewMode>(
                segments: const [
                  ButtonSegment(
                    value: _ViewMode.saptamanal,
                    label: Text('Săptămână → Partener'),
                    icon: Icon(Icons.calendar_view_week_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: _ViewMode.perPartener,
                    label: Text('Partener → Săptămână'),
                    icon: Icon(Icons.handshake_outlined, size: 16),
                  ),
                ],
                selected: {_viewMode},
                // Comutarea NU reîncarcă datele (_load() nu e apelat) — doar
                // reorganizează local ce e deja în _groups (Faza 4), deci
                // perioada/filtrele curente rămân neatinse automat.
                onSelectionChanged: (selection) =>
                    setState(() => _viewMode = selection.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
        ),
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
    final isWeekFirst = _viewMode == _ViewMode.saptamanal;
    // Ambele liste provin din ACELEAȘI date (_groups) — vezi getter-ul
    // _partnersAcrossWeeks, care doar reorganizează local, fără citire nouă.
    final List<PontajFisaPartnerAcrossWeeks> partnersAcrossWeeks =
        isWeekFirst ? const [] : _partnersAcrossWeeks;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeaderSummary()),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => isWeekFirst
                ? _buildWeekCard(_groups[i])
                : _buildPartnerFirstCard(partnersAcrossWeeks[i]),
            childCount:
                isWeekFirst ? _groups.length : partnersAcrossWeeks.length,
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
        children: group.parteneri
            .map((p) => _buildPartnerTile(p, group.weekStart))
            .toList(),
      ),
    );
  }

  /// Cardul principal în vederea Partener→Săptămână (Faza 4) — partenerul e
  /// nivelul de sus, cu toate săptămânile lui (din intervalul curent)
  /// dedesubt, fiecare cu statusul ei propriu de plată (plata se
  /// urmărește per partener+săptămână, nu global pe partener — vezi
  /// `PartnerWeeklyPaymentRepository.paymentId`).
  Widget _buildPartnerFirstCard(PontajFisaPartnerAcrossWeeks partner) {
    final theme = Theme.of(context);
    final name = partner.partnerNume.trim().isEmpty
        ? partner.partnerId
        : partner.partnerNume.trim();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ExpansionTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${partner.saptamani.length} '
          '${partner.saptamani.length == 1 ? "săptămână" : "săptămâni"}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          '${_fmt.format(partner.totalCost)} RON',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: theme.colorScheme.primary,
          ),
        ),
        children: partner.saptamani.map((e) {
          final weekLabel = 'Săpt. ${_dateFmt.format(e.weekStart)} – '
              '${_dateFmt.format(e.weekStart.add(const Duration(days: 6)))}';
          return _buildPartnerTile(e.total, e.weekStart, titleLabel: weekLabel);
        }).toList(),
      ),
    );
  }

  /// Cardul "partener într-o săptămână" — nucleul comun al AMBELOR ierarhii
  /// (Faza 4): în vederea Săptămână→Partener, `titleLabel` e numele
  /// partenerului (apelat din `_buildWeekCard`); în vederea Partener→
  /// Săptămână, `titleLabel` e intervalul săptămânii (apelat din
  /// `_buildPartnerFirstCard`, unde numele partenerului e deja afișat pe
  /// cardul-părinte). Restul (badge status, avertisment discrepanță, buton
  /// marchează plată, listă muncitori) e IDENTIC, indiferent de ierarhie.
  Widget _buildPartnerTile(
      PontajFisaPartnerWeeklyTotal partner, DateTime weekStart,
      {String? titleLabel}) {
    final name = titleLabel ??
        (partner.partnerNume.trim().isEmpty
            ? partner.partnerId
            : partner.partnerNume.trim());
    final payId =
        PartnerWeeklyPaymentRepository.paymentId(partner.partnerId, weekStart);
    final payment = _payments[payId];
    final hasPaymentRecord = payment != null;
    // Status DERIVAT (Faza 3) — comparație amountPaid vs. totalCost curent,
    // NU un câmp stocat. Vezi derivePartnerWeeklyPaymentStatus().
    final status = derivePartnerWeeklyPaymentStatus(
      payment: payment,
      totalCost: partner.totalCost,
    );
    final isPaidFully = status == PartnerWeeklyPaymentDerivedStatus.platit;
    // Avertisment SEPARAT de statusul de plată: calculatedAmountAtMarking
    // s-a schimbat față de pontajul curent (pontaj modificat DUPĂ marcare).
    // NU comparăm amountPaid aici (asta face derivePartnerWeeklyPaymentStatus).
    final hasDiscrepancy = hasPaymentRecord &&
        (payment.calculatedAmountAtMarking - partner.totalCost).abs() > 0.005;

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            _buildPaymentStatusBadge(status),
          ],
        ),
        subtitle: hasPaymentRecord
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPaidFully ? Icons.check_circle : Icons.pie_chart_outline,
                    size: 12,
                    color: isPaidFully
                        ? Colors.green.shade600
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${_fmt.format(payment.amountPaid)} RON plătit'
                    ' · ${_dateFmt.format(payment.paidAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isPaidFully
                          ? Colors.green.shade700
                          : Colors.orange.shade800,
                    ),
                  ),
                ],
              )
            : Text('${partner.muncitori.length} muncitori',
                style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasDiscrepancy)
              Tooltip(
                message: 'Pontajul s-a modificat de la marcarea plății'
                    ' — verifică (marcat: '
                    '${_fmt.format(payment.calculatedAmountAtMarking)} RON,'
                    ' curent: ${_fmt.format(partner.totalCost)} RON)',
                child: Icon(Icons.warning_amber_rounded,
                    size: 15, color: Colors.orange.shade700),
              ),
            if (hasDiscrepancy) const SizedBox(width: 2),
            Text(
              '${_fmt.format(partner.totalCost)} RON',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isPaidFully ? Colors.grey.shade500 : null,
              ),
            ),
            const SizedBox(width: 2),
            SizedBox(
              width: 30,
              height: 30,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () =>
                      _showMarkPaymentDialog(partner, weekStart, payment),
                  child: Icon(
                    hasPaymentRecord
                        ? Icons.edit_outlined
                        : Icons.payments_outlined,
                    size: 16,
                    color: hasPaymentRecord
                        ? Colors.grey.shade500
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        children: partner.muncitori.map(_buildWorkerTile).toList(),
      ),
    );
  }

  /// Badge/chip de status de plată (Faza 3) — Plătit (verde) / Plătit
  /// parțial (portocaliu) / Neplătit (roșu). Paletă ALINIATĂ cu modulul
  /// "Financiar parteneri" (`partner_financial_page.dart:2438-2466` —
  /// verde=achitat/încasat, portocaliu=neîncasat/pending, roșu=de plătit),
  /// ca să nu introducă o paletă nouă doar pentru acest ecran. Stil chip
  /// (padding+border+background alpha) consecvent cu badge-ul de status
  /// deja folosit pentru reconcilieri în același modul financiar
  /// (`partner_financial_page.dart:1739-1759`).
  Widget _buildPaymentStatusBadge(PartnerWeeklyPaymentDerivedStatus status) {
    final (label, color) = switch (status) {
      PartnerWeeklyPaymentDerivedStatus.platit => (
          'Plătit',
          Colors.green.shade700
        ),
      PartnerWeeklyPaymentDerivedStatus.platitPartial => (
          'Plătit parțial',
          Colors.orange.shade700
        ),
      PartnerWeeklyPaymentDerivedStatus.neplatit => (
          'Neplătit',
          Colors.red.shade700
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<void> _showMarkPaymentDialog(
    PontajFisaPartnerWeeklyTotal partner,
    DateTime weekStart,
    PartnerWeeklyPayment? existing,
  ) async {
    final name = partner.partnerNume.trim().isEmpty
        ? partner.partnerId
        : partner.partnerNume.trim();
    final amountCtrl = TextEditingController(
      text: existing != null
          ? existing.amountPaid.toStringAsFixed(2)
          : partner.totalCost.toStringAsFixed(2),
    );
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    final result = await showDialog<_PaymentDialogResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Marchează plată' : 'Editează plată'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        'Săpt. ${_dateFmt.format(weekStart)}'
                        ' – ${_dateFmt.format(weekStart.add(const Duration(days: 6)))}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Total pontaj calculat:'
                        ' ${_fmt.format(partner.totalCost)} RON',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (existing != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Marcat pe: ${_dateFmt.format(existing.paidAt)}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sumă plătită (RON)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notițe (opțional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(const _PaymentDialogResult._cancel()),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              child: const Text('Anulează marcarea'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Închide'),
          ),
          FilledButton(
            onPressed: () {
              final raw = amountCtrl.text.trim().replaceAll(',', '.');
              final amount = double.tryParse(raw) ?? partner.totalCost;
              Navigator.of(ctx).pop(_PaymentDialogResult._save(
                amount: amount,
                notes: notesCtrl.text.trim(),
              ));
            },
            child: Text(existing == null ? 'Marchează' : 'Salvează'),
          ),
        ],
      ),
    );

    amountCtrl.dispose();
    notesCtrl.dispose();

    if (!mounted || result == null) return;

    final payId =
        PartnerWeeklyPaymentRepository.paymentId(partner.partnerId, weekStart);

    if (result.shouldCancel) {
      setState(() => _payments.remove(payId));
      _paymentRepo.deletePayment(payId).catchError((Object e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Eroare la anulare: $e')),
          );
          _load();
        }
      });
      return;
    }

    final newPayment = PartnerWeeklyPayment(
      id: payId,
      partnerId: partner.partnerId,
      weekStart: weekStart,
      amountPaid: result.amount,
      calculatedAmountAtMarking: partner.totalCost,
      paidAt: existing?.paidAt ?? DateTime.now(),
      notes: result.notes.isEmpty ? null : result.notes,
    );
    setState(() => _payments[payId] = newPayment);
    _paymentRepo.upsertPayment(newPayment).catchError((Object e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare la salvare: $e')),
        );
        _load();
      }
    });
  }

  Widget _buildWorkerTile(PontajFisaWorkerWeeklyTotal worker) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
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
        ),
        // Detaliu per intrare individuală (Faza 2, aug 2026) — lucrare +
        // data/perioada exactă, indiferent dacă muncitorul are 1 sau mai
        // multe intrări în săptămâna asta (detaliul rămâne util și la 1).
        Padding(
          padding: const EdgeInsets.only(left: 56, right: 16, bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                worker.intrari.map(_buildWorkerEntryRow).toList(growable: false),
          ),
        ),
      ],
    );
  }

  /// O linie compactă pentru O intrare individuală de pontaj a unui
  /// muncitor (lucrare + dată/perioadă exactă + ore + cost).
  Widget _buildWorkerEntryRow(PontajFisaWeeklyEntry entry) {
    final row = entry.row;
    final jobLabel = row.jobTitle.trim().isEmpty
        ? (row.jobCode.trim().isEmpty ? '—' : row.jobCode)
        : (row.jobCode.trim().isEmpty
            ? row.jobTitle
            : '${row.jobCode} · ${row.jobTitle}');
    final start = row.dataStart;
    final end = row.dataEnd ?? start;
    final periodLabel = start == null
        ? '—'
        : (end == null || _isSameDay(start, end)
            ? _dateFmt.format(start)
            : '${_dateFmt.format(start)} – ${_dateFmt.format(end)}');

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.work_outline, size: 12, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$jobLabel · $periodLabel',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${_fmt.format(entry.row.oreTotale)} h · '
            '${_fmt.format(entry.row.costTotal)} RON',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Rezultat intern al dialogului de marcare plată.
class _PaymentDialogResult {
  const _PaymentDialogResult._cancel()
      : shouldCancel = true,
        amount = 0,
        notes = '';

  const _PaymentDialogResult._save({
    required this.amount,
    required this.notes,
  }) : shouldCancel = false;

  final bool shouldCancel;
  final double amount;
  final String notes;
}
