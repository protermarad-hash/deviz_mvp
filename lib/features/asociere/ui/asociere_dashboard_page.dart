import 'package:flutter/material.dart';

import '../../../core/cloud/offline_sync_runtime.dart';
import '../asociere_analytics.dart';
import '../pontaj_asociere_models.dart';
import '../cost_asociere_models.dart';
import '../venit_asociere_models.dart';
import '../deplasare_asociere_models.dart';
import '../decont_lunar_asociere_models.dart';
import '../asociere_logistica_repository.dart';
import '../cost_asociere_repository.dart';
import '../decont_lunar_asociere_repository.dart';
import '../lucrare_asociere_cloud_repository.dart';
import '../lucrare_asociere_models.dart';
import '../pontaj_asociere_repository.dart';
import '../venit_asociere_repository.dart';

class AsociereDashboardPage extends StatefulWidget {
  const AsociereDashboardPage({
    super.key,
    required this.onQuickAction,
    required this.canViewFinancial,
  });
  final ValueChanged<String> onQuickAction;
  final bool canViewFinancial;

  @override
  State<AsociereDashboardPage> createState() => _AsociereDashboardPageState();
}

class _AsociereDashboardPageState extends State<AsociereDashboardPage> {
  bool _loading = true;
  String? _error;
  List<LucrareAsociereRecord> _projects = const [];
  List<AsociereAnalytics> _analytics = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        LucrareAsociereCloudRepository.instance
            .listMerged(includeFinancial: widget.canViewFinancial),
        PontajAsociereRepository.instance.listMerged(),
        widget.canViewFinancial
            ? CostAsociereRepository.instance.listMerged()
            : Future.value(<CostAsociereRecord>[]),
        widget.canViewFinancial
            ? VenitAsociereRepository.instance.listMerged()
            : Future.value(<VenitAsociereRecord>[]),
        DeplasareAsociereRepository.instance.listMerged(),
        widget.canViewFinancial
            ? DecontLunarAsociereRepository.instance.listMerged()
            : Future.value(<DecontLunarAsociereRecord>[]),
        OfflineSyncRuntime.instance.pendingItemsCount(),
      ]);
      final projects = values[0] as List<LucrareAsociereRecord>;
      final pontaje = values[1] as List<PontajAsociereRecord>;
      final costuri = values[2] as List<CostAsociereRecord>;
      final venituri = values[3] as List<VenitAsociereRecord>;
      final deplasari = values[4] as List<DeplasareAsociereRecord>;
      final deconturi = values[5] as List<DecontLunarAsociereRecord>;
      final pending = values[6] as int;
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _analytics = projects
            .map((project) => AsociereAnalytics(
                  project: project,
                  pontaje: pontaje
                      .where((item) => item.projectId == project.id)
                      .toList(),
                  costuri: costuri
                      .where((item) => item.projectId == project.id)
                      .toList(),
                  venituri: venituri
                      .where((item) => item.projectId == project.id)
                      .toList(),
                  deplasari: deplasari
                      .where((item) => item.projectId == project.id)
                      .toList(),
                  deconturi: deconturi
                      .where((item) => item.projectId == project.id)
                      .toList(),
                  pendingOperations: pending,
                ))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  double _sum(double Function(AsociereAnalytics) read) =>
      _analytics.fold(0, (sum, item) => sum + read(item));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('Dashboard indisponibil: $_error'));
    }
    final active =
        _projects.where((item) => item.active && !item.arhivat).length;
    final delayed = _projects.where((item) => item.esteIntarziata).length;
    final noRecentActivity = _projects
        .where((item) => DateTime.now().difference(item.updatedAt).inDays > 14)
        .length;
    final alerts =
        _analytics.fold<int>(0, (sum, item) => sum + item.alerts.length);
    final cards = <(String, String, IconData)>[
      ('Proiecte active', '$active', Icons.handshake_outlined),
      ('Proiecte întârziate', '$delayed', Icons.event_busy_outlined),
      (
        'Fără activitate recentă',
        '$noRecentActivity',
        Icons.history_toggle_off
      ),
      (
        'Valoare contractuală',
        _money(
            _projects.fold(0, (sum, item) => sum + item.valoareContractuala)),
        Icons.request_quote_outlined
      ),
      (
        'Venit facturat',
        _money(_sum((item) => item.venitFacturat)),
        Icons.receipt_long_outlined
      ),
      (
        'Venit încasat',
        _money(_sum((item) => item.venitIncasat)),
        Icons.payments_outlined
      ),
      (
        'Costuri aprobate',
        _money(_sum((item) => item.costAprobat)),
        Icons.task_alt_outlined
      ),
      (
        'Costuri în așteptare',
        _money(_sum((item) => item.costInAsteptare)),
        Icons.pending_actions_outlined
      ),
      (
        'Rezultat estimat',
        _money(_sum((item) => item.rezultat)),
        Icons.trending_up_outlined
      ),
      (
        'Deconturi de confirmat',
        '${_analytics.fold<int>(0, (sum, item) => sum + item.deconturiDeConfirmat)}',
        Icons.fact_check_outlined
      ),
      ('Documente/alerte', '$alerts', Icons.warning_amber_outlined),
      (
        'Deplasări active',
        '${_analytics.fold<int>(0, (sum, item) => sum + item.deplasari.length)}',
        Icons.route_outlined
      ),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Dashboard Asociere',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisExtent: 112,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return Card(
                  child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(card.$3),
                            const Spacer(),
                            Text(card.$2,
                                style: Theme.of(context).textTheme.titleLarge),
                            Text(card.$1,
                                maxLines: 1, overflow: TextOverflow.ellipsis)
                          ])));
            },
          ),
          const SizedBox(height: 16),
          Text('Acțiuni rapide',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _action('Proiect nou', 'proiect_nou', Icons.add_business),
            _action('Pontaj nou', 'pontaje', Icons.timer_outlined),
            _action('Cost nou', 'costuri', Icons.shopping_cart_outlined),
            _action('Deplasare nouă', 'deplasari', Icons.route_outlined),
            _action('Venit nou', 'venituri', Icons.payments_outlined),
            _action('Registru', 'registru', Icons.menu_book_outlined),
            _action('Decont', 'deconturi', Icons.fact_check_outlined),
          ]),
        ],
      ),
    );
  }

  String _money(double value) => '${value.toStringAsFixed(2)} RON';
  Widget _action(String label, String id, IconData icon) => ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: () => widget.onQuickAction(id),
      );
}
