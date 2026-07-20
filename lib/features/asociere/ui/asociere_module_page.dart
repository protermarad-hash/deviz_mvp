import 'package:flutter/material.dart';

import '../../../core/help/help_module_button.dart';
import '../../../core/repositories/app_data_repository.dart';
import '../lucrare_asociere_models.dart';
import '../asociere_access_policy.dart';
import 'asociere_dashboard_page.dart';
import 'lucrare_asociere_detail_page.dart';
import 'lucrare_asociere_form_page.dart';
import 'lucrari_asociere_page.dart';

class AsociereModulePage extends StatefulWidget {
  const AsociereModulePage({
    super.key,
    required this.appRepository,
    required this.roleKey,
    required this.userId,
  });
  final AppDataRepository appRepository;
  final String? roleKey;
  final String? userId;
  @override
  State<AsociereModulePage> createState() => _AsociereModulePageState();
}

class _AsociereModulePageState extends State<AsociereModulePage> {
  static const _sections = <(String, String, IconData)>[
    ('dashboard', 'Dashboard', Icons.dashboard_outlined),
    ('proiecte', 'Proiecte', Icons.handshake_outlined),
    ('proiect_nou', 'Proiect nou', Icons.add_business_outlined),
    ('pontaje', 'Pontaje', Icons.timer_outlined),
    ('deplasari', 'Deplasări', Icons.route_outlined),
    ('costuri', 'Costuri', Icons.shopping_cart_outlined),
    ('venituri', 'Venituri', Icons.payments_outlined),
    ('registru', 'Registru', Icons.menu_book_outlined),
    ('deconturi', 'Deconturi', Icons.fact_check_outlined),
    ('configurari', 'Configurări', Icons.settings_outlined),
  ];
  int _index = 0;
  String get _actor => (widget.userId ?? '').trim().isEmpty
      ? 'local-user'
      : widget.userId!.trim();
  bool get _isAdmin => AsociereAccessPolicy.allows(
      widget.roleKey, AsocierePermission.confirmExternal);
  bool get _canManage => AsociereAccessPolicy.allows(
      widget.roleKey, AsocierePermission.manageProject);
  bool get _canViewFinancial => AsociereAccessPolicy.allows(
      widget.roleKey, AsocierePermission.viewFinancial);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Asocieri'),
          actions: const [HelpModuleButton(moduleId: 'asocieri')]),
      body: wide
          ? Row(children: [
              NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  destinations: _sections
                      .map((item) => NavigationRailDestination(
                          icon: Icon(item.$3), label: Text(item.$2)))
                      .toList()),
              const VerticalDivider(width: 1),
              Expanded(child: _content())
            ])
          : Column(children: [
              SizedBox(
                  height: 58,
                  child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(8),
                      itemCount: _sections.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) => ChoiceChip(
                          avatar: Icon(_sections[i].$3, size: 18),
                          label: Text(_sections[i].$2),
                          selected: i == _index,
                          onSelected: (_) => _select(i)))),
              Expanded(child: _content())
            ]),
    );
  }

  void _select(int value) {
    if (_sections[value].$1 == 'proiect_nou') {
      _new();
      return;
    }
    setState(() => _index = value);
  }

  Widget _content() {
    final id = _sections[_index].$1;
    if (id == 'dashboard') return AsociereDashboardPage(onQuickAction: _quick);
    return LucrariAsocierePage(
        appRepository: widget.appRepository,
        actorId: _actor,
        canManage: _canManage,
        canArchive: AsociereAccessPolicy.allows(
            widget.roleKey, AsocierePermission.archive),
        onOpen: (project) => _open(project, _tabFor(id)));
  }

  int _tabFor(String id) => switch (id) {
        'pontaje' => 2,
        'deplasari' => 3,
        'costuri' => 4,
        'venituri' => 5,
        'registru' => 6,
        'deconturi' => 7,
        'configurari' => 1,
        _ => 0,
      };

  void _quick(String id) {
    if (id == 'proiect_nou') {
      _new();
      return;
    }
    final index = _sections.indexWhere((item) => item.$1 == id);
    if (index >= 0) setState(() => _index = index);
  }

  Future<void> _new() async {
    if (!_canManage) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Rolul curent nu poate crea proiecte Asociere.')));
      return;
    }
    final project = await Navigator.of(context).push<LucrareAsociereRecord>(
        MaterialPageRoute(
            builder: (_) => LucrareAsociereFormPage(
                appRepository: widget.appRepository, actorId: _actor)));
    if (project != null && mounted) _open(project, 0);
  }

  void _open(LucrareAsociereRecord project, int initialTab) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LucrareAsociereDetailPage(
            project: project,
            appRepository: widget.appRepository,
            actorId: _actor,
            isAdmin: _isAdmin,
            canManage: _canManage,
            canViewFinancial: _canViewFinancial,
            initialTab: initialTab)));
  }
}
