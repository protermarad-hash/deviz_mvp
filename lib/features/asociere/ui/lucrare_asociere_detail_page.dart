import 'package:flutter/material.dart';

import '../../../core/cloud/offline_sync_runtime.dart';
import '../../../core/repositories/app_data_repository.dart';
import '../asociere_analytics.dart';
import '../asociere_csv_export_service.dart';
import '../asociere_logistica_repository.dart';
import '../asociere_models.dart';
import '../asociere_repository.dart';
import '../cost_asociere_repository.dart';
import '../decont_lunar_asociere_repository.dart';
import '../lucrare_asociere_models.dart';
import '../pontaj_asociere_repository.dart';
import '../venit_asociere_repository.dart';
import 'asociere_chart_card.dart';
import 'decont_asociere_page.dart';
import 'logistica_asociere_page.dart';
import 'lucrare_asociere_form_page.dart';
import 'personal_tarife_asociere_page.dart';
import 'pontaj_asociere_page.dart';
import 'registru_asociere_page.dart';
import 'tarife_asociere_page.dart';

class LucrareAsociereDetailPage extends StatefulWidget {
  const LucrareAsociereDetailPage({
    super.key,
    required this.project,
    required this.appRepository,
    required this.actorId,
    required this.isAdmin,
    required this.canManage,
    required this.canViewFinancial,
    this.initialTab = 0,
  });
  final LucrareAsociereRecord project;
  final AppDataRepository appRepository;
  final String actorId;
  final bool isAdmin;
  final bool canManage;
  final bool canViewFinancial;
  final int initialTab;
  @override
  State<LucrareAsociereDetailPage> createState() =>
      _LucrareAsociereDetailPageState();
}

