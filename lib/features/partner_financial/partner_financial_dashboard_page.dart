import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/help/help_module_button.dart';
import '../../core/repositories/app_data_repository.dart';
import 'partner_financial_models.dart';
import 'partner_financial_page.dart';
import 'partner_financial_repository.dart';

// ── Model alertă sold inactiv ─────────────────────────────────────────────────
enum _AlertSeverity { urgent, warning }

class _PartnerAlert {
  _PartnerAlert({
    required this.summary,
    required this.lastTxDate,
    required this.daysSince,
    required this.severity,
  });
  final PartnerFinancialSummary summary;
  final DateTime lastTxDate;
  final int daysSince;
  final _AlertSeverity severity;
}

// ── Opțiuni sortare ───────────────────────────────────────────────────────────
enum _SortOption { balanceDesc, balanceAsc, name, stalest }

extension _SortLabel on _SortOption {
  String get label {
    switch (this) {
      case _SortOption.balanceDesc:
        return 'Sold descrescător';
      case _SortOption.balanceAsc:
        return 'Sold crescător';
      case _SortOption.name:
        return 'Nume A→Z';
      case _SortOption.stalest:
        return 'Cel mai vechi';
    }
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────
class PartnerFinancialDashboardPage extends StatefulWidget {
  const PartnerFinancialDashboardPage({
    super.key,
    this.appRepository,
  });

  final AppDataRepository? appRepository;

  @override
  State<PartnerFinancialDashboardPage> createState() =>
      _PartnerFinancialDashboardPageState();
}

class _PartnerFinancialDashboardPageState
    extends State<PartnerFinancialDashboardPage> {
  final _repository = PartnerFinancialRepository();
  final _fmt = NumberFormat('#,##0.00', 'ro_RO');

  bool _loading = true;
  bool _syncing = false;
  bool _recalculating = false;

  List<PartnerFinancialSummary> _summaries = const [];
  Map<String, DateTime> _lastTxDate = const {};
  List<_PartnerAlert> _alerts = const [];

  String _filter = 'toti';
  _SortOption _sort = _SortOption.balanceDesc;
  bool _showAllAlerts = false;

  static const int _topCount = 10;
  static const int _staleWarningDays = 30;
  static const int _staleUrgentDays = 60;
  static const double _minAlertBalance = 100;

  @override
  void initState() {
    super.initState();
    FirebaseBootstrap.onlineNotifier.addListener(_onOnlineChanged);
    Future.microtask(_loadPhase1);
  }

  @override
  void dispose() {
    FirebaseBootstrap.onlineNotifier.removeListener(_onOnlineChanged);
    super.dispose();
  }

  void _onOnlineChanged() {
    if (!mounted) return;
    setState(() {}); // actualizează iconița status
    if (FirebaseBootstrap.isOnline) {
      // La revenire online: dacă lista e goală sau există alerte fără date reale,
      // declanșează faza 2 în background
      _loadPhase2();
    }
  }

  // ── Faza 1: date locale imediate ─────────────────────────────────────────
  Future<void> _loadPhase1() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final summaries = await _repository.listLocalOnlySummaries();
    final txns = await _repository.listLocalOnlyTransactions();
    final lastTxDate = _computeLastTxDates(txns);
    final alerts = _computeAlerts(summaries, lastTxDate);

    if (!mounted) return;
    setState(() {
      _summaries = summaries..sort(_comparator);
      _lastTxDate = lastTxDate;
      _alerts = alerts;
      _loading = false;
    });

    // Faza 2 în background — nu blochează UI-ul
    if (FirebaseBootstrap.isOnline) {
      _loadPhase2();
    }
  }

  // ── Faza 2: sync Firestore în background ──────────────────────────────────
  Future<void> _loadPhase2() async {
    if (_syncing || !mounted) return;
    if (!mounted) return;
    setState(() => _syncing = true);

    try {
      await _syncAllFromAppointments();
      await _repository.rebuildAllSummaries();

      final summaries = await _repository.listAllSummaries();
      final txns = await _repository.listLocalOnlyTransactions();
      final lastTxDate = _computeLastTxDates(txns);
      final alerts = _computeAlerts(summaries, lastTxDate);

      if (!mounted) return;
      setState(() {
        _summaries = summaries..sort(_comparator);
        _lastTxDate = lastTxDate;
        _alerts = alerts;
      });
    } catch (_) {
      // Eșec silențios — datele locale rămân vizibile
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  // ── Calcul ultima dată tranzacție per partener ────────────────────────────
  Map<String, DateTime> _computeLastTxDates(
      List<PartnerTransaction> allTx) {
    final result = <String, DateTime>{};
    for (final tx in allTx) {
      final existing = result[tx.partnerId];
      if (existing == null || tx.date.isAfter(existing)) {
        result[tx.partnerId] = tx.date;
      }
    }
    return result;
  }

  // ── Calcul alerte solduri inactiva ────────────────────────────────────────
  List<_PartnerAlert> _computeAlerts(
    List<PartnerFinancialSummary> summaries,
    Map<String, DateTime> lastTxDate,
  ) {
    final now = DateTime.now();
    final alerts = <_PartnerAlert>[];
    for (final s in summaries) {
      if (s.soldNet < _minAlertBalance) continue;
      final last = lastTxDate[s.partnerId];
      if (last == null) continue;
      final days = now.difference(last).inDays;
      if (days >= _staleWarningDays) {
        alerts.add(_PartnerAlert(
          summary: s,
          lastTxDate: last,
          daysSince: days,
          severity: days >= _staleUrgentDays
              ? _AlertSeverity.urgent
              : _AlertSeverity.warning,
        ));
      }
    }
    alerts.sort((a, b) => b.daysSince.compareTo(a.daysSince));
    return alerts;
  }

  // ── Sync programări din Firestore ─────────────────────────────────────────
  Future<void> _syncAllFromAppointments() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('appointments').get();
      final now = DateTime.now();

      double parseNum(dynamic v) =>
          v is num ? v.toDouble() : double.tryParse('$v'.replaceAll(',', '.')) ?? 0;

      PartnerTransactionStatus mapStatus(String raw) {
        final v = raw.trim().toLowerCase();
        if (v == 'platit' || v == 'conform_contract') {
          return PartnerTransactionStatus.platit;
        }
        return PartnerTransactionStatus.neplatit;
      }

      final toUpsert = <PartnerTransaction>[];
      for (final doc in snapshot.docs) {
        final raw = doc.data();
        final id = doc.id;
        final scheduledDateStr =
            (raw['scheduled_date'] ?? raw['scheduledDate'] ?? '').toString();
        final scheduledDate = DateTime.tryParse(scheduledDateStr) ?? now;
        final title = (raw['title'] ?? '').toString().trim();
        final label = title.isEmpty
            ? 'Programare ${scheduledDate.day.toString().padLeft(2, '0')}.${scheduledDate.month.toString().padLeft(2, '0')}.${scheduledDate.year}'
            : title;

        final forId =
            (raw['for_partner_id'] ?? raw['forPartnerId'] ?? '').toString().trim();
        final forName =
            (raw['for_partner_name'] ?? raw['forPartnerName'] ?? '').toString().trim();
        final forAmount = parseNum(
            raw['for_partner_invoice_amount'] ?? raw['forPartnerInvoiceAmount']);
        if (forId.isNotEmpty && forAmount > 0) {
          toUpsert.add(PartnerTransaction(
            id: 'ptxn_${id}_for',
            partnerId: forId,
            partnerName: forName,
            type: PartnerTransactionType.incasareProgramare,
            direction: PartnerTransactionDirection.intrare,
            amount: forAmount,
            date: scheduledDate,
            description: 'Programare: $label',
            referenceId: id,
            referenceType: 'programare',
            paymentMethod: PartnerTransactionPaymentMethod.transfer,
            status: mapStatus(
              (raw['for_partner_receive_status'] ?? raw['forPartnerReceiveStatus'] ?? '')
                  .toString(),
            ),
            createdAt: now,
            updatedAt: now,
          ));
        }

        final execId =
            (raw['executing_partner_id'] ?? raw['executingPartnerId'] ?? '')
                .toString()
                .trim();
        final execName =
            (raw['executing_partner_name'] ?? raw['executingPartnerName'] ?? '')
                .toString()
                .trim();
        final execAmount = parseNum(
            raw['executing_partner_commission'] ?? raw['executingPartnerCommission']);
        if (execId.isNotEmpty && execAmount > 0) {
          toUpsert.add(PartnerTransaction(
            id: 'ptxn_${id}_exec',
            partnerId: execId,
            partnerName: execName,
            type: PartnerTransactionType.plataProgramare,
            direction: PartnerTransactionDirection.iesire,
            amount: execAmount,
            date: scheduledDate,
            description: 'Programare: $label',
            referenceId: id,
            referenceType: 'programare',
            paymentMethod: PartnerTransactionPaymentMethod.transfer,
            status: mapStatus(
              (raw['executing_partner_payment_status'] ??
                      raw['executingPartnerPaymentStatus'] ??
                      '')
                  .toString(),
            ),
            createdAt: now,
            updatedAt: now,
          ));
        }
      }

      if (toUpsert.isNotEmpty) {
        await _repository.upsertTransactionsBatch(
          toUpsert,
          preserveExistingStatus: true,
        );
      }
    } catch (e) {
      debugPrint('[PartnerFinancialDashboard] sync tranzacții batch eșuat: $e');
    }
  }

  Future<void> _recalculateAll() async {
    if (_recalculating || _loading) return;
    if (!mounted) return;
    setState(() => _recalculating = true);
    try {
      final count = await _repository.rebuildAllSummaries();
      final summaries = await _repository.listAllSummaries();
      final txns = await _repository.listLocalOnlyTransactions();
      final lastTxDate = _computeLastTxDates(txns);
      final alerts = _computeAlerts(summaries, lastTxDate);
      if (!mounted) return;
      setState(() {
        _summaries = summaries..sort(_comparator);
        _lastTxDate = lastTxDate;
        _alerts = alerts;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recalculat $count parteneri.')),
        );
      }
    } finally {
      if (mounted) setState(() => _recalculating = false);
    }
  }

  // ── Comparator sortare ────────────────────────────────────────────────────
  int _comparator(PartnerFinancialSummary a, PartnerFinancialSummary b) {
    switch (_sort) {
      case _SortOption.balanceDesc:
        return b.soldNet.compareTo(a.soldNet);
      case _SortOption.balanceAsc:
        return a.soldNet.compareTo(b.soldNet);
      case _SortOption.name:
        return a.partnerName
            .toLowerCase()
            .compareTo(b.partnerName.toLowerCase());
      case _SortOption.stalest:
        final aLast = _lastTxDate[a.partnerId];
        final bLast = _lastTxDate[b.partnerId];
        if (aLast == null && bLast == null) return 0;
        if (aLast == null) return 1;
        if (bLast == null) return -1;
        return aLast.compareTo(bLast); // cel mai vechi = fără activitate
    }
  }

  // ── Date filtrate și sortate ──────────────────────────────────────────────
  List<PartnerFinancialSummary> get _filtered {
    List<PartnerFinancialSummary> base;
    switch (_filter) {
      case 'de_incasat':
        base = _summaries.where((s) => s.soldNet > 0).toList();
        break;
      case 'de_platit':
        base = _summaries.where((s) => s.soldNet < 0).toList();
        break;
      case 'alerte':
        base = _alerts.map((a) => a.summary).toList();
        return base; // deja sortate după gravitate
      default:
        base = List<PartnerFinancialSummary>.from(_summaries);
    }
    base.sort(_comparator);
    return base;
  }

  // ── Totale globale ────────────────────────────────────────────────────────
  double get _totalDeIncasat =>
      _summaries.fold(0, (acc, s) => acc + s.totalDeIncasat);
  double get _totalDePlata =>
      _summaries.fold(0, (acc, s) => acc + s.totalDePlata);
  double get _soldNetTotal => _totalDeIncasat - _totalDePlata;

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financiar parteneri'),
        actions: [
          // Sort menu
          PopupMenuButton<_SortOption>(
            icon: const Icon(Icons.sort_outlined),
            tooltip: 'Sortează',
            onSelected: (v) => setState(() {
              _sort = v;
              _summaries = List.from(_summaries)..sort(_comparator);
            }),
            itemBuilder: (_) => _SortOption.values
                .map((o) => PopupMenuItem(
                      value: o,
                      child: Row(
                        children: [
                          Icon(
                            o == _sort
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(o.label),
                        ],
                      ),
                    ))
                .toList(),
          ),
          // Recalculate
          _recalculating
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.calculate_outlined),
                  tooltip: 'Recalculează solduri',
                  onPressed: (_loading || _syncing) ? null : _recalculateAll,
                ),
          // Sync status / manual sync
          _syncing
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    FirebaseBootstrap.isOnline
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                    color: FirebaseBootstrap.isOnline
                        ? Colors.green.shade600
                        : Colors.orange.shade600,
                  ),
                  tooltip: FirebaseBootstrap.isOnline
                      ? 'Online — apasă pentru re-sync'
                      : 'Offline — datele sunt din cache local',
                  onPressed: _loading ? null : _loadPhase2,
                ),
          const HelpModuleButton(moduleId: 'financiar_parteneri'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPhase1,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildGlobalSummary()),
                  if (_alerts.isNotEmpty)
                    SliverToBoxAdapter(child: _buildAlertsSection()),
                  SliverToBoxAdapter(child: _buildFilterChips()),
                  const SliverToBoxAdapter(child: SizedBox(height: 4)),
                  if (_filtered.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Nicio tranzacție pentru filtrul selectat.'),
                            const SizedBox(height: 12),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'Firebase: init=${FirebaseBootstrap.isInitialized} '
                                  'online=${FirebaseBootstrap.isOnline}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _loadPhase1,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Reîncarcă'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final list = _filtered;
                          if (i >= list.length) return null;
                          return Column(
                            children: [
                              _buildPartnerCard(list[i]),
                              if (i < list.length - 1)
                                const Divider(height: 1, indent: 16),
                            ],
                          );
                        },
                        childCount: _filtered.length,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // ── Widget: sumar global ──────────────────────────────────────────────────
  Widget _buildGlobalSummary() {
    final soldNet = _soldNetTotal;
    final soldColor = soldNet >= 0 ? Colors.green.shade700 : Colors.red.shade700;
    final urgentCount =
        _alerts.where((a) => a.severity == _AlertSeverity.urgent).length;
    final warningCount =
        _alerts.where((a) => a.severity == _AlertSeverity.warning).length;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sumar global parteneri',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${_summaries.length} parteneri',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryRow(
              label: 'Total de încasat',
              value: '${_fmt.format(_totalDeIncasat)} RON',
              color: Colors.green.shade700,
            ),
            _SummaryRow(
              label: 'Total de plătit',
              value: '${_fmt.format(_totalDePlata)} RON',
              color: Colors.red.shade700,
            ),
            const Divider(height: 16),
            _SummaryRow(
              label: 'Sold NET total',
              value: '${soldNet >= 0 ? '+' : ''}${_fmt.format(soldNet)} RON',
              color: soldColor,
              bold: true,
            ),
            // Badge-uri alerte
            if (_alerts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (urgentCount > 0)
                    _AlertChip(
                      label: '$urgentCount urgent${urgentCount > 1 ? 'e' : ''}',
                      color: Colors.red.shade700,
                      onTap: () =>
                          setState(() => _filter = 'alerte'),
                    ),
                  if (warningCount > 0)
                    _AlertChip(
                      label: '$warningCount atenție',
                      color: Colors.orange.shade700,
                      onTap: () =>
                          setState(() => _filter = 'alerte'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Widget: secțiunea alerte ──────────────────────────────────────────────
  Widget _buildAlertsSection() {
    final dateFmt = DateFormat('dd.MM.yyyy');
    final visibleAlerts =
        _showAllAlerts ? _alerts : _alerts.take(_topCount).toList();

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_outlined,
                    size: 18, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Solduri inactiva (≥$_staleWarningDays zile)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade800,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${_alerts.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...visibleAlerts.map((alert) {
              final isUrgent = alert.severity == _AlertSeverity.urgent;
              final alertColor =
                  isUrgent ? Colors.red.shade700 : Colors.orange.shade700;
              final name = alert.summary.partnerName.isEmpty
                  ? alert.summary.partnerId
                  : alert.summary.partnerName;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: InkWell(
                  onTap: () => _openPartner(alert.summary),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: alertColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: alertColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isUrgent
                              ? Icons.error_outline
                              : Icons.schedule_outlined,
                          size: 16,
                          color: alertColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: alertColor,
                                ),
                              ),
                              Text(
                                'Ultima tranzacție: ${dateFmt.format(alert.lastTxDate)} — ${alert.daysSince} zile fără activitate',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_fmt.format(alert.summary.soldNet)} RON',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: alertColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (_alerts.length > _topCount) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: () =>
                    setState(() => _showAllAlerts = !_showAllAlerts),
                child: Text(
                  _showAllAlerts
                      ? 'Afișează mai puțin'
                      : 'Afișează toate (${_alerts.length})',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Widget: filter chips ──────────────────────────────────────────────────
  Widget _buildFilterChips() {
    final filters = <(String, String, int?)>[
      ('toti', 'Toți', null),
      ('de_incasat', 'De încasat', _summaries.where((s) => s.soldNet > 0).length),
      ('de_platit', 'De plătit', _summaries.where((s) => s.soldNet < 0).length),
      if (_alerts.isNotEmpty) ('alerte', 'Alerte', _alerts.length),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: filters.map((f) {
          final isSelected = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                f.$3 != null ? '${f.$2} (${f.$3})' : f.$2,
              ),
              selected: isSelected,
              onSelected: (_) => setState(() => _filter = f.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Widget: card partener ─────────────────────────────────────────────────
  Widget _buildPartnerCard(PartnerFinancialSummary s) {
    final soldNet = s.soldNet;
    final isPositive = soldNet >= 0;
    final color = isPositive ? Colors.green.shade700 : Colors.red.shade700;
    final name = s.partnerName.isEmpty ? s.partnerId : s.partnerName;

    // Alertă pentru acest partener
    final alert = _alerts.where((a) => a.summary.partnerId == s.partnerId).firstOrNull;
    final isUrgent = alert?.severity == _AlertSeverity.urgent;
    final isWarning = alert?.severity == _AlertSeverity.warning;

    final lastTx = _lastTxDate[s.partnerId];
    final dateFmt = DateFormat('dd.MM.yyyy');

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor:
                isPositive ? Colors.green.shade50 : Colors.red.shade50,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isUrgent || isWarning)
            Positioned(
              right: -4,
              top: -4,
              child: Icon(
                isUrgent ? Icons.error : Icons.warning_amber,
                size: 14,
                color: isUrgent
                    ? Colors.red.shade700
                    : Colors.orange.shade700,
              ),
            ),
        ],
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${s.transactionCount} tranzacții'
            '${lastTx != null ? ' · ultima: ${dateFmt.format(lastTx)}' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (alert != null)
            Text(
              '${alert.daysSince} zile fără activitate',
              style: TextStyle(
                fontSize: 11,
                color: isUrgent
                    ? Colors.red.shade600
                    : Colors.orange.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
      trailing: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          '${soldNet >= 0 ? '+' : ''}${_fmt.format(soldNet)} RON',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
      onTap: () => _openPartner(s),
    );
  }

  void _openPartner(PartnerFinancialSummary s) {
    final name = s.partnerName.isEmpty ? s.partnerId : s.partnerName;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartnerFinancialPage(
          partnerId: s.partnerId,
          partnerName: name,
          appRepository: widget.appRepository,
        ),
      ),
    ).then((_) {
      // La întoarcere, reîncarcă datele locale (soldurile pot fi modificate)
      if (mounted) _loadPhase1();
    });
  }
}

// ── Widgets helper ─────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });
  final String label;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: bold ? color : null,
              fontWeight: bold ? FontWeight.bold : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              fontSize: bold ? 15 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  const _AlertChip({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_outlined, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
