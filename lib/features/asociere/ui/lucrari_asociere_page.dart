import 'package:flutter/material.dart';

import '../../../core/cloud/firebase_bootstrap.dart';
import '../../../core/cloud/offline_sync_runtime.dart';
import '../../../core/repositories/app_data_repository.dart';
import '../lucrare_asociere_cloud_repository.dart';
import '../lucrare_asociere_local_store.dart';
import '../lucrare_asociere_models.dart';
import '../lucrare_asociere_cloud_projection.dart';
import '../asociere_models.dart';
import '../asociere_repository.dart';
import 'asociere_string_autocomplete.dart';
import 'lucrare_asociere_form_page.dart';

class LucrariAsocierePage extends StatefulWidget {
  const LucrariAsocierePage({
    super.key,
    required this.appRepository,
    required this.actorId,
    required this.onOpen,
    required this.canManage,
    required this.canArchive,
    required this.canViewFinancial,
  });

  final AppDataRepository appRepository;
  final String actorId;
  final ValueChanged<LucrareAsociereRecord> onOpen;
  final bool canManage;
  final bool canArchive;
  final bool canViewFinancial;

  @override
  State<LucrariAsocierePage> createState() => _LucrariAsocierePageState();
}

class _LucrariAsocierePageState extends State<LucrariAsocierePage> {
  List<LucrareAsociereRecord> _items = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _status = '';
  String _client = '';
  String _partner = '';
  String _manager = '';
  bool _archived = false;
  bool _descending = true;
  int _pending = 0;
  final _queryController = TextEditingController();
  final _localStore = const LucrareAsociereLocalStore();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final filters = await _localStore.loadFilters();
    _query = '${filters['query'] ?? ''}';
    _status = '${filters['status'] ?? ''}';
    _client = '${filters['client'] ?? ''}';
    _partner = '${filters['partner'] ?? ''}';
    _manager = '${filters['manager'] ?? ''}';
    _archived = filters['archived'] == true;
    _descending = filters['descending'] != false;
    _queryController.text = _query;
    await _load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _saveFilters() => _localStore.saveFilters({
        'query': _query,
        'status': _status,
        'client': _client,
        'partner': _partner,
        'manager': _manager,
        'archived': _archived,
        'descending': _descending,
      });

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final localRaw =
          await LucrareAsociereCloudRepository.instance.listLocal();
      final local = widget.canViewFinancial
          ? localRaw
          : localRaw.map((item) => item.withoutFinancialData()).toList();
      if (mounted) setState(() => _items = local);
      final values = await Future.wait([
        LucrareAsociereCloudRepository.instance
            .listMerged(includeFinancial: widget.canViewFinancial),
        OfflineSyncRuntime.instance.pendingItemsCount(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = values[0] as List<LucrareAsociereRecord>;
        _pending = values[1] as int;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<LucrareAsociereRecord> get _visible {
    final status =
        _status.isEmpty ? null : LucrareAsociereStatus.fromValue(_status);
    final values = LucrareAsociereCloudRepository.instance.search(
      _items,
      query: _query,
      status: status,
      clientId: _idForSnapshot(
          _client, (item) => item.clientNameSnapshot, (item) => item.clientId),
      partnerId: _idForSnapshot(_partner, (item) => item.partnerNameSnapshot,
          (item) => item.partnerId),
      managerId: _idForSnapshot(_manager, (item) => item.managerNameSnapshot,
          (item) => item.managerId),
      includeArchived: _archived,
    );
    values.sort((a, b) => _descending
        ? b.updatedAt.compareTo(a.updatedAt)
        : a.updatedAt.compareTo(b.updatedAt));
    return values;
  }

  String _idForSnapshot(
      String value,
      String Function(LucrareAsociereRecord) name,
      String Function(LucrareAsociereRecord) id) {
    if (value.isEmpty) return '';
    for (final item in _items) {
      if (name(item).toLowerCase() == value.toLowerCase()) return id(item);
    }
    return '__missing__';
  }

  @override
  Widget build(BuildContext context) {
    final values = _visible;
    return Scaffold(
      floatingActionButton: widget.canManage
          ? FloatingActionButton.extended(
              heroTag: 'asociere_project_new',
              onPressed: _newProject,
              icon: const Icon(Icons.add),
              label: const Text('Proiect nou'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _filters()),
          if (_error != null)
            SliverToBoxAdapter(child: _errorBanner())
          else if (_loading && _items.isEmpty)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else if (values.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.handshake_outlined, size: 56),
                  const SizedBox(height: 12),
                  const Text(
                      'Nu există proiecte Asociere pentru filtrele curente.'),
                  const SizedBox(height: 12),
                  if (widget.canManage)
                    FilledButton.icon(
                        onPressed: _newProject,
                        icon: const Icon(Icons.add),
                        label: const Text('Creează proiect')),
                ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
              sliver: SliverList.builder(
                itemCount: values.length,
                itemBuilder: (context, index) => _projectCard(values[index]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _filters() {
    List<String> unique<T>(T Function(LucrareAsociereRecord) read) => _items
        .map(read)
        .where((value) => '$value'.trim().isNotEmpty)
        .map((e) => '$e')
        .toSet()
        .toList()
      ..sort();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        TextField(
          controller: _queryController,
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Caută număr, denumire, client sau partener',
              border: OutlineInputBorder()),
          onChanged: (value) {
            setState(() => _query = value);
            _saveFilters();
          },
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(
              width: 190,
              child: AsociereStringAutocomplete(
                  label: 'Status',
                  optiuni: [
                    '',
                    ...LucrareAsociereStatus.values.map((item) => item.value)
                  ],
                  value: _status,
                  onChanged: (value) {
                    setState(() => _status = value);
                    _saveFilters();
                  })),
          SizedBox(
              width: 220,
              child: AsociereStringAutocomplete(
                  label: 'Client',
                  optiuni: unique((item) => item.clientNameSnapshot),
                  value: _client,
                  onChanged: (value) {
                    setState(() => _client = value);
                    _saveFilters();
                  })),
          SizedBox(
              width: 220,
              child: AsociereStringAutocomplete(
                  label: 'Partener',
                  optiuni: unique((item) => item.partnerNameSnapshot),
                  value: _partner,
                  onChanged: (value) {
                    setState(() => _partner = value);
                    _saveFilters();
                  })),
          SizedBox(
              width: 220,
              child: AsociereStringAutocomplete(
                  label: 'Manager',
                  optiuni: unique((item) => item.managerNameSnapshot),
                  value: _manager,
                  onChanged: (value) {
                    setState(() => _manager = value);
                    _saveFilters();
                  })),
          FilterChip(
              label: const Text('Include arhivate'),
              selected: _archived,
              onSelected: (value) {
                setState(() => _archived = value);
                _saveFilters();
              }),
          ActionChip(
              avatar:
                  Icon(_descending ? Icons.arrow_downward : Icons.arrow_upward),
              label: const Text('Sortare actualizare'),
              onPressed: () {
                setState(() => _descending = !_descending);
                _saveFilters();
              }),
        ]),
        const SizedBox(height: 8),
        ValueListenableBuilder<bool>(
          valueListenable: FirebaseBootstrap.onlineNotifier,
          builder: (context, online, _) => Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                  size: 18,
                ),
                Text(online ? 'Online' : 'Offline'),
                if (OfflineSyncRuntime.instance.isSyncing)
                  const Chip(label: Text('Sincronizare')),
                if (_pending > 0)
                  Chip(label: Text('$_pending operații în așteptare')),
                Text('Ultima sincronizare: ${_syncLabel()}'),
                if (_pending > 0 ||
                    OfflineSyncRuntime.instance.lastSyncError != null)
                  TextButton.icon(
                    onPressed: _retrySync,
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Retry'),
                  ),
                if (OfflineSyncRuntime.instance.lastSyncError != null)
                  const Tooltip(
                    message:
                        'Există o operație nesincronizată. Datele locale au fost păstrate.',
                    child: Icon(Icons.error_outline, color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  String _syncLabel() {
    final runtimeValue = OfflineSyncRuntime.instance.lastSyncFinishedAt;
    final repositoryValue = LucrareAsociereCloudRepository.lastSyncAt;
    final value = runtimeValue == null ||
            (repositoryValue != null && repositoryValue.isAfter(runtimeValue))
        ? repositoryValue
        : runtimeValue;
    if (value == null) return 'neefectuată';
    return '${value.day}.${value.month}.${value.year} ${value.hour}:${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _retrySync() async {
    await FirebaseBootstrap.checkOnline();
    if (FirebaseBootstrap.isOnline) {
      await OfflineSyncRuntime.instance.syncPending(force: true);
    }
    await _load();
  }

  Widget _projectCard(LucrareAsociereRecord item) => Card(
        child: InkWell(
          onTap: () => widget.onOpen(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text('${item.numar} · ${item.denumire}',
                        style: Theme.of(context).textTheme.titleMedium)),
                Chip(label: Text(item.status.label)),
                if (widget.canManage)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'duplicate') _duplicate(item);
                      if (value == 'archive') _archive(item);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'duplicate',
                          child: Text('Duplică drept draft')),
                      if (widget.canArchive)
                        const PopupMenuItem(
                            value: 'archive', child: Text('Arhivează')),
                    ],
                  ),
              ]),
              Text(
                  '${item.clientNameSnapshot.isEmpty ? 'Client nespecificat' : item.clientNameSnapshot} · ${item.partnerNameSnapshot}'),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: item.progres),
              const SizedBox(height: 8),
              Wrap(spacing: 16, children: [
                if (widget.canViewFinancial)
                  Text(
                      '${item.valoareContractuala.toStringAsFixed(2)} ${item.moneda}'),
                Text(
                    'Perioadă: ${item.dataInceput.day}.${item.dataInceput.month}.${item.dataInceput.year}${item.termenEstimat == null ? '' : ' – ${item.termenEstimat!.day}.${item.termenEstimat!.month}.${item.termenEstimat!.year}'}'),
                if (item.esteIntarziata)
                  const Text('⚠ Termen depășit',
                      style: TextStyle(color: Colors.red)),
              ]),
            ]),
          ),
        ),
      );

  Widget _errorBanner() => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: const Text('Încărcarea proiectelor a eșuat'),
          subtitle: Text(_error!),
          trailing:
              TextButton(onPressed: _load, child: const Text('Reîncearcă')),
        ),
      );

  Future<void> _newProject() async {
    final result = await Navigator.of(context).push<LucrareAsociereRecord>(
      MaterialPageRoute(
          builder: (_) => LucrareAsociereFormPage(
              appRepository: widget.appRepository, actorId: widget.actorId)),
    );
    if (result != null) {
      await _load();
      widget.onOpen(result);
    }
  }

  Future<void> _duplicate(LucrareAsociereRecord source) async {
    final now = DateTime.now();
    final clone = LucrareAsociereRecord.fromMap(source.toMap()
      ..addAll({
        'id': 'la_${now.microsecondsSinceEpoch}',
        'numar': '${source.numar}-COPIE',
        'status': LucrareAsociereStatus.draft.value,
        'data_finalizare': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'created_by': widget.actorId,
        'updated_by': widget.actorId,
        'revision': 1,
        'active': true,
        'arhivat': false,
      }));
    try {
      await LucrareAsociereCloudRepository.instance.create(clone);
      final contracts =
          await AsociereRepository.instance.listByProject(source.id);
      final contract = contracts.firstOrNull;
      if (contract != null) {
        await AsociereRepository.instance.upsertAsociere(
          AsociereRecord.fromMap(contract.toMap()
            ..addAll({
              'id': 'contract_${clone.id}',
              'lucrare_asociere_id': clone.id,
              'status': AsociereStatus.activa.value,
              'data_receptie_finala': null,
              'created_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
              'created_by': widget.actorId,
              'updated_by': widget.actorId,
              'revision': 1,
            })),
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _archive(LucrareAsociereRecord item) async {
    await LucrareAsociereCloudRepository.instance
        .archive(item.id, actor: widget.actorId);
    await _load();
  }
}
