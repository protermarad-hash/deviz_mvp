import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/auth/app_role_policy.dart';
import '../../core/help/help_module_button.dart';
import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import '../../core/repositories/app_data_repository.dart';
import '../../core/repositories/local_app_data_repository.dart';
import '../../core/widgets/app_viewport_guard.dart';
import '../../core/widgets/client_info_card.dart';
import '../../core/widgets/client_autocomplete_field.dart';
import '../clients/client_models.dart';
import '../notifications/notification_models.dart';
import '../notifications/notification_service.dart';
import 'firebase_lucrari_repository.dart';
import 'job_models.dart';
import 'lucrare_detalii_page.dart';
import 'lucrari_cloud_repository.dart';

/// Prioritatea de afișare a unei lucrări după status (sortare logică, nu cronologică).
/// Ordinea dorită: În execuție → Planificate → (Noi/Ofertate) →
/// În așteptare/blocate → Anulate (Închise) → Finalizate (ultimele).
int _jobStatusRank(JobStatus status) {
  switch (status) {
    case JobStatus.inExecutie:
      return 0;
    case JobStatus.planificata:
      return 1;
    case JobStatus.noua:
      return 2;
    case JobStatus.ofertata:
      return 3;
    case JobStatus.suspendata:
      return 4;
    case JobStatus.inchisa:
      return 5;
    case JobStatus.finalizata:
      return 6;
  }
}

/// Comparator: întâi după prioritatea statusului, apoi (în cadrul aceluiași
/// status) după dată descrescător (cele mai recente primele).
int _compareJobsByStatus(JobRecord a, JobRecord b) {
  final byStatus = _jobStatusRank(a.status).compareTo(_jobStatusRank(b.status));
  if (byStatus != 0) return byStatus;
  return b.createdAt.compareTo(a.createdAt);
}

class JobsPage extends StatefulWidget {
  const JobsPage({
    super.key,
    required this.repository,
    this.fieldAuthRoleKey,
    this.fieldAuthUserId,
    this.fieldAuthUserLabel,
    this.fieldAuthTeamId,
  });

  final AppDataRepository repository;
  final String? fieldAuthRoleKey;
  final String? fieldAuthUserId;
  final String? fieldAuthUserLabel;
  final String? fieldAuthTeamId;

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  static const Duration _backgroundJobsRefreshCooldown =
      Duration(seconds: 15);
  final TextEditingController _searchController = TextEditingController();
  final NotificationCenterService _notificationService =
      NotificationCenterService();

  bool _isLoading = true;
  String? _loadError;
  List<JobRecord> _jobs = const [];
  List<JobRecord> _filteredJobs = const [];
  List<_LookupOption> _clients = const [];
  Timer? _clientsReloadDebounce;
  bool _clientsReloading = false;
  Future<void>? _backgroundJobsRefreshFuture;
  DateTime? _lastBackgroundJobsRefreshAt;
  // Recorduri complete pentru afișarea detaliilor client în formular
  List<dynamic> _fullClientRecords = const [];
  // Map O(1) pentru lookup rapid în build()
  Map<String, String> _clientLabelById = const {};
  JobStatus? _statusFilter;
  String? _clientFilter;
  LucrariCloudRepository? _cloudRepository;
  String _dataSourceLabel = 'local';
  String? _cloudFallbackReason;
  bool _filtersVisible = false;

  int get _activeFilterCount {
    int count = 0;
    if (_statusFilter != null) count++;
    if ((_clientFilter ?? '').isNotEmpty) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  AppDataRepository get _repository => widget.repository;

  bool get _isTechnician => AppRolePolicy.isTechnician(widget.fieldAuthRoleKey);

  String _shortCloudError(Object error) {
    final raw = error.toString().replaceAll('\n', ' ').trim();
    if (raw.isEmpty) return 'necunoscuta';
    return raw.length > 140 ? '${raw.substring(0, 140)}…' : raw;
  }

  String _localLabelWithFallback() {
    final reason =
        (_cloudFallbackReason ?? FirebaseBootstrap.lastErrorMessage ?? '')
            .trim();
    if (reason.isEmpty) return 'local';
    return 'local';
  }

  @override
  void initState() {
    super.initState();
    _refreshCloudRepository();
    _searchController.addListener(_applyFilters);
    LocalAppDataRepository.clientsChangeCount.addListener(_handleClientsChanged);
    // Reîncarcă din cloud când Firebase devine disponibil după startup
    // (CLAUDE.md ANTI-PATTERN 4 — pagini care nu se reîncarcă după startup)
    FirebaseBootstrap.onlineNotifier.addListener(_onOnlineChanged);
    Future.microtask(_loadData);
  }

  void _refreshCloudRepository() {
    if (FirebaseBootstrap.isInitialized) {
      _cloudRepository ??= FirebaseLucrariRepository();
    } else {
      _cloudFallbackReason = FirebaseBootstrap.lastErrorMessage;
      _dataSourceLabel = 'local';
    }
  }

  @override
  void dispose() {
    FirebaseBootstrap.onlineNotifier.removeListener(_onOnlineChanged);
    LocalAppDataRepository.clientsChangeCount.removeListener(_handleClientsChanged);
    _clientsReloadDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onOnlineChanged() {
    if (FirebaseBootstrap.isOnline && mounted && _jobs.isEmpty && !_isLoading) {
      _loadData();
    }
  }

  /// Reîncarcă doar lista de clienți fără a reîncărca lucrările.
  void _handleClientsChanged() {
    if (_isLoading) {
      return;
    }
    _clientsReloadDebounce?.cancel();
    _clientsReloadDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _reloadClientsOnly();
    });
  }