class _LucrareAsociereDetailPageState extends State<LucrareAsociereDetailPage>
    with SingleTickerProviderStateMixin {
  late LucrareAsociereRecord _project = widget.project;
  late final TabController _tabs = TabController(
      length: 11, vsync: this, initialIndex: widget.initialTab.clamp(0, 10));
  AsociereRecord? _contract;
  AsociereAnalytics? _analytics;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final contracts =
        await AsociereRepository.instance.listByProject(_project.id);
    final values = await Future.wait([
      PontajAsociereRepository.instance.listByProject(_project.id),
      CostAsociereRepository.instance.listByProject(_project.id),
      VenitAsociereRepository.instance.listByProject(_project.id),
      DeplasareAsociereRepository.instance.listByProject(_project.id),
      DecontLunarAsociereRepository.instance.listByProject(_project.id),
      OfflineSyncRuntime.instance.pendingItemsCount(),
    ]);
    if (!mounted) return;
    setState(() {
      _contract = contracts.firstOrNull;
      _analytics = AsociereAnalytics(
          project: _project,
          pontaje: values[0] as dynamic,
          costuri: values[1] as dynamic,
          venituri: values[2] as dynamic,
          deplasari: values[3] as dynamic,
          deconturi: values[4] as dynamic,
          pendingOperations: values[5] as int);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final contract = _contract;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_project.numar} · ${_project.denumire}'),
          Text(_project.partnerNameSnapshot,
              style: Theme.of(context).textTheme.bodySmall)
        ]),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Exporturi',
            icon: const Icon(Icons.download_outlined),
            onSelected: _export,
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'registru', child: Text('Export Registru CSV')),
              PopupMenuItem(value: 'decont', child: Text('Export Decont CSV')),
              PopupMenuItem(
                  value: 'pontaje', child: Text('Export Pontaje CSV')),
              PopupMenuItem(
                  value: 'deplasari', child: Text('Export Deplasări CSV')),
            ],
          ),
          if (widget.canManage)
            IconButton(
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editează proiectul'),
        ],
        bottom: TabBar(controller: _tabs, isScrollable: true, tabs: const [
          Tab(text: 'Rezumat'),
          Tab(text: 'Configurare'),
          Tab(text: 'Pontaje'),
          Tab(text: 'Deplasări'),
          Tab(text: 'Costuri'),
          Tab(text: 'Venituri'),
          Tab(text: 'Registru'),
          Tab(text: 'Deconturi'),
          Tab(text: 'Documente'),
          Tab(text: 'Activitate'),
          Tab(text: 'Personal & tarife'),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : contract == null
              ? const Center(
                  child: Text(
                      'Configurația contractuală lipsește. Editează și salvează proiectul pentru a o crea.'))
              : TabBarView(controller: _tabs, children: [
                  _summary(),
                  _configuration(contract),
                  PontajAsocierePage(
                      projectId: _project.id,
                      contractId: contract.id,
                      appRepository: widget.appRepository,
                      actorId: widget.actorId,
                      canEdit: widget.canManage,
                      canRegisterExternalConfirmation: widget.isAdmin,
                      canViewFinancial: widget.canViewFinancial,
                      canConfigureRates: widget.isAdmin,
                      onOpenTarife: () => _tabs.animateTo(10)),
                  LogisticaAsocierePage(
                      projectId: _project.id,
                      actorId: widget.actorId,
                      canEdit: widget.canManage),
                  widget.canViewFinancial
                      ? RegistruAsocierePage(
                          projectId: _project.id,
                          contractId: contract.id,
                          actorId: widget.actorId,
                          canEdit: widget.canManage,
                          canApprove: widget.isAdmin,
                          initialMode: 'costuri')
                      : _restricted(),
                  widget.canViewFinancial
                      ? RegistruAsocierePage(
                          projectId: _project.id,
                          contractId: contract.id,
                          actorId: widget.actorId,
                          canEdit: widget.canManage,
                          canApprove: false,
                          initialMode: 'venituri')
                      : _restricted(),
                  widget.canViewFinancial
                      ? RegistruAsocierePage(
                          projectId: _project.id,
                          contractId: contract.id,
                          actorId: widget.actorId,
                          canEdit: widget.canManage,
                          canApprove: widget.isAdmin)
                      : _restricted(),
                  widget.canViewFinancial
                      ? DecontAsocierePage(
                          projectId: _project.id,
                          contractId: contract.id,
                          actorId: widget.actorId,
                          canConfirm: widget.isAdmin)
                      : _restricted(),
                  _documents(),
                  _activity(),
                  PersonalTarifeAsocierePage(
                      projectId: _project.id,
                      contractId: contract.id,
                      appRepository: widget.appRepository,
                      canConfigureRates: widget.isAdmin,
                      canViewFinancial: widget.canViewFinancial),
                ]),
    );
  }

  Widget _summary() {
    final data = _analytics!;
    final cards = <(String, double)>[
      ('Valoare proiect', _project.valoareContractuala),
      ('Facturat', data.venitFacturat),
      ('Încasat', data.venitIncasat),
      ('Cost aprobat', data.costAprobat),
      ('Cost în așteptare', data.costInAsteptare),
      ('Profit/pierdere', data.rezultat),
      ('Ore', data.ore),
      ('Kilometri', data.kilometri),
      ('Logistică', data.logistic),
    ];
    return RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          if (data.alerts.isNotEmpty)
            ...data.alerts.map((alert) => Card(
                color: alert.severity == AsociereAlertSeverity.critical
                    ? Theme.of(context).colorScheme.errorContainer
                    : null,
                child: ListTile(
                    leading: const Icon(Icons.warning_amber),
                    title: Text(alert.explanation),
                    trailing: TextButton(
                        onPressed: () => _openAlert(alert.route),
                        child: Text(alert.action))))),
          GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 95,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8),
              itemCount: cards.length,
              itemBuilder: (_, i) => Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cards[i].$1),
                            const Spacer(),
                            Text(
                                '${cards[i].$2.toStringAsFixed(2)} ${cards[i].$1 == 'Ore' || cards[i].$1 == 'Kilometri' ? '' : _project.moneda}',
                                style: Theme.of(context).textTheme.titleMedium)
                          ])))),
          const SizedBox(height: 12),
          _chart(
              'Estimat versus realizat',
              data.estimatVersusRealizat.entries
                  .map((e) => AsociereChartSeries(e.key, e.value,
                      e.key.endsWith('realizat') ? Colors.green : Colors.blue))
                  .toList()),
          _chart(
              'Evoluție lunară',
              data.evolutieLunara.entries
                  .map((e) => AsociereChartSeries(
                      e.key,
                      e.value,
                      e.key.endsWith('cost')
                          ? Colors.red
                          : e.key.endsWith('încasat')
                              ? Colors.green
                              : Colors.blue))
                  .toList()),
          _chart(
              'Costuri pe asociat',
              data.costuriPeAsociat.entries
                  .map(
                      (e) => AsociereChartSeries(e.key, e.value, Colors.orange))
                  .toList()),
          _chart(
              'Costuri pe categorie',
              data.costuriPeCategorie.entries
                  .map(
                      (e) => AsociereChartSeries(e.key, e.value, Colors.purple))
                  .toList()),
          _chart(
              'Ore lucrate pe săptămână',
              data.orePeAsociat.entries
                  .map((e) => AsociereChartSeries(e.key, e.value,
                      e.key == 'PRO TERM' ? Colors.teal : Colors.orange))
                  .toList(),
              unit: 'ore'),
          _chart(
              'Deplasări',
              [
                AsociereChartSeries('Kilometri', data.kilometri, Colors.indigo),
                AsociereChartSeries(
                    'Transport/logistică', data.logistic, Colors.red)
              ],
              unit: _project.moneda),
        ]));
  }

  Widget _chart(String title, List<AsociereChartSeries> series,
          {String? unit}) =>
      AsociereChartCard(
          title: title, series: series, unit: unit ?? _project.moneda);
  Widget _configuration(AsociereRecord contract) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const ListTile(
            leading: Icon(Icons.business),
            title: Text('Părți'),
            subtitle: Text('PRO TERM + un singur Partener')),
        ListTile(
            title: const Text('Cote'),
            subtitle: Text(
                'PRO TERM ${contract.cotaProTerm}% · Partener ${contract.cotaPartener}%')),
        ListTile(
            title: const Text('Facturează beneficiarul'),
            subtitle: Text(contract.cineFactureazaBeneficiarul.label)),
        ListTile(
            title: const Text('Rezervă / garanție'),
            subtitle: Text(
                '${contract.procentRezervaGarantie}% · ${contract.durataGarantieLuni} luni')),
        if (widget.isAdmin)
          SizedBox(
              height: 520,
              child: TarifeAsocierePage(
                  projectId: _project.id,
                  contractId: contract.id,
                  canEdit: true)),
      ]);
  Widget _documents() => const Center(
      child: Text(
          'Documentele proiectului folosesc infrastructura generică; atașarea nu copiază automat aprobări sau documente.'));
  Widget _activity() => Center(
      child: Text(
          'Revizie proiect ${_project.revision} · actualizat ${_project.updatedAt.toLocal()} · operații pending ${_analytics?.pendingOperations ?? 0}'));
  Widget _restricted() => const Center(
      child: Text(
          'Rolul curent nu are acces la datele financiare ale Asocierii.'));

  void _openAlert(String route) {
    final index = {
      'rezumat': 0,
      'configurare': 1,
      'pontaje': 2,
      'deplasari': 3,
      'costuri': 4,
      'venituri': 5,
      'registru': 6,
      'deconturi': 7,
      'documente': 8,
      'activitate': 9
    }[route];
    if (index != null) _tabs.animateTo(index);
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<LucrareAsociereRecord>(
        MaterialPageRoute(
            builder: (_) => LucrareAsociereFormPage(
                appRepository: widget.appRepository,
                actorId: widget.actorId,
                initial: _project)));
    if (updated != null) {
      setState(() {
        _project = updated;
        _loading = true;
      });
      await _load();
    }
  }

  Future<void> _export(String type) async {
    if (!widget.canViewFinancial && (type == 'registru' || type == 'decont')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Rolul curent nu poate exporta date financiare.')));
      return;
    }
    try {
      switch (type) {
        case 'registru':
          await AsociereCsvExportService.exportRegistru(_project.id);
        case 'decont':
          await AsociereCsvExportService.exportDecont(_project.id);
        case 'pontaje':
          await AsociereCsvExportService.exportPontaje(_project.id);
        case 'deplasari':
          await AsociereCsvExportService.exportDeplasari(_project.id);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export eșuat: $error')));
      }
    }
  }
}
