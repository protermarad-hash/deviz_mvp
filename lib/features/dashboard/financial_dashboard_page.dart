import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/help/help_module_button.dart';
import '../stoc/stoc_models.dart';
import '../stoc/stoc_repository.dart';
import '../../core/services/export_contabilitate_service.dart';
import '../obiective/obiective_models.dart';
import '../obiective/obiective_repository.dart';
import 'financial_dashboard_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pagina Dashboard Financiar
// ─────────────────────────────────────────────────────────────────────────────

class FinancialDashboardPage extends StatefulWidget {
  const FinancialDashboardPage({super.key});

  @override
  State<FinancialDashboardPage> createState() => _FinancialDashboardPageState();
}

class _FinancialDashboardPageState extends State<FinancialDashboardPage> {
  final _fmt = NumberFormat('#,##0.00', 'ro_RO');
  final _fmtInt = NumberFormat('#,##0', 'ro_RO');

  bool _loading = true;
  FinancialDashboardData _data = FinancialDashboardData.empty();
  List<StocItem> _stocCritic = const [];
  ObiectivProgress? _obiectivProgress;

  @override
  void initState() {
    super.initState();
    FirebaseBootstrap.onlineNotifier.addListener(_onOnlineChanged);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    FirebaseBootstrap.onlineNotifier.removeListener(_onOnlineChanged);
    super.dispose();
  }

