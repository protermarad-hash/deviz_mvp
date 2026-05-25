import 'package:flutter/material.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/document_file_service.dart';
import '../../core/repositories/app_data_repository.dart';
import '../../core/repositories/local_app_data_repository.dart';
import '../../core/widgets/adaptive_side_panel_layout.dart';
import 'registry_models.dart';
import 'registry_store.dart';
import '../../core/widgets/help_button.dart';
import '../../core/help_content.dart';

class RegistraturaDashboardPage extends StatefulWidget {
  const RegistraturaDashboardPage({
    super.key,
    required this.repository,
  });

  final AppDataRepository repository;

  @override
  State<RegistraturaDashboardPage> createState() =>
      _RegistraturaDashboardPageState();
}

class _RegistraturaDashboardPageState extends State<RegistraturaDashboardPage> {
  static const List<String> _canonicalTypeOrder = <String>[
    'contract',
    'deviz',
    'oferta',
    'pv',
    'pif',
    'raport_lucrare',
  ];
  static const Set<String> _knownDocumentTypes = <String>{
    'contract',
    'deviz',
    'oferta',
    'pv',
    'pif',
    'raport_lucrare',
  };

  final TextEditingController _searchController = TextEditingController();
  final Map<String, TextEditingController> _seriesControllers = {
    for (final type in RegistryDocumentSeriesCatalog.configurableTypes)
      type: TextEditingController(),
  };
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _savingSettings = false;
  String _typeFilter = 'all';
  String _dataSourceLabel = 'local_cache';
  String _fallbackReason = '';
  RegistrySettings _registrySettings = const RegistrySettings();

  @override
  void initState() {
    super.initState();
    FirebaseBootstrap.onlineNotifier.addListener(_onOnlineChanged);
    Future.microtask(_load);
  }

  void _onOnlineChanged() {
    if (FirebaseBootstrap.onlineNotifier.value && _rows.isEmpty && !_loading) {
      _load();
    }
  }

