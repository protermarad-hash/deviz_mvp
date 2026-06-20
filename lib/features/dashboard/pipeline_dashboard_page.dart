import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../oferte/offer_models.dart';
import '../jobs/job_models.dart';
import '../crm/crm_models.dart';

/// Dashboard pipeline complet: Lead → Ofertă → Lucrare → Factură
class PipelineDashboardPage extends StatefulWidget {
  const PipelineDashboardPage({super.key});

  @override
  State<PipelineDashboardPage> createState() => _PipelineDashboardPageState();
}

class _PipelineDashboardPageState extends State<PipelineDashboardPage> {
  static final _fmtMoney = NumberFormat('#,##0', 'ro_RO');

  bool _loading = true;

  // Statistici pipeline
  int _crmTotal = 0;
  int _oferteTotal = 0;
  int _oferteTrimise = 0;
  int _oferteAcceptate = 0;
  // ignore: unused_field
  int _oferteRespinse = 0;
  // ignore: unused_field
  int _oferteExpirate = 0;
  int _lucrarilActive = 0;
  int _lucrarileFinalizate = 0;
  int _lucrarileFacturate = 0;
  // ignore: unused_field
  double _valoareOferte = 0;
  double _valoareLucrari = 0;
  double _valoareDeFacturat = 0;

  // Liste pentru secțiuni de atenție
  List<OfferRecord> _oferteExiprateList = [];
  List<JobRecord> _lucrarilNecesitaActiune = [];

  // Activitate recentă
  final List<_PipelineEvent> _activitateRecenta = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final lunaStart = DateTime(now.year, now.month, 1);
      final expiredCutoff = now.subtract(const Duration(days: 30));

      // Oferte
      final oferteRaw = prefs.getString('ultra_offers_v1');
      List<OfferRecord> oferte = [];
      if (oferteRaw != null && oferteRaw.isNotEmpty) {
        try {
          final list = jsonDecode(oferteRaw) as List;
          oferte = list
              .whereType<Map>()
              .map((m) => OfferRecord.fromMap(Map<String, dynamic>.from(m)))
              .where((o) => o.id.isNotEmpty)
              .toList();
        } catch (e) {
          debugPrint('[PipelineDashboard] parsare oferte eșuată: $e');
        }
      }

      // Lucrări
      final jobsRaw = prefs.getString('ultra_jobs_v1');
      List<JobRecord> lucrari = [];
      if (jobsRaw != null && jobsRaw.isNotEmpty) {
        try {
          final list = jsonDecode(jobsRaw) as List;
          lucrari = list
              .whereType<Map>()
              .map((m) => JobRecord.fromMap(Map<String, dynamic>.from(m)))
              .where((j) => j.id.isNotEmpty && j.isActive)
              .toList();
        } catch (e) {
          debugPrint('[PipelineDashboard] parsare lucrări eșuată: $e');
        }
      }

      // CRM
      final crmRaw = prefs.getString('crm_records_v1');
      List<CrmRecord> crm = [];
      if (crmRaw != null && crmRaw.isNotEmpty) {
        try {
          final list = jsonDecode(crmRaw) as List;
          crm = list
              .whereType<Map>()
              .map((m) => CrmRecord.fromMap(Map<String, dynamic>.from(m)))
              .where((c) => c.id.isNotEmpty)
              .toList();
        } catch (e) {
          debugPrint('[PipelineDashboard] parsare CRM eșuată: $e');
        }
      }

      // Calculează statistici
      final oferteExpirate = oferte
          .where((o) =>
              o.status == OfferStatus.sent &&
              o.updatedAt.isBefore(expiredCutoff) &&
              !o.isConverted)
          .toList();
      final oferteTrimise =
          oferte.where((o) => o.status == OfferStatus.sent).length;
      final oferteAcceptate =
          oferte.where((o) => o.status == OfferStatus.accepted).length;
      final oferteRespinse =
          oferte.where((o) => o.status == OfferStatus.rejected).length;
      final lucrarilActive = lucrari
          .where((j) =>
              j.status == JobStatus.inExecutie ||
              j.status == JobStatus.planificata)
          .length;
      final lucrarileFinalizate =
          lucrari.where((j) => j.status == JobStatus.finalizata).length;
      final lucrarileFacturate =
          lucrari.where((j) => j.smartbillFacturaNumar.isNotEmpty).length;