  Future<void> _reloadClientsOnly() async {
    if (_isLoading || _clientsReloading) {
      return;
    }
    _clientsReloading = true;
    try {
      final clientsRaw = await _loadClientsRawSafe();
      if (!mounted) return;
      final clients = clientsRaw
          .map(_LookupOption.fromDynamic)
          .where((e) => e.id.trim().isNotEmpty)
          .fold<Map<String, _LookupOption>>(
            <String, _LookupOption>{},
            (acc, e) {
              acc[e.id] = e;
              return acc;
            },
          )
          .values
          .toList(growable: false);
      final clientLabelById = {
        for (final c in clients)
          if (c.id.trim().isNotEmpty) c.id: c.label,
      };
      final filteredJobs = _computeFilteredJobs(
        jobs: _jobs,
        clients: clients,
        clientLabelById: clientLabelById,
      );
      setState(() {
        _clients = clients;
        _clientLabelById = clientLabelById;
        _filteredJobs = filteredJobs;
      });
    } finally {
      _clientsReloading = false;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final List<JobRecord> jobs = await _loadJobsResolved();
      final sortedJobs = List<JobRecord>.from(jobs)..sort(_compareJobsByStatus);

      final Iterable<dynamic> clientsRaw = await _loadClientsRawSafe();

      final normalizedClientsRaw = clientsRaw;

      var clients = normalizedClientsRaw
          .map(_LookupOption.fromDynamic)
          .where((entry) => entry.id.trim().isNotEmpty)
          .fold<Map<String, _LookupOption>>(
            <String, _LookupOption>{},
            (acc, e) {
              acc[e.id] = e;
              return acc;
            },
          )
          .values
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _jobs = sortedJobs;
        _clients = clients;
        _fullClientRecords = normalizedClientsRaw.toList(growable: false);
        // Map O(1) pentru lookup rapid în build()
        _clientLabelById = {
          for (final c in clients)
            if (c.id.trim().isNotEmpty) c.id: c.label,
        };
      });
      _applyFilters();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _jobs = const [];
        _filteredJobs = const [];
        _clients = const [];
        _loadError = 'Nu am putut încărca lucrările. Încearcă reîncărcarea.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<JobRecord>> _loadJobsSafe() async {
    try {
      final List<JobRecord> raw =
          await _repository.listJobs().timeout(const Duration(seconds: 8));
      return List<JobRecord>.from(raw);
    } catch (_) {
      return <JobRecord>[];
    }
  }

  Future<List<JobRecord>> _loadJobsResolved() async {
    final localJobs = await _loadJobsSafe();
    _refreshCloudRepository();
    _scheduleBackgroundJobsRefresh();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _dataSourceLabel = _localLabelWithFallback();
    } else {
      _dataSourceLabel = 'local';
      _cloudFallbackReason = null;
    }
    return localJobs;
  }

  void _scheduleBackgroundJobsRefresh() {
    if (_backgroundJobsRefreshFuture != null) {
      return;
    }
    final now = DateTime.now();
    if (_lastBackgroundJobsRefreshAt != null &&
        now.difference(_lastBackgroundJobsRefreshAt!) <
            _backgroundJobsRefreshCooldown) {
      return;
    }
    final future = _refreshJobsFromCloudBackground();
    _backgroundJobsRefreshFuture = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_backgroundJobsRefreshFuture, future)) {
          _backgroundJobsRefreshFuture = null;
          _lastBackgroundJobsRefreshAt = DateTime.now();
        }
      }),
    );
  }

  Future<void> _refreshJobsFromCloudBackground() async {
    await OfflineSyncRuntime.instance.syncPending();
    _refreshCloudRepository();
    final cloud = _cloudRepository;
    if (cloud == null) {
      return;
    }
    try {
      final cloudItems =
          await cloud.listJobs().timeout(const Duration(seconds: 8));
      final repository = _repository;
      final mergedJobs = repository is LocalAppDataRepository
          ? await repository.mergeJobsFromCloud(cloudItems)
          : cloudItems;
      if (!mounted) {
        return;
      }
      final sortedJobs = List<JobRecord>.from(mergedJobs)
        ..sort(_compareJobsByStatus);
      final filteredJobs = _computeFilteredJobs(
        jobs: sortedJobs,
        clients: _clients,
        clientLabelById: _clientLabelById,
      );
      setState(() {
        _jobs = sortedJobs;
        _filteredJobs = filteredJobs;
        _dataSourceLabel = 'cloud';
        _cloudFallbackReason = null;
        _loadError = null;
      });
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      if (!mounted) {
        return;
      }
      setState(() {
        _cloudFallbackReason = _shortCloudError(error);
        _dataSourceLabel = _localLabelWithFallback();
      });
    }
  }

  Future<void> _saveJobResolved(JobRecord job) async {
    final previous = _findJobById(job.id);
    // Auto-completare linii planificate la finalizare
    JobRecord effective = job;
    if (job.status == JobStatus.finalizata && job.liniiPlanificate.isNotEmpty) {
      final liniiAutoComplete = job.liniiPlanificate.map((l) {
        if (l.cantitateReala <= 0) {
          return l.copyWith(cantitateReala: l.cantitateOferta);
        }
        return l;
      }).toList();
      effective = job.copyWith(liniiPlanificate: liniiAutoComplete);
    }
    final next = await _repository.saveJob(effective);
    _refreshCloudRepository();
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.upsertJob(next);
        _dataSourceLabel = 'cloud';
        _cloudFallbackReason = null;
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _cloudFallbackReason = _shortCloudError(error);
        _dataSourceLabel = _localLabelWithFallback();
      }
    }
    // Queue ÎNTOTDEAUNA — garantează sync chiar și când cloud e disponibil (BUG 1)
    await OfflineSyncRuntime.instance.queueJob(next);
    await _notifyJobSaved(next, previous: previous);
  }

  Future<void> _notifyJobSaved(
    JobRecord job, {
    JobRecord? previous,
  }) async {
    NotificationEventType? eventType;
    if (previous == null && job.assignedTeamId.trim().isNotEmpty) {
      eventType = NotificationEventType.jobAssigned;
    } else if (previous != null &&
        previous.assignedTeamId.trim() != job.assignedTeamId.trim() &&
        job.assignedTeamId.trim().isNotEmpty) {
      eventType = NotificationEventType.jobAssigned;
    } else if (previous != null && previous.status != job.status) {
      eventType = NotificationEventType.jobStatusChanged;
    }
    if (eventType == null) {
      return;
    }
    final title = eventType == NotificationEventType.jobAssigned
        ? 'Lucrare alocata'
        : 'Status lucrare actualizat';
    final clientLabel = _clientName(job.clientId).trim();
    final message =
        '${job.jobCode.trim().isEmpty ? 'Lucrare' : job.jobCode.trim()} | ${job.title.trim().isEmpty ? '-' : job.title.trim()} | Status: ${job.status.label} | Client: ${clientLabel.isEmpty ? '-' : clientLabel}';
    await _notificationService.dispatchEvent(
      NotificationDispatchRequest(
        eventType: eventType,
        title: title,
        message: message,
        sourceModule: 'lucrari',
        sourceEntityId: job.id,
        sourceLabel:
            job.jobCode.trim().isEmpty ? 'Lucrare' : job.jobCode.trim(),
        recipientTeamIds: job.assignedTeamId.trim().isEmpty
            ? const <String>[]
            : <String>[job.assignedTeamId.trim()],
        recipientRoleKeys: const <String>['admin', 'office'],
        recipientUserIds: job.createdByUserId.trim().isEmpty
            ? const <String>[]
            : <String>[job.createdByUserId.trim()],
        recipientEmails: job.createdByUserEmail.trim().isEmpty
            ? const <String>[]
            : <String>[job.createdByUserEmail.trim()],
        metadata: <String, dynamic>{
          'job_status': job.status.value,
          'client_id': job.clientId,
        },
      ),
    );
  }

  Future<void> _deleteJobResolved(String jobId) async {
    _refreshCloudRepository();
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.deleteJob(jobId);
        _dataSourceLabel = 'cloud';
        _cloudFallbackReason = null;
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _cloudFallbackReason = _shortCloudError(error);
        _dataSourceLabel = _localLabelWithFallback();
      }
    }
    await _repository.deleteJob(jobId);
    // Queue ÎNTOTDEAUNA — garantează sync chiar și când cloud e disponibil (BUG 1)
    await OfflineSyncRuntime.instance.queueJobDelete(jobId);
  }

  Future<Iterable<dynamic>> _loadClientsRawSafe() async {
    try {
      final dynamic repositoryDynamic = _repository;
      final dynamic fullClients =
          await (repositoryDynamic.listClients() as Future<dynamic>)
              .timeout(const Duration(seconds: 8));
      if (fullClients is Iterable) {
        return fullClients;
      }
    } catch (_) {
      // continue to lookup fallback
    }

    try {
      final dynamic lookupClients = await _repository
          .listClientsLookup()
          .timeout(const Duration(seconds: 8));
      if (lookupClients is Iterable) {
        return lookupClients;
      }
    } catch (_) {
      // return empty below
    }
    return const <dynamic>[];
  }

  void _applyFilters() {
    final filtered = _computeFilteredJobs(
      jobs: _jobs,
      clients: _clients,
      clientLabelById: _clientLabelById,
    );
    if (!mounted) return;
    setState(() => _filteredJobs = filtered);
  }

  List<JobRecord> _computeFilteredJobs({
    required List<JobRecord> jobs,
    required List<_LookupOption> clients,
    required Map<String, String> clientLabelById,
  }) {
    final query = _searchController.text.trim().toLowerCase();
    String clientName(String clientId) {
      final lookup = clientLabelById[clientId];
      if (lookup != null && lookup.trim().isNotEmpty) {
        return lookup;
      }
      for (final client in clients) {
        if (client.id == clientId) {
          return client.label;
        }
      }
      return 'Client necunoscut';
    }

    var filtered = jobs.where((job) {
      if (_statusFilter != null && job.status != _statusFilter) {
        return false;
      }
      if (_clientFilter != null &&
          _clientFilter!.isNotEmpty &&
          job.clientId != _clientFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final resolvedClientName = clientName(job.clientId).toLowerCase();
      return job.jobCode.toLowerCase().contains(query) ||
          job.title.toLowerCase().contains(query) ||
          job.location.toLowerCase().contains(query) ||
          resolvedClientName.contains(query);
    }).toList(growable: false);
    // Tehnicianul vede doar lucrările echipei sale
    if (_isTechnician && (widget.fieldAuthTeamId ?? '').isNotEmpty) {
      filtered = filtered
          .where((job) => job.assignedTeamId == widget.fieldAuthTeamId)
          .toList(growable: false);
    }
    return filtered;
  }

  Future<bool> _openJobForm({JobRecord? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _JobFormDialog(
        repository: _repository,
        clients: _clients,
        existing: existing,
        onSave: _saveJobResolved,
        fullClientRecords: _fullClientRecords,
      ),
    );
    if (saved == true) {
      await _loadData();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null
              ? 'Lucrarea a fost salvată.'
              : 'Lucrarea a fost actualizată.'),
        ),
      );
      return true;
    }
    return false;
  }

  Future<void> _deleteJob(JobRecord job) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ștergere lucrare'),
        content: Text('Sigur vrei să ștergi lucrarea ${job.jobCode}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _deleteJobResolved(job.id);
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lucrarea a fost ștearsă.')),
    );
  }

  JobRecord? _findJobById(String id) {
    for (final item in _jobs) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _openJobDetails(JobRecord job) async {
    var currentJob = job;
    while (mounted) {
      final action = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => LucrareDetaliiPage(
            repository: _repository,
            job: currentJob,
            clientName: _clientName(currentJob.clientId),
            roleKey: widget.fieldAuthRoleKey,
          ),
        ),
      );
      if (action != 'edit') {
        break;
      }
      final saved = await _openJobForm(existing: currentJob);
      if (!mounted) return;
      if (saved) {
        final refreshed = _findJobById(currentJob.id);
        if (refreshed == null) {
          break;
        }
        currentJob = refreshed;
      }
    }
  }

  Widget _filterToggleButton(
      ColorScheme cs, bool hasFilters, bool isWide) {
    if (isWide) return const SizedBox.shrink();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        OutlinedButton.icon(
          onPressed: () =>
              setState(() => _filtersVisible = !_filtersVisible),
          icon: Icon(
            _filtersVisible ? Icons.filter_list_off : Icons.filter_list,
            size: 18,
          ),
          label: Text(_filtersVisible ? 'Ascunde' : 'Filtre'),
          style: OutlinedButton.styleFrom(
            foregroundColor: hasFilters ? cs.primary : null,
            side: hasFilters
                ? BorderSide(color: cs.primary, width: 1.5)
                : null,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        if (hasFilters)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$_activeFilterCount',
                style: TextStyle(
                  color: cs.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _clientName(String id) {
    // O(1) lookup din Map pre-construit
    return _clientLabelById[id] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: AppViewportGuard.scrollablePadding(reserveForFab: true),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                final showFilters = isWide || _filtersVisible;
                final cs = Theme.of(context).colorScheme;
                final hasFilters = _activeFilterCount > 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                textCapitalization:
                                    TextCapitalization.sentences,
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText:
                                      'Caută după cod, titlu, client, locație...',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _searchController.text
                                          .trim()
                                          .isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchController.clear();
                                            _applyFilters();
                                          },
                                        )
                                      : null,
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Reîncarcă',
                              onPressed: _isLoading ? null : _loadData,
                              icon: const Icon(Icons.refresh),
                            ),
                            if (!isWide) ...[
                              const SizedBox(width: 4),
                              _filterToggleButton(
                                  cs, hasFilters, isWide),
                            ],
                            const SizedBox(width: 4),
                            const HelpModuleButton(moduleId: 'jobs'),
                          ],
                        ),
                        if (showFilters) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: 200,
                                child: DropdownButtonFormField<JobStatus?>(
                                  initialValue: _statusFilter,
                                  decoration: const InputDecoration(
                                      labelText: 'Status'),
                                  items: [
                                    const DropdownMenuItem<JobStatus?>(
                                      value: null,
                                      child: Text('Toate'),
                                    ),
                                    ...JobStatus.values.map(
                                      (s) => DropdownMenuItem<JobStatus?>(
                                        value: s,
                                        child: Text(s.label),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _statusFilter = value);
                                    _applyFilters();
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 240,
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _normalizeClientFilter(),
                                  decoration: const InputDecoration(
                                      labelText: 'Client'),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Toți clienții'),
                                    ),
                                    ..._clients.map(
                                      (c) => DropdownMenuItem<String?>(
                                        value: c.id,
                                        child: Text(c.label),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _clientFilter = value);
                                    _applyFilters();
                                  },
                                ),
                              ),
                              Chip(
                                label: Text('Sursă: $_dataSourceLabel'),
                                visualDensity: VisualDensity.compact,
                              ),
                              if ((_cloudFallbackReason ?? '')
                                  .trim()
                                  .isNotEmpty)
                                Text(
                                  'Fallback: ${_shortCloudError(_cloudFallbackReason!)}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _loadError!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _loadData,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reîncarcă'),
                              ),
                            ],
                          ),
                        )
                      : _filteredJobs.isEmpty
                          ? const Center(
                              child: Text('Nu există lucrări salvate.'),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 100),
                              itemCount: _filteredJobs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final job = _filteredJobs[index];
                                final statusColor = job.status.color;
                                final cs = Theme.of(context).colorScheme;
                                final dueText = job.dueDate != null
                                    ? _formatDate(job.dueDate!)
                                    : null;
                                final clientLabel =
                                    _clientName(job.clientId);
                                return Card(
                                  clipBehavior: Clip.antiAlias,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color:
                                          statusColor.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () => _openJobDetails(job),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: statusColor
                                            .withValues(alpha: 0.06),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // ── Rând 1: cod + status badge + dată ──
                                          Row(
                                            children: [
                                              if (job.jobCode
                                                  .trim()
                                                  .isNotEmpty) ...[
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        cs.primaryContainer,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    job.jobCode.trim(),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: cs
                                                          .onPrimaryContainer,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              // Badge status colorat
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: statusColor
                                                      .withValues(alpha: 0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: statusColor
                                                        .withValues(alpha: 0.5),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  job.status.label,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: statusColor,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              if (!job.isActive) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade200,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    'Inactivă',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              const Spacer(),
                                              if (dueText != null)
                                                Text(
                                                  'Termen: $dueText',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: cs.outline,
                                                  ),
                                                ),
                                              if (!_isTechnician) ...[
                                                const SizedBox(width: 4),
                                                SizedBox(
                                                  width: 32,
                                                  height: 32,
                                                  child: PopupMenuButton<
                                                      String>(
                                                    padding: EdgeInsets.zero,
                                                    icon: const Icon(
                                                        Icons.more_vert,
                                                        size: 18),
                                                    tooltip: 'Acțiuni',
                                                    onSelected: (v) {
                                                      if (v == 'edit') {
                                                        _openJobForm(
                                                            existing: job);
                                                      } else if (v ==
                                                          'delete') {
                                                        _deleteJob(job);
                                                      }
                                                    },
                                                    itemBuilder: (_) => [
                                                      const PopupMenuItem(
                                                        value: 'edit',
                                                        child: ListTile(
                                                          leading: Icon(Icons
                                                              .edit_outlined),
                                                          title:
                                                              Text('Editează'),
                                                          dense: true,
                                                          contentPadding:
                                                              EdgeInsets.zero,
                                                        ),
                                                      ),
                                                      const PopupMenuItem(
                                                        value: 'delete',
                                                        child: ListTile(
                                                          leading: Icon(
                                                              Icons
                                                                  .delete_outline,
                                                              color:
                                                                  Colors.red),
                                                          title: Text('Șterge',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .red)),
                                                          dense: true,
                                                          contentPadding:
                                                              EdgeInsets.zero,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          // ── Titlu lucrare ──
                                          Text(
                                            job.title.isNotEmpty
                                                ? job.title
                                                : '(fără titlu)',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (clientLabel.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(Icons.person_outline,
                                                    size: 13,
                                                    color: cs.outline),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    clientLabel,
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: cs.outline),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (job.location.isNotEmpty ||
                                              job.city.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                    Icons
                                                        .location_on_outlined,
                                                    size: 13,
                                                    color: cs.outline),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    [
                                                      job.location,
                                                      job.city
                                                    ]
                                                        .where((s) =>
                                                            s.isNotEmpty)
                                                        .join(', '),
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: cs.outline),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (job.sourceOfferNumber
                                              .trim()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Ofertă: ${job.sourceOfferNumber.trim()}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: cs.outline),
                                            ),
                                          ],
                                          // ── Butoane rapide schimbare status ──
                                          if (!_isTechnician) ...[
                                            const SizedBox(height: 8),
                                            SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                children: JobStatus.values
                                                    .where(
                                                        (s) => s != job.status)
                                                    .map(
                                                      (s) => Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(right: 6),
                                                        child: OutlinedButton(
                                                          style: OutlinedButton
                                                              .styleFrom(
                                                            foregroundColor:
                                                                s.color,
                                                            side: BorderSide(
                                                                color: s.color
                                                                    .withValues(
                                                                        alpha:
                                                                            0.5)),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        10,
                                                                    vertical:
                                                                        4),
                                                            minimumSize:
                                                                const Size(
                                                                    0, 28),
                                                            tapTargetSize:
                                                                MaterialTapTargetSize
                                                                    .shrinkWrap,
                                                            textStyle:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        11),
                                                          ),
                                                          onPressed: () =>
                                                              _changeJobStatus(
                                                                  job, s),
                                                          child: Text(
                                                              '→ ${s.label}'),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isTechnician
          ? null
          : FloatingActionButton.extended(
              onPressed: _isLoading ? null : () => _openJobForm(),
              icon: const Icon(Icons.add),
              label: const Text('Adaugă lucrare'),
            ),
    );
  }

  Future<void> _changeJobStatus(JobRecord job, JobStatus newStatus) async {
    final updated = job.copyWith(status: newStatus, updatedAt: DateTime.now());
    // Optimistic UI
    setState(() {
      final idx = _jobs.indexWhere((j) => j.id == job.id);
      if (idx >= 0) _jobs[idx] = updated;
      final idx2 = _filteredJobs.indexWhere((j) => j.id == job.id);
      if (idx2 >= 0) _filteredJobs[idx2] = updated;
    });
    _saveJobResolved(updated).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Eroare schimbare status: $e')));
        _loadData();
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status → ${newStatus.label}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String? _normalizeClientFilter() {
    if (_clientFilter == null) return null;
    final exists = _clients.any((client) => client.id == _clientFilter);
    return exists ? _clientFilter : null;
  }
}

class _JobFormDialog extends StatefulWidget {
  const _JobFormDialog({
    required this.repository,
    required this.clients,
    required this.onSave,
    this.existing,
    this.fullClientRecords = const [],
  });

  final AppDataRepository repository;
  final List<_LookupOption> clients;
  final Future<void> Function(JobRecord job) onSave;
  final JobRecord? existing;
  final List<dynamic> fullClientRecords;

  @override
  State<_JobFormDialog> createState() => _JobFormDialogState();
}

class _JobFormDialogState extends State<_JobFormDialog> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  final _countyController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _estimatedValueController = TextEditingController();
  final _notesController = TextEditingController();

  // Clienți adăugați inline din dialog fără a reîncărca toată pagina
  final List<ClientRecord> _extraClients = [];

  bool _saving = false;
  String? _selectedClientId;
  JobStatus _selectedStatus = JobStatus.noua;
  bool _isActive = true;
  DateTime? _startDate;
  DateTime? _dueDate;
  String _jobCode = '';

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _jobCode = existing.jobCode;
      _selectedClientId = _normalizeClient(existing.clientId);
      _titleController.text = existing.title;
      _locationController.text = existing.location;
      _cityController.text = existing.city;
      _countyController.text = existing.county;
      _contactController.text = existing.contactPerson;
      _phoneController.text = existing.contactPhone;
      _descriptionController.text = existing.description;
      _categoryController.text = existing.category;
      _selectedStatus = existing.status;
      _startDate = existing.startDate;
      _dueDate = existing.dueDate;
      _estimatedValueController.text =
          existing.estimatedValue?.toStringAsFixed(2) ?? '';
      _notesController.text = existing.notes;
      _isActive = existing.isActive;
      return;
    }
    _bootstrapCode();
  }

  Future<void> _bootstrapCode() async {
    String code;
    try {
      code = await widget.repository
          .nextJobCode()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      final stamp = DateTime.now().millisecondsSinceEpoch.toString();
      code = 'JOB-${stamp.substring(stamp.length - 4)}';
    }
    if (!mounted) return;
    setState(() => _jobCode = code);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _countyController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _estimatedValueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.existing == null ? 'Adaugă lucrare' : 'Editează lucrare'),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _disabledInfoField('Cod lucrare',
                    _jobCode.isEmpty ? 'Se generează...' : _jobCode),
                SizedBox(
                  width: 360,
                  child: ClientAutocompleteField(
                    key: ValueKey(
                        'job-form-client-${_selectedClientId ?? 'none'}'),
                    clients: _clientRecords,
                    initialClient: _selectedClientRecord,
                    labelText: 'Client',
                    helperText: _clientRecords.isEmpty
                        ? 'Nu există clienți salvați.'
                        : null,
                    onClientSelected: (c) =>
                        setState(() => _selectedClientId = c?.id),
                    repository: widget.repository,
                    tipEntitate: 'Client',
                    onClientAdded: (c) => setState(() {
                      _extraClients.add(c);
                      _selectedClientId = c.id;
                    }),
                  ),
                ),
                // Card detalii client — apare când e selectat un client
                if (_selectedClientId != null)
                  Builder(
                    builder: (context) {
                      final raw = widget.fullClientRecords
                          .where((r) {
                            try { return (r as dynamic).id == _selectedClientId; } catch (_) { return false; }
                          })
                          .firstOrNull;
                      if (raw == null || raw is! ClientRecord) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClientInfoCard(client: raw, compact: true),
                      );
                    },
                  ),
                SizedBox(
                  width: 360,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _titleController,
                    decoration:
                        const InputDecoration(labelText: 'Titlu lucrare'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Completează titlul lucrării.'
                            : null,
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'Locație'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'Oraș'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _countyController,
                    decoration: const InputDecoration(labelText: 'Județ'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _contactController,
                    decoration:
                        const InputDecoration(labelText: 'Persoană contact'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _phoneController,
                    decoration:
                        const InputDecoration(labelText: 'Telefon contact'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _categoryController,
                    decoration: const InputDecoration(labelText: 'Categorie'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<JobStatus>(
                    initialValue: _selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: JobStatus.values
                        .map(
                          (status) => DropdownMenuItem<JobStatus>(
                            value: status,
                            child: Text(status.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedStatus = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _estimatedValueController,
                    decoration:
                        const InputDecoration(labelText: 'Valoare estimată'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                _dateField(
                  label: 'Dată început',
                  value: _startDate,
                  onTap: () => _pickDate(
                      initial: _startDate,
                      onPicked: (value) {
                        setState(() => _startDate = value);
                      }),
                ),
                _dateField(
                  label: 'Termen',
                  value: _dueDate,
                  onTap: () => _pickDate(
                      initial: _dueDate,
                      onPicked: (value) {
                        setState(() => _dueDate = value);
                      }),
                ),
                SizedBox(
                  width: 732,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Descriere'),
                    minLines: 2,
                    maxLines: 4,
                  ),
                ),
                SizedBox(
                  width: 732,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _notesController,
                    decoration: const InputDecoration(labelText: 'Observații'),
                    minLines: 2,
                    maxLines: 4,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: SwitchListTile(
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                    title: const Text('Activ'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Anulează'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Se salvează...' : 'Salvează'),
        ),
      ],
    );
  }

  Widget _disabledInfoField(String label, String value) {
    return SizedBox(
      width: 220,
      child: TextFormField(
        textCapitalization: TextCapitalization.sentences,
        enabled: false,
        initialValue: value,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required Future<void> Function() onTap,
  }) {
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          child: Text(value == null ? '-' : _formatDate(value)),
        ),
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    onPicked(picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_jobCode.isEmpty) {
      final stamp = DateTime.now().millisecondsSinceEpoch.toString();
      _jobCode = 'JOB-${stamp.substring(stamp.length - 4)}';
    }
    final now = DateTime.now();
    final existing = widget.existing;
    final estimatedValue = double.tryParse(
      _estimatedValueController.text.trim().replaceAll(',', '.'),
    );
    setState(() => _saving = true);
    try {
      await widget.onSave(
        JobRecord(
          id: existing?.id ?? 'job-${now.microsecondsSinceEpoch}',
          jobCode: _jobCode,
          clientId: _selectedClientId ?? '',
          title: _titleController.text.trim(),
          location: _locationController.text.trim(),
          city: _cityController.text.trim(),
          county: _countyController.text.trim(),
          contactPerson: _contactController.text.trim(),
          contactPhone: _phoneController.text.trim(),
          clientDepartmentId: existing?.clientDepartmentId ?? '',
          clientDepartmentName: existing?.clientDepartmentName ?? '',
          contactPersonId: existing?.contactPersonId ?? '',
          contactPersonEmail: existing?.contactPersonEmail ?? '',
          description: _descriptionController.text.trim(),
          category: _categoryController.text.trim(),
          status: _selectedStatus,
          startDate: _startDate,
          dueDate: _dueDate,
          closedDate: existing?.closedDate,
          estimatedValue: estimatedValue,
          notes: _notesController.text.trim(),
          isActive: _isActive,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String? _normalizeClient(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    final exists = widget.clients.any((client) => client.id == id);
    return exists ? id : null;
  }

  /// Extrage ClientRecord-urile reale din fullClientRecords + clienți adăugați inline
  List<ClientRecord> get _clientRecords => [
        ...widget.fullClientRecords.whereType<ClientRecord>(),
        ..._extraClients,
      ];

  ClientRecord? get _selectedClientRecord =>
      _clientRecords.where((r) => r.id == _selectedClientId).firstOrNull;
}

class _LookupOption {
  const _LookupOption({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  static String _tryReadString(dynamic Function() getter) {
    try {
      final value = getter();
      return value?.toString().trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  factory _LookupOption.fromDynamic(dynamic raw) {
    if (raw is Map) {
      final id = (raw['id'] ?? '').toString().trim();
      final labelCandidate = (raw['label'] ?? '').toString().trim();
      final titleCandidate = (raw['title'] ?? '').toString().trim();
      final nameCandidate =
          (raw['name'] ?? raw['companyName'] ?? '').toString().trim();
      final contactCandidate = (raw['contactPerson'] ?? '').toString().trim();
      final label = labelCandidate.isNotEmpty
          ? labelCandidate
          : (titleCandidate.isNotEmpty
              ? titleCandidate
              : (nameCandidate.isNotEmpty ? nameCandidate : contactCandidate));
      return _LookupOption(id: id, label: label.isNotEmpty ? label : id);
    }
    final id = _tryReadString(() => (raw as dynamic).id);
    final labelCandidate = _tryReadString(() => (raw as dynamic).label);
    final titleCandidate = _tryReadString(() => (raw as dynamic).title);
    final displayNameCandidate =
        _tryReadString(() => (raw as dynamic).displayName);
    final nameCandidate = _tryReadString(() => (raw as dynamic).name);
    final companyNameCandidate =
        _tryReadString(() => (raw as dynamic).companyName);
    final contactCandidate =
        _tryReadString(() => (raw as dynamic).contactPerson);
    final label = labelCandidate.isNotEmpty
        ? labelCandidate
        : (titleCandidate.isNotEmpty
            ? titleCandidate
            : (displayNameCandidate.isNotEmpty
                ? displayNameCandidate
                : (nameCandidate.isNotEmpty
                    ? nameCandidate
                    : (companyNameCandidate.isNotEmpty
                        ? companyNameCandidate
                        : contactCandidate))));
    return _LookupOption(id: id, label: label.isNotEmpty ? label : id);
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day.$month.$year';
}