  @override
  void dispose() {
    FirebaseBootstrap.onlineNotifier.removeListener(_onOnlineChanged);
    _searchController.dispose();
    for (final controller in _seriesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final settingsFuture = widget.repository.loadRegistrySettings().catchError(
          (_) => const RegistrySettings(),
        );
    try {
      final entries = await widget.repository.listRegistryEntries();
      final rows = entries.map(_rowFromEntry).toList(growable: false);
      var dataSourceLabel = 'cloud';
      var fallbackReason = '';
      final repository = widget.repository;
      if (repository is LocalAppDataRepository) {
        dataSourceLabel = repository.lastRegistryDataSourceLabel;
        fallbackReason = repository.lastRegistryFallbackReason;
      }
      if (!mounted) {
        return;
      }
      final settings = await settingsFuture;
      _applySeriesSettings(settings);
      setState(() {
        _rows = rows;
        _loading = false;
        _dataSourceLabel = dataSourceLabel;
        _fallbackReason = fallbackReason;
        _registrySettings = settings;
      });
      return;
    } catch (error) {
      await RegistryStore.syncKnownDocumentSources();
      final rows = await RegistryStore.readEntries();
      if (!mounted) {
        return;
      }
      final settings = await settingsFuture;
      _applySeriesSettings(settings);
      setState(() {
        _rows = rows;
        _loading = false;
        _dataSourceLabel = 'local_cache';
        _fallbackReason = error.toString();
        _registrySettings = settings;
      });
      return;
    }
  }

  void _applySeriesSettings(RegistrySettings settings) {
    for (final type in RegistryDocumentSeriesCatalog.configurableTypes) {
      _seriesControllers[type]?.text = settings.seriesPrefixFor(type);
    }
  }

  Future<void> _saveSeriesSettings() async {
    setState(() => _savingSettings = true);
    try {
      final prefixes = <String, String>{
        for (final type in RegistryDocumentSeriesCatalog.configurableTypes)
          if ((_seriesControllers[type]?.text.trim() ?? '').isNotEmpty)
            type: _seriesControllers[type]!.text.trim().toUpperCase(),
      };
      final nextSettings = _registrySettings.copyWith(
        documentSeriesPrefixes: prefixes,
      );
      await widget.repository.saveRegistrySettings(nextSettings);
      if (!mounted) {
        return;
      }
      setState(() => _registrySettings = nextSettings);
      _snack('Seriile documentelor au fost salvate.');
    } finally {
      if (mounted) {
        setState(() => _savingSettings = false);
      }
    }
  }

  Map<String, dynamic> _rowFromEntry(RegistryEntry entry) {
    final displayNumber = entry.registryNumber.trim().isNotEmpty
        ? entry.registryNumber.trim()
        : entry.documentNumber.trim();
    final documentDate =
        entry.documentDate?.toIso8601String().split('T').first ?? '';
    final registeredDate =
        entry.registeredAt.toIso8601String().split('T').first;
    return <String, dynamic>{
      'id': entry.id,
      'type': RegistryStore.normalizeDocumentTypeUi(entry.documentCategory),
      'source': entry.documentCategory,
      'number': displayNumber,
      'documentNumber': entry.documentNumber.trim(),
      'date': documentDate.isEmpty ? registeredDate : documentDate,
      'title': entry.documentTitle,
      'client': entry.recipientName.trim().isNotEmpty
          ? entry.recipientName.trim()
          : entry.issuerName.trim(),
      'jobCode': entry.jobId.trim(),
      'jobId': entry.jobId.trim(),
      'status': entry.status,
      'filePath': entry.filePath,
      'referenceId': entry.id,
    };
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openByFilePath(String path) async {
    final result = await DocumentFileService.openFile(path);
    _snack(result.message);
    if (result.shouldOfferShare) {
      try {
        await DocumentFileService.shareFile(
          path,
          subject: 'Document registratura',
          text: 'Document registratura generat din aplicatie.',
        );
        _snack('Share deschis.');
      } catch (_) {
        _snack('Nu am putut deschide meniul Share.');
      }
    }
  }

  Future<void> _onOpenRow(Map<String, dynamic> row) async {
    final route = '${row['sourceRoute'] ?? ''}'.trim();
    if (route.isNotEmpty) {
      try {
        await Navigator.of(context).pushNamed(
          route,
          arguments: row['sourceArgs'],
        );
        return;
      } catch (_) {}
    }
    final path = '${row['filePath'] ?? ''}'.trim();
    if (path.isNotEmpty) {
      await _openByFilePath(path);
      return;
    }
    _snack('Nu există o referință validă pentru deschidere.');
  }

  List<Map<String, dynamic>> get _visibleRows {
    final query = _searchController.text.trim().toLowerCase();
    return _rows.where((row) {
      final type = _rowTypeCanonical(row);
      if (_typeFilter != 'all' && type != _typeFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final number = '${row['number'] ?? ''}'.toLowerCase();
      final title = '${row['title'] ?? ''}'.toLowerCase();
      final client = '${row['client'] ?? ''}'.toLowerCase();
      return number.contains(query) ||
          title.contains(query) ||
          client.contains(query);
    }).toList(growable: false);
  }

  List<String> get _typeOptions {
    final set = <String>{'all', ..._canonicalTypeOrder};
    for (final row in _rows) {
      final type = _rowTypeCanonical(row);
      if (type.isNotEmpty) {
        set.add(type);
      }
    }
    final ordered = <String>['all'];
    for (final type in _canonicalTypeOrder) {
      if (set.contains(type)) {
        ordered.add(type);
      }
    }
    final extras = set
        .where(
          (type) => type != 'all' && !_canonicalTypeOrder.contains(type.trim()),
        )
        .toList(growable: false)
      ..sort();
    ordered.addAll(extras);
    return ordered;
  }

  String _formatType(String type) {
    if (type == 'all') {
      return 'Toate tipurile';
    }
    if (type == 'pv') {
      return 'PV';
    }
    if (type == 'raport_lucrare') {
      return 'Raport lucrare';
    }
    return RegistryStore.documentTypeLabelUi(type);
  }

  String _canonicalTypeFromNumber(String numberRaw) {
    final number = numberRaw.trim().toUpperCase();
    if (number.startsWith('CT-')) return 'contract';
    if (number.startsWith('DV-')) return 'deviz';
    if (number.startsWith('OF-')) return 'oferta';
    if (number.startsWith('PV-')) return 'pv';
    if (number.startsWith('PIF-')) return 'pif';
    if (number.startsWith('RAP-')) return 'raport_lucrare';
    return '';
  }

  String _rowTypeCanonical(Map<String, dynamic> row) {
    final fromType = RegistryStore.normalizeDocumentTypeUi(row['type']);
    if (_knownDocumentTypes.contains(fromType)) {
      return fromType;
    }
    final fromSource = RegistryStore.normalizeDocumentTypeUi(row['source']);
    if (_knownDocumentTypes.contains(fromSource)) {
      return fromSource;
    }
    final legacyType = RegistryStore.normalizeDocumentType(row['type']);
    if (legacyType == 'process_verbal') {
      return 'pv';
    }
    if (_knownDocumentTypes.contains(legacyType)) {
      return legacyType;
    }
    final numberType = _canonicalTypeFromNumber(
      '${row['number'] ?? row['numarDocument'] ?? ''}',
    );
    if (_knownDocumentTypes.contains(numberType)) {
      return numberType;
    }
    return '';
  }

  String _rowTypeLabel(Map<String, dynamic> row) {
    return RegistryStore.documentTypeLabelUi(_rowTypeCanonical(row));
  }

  Widget _summaryChip(String label, String value, {IconData? icon}) {
    return Chip(
      avatar: icon == null ? null : Icon(icon, size: 16),
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildRegistrySidePanel(List<Map<String, dynamic>> rows) {
    final withFiles = rows
        .where((row) => '${row['filePath'] ?? ''}'.trim().isNotEmpty)
        .length;
    final withJobLinks =
        rows.where((row) => '${row['jobCode'] ?? ''}'.trim().isNotEmpty).length;

    return SidePanelCard(
      title: 'Panou Registratura',
      footer: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Reincarca'),
          ),
          TextButton.icon(
            onPressed: () => setState(() {
              _typeFilter = 'all';
              _searchController.clear();
            }),
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Reset filtre'),
          ),
        ],
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          DropdownButtonFormField<String>(
            initialValue:
                _typeOptions.contains(_typeFilter) ? _typeFilter : 'all',
            decoration: const InputDecoration(
              labelText: 'Tip document',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _typeOptions
                .map(
                  (type) => DropdownMenuItem<String>(
                    value: type,
                    child: Text(_formatType(type)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              setState(() => _typeFilter = value ?? 'all');
            },
          ),
          const SizedBox(height: 12),
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Cauta dupa numar, client, titlu',
              border: OutlineInputBorder(),
              isDense: true,
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(
                'Total filtrate',
                rows.length.toString(),
                icon: Icons.inventory_2_outlined,
              ),
              _summaryChip(
                'Cu fisier',
                withFiles.toString(),
                icon: Icons.attach_file_outlined,
              ),
              _summaryChip(
                'Cu lucrare',
                withJobLinks.toString(),
                icon: Icons.assignment_outlined,
              ),
              Chip(
                label: Text('Sursa date: $_dataSourceLabel'),
                visualDensity: VisualDensity.compact,
              ),
              if (_fallbackReason.trim().isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.cloud_off, size: 16),
                  label: Text('Motiv fallback: $_fallbackReason'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar({required bool showPanelButton}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Registratura',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (showPanelButton)
                Builder(
                  builder: (context) => FilledButton.tonalIcon(
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    icon: const Icon(Icons.tune_outlined),
                    label: const Text('Filtre si panou'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeriesSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Serii documente',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Configureaza prefixele folosite la numerotarea automata. Formatul numeric ramane unitar, iar anul se pastreaza automat pentru documentele care il folosesc deja.',
                ),
                const SizedBox(height: 16),
                for (final type
                    in RegistryDocumentSeriesCatalog.configurableTypes) ...[
                  TextField(
                    controller: _seriesControllers[type],
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: RegistryDocumentSeriesCatalog.label(type),
                      helperText:
                          'Exemplu: ${RegistryDocumentSeriesCatalog.example(type, prefix: _seriesControllers[type]?.text)}',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _savingSettings ? null : _saveSeriesSettings,
                    icon: _savingSettings
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Salveaza seriile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visibleRows;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final showInlineSidePanel = screenWidth >= 1180;
    final sideDrawerWidth = screenWidth >= 900 ? 360.0 : screenWidth * 0.92;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Registratura'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Documente'),
              Tab(text: 'Serii documente'),
            ],
          ),
          actions: [
            HelpButton(content: AppHelp.registratura),
            if (!showInlineSidePanel)
              Builder(
                builder: (context) => IconButton(
                  tooltip: 'Filtre si panou',
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                  icon: const Icon(Icons.tune_outlined),
                ),
              ),
          ],
        ),
        endDrawer: showInlineSidePanel
            ? null
            : Drawer(
                width: sideDrawerWidth,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildRegistrySidePanel(rows),
                  ),
                ),
              ),
        body: TabBarView(
          children: [
            AdaptiveSidePanelLayout(
              showSidePanel: showInlineSidePanel,
              sidePanelWidth: screenWidth >= 1480 ? 372 : 344,
              sidePanel: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                child: _buildRegistrySidePanel(rows),
              ),
              mainContent: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildToolbar(showPanelButton: !showInlineSidePanel),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : rows.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Nu exista documente inregistrate.',
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: rows.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final row = rows[index];
                                    final type = _rowTypeLabel(row);
                                    final number = '${row['number'] ?? '-'}';
                                    final date = '${row['date'] ?? '-'}';
                                    final title = '${row['title'] ?? '-'}';
                                    final client = '${row['client'] ?? '-'}';
                                    final jobCode = '${row['jobCode'] ?? '-'}';
                                    final status = '${row['status'] ?? '-'}';
                                    final path =
                                        '${row['filePath'] ?? ''}'.trim();
                                    final source = '${row['source'] ?? '-'}';
                                    return Card(
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.description_outlined,
                                        ),
                                        title: Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              number,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            Chip(
                                              label: Text(type),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                _summaryChip(
                                                  'Data',
                                                  date,
                                                  icon: Icons.event_outlined,
                                                ),
                                                _summaryChip(
                                                  'Sursa',
                                                  source,
                                                  icon: Icons.hub_outlined,
                                                ),
                                                _summaryChip(
                                                  'Status',
                                                  status,
                                                  icon: Icons.info_outline,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text('Titlu: $title'),
                                            Text('Client: $client'),
                                            Text('Cod lucrare: $jobCode'),
                                            if ('${row['documentNumber'] ?? ''}'
                                                    .trim()
                                                    .isNotEmpty &&
                                                '${row['documentNumber'] ?? ''}'
                                                        .trim() !=
                                                    number)
                                              Text(
                                                'Nr. document: ${row['documentNumber']}',
                                              ),
                                            Text(
                                              'Referinta: ${path.isEmpty ? '-' : path}',
                                            ),
                                          ],
                                        ),
                                        trailing: TextButton.icon(
                                          onPressed: () => _onOpenRow(row),
                                          icon: const Icon(
                                            Icons.open_in_new,
                                            size: 18,
                                          ),
                                          label: const Text('Deschide'),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ),
                ],
              ),
            ),
            _buildSeriesSettingsTab(),
          ],
        ),
      ),
    );
  }
}