      // Lucrări care necesită acțiune
      final lucrarilNecesita = lucrari.where((j) {
        if (j.status == JobStatus.finalizata &&
            j.smartbillFacturaNumar.isEmpty) {
          return true;
        }
        if (j.status == JobStatus.planificata &&
            j.createdAt.isBefore(now.subtract(const Duration(days: 7)))) {
          return true;
        }
        if (j.status == JobStatus.inExecutie &&
            j.createdAt.isBefore(now.subtract(const Duration(days: 30)))) {
          return true;
        }
        return false;
      }).toList();

      // Valori financiare
      final valOferte = oferte
          .where((o) =>
              o.status != OfferStatus.rejected &&
              o.status != OfferStatus.cancelled)
          .fold(0.0, (s, o) => s + o.totalValue);
      final valLucrari = lucrari
          .where((j) =>
              j.status == JobStatus.inExecutie ||
              j.status == JobStatus.planificata)
          .fold(0.0, (s, j) => s + (j.estimatedValue ?? 0));
      final valDeFacturat = lucrari
          .where((j) =>
              j.status == JobStatus.finalizata &&
              j.smartbillFacturaNumar.isEmpty)
          .fold(0.0, (s, j) => s + j.totalReal);

      // Activitate recentă (ultime 10 acțiuni)
      final events = <_PipelineEvent>[];
      for (final o in oferte.take(20)) {
        if (o.updatedAt.isAfter(lunaStart)) {
          events.add(_PipelineEvent(
            icon: Icons.description_outlined,
            color: Colors.blue,
            label: 'Ofertă ${o.status.label}: ${o.offerNumber}',
            subtitle: o.clientName,
            data: o.updatedAt,
          ));
        }
      }
      for (final j in lucrari.take(20)) {
        if (j.updatedAt.isAfter(lunaStart)) {
          events.add(_PipelineEvent(
            icon: Icons.construction_outlined,
            color: Colors.purple,
            label: 'Lucrare ${j.status.label}: ${j.jobCode}',
            subtitle: j.title,
            data: j.updatedAt,
          ));
        }
      }
      events.sort((a, b) => b.data.compareTo(a.data));