  void _onOnlineChanged() {
    if (FirebaseBootstrap.onlineNotifier.value && mounted) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        FinancialDashboardService.instance.loadDashboard(),
        StocRepository.instance.listStocCritic(),
        ObiectiveRepository.instance.getOrCreateCurrent(),
      ]);
      ObiectivProgress? prog;
      try {
        final o = results[2] as ObiectivLunar;
        if (o.targetIncasariRON > 0) {
          prog = ObiectivProgress(
            obiectiv: o,
            incasariActuale: (_data.incasariLunaAceasta),
            lucrariNoi: 0,
            programariRON: 0,
            oferteTrimise: 0,
            rataConversieActuala: 0,
          );
        }
      } catch (e) {
        debugPrint('[FinancialDashboard] calcul progres obiectiv eșuat: $e');
      }
      if (mounted) {
        setState(() {
          _data = results[0] as FinancialDashboardData;
          _stocCritic = results[1] as List<StocItem>;
          _obiectivProgress = prog;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Financiar'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reîncarcă',
              onPressed: _load,
            ),
          const HelpModuleButton(moduleId: 'dashboard'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _secIncasari(cs),
                  const SizedBox(height: 12),
                  _secProfit(cs),
                  const SizedBox(height: 12),
                  _secAlertaRestante(cs),
                  const SizedBox(height: 12),
                  _secDatorii(cs),
                  const SizedBox(height: 12),
                  _secGrafic(cs),
                  const SizedBox(height: 12),
                  _secActivitate(cs),
                  const SizedBox(height: 12),
                  _secTopParteneri(cs),
                  const SizedBox(height: 12),
                  _secTopAngajati(cs),
                  if (_stocCritic.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _secAlertaStoc(cs),
                  ],
                  if (_obiectivProgress != null) ...[
                    const SizedBox(height: 12),
                    _secObiective(cs),
                  ],
                  const SizedBox(height: 12),
                  _secExportContabilitate(cs),
                  const SizedBox(height: 20),
                ],
              ),
      ),
    );
  }

  // ── SECȚIUNEA 1: ÎNCASĂRI ──────────────────────────────────────────────────

  Widget _secIncasari(ColorScheme cs) {
    return _card(
      title: 'Încasări',
      icon: Icons.payments_outlined,
      color: const Color(0xFF1565C0),
      child: Row(
        children: [
          _statCol(
            label: 'Luna aceasta',
            value: '${_fmt.format(_data.incasariLunaAceasta)} RON',
            large: true,
            color: const Color(0xFF1565C0),
          ),
          const VerticalDivider(width: 1),
          _statCol(
            label: 'Luna trecută',
            value: '${_fmt.format(_data.incasariLunaTrecuta)} RON',
          ),
          const VerticalDivider(width: 1),
          _statCol(
            label: 'An curent',
            value: '${_fmt.format(_data.incasariAnAcesta)} RON',
          ),
        ],
      ),
    );
  }

  // ── SECȚIUNEA 2: PROFIT ────────────────────────────────────────────────────

  Widget _secProfit(ColorScheme cs) {
    final isPositive = _data.profitBrutLuna >= 0;
    final profitColor = isPositive ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    return _card(
      title: 'Profit lunar',
      icon: Icons.trending_up,
      color: profitColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statCol(
                label: 'Profit brut',
                value: '${_fmt.format(_data.profitBrutLuna)} RON',
                large: true,
                color: profitColor,
              ),
              const VerticalDivider(width: 1),
              _statCol(
                label: 'Marjă',
                value: '${_data.marjaProfit.toStringAsFixed(1)}%',
                color: profitColor,
              ),
            ],
          ),
          const Divider(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                _breakdownRow('Încasări', _data.incasariLunaAceasta, const Color(0xFF1565C0)),
                _breakdownRow('Angajați', -_data.costuriAngajatiLuna, const Color(0xFFC62828)),
                _breakdownRow('Parteneri', -_data.costuriParteneriLuna, const Color(0xFFE65100)),
                _breakdownRow('Materiale', -_data.costuriMaterialeLuna, const Color(0xFF6A1B9A)),
                const Divider(height: 8),
                _breakdownRow('Total costuri', -_data.totalCosturiLuna, const Color(0xFFC62828), bold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, double value, Color color, {bool bold = false}) {
    final sign = value >= 0 ? '+' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          Text(
            '$sign${_fmt.format(value)} RON',
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── SECȚIUNEA 3: ALERTĂ PLĂȚI RESTANTE ────────────────────────────────────

  Widget _secAlertaRestante(ColorScheme cs) {
    final total = _data.deIncasatParteneri + _data.deIncasatClienti;
    final hasAlert = total > 0.01;
    final cardColor = hasAlert ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9);
    final borderColor = hasAlert ? const Color(0xFFEF9A9A) : const Color(0xFFA5D6A7);
    final textColor = hasAlert ? const Color(0xFFC62828) : const Color(0xFF2E7D32);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasAlert ? Icons.warning_amber_outlined : Icons.check_circle_outline,
                  color: textColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  hasAlert ? 'Plăți restante' : 'Fără restanțe',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (hasAlert) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _alertChip(
                    'De la parteneri',
                    _data.deIncasatParteneri,
                    textColor,
                  ),
                  const SizedBox(width: 8),
                  _alertChip(
                    'De la clienți (${_data.numarFacturiRestante} fact.)',
                    _data.deIncasatClienti,
                    textColor,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Total: ${_fmt.format(total)} RON',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _alertChip(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color)),
            Text(
              '${_fmt.format(amount)} RON',
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ── SECȚIUNEA 4: DATORII DE PLĂTIT ────────────────────────────────────────

  Widget _secDatorii(ColorScheme cs) {
    final total = _data.datoriiAngajati + _data.datoriiParteneri;
    return _card(
      title: 'Datorii de plătit',
      icon: Icons.account_balance_wallet_outlined,
      color: const Color(0xFFE65100),
      child: Row(
        children: [
          _statCol(
            label: 'Angajați',
            value: '${_fmt.format(_data.datoriiAngajati)} RON',
            color: _data.datoriiAngajati > 0.01 ? const Color(0xFFC62828) : Colors.black54,
          ),
          const VerticalDivider(width: 1),
          _statCol(
            label: 'Parteneri',
            value: '${_fmt.format(_data.datoriiParteneri)} RON',
            color: _data.datoriiParteneri > 0.01 ? const Color(0xFFE65100) : Colors.black54,
          ),
          const VerticalDivider(width: 1),
          _statCol(
            label: 'TOTAL',
            value: '${_fmt.format(total)} RON',
            large: true,
            color: total > 0.01 ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
          ),
        ],
      ),
    );
  }

  // ── SECȚIUNEA 5: GRAFIC 6 LUNI ─────────────────────────────────────────────

  Widget _secGrafic(ColorScheme cs) {
    return _card(
      title: 'Ultimele 6 luni',
      icon: Icons.bar_chart_outlined,
      color: const Color(0xFF1565C0),
      child: _data.graficUltimele6Luni.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nu există date pentru grafic.',
                  style: TextStyle(color: Colors.black38),
                ),
              ),
            )
          : SizedBox(
              height: 180,
              child: CustomPaint(
                painter: _BarChartPainter(data: _data.graficUltimele6Luni),
                size: Size.infinite,
              ),
            ),
    );
  }

  // ── SECȚIUNEA 6: ACTIVITATE ────────────────────────────────────────────────

  Widget _secActivitate(ColorScheme cs) {
    return _card(
      title: 'Activitate',
      icon: Icons.event_available_outlined,
      color: const Color(0xFF1565C0),
      child: Row(
        children: [
          _statCol(
            label: 'Programări azi',
            value: _fmtInt.format(_data.programariAzi),
            large: true,
            color: const Color(0xFF1565C0),
          ),
          const VerticalDivider(width: 1),
          _statCol(
            label: 'Programări săpt.',
            value: _fmtInt.format(_data.programariAceastaSaptamana),
          ),
          const VerticalDivider(width: 1),
          _statCol(
            label: 'Lucrări în curs',
            value: _fmtInt.format(_data.lucrariInCurs),
            color: _data.lucrariInCurs > 0 ? const Color(0xFFE65100) : Colors.black87,
          ),
          const VerticalDivider(width: 1),
          _statCol(
            label: 'Finalizate luna',
            value: _fmtInt.format(_data.lucrariFinalizateLuna),
            color: _data.lucrariFinalizateLuna > 0 ? const Color(0xFF2E7D32) : Colors.black87,
          ),
        ],
      ),
    );
  }

  // ── SECȚIUNEA 7: TOP PARTENERI ─────────────────────────────────────────────

  Widget _secTopParteneri(ColorScheme cs) {
    final list = _data.topParteneriDeIncasat;
    return _card(
      title: 'Top parteneri — de încasat',
      icon: Icons.handshake_outlined,
      color: const Color(0xFF1565C0),
      child: list.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nicio creanță de la parteneri.',
                style: TextStyle(color: Colors.black38, fontSize: 13),
              ),
            )
          : Column(
              children: list.asMap().entries.map((e) {
                final idx = e.key + 1;
                final p = e.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFF1565C0),
                        child: Text(
                          '$idx',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.partnerName.isEmpty ? p.partnerId : p.partnerName,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${_fmt.format(p.balance)} RON',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── SECȚIUNEA 8: TOP ANGAJAȚI DE PLĂTIT ───────────────────────────────────

  Widget _secTopAngajati(ColorScheme cs) {
    final list = _data.topAngajatiDePlata;
    return _card(
      title: 'Top angajați — de plătit',
      icon: Icons.people_outline,
      color: const Color(0xFFC62828),
      child: list.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nicio datorie către angajați.',
                style: TextStyle(color: Colors.black38, fontSize: 13),
              ),
            )
          : Column(
              children: list.asMap().entries.map((e) {
                final idx = e.key + 1;
                final emp = e.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFFC62828),
                        child: Text(
                          '$idx',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          emp.employeeName.isEmpty ? emp.employeeId : emp.employeeName,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${_fmt.format(emp.balance)} RON',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC62828),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _secAlertaStoc(ColorScheme cs) {
    return _card(
      title: 'Alerta stoc (${_stocCritic.length} produse)',
      icon: Icons.warehouse_outlined,
      color: Colors.orange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._stocCritic.take(3).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_outlined,
                        size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(item.productName,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${item.cantitate.toStringAsFixed(1)} ${item.unitate}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: Colors.red),
                    ),
                  ],
                ),
              )),
          if (_stocCritic.length > 3)
            Text('...si alte ${_stocCritic.length - 3} produse',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _secObiective(ColorScheme cs) {
    final p = _obiectivProgress;
    if (p == null) return const SizedBox.shrink();
    final o = p.obiectiv;

    Widget miniBar(String label, double progres, Color color) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
                width: 90,
                child: Text(label,
                    style: const TextStyle(fontSize: 11))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (progres / 100).clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade200,
                  color: progres >= 100 ? Colors.green : color,
                  minHeight: 8,
                ),
              ),
            ),
            SizedBox(
              width: 42,
              child: Text(
                ' ${progres.toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: progres >= 100
                        ? Colors.green
                        : color),
              ),
            ),
          ],
        ),
      );
    }

    return _card(
      title:
          'Obiective ${_monthName(o.luna)} ${o.an}',
      icon: Icons.flag_outlined,
      color: cs.primary,
      child: Column(
        children: [
          if (o.targetIncasariRON > 0)
            miniBar('Incasari',
                p.progresIncasari, Colors.green),
          if (o.targetLucrariNoi > 0)
            miniBar('Lucrari', p.progresLucrari, Colors.blue),
          if (o.targetProgramariRON > 0)
            miniBar('Programari',
                p.progresProgramari, Colors.purple),
        ],
      ),
    );
  }

  String _monthName(int luna) {
    const n = <String>['', 'Ian', 'Feb', 'Mar', 'Apr', 'Mai', 'Iun',
      'Iul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return luna >= 1 && luna <= 12 ? n[luna] : '$luna';
  }

  Widget _secExportContabilitate(ColorScheme cs) {
    final now = DateTime.now();
    final luna = now.month == 1 ? 12 : now.month - 1;
    final an = now.month == 1 ? now.year - 1 : now.year;
    const months = <String>[
      '', 'Ianuarie', 'Februarie', 'Martie', 'Aprilie', 'Mai', 'Iunie',
      'Iulie', 'August', 'Septembrie', 'Octombrie', 'Noiembrie', 'Decembrie'
    ];
    return _card(
      title: 'Export contabilitate — ${months[luna]} $an',
      icon: Icons.table_chart_outlined,
      color: cs.primary,
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.download_outlined, size: 16),
              label: const Text('Descarca Excel'),
              onPressed: () async {
                try {
                  await ExportContabilitateService.instance
                      .salveazaSiShare(an: an, luna: luna);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Eroare export: $e')),
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.email_outlined, size: 16),
              label: const Text('Trimite contabila'),
              onPressed: () async {
                final email = await ExportContabilitateService.instance
                    .getEmailContabila();
                if (!mounted) return;
                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Configurati email contabila in Setarile companiei.'),
                    ),
                  );
                  return;
                }
                try {
                  await ExportContabilitateService.instance
                      .trimiteRaportPeEmail(an: an, luna: luna);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Eroare: $e')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers UI ─────────────────────────────────────────────────────────────

  Widget _card({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _statCol({
    required String label,
    required String value,
    bool large = false,
    Color? color,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: large ? 15 : 13,
                fontWeight: large ? FontWeight.bold : FontWeight.w500,
                color: color ?? Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grafic bare 6 luni — CustomPainter (fără librării externe)
// ─────────────────────────────────────────────────────────────────────────────

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.data});
  final List<MonthlyRevenue> data;

  static const Color _colorIncasari = Color(0xFF1565C0);
  static const Color _colorCosturi = Color(0xFFE65100);
  static const Color _colorProfit = Color(0xFF2E7D32);
  static const Color _colorProfitNeg = Color(0xFFC62828);
  static const Color _gridColor = Color(0xFFEEEEEE);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double labelHeight = 28.0;
    const double legendHeight = 20.0;
    const double leftPadding = 52.0;
    const double rightPadding = 8.0;
    const double topPadding = 8.0;

    final chartHeight = size.height - labelHeight - legendHeight - topPadding;
    final chartWidth = size.width - leftPadding - rightPadding;

    // Valoare maximă pentru scala Y
    double maxVal = 0;
    for (final m in data) {
      maxVal = math.max(maxVal, m.incasari);
      maxVal = math.max(maxVal, m.costuri);
      maxVal = math.max(maxVal, m.profit.abs());
    }
    if (maxVal < 1) maxVal = 1;

    final gridPaint = Paint()..color = _gridColor..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    // Grid orizontal (4 linii)
    for (var i = 0; i <= 4; i++) {
      final y = topPadding + chartHeight * (1 - i / 4);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      // Etichete Y
      final val = maxVal * i / 4;
      final valLabel = val >= 1000 ? '${(val / 1000).toStringAsFixed(0)}k' : val.toStringAsFixed(0);
      textPainter
        ..text = TextSpan(
          text: valLabel,
          style: const TextStyle(fontSize: 9, color: Colors.black38),
        )
        ..layout();
      textPainter.paint(
        canvas,
        Offset(leftPadding - textPainter.width - 4, y - textPainter.height / 2),
      );
    }

    // Bare per lună
    final n = data.length;
    final groupWidth = chartWidth / n;
    const barGroupPad = 6.0;
    const barCount = 3;
    final barWidth = (groupWidth - barGroupPad * 2) / barCount;

    for (var i = 0; i < n; i++) {
      final m = data[i];
      final groupLeft = leftPadding + i * groupWidth + barGroupPad;

      void drawBar(int barIdx, double value, Color color) {
        final barH = (value.abs() / maxVal * chartHeight).clamp(0.0, chartHeight);
        final x = groupLeft + barIdx * barWidth;
        final y = topPadding + chartHeight - barH;
        final rect = Rect.fromLTWH(x, y, barWidth - 1.5, barH);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: const Radius.circular(2),
            topRight: const Radius.circular(2),
          ),
          Paint()..color = color,
        );
      }

      drawBar(0, m.incasari, _colorIncasari);
      drawBar(1, m.costuri, _colorCosturi);
      drawBar(2, m.profit, m.profit >= 0 ? _colorProfit : _colorProfitNeg);

      // Etichetă lună
      textPainter
        ..text = TextSpan(
          text: m.luna,
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        )
        ..layout();
      textPainter.paint(
        canvas,
        Offset(
          groupLeft + (groupWidth - barGroupPad * 2) / 2 - textPainter.width / 2,
          topPadding + chartHeight + 4,
        ),
      );
    }

    // Legendă
    void drawLegend(double x, Color color, String label) {
      final rect = Rect.fromLTWH(x, size.height - legendHeight + 4, 10, 10);
      canvas.drawRect(rect, Paint()..color = color);
      textPainter
        ..text = TextSpan(
          text: label,
          style: const TextStyle(fontSize: 9, color: Colors.black54),
        )
        ..layout();
      textPainter.paint(canvas, Offset(x + 13, size.height - legendHeight + 4));
    }

    drawLegend(leftPadding, _colorIncasari, 'Încasări');
    drawLegend(leftPadding + 60, _colorCosturi, 'Costuri');
    drawLegend(leftPadding + 115, _colorProfit, 'Profit');
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.data != data;
}
