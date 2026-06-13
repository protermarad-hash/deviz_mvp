import 'package:flutter/material.dart';

import 'profitabilitate_service.dart';

class AnalizaPage extends StatefulWidget {
  const AnalizaPage({super.key});

  @override
  State<AnalizaPage> createState() => _AnalizaPageState();
}

class _AnalizaPageState extends State<AnalizaPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _service = ProfitabilitateService.instance;

  List<ProfitabilitateTipLucrare> _perTip = [];
  List<ProfitabilitateAngajat> _perAngajat = [];
  bool _loading = true;
  String _perioadaLabel = 'Luna aceasta';

  // Perioade predefinite
  static final _perioade = <String, DateRange>{
    'Luna aceasta': DateRange(
      DateTime(DateTime.now().year, DateTime.now().month),
      DateTime(DateTime.now().year, DateTime.now().month + 1),
    ),
    'Trimestrul': DateRange(
      DateTime(DateTime.now().year,
          ((DateTime.now().month - 1) ~/ 3) * 3 + 1),
      DateTime(DateTime.now().year,
          ((DateTime.now().month - 1) ~/ 3) * 3 + 4),
    ),
    'Anul curent': DateRange(
      DateTime(DateTime.now().year),
      DateTime(DateTime.now().year + 1),
    ),
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final range = _perioade[_perioadaLabel]!;
    final tipData = await _service.analizeazaPerTip(
        from: range.from, to: range.to);
    final angData = await _service.analizeazaPerAngajat(
        from: range.from, to: range.to);
    if (!mounted) return;
    setState(() {
      _perTip = tipData;
      _perAngajat = angData;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analiza profitabilitate'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _perioadaLabel,
            onSelected: (v) {
              setState(() => _perioadaLabel = v);
              _load();
            },
            itemBuilder: (_) => _perioade.keys
                .map((k) => PopupMenuItem(value: k, child: Text(k)))
                .toList(),
            child: Chip(
              label: Text(_perioadaLabel,
                  style: const TextStyle(fontSize: 12)),
              avatar: const Icon(Icons.date_range_outlined, size: 16),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(
                icon: Icon(Icons.category_outlined),
                text: 'Per tip lucrare'),
            Tab(
                icon: Icon(Icons.people_outlined),
                text: 'Per angajat'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _buildPerTipTab(),
                _buildPerAngajatTab(),
              ],
            ),
    );
  }

  // ── TAB 0 — Per tip lucrare ───────────────────────────────────────────────

  Widget _buildPerTipTab() {
    if (_perTip.isEmpty) {
      return const Center(
          child: Text('Nicio programare in perioada selectata.'));
    }

    final maxProfit = _perTip
        .map((t) => t.profitTotal.abs())
        .fold(0.0, (a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Tabel rezumat
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rezumat per tip lucrare',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      headingRowHeight: 32,
                      dataRowMinHeight: 28,
                      dataRowMaxHeight: 40,
                      columns: const [
                        DataColumn(label: Text('Tip lucrare')),
                        DataColumn(
                            label: Text('Nr.'), numeric: true),
                        DataColumn(
                            label: Text('Incasari'), numeric: true),
                        DataColumn(
                            label: Text('Costuri'), numeric: true),
                        DataColumn(
                            label: Text('Profit'), numeric: true),
                        DataColumn(
                            label: Text('Marja %'), numeric: true),
                      ],
                      rows: _perTip
                          .map((t) => DataRow(cells: [
                                DataCell(Text(t.tip,
                                    style: const TextStyle(
                                        fontSize: 12))),
                                DataCell(Text('${t.nrProgramari}',
                                    style: const TextStyle(
                                        fontSize: 12))),
                                DataCell(Text(
                                    '${t.incasariTotal.toStringAsFixed(0)} RON',
                                    style: const TextStyle(
                                        fontSize: 12))),
                                DataCell(Text(
                                    '${t.costuriTotal.toStringAsFixed(0)} RON',
                                    style: const TextStyle(
                                        fontSize: 12))),
                                DataCell(Text(
                                    '${t.profitTotal.toStringAsFixed(0)} RON',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: t.profitTotal >= 0
                                            ? Colors.green
                                            : Colors.red))),
                                DataCell(Text(
                                    '${t.marjaProfit.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                        fontSize: 12))),
                              ]))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Bar chart profit
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Profit per tip (RON)',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),
                  ..._perTip.take(8).map((t) {
                    final ratio = maxProfit > 0
                        ? (t.profitTotal.abs() / maxProfit)
                            .clamp(0.0, 1.0)
                        : 0.0;
                    final color = t.profitTotal >= 0
                        ? Colors.green
                        : Colors.red;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              t.tip,
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: ratio,
                                  child: Container(
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color:
                                          color.withValues(alpha: 0.75),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                          left: 6),
                                      child: Text(
                                        '${t.profitTotal.toStringAsFixed(0)} RON',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text(
                              ' ${t.nrProgramari}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 1 — Per angajat ──────────────────────────────────────────────────

  Widget _buildPerAngajatTab() {
    if (_perAngajat.isEmpty) {
      return const Center(
          child: Text('Nicio inregistrare in perioada selectata.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _perAngajat.length,
      itemBuilder: (_, i) {
        final a = _perAngajat[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(a.angajatNume,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                    ),
                    Text('${a.nrProgramari} prog.',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _metricChip('Valoare', a.valoareGenerata,
                        Colors.blue),
                    const SizedBox(width: 8),
                    _metricChip('Cost', a.costAngajat, Colors.orange),
                    const SizedBox(width: 8),
                    _metricChip(
                        'Profit',
                        a.profit,
                        a.profit >= 0 ? Colors.green : Colors.red),
                  ],
                ),
                if (a.costAngajat > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'ROI: ${a.roi.toStringAsFixed(1)}%',
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              a.roi >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metricChip(String label, double val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(
            '${val.toStringAsFixed(0)} RON',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color),
          ),
        ],
      ),
    );
  }
}

class DateRange {
  const DateRange(this.from, this.to);
  final DateTime from;
  final DateTime to;
}