      if (!mounted) return;
      setState(() {
        _crmTotal = crm.length;
        _oferteTotal = oferte.length;
        _oferteTrimise = oferteTrimise;
        _oferteAcceptate = oferteAcceptate;
        _oferteRespinse = oferteRespinse;
        _oferteExpirate = oferteExpirate.length;
        _lucrarilActive = lucrarilActive;
        _lucrarileFinalizate = lucrarileFinalizate;
        _lucrarileFacturate = lucrarileFacturate;
        _valoareOferte = valOferte;
        _valoareLucrari = valLucrari;
        _valoareDeFacturat = valDeFacturat;
        _oferteExiprateList = oferteExpirate;
        _lucrarilNecesitaActiune = lucrarilNecesita;
        _activitateRecenta
          ..clear()
          ..addAll(events.take(10));
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── TITLU ──────────────────────────────────────────────────────────
          const Text(
            'Pipeline Vânzări',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Flux complet: Lead → Ofertă → Lucrare → Factură',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          // ── SECȚIUNEA 1 — FUNNEL VIZUAL ────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Funnel pipeline',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _FunnelStep(
                            label: 'Lead-uri',
                            count: _crmTotal,
                            color: Colors.blue),
                        const _Arrow(),
                        _FunnelStep(
                            label: 'Oferte',
                            count: _oferteTrimise,
                            color: Colors.orange),
                        const _Arrow(),
                        _FunnelStep(
                            label: 'Lucrări active',
                            count: _lucrarilActive,
                            color: Colors.purple),
                        const _Arrow(),
                        _FunnelStep(
                            label: 'Facturate',
                            count: _lucrarileFacturate,
                            color: Colors.green),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── SECȚIUNEA 2 — KPI-URI ──────────────────────────────────────────
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.4,
            children: [
              _KpiCard(
                label: 'Oferte trimise',
                value: '$_oferteTrimise',
                sub: 'din $_oferteTotal total',
                color: Colors.orange,
                icon: Icons.send_outlined,
              ),
              _KpiCard(
                label: 'Rată conversie',
                value: _oferteTrimise > 0
                    ? '${(_oferteAcceptate / _oferteTrimise * 100).toStringAsFixed(0)}%'
                    : '-',
                sub: '$_oferteAcceptate acceptate',
                color: Colors.green,
                icon: Icons.trending_up_outlined,
              ),
              _KpiCard(
                label: 'Valoare lucrări',
                value: '${_fmtMoney.format(_valoareLucrari)} RON',
                sub: '$_lucrarilActive active',
                color: Colors.purple,
                icon: Icons.construction_outlined,
              ),
              _KpiCard(
                label: 'De facturat',
                value: '${_fmtMoney.format(_valoareDeFacturat)} RON',
                sub: '${_lucrarileFinalizate - _lucrarileFacturate} lucrări',
                color: _valoareDeFacturat > 0 ? Colors.red : Colors.grey,
                icon: Icons.receipt_long_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── SECȚIUNEA 3 — OFERTE EXPIRATE ─────────────────────────────────
          if (_oferteExiprateList.isNotEmpty)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_outlined,
                            color: Colors.orange[700], size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${_oferteExiprateList.length} oferte fără răspuns (> 30 zile)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._oferteExiprateList.take(5).map((o) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${o.offerNumber} — ${o.clientName}',
                              style:
                                  const TextStyle(fontSize: 13)),
                          subtitle: Text(
                              '${_fmtMoney.format(o.totalValue)} RON',
                              style: const TextStyle(fontSize: 11)),
                          trailing: Wrap(spacing: 4, children: [
                            OutlinedButton(
                              onPressed: null,
                              style: OutlinedButton.styleFrom(
                                  visualDensity:
                                      VisualDensity.compact,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8)),
                              child: const Text('Reactivează',
                                  style: TextStyle(fontSize: 11)),
                            ),
                          ]),
                        )),
                  ],
                ),
              ),
            ),
          if (_oferteExiprateList.isNotEmpty) const SizedBox(height: 12),

          // ── SECȚIUNEA 4 — LUCRĂRI CU ACȚIUNE ─────────────────────────────
          if (_lucrarilNecesitaActiune.isNotEmpty)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side:
                    BorderSide(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pending_actions_outlined,
                            color: Color(0xFFC62828), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${_lucrarilNecesitaActiune.length} lucrări necesită acțiune',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC62828)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._lucrarilNecesitaActiune.take(5).map((j) {
                      final motivText = j.status == JobStatus.finalizata &&
                              j.smartbillFacturaNumar.isEmpty
                          ? 'Neînregistrată SmartBill'
                          : 'Fără activitate recentă';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${j.jobCode} — ${j.title}',
                            style:
                                const TextStyle(fontSize: 13)),
                        subtitle: Text(motivText,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFFC62828))),
                        trailing: Text(j.status.label,
                            style: const TextStyle(fontSize: 11)),
                      );
                    }),
                  ],
                ),
              ),
            ),
          if (_lucrarilNecesitaActiune.isNotEmpty) const SizedBox(height: 12),

          // ── SECȚIUNEA 5 — ACTIVITATE RECENTĂ ──────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Activitate recentă',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  if (_activitateRecenta.isEmpty)
                    const Text('Nicio activitate luna aceasta.',
                        style: TextStyle(color: Colors.grey))
                  else
                    ..._activitateRecenta.map((e) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading:
                              Icon(e.icon, color: e.color, size: 18),
                          title: Text(e.label,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(e.subtitle,
                              style: const TextStyle(fontSize: 11)),
                          trailing: Text(
                            DateFormat('dd.MM').format(e.data),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Widgets helper ─────────────────────────────────────────────────────────────

class _FunnelStep extends StatelessWidget {
  const _FunnelStep({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.sub = '',
  });
  final String label;
  final String value;
  final String sub;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                  Text(value,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: color),
                      overflow: TextOverflow.ellipsis),
                  if (sub.isNotEmpty)
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey),
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PipelineEvent {
  const _PipelineEvent({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.data,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final DateTime data;
}
