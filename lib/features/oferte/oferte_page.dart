import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firestore_auth_warning_service.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import '../../core/repositories/app_data_repository.dart';
import '../../core/repositories/local_app_data_repository.dart';
import '../../core/design_system/app_tokens.dart';
import '../../core/design_system/widgets/app_card.dart';
import '../../core/design_system/widgets/app_empty_state.dart';
import '../../core/design_system/widgets/app_status_chip.dart';
import '../../core/widgets/adaptive_side_panel_layout.dart';
import '../../core/widgets/app_viewport_guard.dart';
import '../ai_assistant/ai_assistant_service.dart';
import '../clients/client_models.dart';
import '../jobs/firebase_lucrari_repository.dart';
import '../jobs/job_models.dart';
import '../jobs/lucrare_detalii_page.dart' show LucrareDetaliiPage;
import '../jobs/lucrari_cloud_repository.dart';
import 'company_cost_profile_models.dart';
import 'company_cost_profile_service.dart';
import 'firebase_oferte_repository.dart';
import 'local_oferte_repository.dart';
import 'oferta_detaliu_page.dart';
import 'offer_commercial_package_models.dart';
import 'offer_editor_defaults_store.dart';
import 'offer_requirement_ai_dialog.dart';
import 'offer_currency_converter.dart';
import 'offer_list_filter.dart';
import 'offer_models.dart';
import 'offer_smartbill_models.dart';
import 'offer_standard_catalog_models.dart';
import 'offer_standard_catalog_service.dart';
import 'oferte_cloud_repository.dart';
import 'deviz_articole_baza_page.dart';
import 'oferte_dialogs/company_cost_profile_dialog.dart';
import 'oferte_dialogs/offer_commercial_clause_templates_dialog.dart';
import 'oferte_dialogs/offer_defaults_dialog.dart';
import 'oferte_dialogs/offer_form_dialog.dart';
import 'oferte_dialogs/offer_commercial_package_templates_dialog.dart';
import 'oferte_dialogs/offer_labor_templates_dialog.dart';
import '../../core/help/help_module_button.dart';

/// Prioritatea de afișare a unei oferte după status (sortare logică).
/// Ordinea dorită: Acceptat → Trimis → (În așteptare) → Draft → Respins →
/// Anulat → Convertită (ultimele). Convertirea are prioritate ABSOLUTĂ peste
/// statusul de bază: o ofertă convertită în lucrare merge ultima indiferent
/// dacă era „acceptată” înainte.
int _offerStatusRank(OfferRecord o) {
  if (o.isConverted) return 100;
  switch (o.status) {
    case OfferStatus.accepted:
      return 0;
    case OfferStatus.sent:
      return 1;
    case OfferStatus.awaiting:
      return 2;
    case OfferStatus.draft:
      return 3;
    case OfferStatus.rejected:
      return 4;
    case OfferStatus.cancelled:
      return 5;
  }
}

/// Comparator: întâi după prioritatea statusului, apoi (în cadrul aceluiași
/// status) după dată descrescător (cele mai recente primele).
int _compareOffersByStatus(OfferRecord a, OfferRecord b) {
  final byStatus = _offerStatusRank(a).compareTo(_offerStatusRank(b));
  if (byStatus != 0) return byStatus;
  return b.updatedAt.compareTo(a.updatedAt);
}

class OfertePage extends StatefulWidget {
  const OfertePage({
    super.key,
    required this.repository,
    this.currentUserId,
    this.currentUserEmail,
    this.initialDraftOffer,
    this.autoOpenDraftOnStart = false,
    this.autoCloseAfterDraftSave = false,
    this.initialFocusOfferId = '',
    this.onOfferSaved,
    this.hideAppBar = false,
  });

  final AppDataRepository repository;
  final String? currentUserId;
  final String? currentUserEmail;
  final OfferRecord? initialDraftOffer;
  final bool autoOpenDraftOnStart;
  final bool autoCloseAfterDraftSave;
  final String initialFocusOfferId;
  final Future<void> Function(OfferRecord offer)? onOfferSaved;

  /// Când e true, AppBar-ul nu se afișează (folosit în tab-ul din OferteDevizeModulPage)
  final bool hideAppBar;

  @override
  State<OfertePage> createState() => _OfertePageState();
}

class _OfertePageState extends State<OfertePage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  static const String _prefKeyStatus = 'oferte_filter_status_v1';
  static const String _prefKeyClient = 'oferte_filter_client_v1';
  static const String _prefKeySearch = 'oferte_filter_search_v1';
  static const Duration _preferencesDebounceDuration =
      Duration(milliseconds: 300);

  @override
  bool get wantKeepAlive => true;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _analysisClientSearchController =
      TextEditingController();
  final LocalOferteRepository _localRepository = LocalOferteRepository();
  final OfferEditorDefaultsStore _defaultsStore = OfferEditorDefaultsStore();
  final OfferStandardCatalogService _standardCatalogService =
      OfferStandardCatalogService();
  final CompanyCostProfileService _companyCostProfileService =
      CompanyCostProfileService();
  late final AiAssistantService _aiAssistantService;
  StreamSubscription<List<OfferRecord>>? _offersSubscription;

  bool _loading = true;
  Timer? _clientsReloadDebounce;
  Timer? _preferencesDebounce;
  bool _clientsReloading = false;
  List<OfferRecord> _items = const <OfferRecord>[];
  List<ClientRecord> _clients = const <ClientRecord>[];
  List<JobRecord> _jobs = const <JobRecord>[];
  // Maps O(1) pentru lookup rapid în build() — evită O(n) per card
  Map<String, String> _clientNameById = const {};
  Map<String, String> _jobLabelById = const {};
  List<OfferLaborTemplate> _laborTemplates = const <OfferLaborTemplate>[];
  List<OfferCommercialClauseTemplate> _clauseTemplates =
      const <OfferCommercialClauseTemplate>[];
  List<OfferCommercialPackageTemplate> _packageTemplates =
      const <OfferCommercialPackageTemplate>[];
  OfferStatus? _statusFilter;
  String _tipOfertaFilter =
      'toate'; // 'toate' | 'oferta_lucrari' | 'deviz_tehnic' | 'mini_oferta' | 'deviz_filtre'
  String? _clientFilter;
  OferteCloudRepository? _cloudRepository;
  LucrariCloudRepository? _lucrariCloudRepository;
  String _dataSourceLabel = 'local_cache';
  String? _fallbackReason;
  OfferEditorDefaults _offerDefaults = const OfferEditorDefaults();
  bool _didHandleInitialDraft = false;
  bool _didHandleInitialFocus = false;
  late final TabController _tabController;
  List<String> _analysisStatusFilters = <String>[];
  String _analysisPerioadaFilter = 'toate';
  String _analysisTipFilter = 'toate';
  String _analysisSearchClient = '';
  Set<String> _selectedIds = <String>{};
  final Map<String, bool> _expandedGroups = <String, bool>{};
  DateTimeRange? _analysisCustomRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
    _aiAssistantService = AiAssistantService(repository: widget.repository);
    if (FirebaseBootstrap.isInitialized) {
      _cloudRepository = FirebaseOferteRepository();
      _lucrariCloudRepository = FirebaseLucrariRepository();
    } else {
      _setLocalCacheSource(FirebaseBootstrap.lastErrorMessage);
    }
    _searchController.addListener(_refreshUi);
    _analysisClientSearchController.addListener(() {
      setState(() {
        _analysisSearchClient = _analysisClientSearchController.text.trim();
      });
    });
    _bindCloudOffers();
    _loadOfferDefaults();
    _loadFilterPreferences();
    // Ascultă modificările de clienți din orice altă pagină (ex: modul Clienți)
    LocalAppDataRepository.clientsChangeCount
        .addListener(_handleClientsChanged);
    Future.microtask(_load);
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging || !mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _loadFilterPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final statusName = prefs.getString(_prefKeyStatus);
    final clientId = prefs.getString(_prefKeyClient);
    final search = prefs.getString(_prefKeySearch) ?? '';
    setState(() {
      if (statusName != null) {
        try {
          _statusFilter = OfferStatus.values.firstWhere(
            (e) => e.name == statusName,
          );
        } catch (_) {
          _statusFilter = null;
        }
      }
      _clientFilter = clientId;
      if (search.isNotEmpty) {
        _searchController.text = search;
      }
    });
  }

  Future<void> _persistFilterPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        _statusFilter == null
            ? prefs.remove(_prefKeyStatus)
            : prefs.setString(_prefKeyStatus, _statusFilter!.name),
        _clientFilter == null
            ? prefs.remove(_prefKeyClient)
            : prefs.setString(_prefKeyClient, _clientFilter!),
        prefs.setString(_prefKeySearch, _searchController.text.trim()),
      ]);
    } catch (error) {
      debugPrint('[Oferte] persist filter preferences failed: $error');
    }
  }

  void _schedulePersistFilterPreferences() {
    _preferencesDebounce?.cancel();
    _preferencesDebounce = Timer(
      _preferencesDebounceDuration,
      () {
        unawaited(_persistFilterPreferences());
      },
    );
  }

  Future<void> _loadOfferDefaults() async {
    final profileFallback = await widget.repository.loadCompanyProfile();
    final loaded = await _defaultsStore.load(profileFallback: profileFallback);
    if (!mounted) return;
    setState(() => _offerDefaults = loaded);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    LocalAppDataRepository.clientsChangeCount
        .removeListener(_handleClientsChanged);
    _clientsReloadDebounce?.cancel();
    _preferencesDebounce?.cancel();
    _offersSubscription?.cancel();
    _analysisClientSearchController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Reîncarcă doar lista de clienți (fără să reîncerce ofertele/job-urile).
  /// Apelată automat când un client e adăugat/șters din orice modul.
  void _handleClientsChanged() {
    if (_loading) {
      return;
    }
    _clientsReloadDebounce?.cancel();
    _clientsReloadDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _reloadClients();
    });
  }

  Future<void> _reloadClients() async {
    if (_loading || _clientsReloading) {
      return;
    }
    _clientsReloading = true;
    try {
      final clients = await _loadClientsSafe();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _clientNameById = {
          for (final c in clients)
            if (c.id.trim().isNotEmpty) c.id: c.name,
        };
      });
    } finally {
      _clientsReloading = false;
    }
  }

  void _refreshUi() {
    if (!mounted) return;
    setState(() {});
    _schedulePersistFilterPreferences();
  }

  String _shortCloudError(Object error) {
    final raw = error.toString().replaceAll('\n', ' ').trim();
    if (raw.isEmpty) return 'necunoscuta';
    return raw.length > 140 ? '${raw.substring(0, 140)}...' : raw;
  }

  void _setCloudSource() {
    _dataSourceLabel = 'cloud';
    _fallbackReason = null;
  }

  void _setLocalCacheSource(String? reason) {
    _dataSourceLabel = 'local_cache';
    final trimmed = (reason ?? '').trim();
    _fallbackReason = trimmed.isEmpty ? null : trimmed;
  }

  void _bindCloudOffers() {
    _offersSubscription?.cancel();
    final cloud = _cloudRepository;
    if (cloud == null) {
      return;
    }
    _offersSubscription = cloud.watchOffers().listen(
      (cloudItems) async {
        await _localRepository.replaceOffers(cloudItems);
        if (!mounted) {
          return;
        }
        setState(() {
          _setCloudSource();
          _items = [...cloudItems]..sort(_compareOffersByStatus);
          _loading = false;
        });
      },
      onError: (Object error) {
        FirebaseBootstrap.registerRuntimeError(error);
        FirestoreAuthWarningService.instance.reportCloudError(error);
        if (!mounted) {
          return;
        }
        setState(() {
          _setLocalCacheSource(_shortCloudError(error));
        });
      },
    );
  }

  Future<List<OfferRecord>> _listOffersResolved() async {
    final cloud = _cloudRepository;
    if (cloud == null) {
      _setLocalCacheSource(
          _fallbackReason ?? FirebaseBootstrap.lastErrorMessage);
      return _localRepository.listOffers();
    }
    try {
      final cloudItems = await cloud.listOffers();
      _setCloudSource();
      await _localRepository.replaceOffers(cloudItems);
      return cloudItems;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      FirestoreAuthWarningService.instance.reportCloudError(error);
      _setLocalCacheSource(_shortCloudError(error));
      return _localRepository.listOffers();
    }
  }

  Future<void> _saveOfferResolved(OfferRecord item) async {
    final resolved = item.offerNumber.trim().isEmpty
        ? item.copyWith(offerNumber: await widget.repository.nextOfferNumber())
        : item.copyWith(offerNumber: item.offerNumber.trim());
    final cloud = _cloudRepository;
    if (cloud != null) {
      // Retry de 3 ori cu backoff exponențial (1s, 2s, 4s) pentru erori tranzitorii
      const maxRetries = 3;
      Object? lastError;
      for (var attempt = 0; attempt < maxRetries; attempt++) {
        try {
          if (attempt > 0) {
            await Future.delayed(Duration(seconds: 1 << attempt));
          }
          await cloud.upsertOffer(resolved);
          _setCloudSource();
          lastError = null;
          break;
        } catch (error) {
          lastError = error;
          FirebaseBootstrap.registerRuntimeError(error);
        }
      }
      if (lastError != null) {
        _setLocalCacheSource(_shortCloudError(lastError));
      }
    } else {
      _setLocalCacheSource(
          _fallbackReason ?? FirebaseBootstrap.lastErrorMessage);
    }
    try {
      await _localRepository.upsertOffer(resolved);
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
    }
    try {
      await OfflineSyncRuntime.instance.queueOffer(resolved);
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
    }
  }

  Future<void> _deleteOfferResolved(String id) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.deleteOffer(id);
        _setCloudSource();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _setLocalCacheSource(_shortCloudError(error));
      }
    } else {
      _setLocalCacheSource(
          _fallbackReason ?? FirebaseBootstrap.lastErrorMessage);
    }
    await _localRepository.deleteOffer(id);
    await OfflineSyncRuntime.instance.queueOfferDelete(id);
  }

  Future<void> _quickUpdateOfferStatus(
    OfferRecord item,
    OfferStatus nextStatus,
  ) async {
    if (item.status == nextStatus) {
      return;
    }
    if (_isOfferFrozen(item)) {
      _showConvertedFrozenMessage(item);
      return;
    }
    await _saveOfferResolved(
      item.copyWith(
        status: nextStatus,
        updatedAt: DateTime.now(),
      ),
    );
    await _load();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status oferta actualizat: ${nextStatus.label}')),
    );
  }

  PopupMenuButton<OfferStatus> _buildOfferStatusMenu(OfferRecord item) {
    return PopupMenuButton<OfferStatus>(
      tooltip: item.isConverted ? 'Oferta convertita' : 'Status oferta',
      enabled: !item.isConverted,
      onSelected: (status) => _quickUpdateOfferStatus(item, status),
      itemBuilder: (_) {
        return OfferStatus.values
            .map(
              (status) => PopupMenuItem<OfferStatus>(
                value: status,
                enabled: status != item.status,
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: _offerStatusBaseColor(status),
                    ),
                    const SizedBox(width: 8),
                    Text(status.label),
                  ],
                ),
              ),
            )
            .toList(growable: false);
      },
      icon: const Icon(Icons.flag_outlined),
    );
  }

  Future<void> _saveJobResolved(JobRecord job) async {
    if (_lucrariCloudRepository == null && FirebaseBootstrap.isInitialized) {
      _lucrariCloudRepository = FirebaseLucrariRepository();
    }
    final cloud = _lucrariCloudRepository;
    var queuedOffline = cloud == null;
    if (cloud != null) {
      try {
        await cloud.upsertJob(job);
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        queuedOffline = true;
      }
    }
    final next = await widget.repository.saveJob(job);
    if (queuedOffline) {
      await OfflineSyncRuntime.instance.queueJob(next);
    }
  }

  Future<void> _load() async {
    try {
      await OfflineSyncRuntime.instance.syncPending();
      // Paralelizare: toate fetch-urile sunt independente
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _listOffersResolved(),
        _loadClientsSafe(),
        _loadJobsSafe(),
        _loadLaborTemplatesSafe(),
        _loadClauseTemplatesSafe(),
        _loadPackageTemplatesSafe(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = [...(results[0] as List<OfferRecord>)]
          ..sort(_compareOffersByStatus);
        _clients = results[1] as List<ClientRecord>;
        _jobs = results[2] as List<JobRecord>;
        // Construieste Maps O(1) pentru lookup rapid
        _clientNameById = {
          for (final c in _clients)
            if (c.id.trim().isNotEmpty) c.id: c.name,
        };
        _jobLabelById = {
          for (final j in _jobs)
            if (j.id.trim().isNotEmpty)
              j.id: (j.jobCode.trim().isNotEmpty && j.title.trim().isNotEmpty)
                  ? '${j.jobCode} - ${j.title}'
                  : j.title.trim().isEmpty
                      ? j.jobCode
                      : j.title,
        };
        _laborTemplates = results[3] as List<OfferLaborTemplate>;
        _clauseTemplates = results[4] as List<OfferCommercialClauseTemplate>;
        _packageTemplates = results[5] as List<OfferCommercialPackageTemplate>;
      });
      await _handleInitialNavigationIntents();
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleInitialNavigationIntents() async {
    if (!mounted) return;
    if (!_didHandleInitialDraft &&
        widget.autoOpenDraftOnStart &&
        widget.initialDraftOffer != null) {
      _didHandleInitialDraft = true;
      final resolved = await _openEditorInternal(
        draftOffer: widget.initialDraftOffer,
        showFeedback: false,
        closePageOnSave: widget.autoCloseAfterDraftSave,
      );
      if (!mounted) return;
      if (!widget.autoCloseAfterDraftSave && resolved != null) {
        await _openDetails(resolved);
      }
      return;
    }
    if (!_didHandleInitialFocus &&
        widget.initialFocusOfferId.trim().isNotEmpty) {
      _didHandleInitialFocus = true;
      final offer = _findOfferById(widget.initialFocusOfferId.trim());
      if (offer != null) {
        await _openDetails(offer);
      }
    }
  }

  Future<List<OfferLaborTemplate>> _loadLaborTemplatesSafe() async {
    try {
      final items = await _standardCatalogService.listLaborTemplates();
      final sorted = [...items]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return sorted;
    } catch (_) {
      return const <OfferLaborTemplate>[];
    }
  }

  Future<List<OfferCommercialClauseTemplate>> _loadClauseTemplatesSafe() async {
    try {
      final items = await _standardCatalogService.listClauseTemplates();
      final sorted = [
        ...items
      ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      return sorted;
    } catch (_) {
      return const <OfferCommercialClauseTemplate>[];
    }
  }

  Future<List<OfferCommercialPackageTemplate>>
      _loadPackageTemplatesSafe() async {
    try {
      final items = await _standardCatalogService.listPackageTemplates();
      final sorted = [...items]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return sorted;
    } catch (_) {
      return const <OfferCommercialPackageTemplate>[];
    }
  }

  Future<List<ClientRecord>> _loadClientsSafe() async {
    try {
      final items = await widget.repository.listClients();
      final sorted = [...items]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return sorted;
    } catch (_) {
      return const <ClientRecord>[];
    }
  }

  Future<List<JobRecord>> _loadJobsSafe() async {
    try {
      final items = await widget.repository.listJobs();
      final sorted = [...items]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sorted;
    } catch (_) {
      return const <JobRecord>[];
    }
  }

  List<OfferRecord> get _filteredItems {
    var items = OfferListFilter.apply(
      items: _items,
      searchQuery: _searchController.text,
      status: _statusFilter,
      clientId: _clientFilter,
      resolveClientName: _resolveClientName,
    );
    if (_tipOfertaFilter != 'toate') {
      items = items
          .where((item) => item.tipOferta == _tipOfertaFilter)
          .toList(growable: false);
    }
    return items;
  }

  String _resolveClientName(OfferRecord item) {
    if (item.clientName.trim().isNotEmpty) return item.clientName.trim();
    // O(1) lookup din Map pre-construit
    return _clientNameById[item.clientId] ?? '-';
  }

  String _dataSourceUiLabel() {
    switch (_dataSourceLabel) {
      case 'cloud':
        return 'cloud';
      case 'local_cache':
        return 'cache local';
      default:
        return _dataSourceLabel;
    }
  }

  String _emptyStateMessage() {
    final hasFilters = OfferListFilter.hasActiveFilters(
      status: _statusFilter,
      clientId: _clientFilter,
      searchQuery: _searchController.text,
    );
    if (hasFilters) {
      return 'Nu există oferte care să corespundă filtrelor curente.';
    }
    return 'Nu există oferte salvate momentan.';
  }

  String _resolveDepartmentLabel(OfferRecord item) {
    return item.departmentName.trim().isEmpty
        ? '-'
        : item.departmentName.trim();
  }

  String _resolveContactLabel(OfferRecord item) {
    return item.contactPersonName.trim().isEmpty
        ? '-'
        : item.contactPersonName.trim();
  }

  String _resolveJobLabel(OfferRecord item) {
    if (item.jobCode.trim().isNotEmpty || item.jobTitle.trim().isNotEmpty) {
      final code = item.jobCode.trim();
      final title = item.jobTitle.trim();
      if (code.isNotEmpty && title.isNotEmpty) return '$code - $title';
      if (code.isNotEmpty) return code;
      if (title.isNotEmpty) return title;
    }
    // O(1) lookup din Map pre-construit
    return _jobLabelById[item.jobId] ?? '-';
  }

  String _displayStatusLabel(OfferRecord item) {
    if (item.isConverted) return 'Convertită';
    return item.status.label;
  }

  Color _offerStatusBaseColor(OfferStatus status) {
    switch (status) {
      case OfferStatus.draft:
        return Colors.blueGrey.shade700;
      case OfferStatus.sent:
        return Colors.blue.shade700;
      case OfferStatus.awaiting:
        return Colors.orange.shade700;
      case OfferStatus.accepted:
        return Colors.green.shade700;
      case OfferStatus.rejected:
        return Colors.red.shade700;
      case OfferStatus.cancelled:
        return Colors.brown.shade700;
    }
  }

  Color _offerStatusColor(OfferRecord item) {
    if (item.isConverted) {
      return Colors.teal.shade700;
    }
    return _offerStatusBaseColor(item.status);
  }

  Widget _buildOfferStatusChip(OfferRecord item) {
    final color = _offerStatusColor(item);
    return AppStatusChip(
      label: _displayStatusLabel(item),
      status: AppStatusKind.neutral,
      customColor: color,
      icon: item.isConverted ? Icons.transform_outlined : Icons.flag_outlined,
    );
  }

  Widget _buildTipOfertaBadge(String tipOferta) {
    final (label, color) = switch (tipOferta) {
      'deviz_tehnic' => ('Deviz tehnic', Colors.purple),
      'mini_oferta' => ('Mini ofertă', Colors.orange),
      'deviz_filtre' => ('Filtre CTA', Colors.teal),
      _ => ('Ofertă', Colors.blue),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildExpiryChip(OfferRecord item) {
    final expiry = item.validUntil;
    if (expiry == null) return const SizedBox.shrink();
    if (item.isConverted || item.status == OfferStatus.accepted) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    final diff = expiryDay.difference(today).inDays;

    final Color color;
    final String label;
    final IconData icon;
    if (diff < 0) {
      color = Colors.red;
      label = 'Expirată (${-diff}z)';
      icon = Icons.timer_off_outlined;
    } else if (diff <= 7) {
      color = Colors.orange;
      label = 'Expiră în ${diff}z';
      icon = Icons.timer_outlined;
    } else {
      color = Colors.green;
      label = 'Validă ${diff}z';
      icon = Icons.check_circle_outline;
    }

    return AppStatusChip(
      label: label,
      status: AppStatusKind.neutral,
      customColor: color,
      icon: icon,
    );
  }

  Widget _buildOfferStatusOptionLabel(OfferStatus status) {
    final color = _offerStatusBaseColor(status);
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 8),
        Text(status.label),
      ],
    );
  }

  bool _isOfferFrozen(OfferRecord item) => item.isConverted;

  void _showConvertedFrozenMessage([OfferRecord? item]) {
    final jobId = item?.convertedToJobId.trim() ?? '';
    final suffix = jobId.isEmpty ? '' : ' Lucrarea generată este $jobId.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Oferta a fost deja convertită în lucrare și nu mai poate fi modificată.$suffix')),
    );
  }

  JobRecord? _findJobById(String id) {
    final normalized = id.trim();
    if (normalized.isEmpty) return null;
    for (final job in _jobs) {
      if (job.id == normalized) return job;
    }
    return null;
  }

  Future<void> _openConvertedJob(OfferRecord item) async {
    final job = _findJobById(item.convertedToJobId);
    if (job == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lucrarea generată pentru oferta ${item.offerNumber} nu a fost găsită în lista curentă.',
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LucrareDetaliiPage(
          repository: widget.repository,
          job: job,
          clientName: _resolveClientName(item),
        ),
      ),
    );
    await _load();
  }

  String _storageModeHint() {
    if (_dataSourceLabel != 'local_cache') return '';
    final reason = (_fallbackReason ?? '').trim();
    if (reason.isEmpty) return ' Operație salvată în cache local.';
    return ' Operație salvată în cache local până la revenirea cloud.';
  }

  String _formatCurrency(double value, {String currency = 'RON'}) {
    final fmt = NumberFormat('#,##0.00', 'ro_RO');
    return '${fmt.format(value)} $currency';
  }

  DateTimeRange? _analysisDateRange() {
    final now = DateTime.now();
    switch (_analysisPerioadaFilter) {
      case 'luna_curenta':
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0),
        );
      case 'luna_trecuta':
        final previousMonth = DateTime(now.year, now.month - 1, 1);
        return DateTimeRange(
          start: previousMonth,
          end: DateTime(previousMonth.year, previousMonth.month + 1, 0),
        );
      case 'an_curent':
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31),
        );
      case 'custom':
        return _analysisCustomRange;
      case 'toate':
      default:
        return null;
    }
  }

  List<OfferRecord> get _analysisFilteredItems {
    Iterable<OfferRecord> items = _items;

    if (_analysisStatusFilters.isNotEmpty) {
      items = items.where(
        (item) => _analysisStatusFilters.contains(item.status.value),
      );
    }

    final range = _analysisDateRange();
    if (range != null) {
      final start =
          DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      );
      items = items.where(
        (item) =>
            !item.issueDate.isBefore(start) && !item.issueDate.isAfter(end),
      );
    }

    if (_analysisTipFilter != 'toate') {
      items =
          items.where((item) => item.tipDocument.value == _analysisTipFilter);
    }

    final clientQuery = _analysisSearchClient.trim().toLowerCase();
    if (clientQuery.isNotEmpty) {
      items = items.where(
        (item) => _resolveClientName(item).toLowerCase().contains(clientQuery),
      );
    }

    final filtered = items.toList(growable: false)
      ..sort((a, b) => b.issueDate.compareTo(a.issueDate));
    _selectedIds = _selectedIds
        .where((id) => filtered.any((item) => item.id == id))
        .toSet();
    return filtered;
  }

  Map<String, List<OfferRecord>> _groupByClient(List<OfferRecord> offers) {
    final map = <String, List<OfferRecord>>{};
    for (final offer in offers) {
      final resolvedName = _resolveClientName(offer).trim();
      final key = resolvedName.isEmpty || resolvedName == '-'
          ? 'Fără client'
          : resolvedName;
      map.putIfAbsent(key, () => <OfferRecord>[]).add(offer);
    }
    return Map<String, List<OfferRecord>>.fromEntries(
      map.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length)),
    );
  }

  double _selectedWithoutVatTotal() {
    final byId = {for (final item in _items) item.id: item};
    return _selectedIds.fold<double>(
      0,
      (sum, id) => sum + (byId[id]?.subtotalComercial ?? 0),
    );
  }

  double _selectedWithVatTotal() {
    final byId = {for (final item in _items) item.id: item};
    return _selectedIds.fold<double>(
      0,
      (sum, id) => sum + (byId[id]?.totalValue ?? 0),
    );
  }

  double _acceptanceRate(List<OfferRecord> list) {
    if (list.isEmpty) return 0;
    return list.where((item) => item.status == OfferStatus.accepted).length /
        list.length *
        100;
  }

  void _toggleAnalysisStatus(String value) {
    setState(() {
      if (value == 'toate') {
        _analysisStatusFilters = <String>[];
        return;
      }
      final next = [..._analysisStatusFilters];
      if (next.contains(value)) {
        next.remove(value);
      } else {
        next.add(value);
      }
      _analysisStatusFilters = next;
    });
  }

  Future<void> _pickCustomAnalysisRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _analysisCustomRange,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _analysisCustomRange = picked;
      _analysisPerioadaFilter = 'custom';
    });
  }

  void _toggleSelectOffer(String offerId, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(offerId);
      } else {
        _selectedIds.remove(offerId);
      }
    });
  }

  void _toggleSelectClientGroup(
    String clientName,
    List<OfferRecord> offers,
    bool selected,
  ) {
    setState(() {
      final ids = offers.map((item) => item.id);
      if (selected) {
        _selectedIds.addAll(ids);
      } else {
        _selectedIds.removeAll(ids);
      }
      _expandedGroups[clientName] = true;
    });
  }

  Future<void> _copySelectedAnalysisTotals() async {
    final text = 'Oferte selectate: ${_selectedIds.length}\n'
        'Fără TVA: ${_formatCurrency(_selectedWithoutVatTotal())}\n'
        'Cu TVA: ${_formatCurrency(_selectedWithVatTotal())}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Valorile selectate au fost copiate.')),
    );
  }

  double _displayedOfferTotal(OfferRecord offer) {
    return offer.priceDisplayMode == OfferPriceDisplayMode.withoutVat
        ? offer.subtotalComercial
        : offer.totalValue;
  }

  String _offerPriceSummary(OfferRecord offer) {
    switch (offer.priceDisplayMode) {
      case OfferPriceDisplayMode.withoutVat:
        return 'Preț ofertat fără TVA: ${offer.subtotalComercial.toStringAsFixed(2)}'
            ' • Total fără TVA: ${offer.subtotalComercial.toStringAsFixed(2)} ${offer.currency}';
      case OfferPriceDisplayMode.withVat:
        return 'Preț ofertat cu TVA: ${offer.totalValue.toStringAsFixed(2)}'
            ' • Total: ${offer.totalValue.toStringAsFixed(2)} ${offer.currency}';
      case OfferPriceDisplayMode.both:
        return 'Preț ofertat fără TVA: ${offer.subtotalComercial.toStringAsFixed(2)}'
            ' • TVA: ${offer.vatValue.toStringAsFixed(2)}'
            ' • Total: ${offer.totalValue.toStringAsFixed(2)} ${offer.currency}';
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  Future<void> _openEditor({
    OfferRecord? existing,
    TipDocumentDeviz? defaultTipDocument,
  }) async {
    if (existing != null && _isOfferFrozen(existing)) {
      _showConvertedFrozenMessage(existing);
      return;
    }
    await _openEditorInternal(
      existing: existing,
      showFeedback: true,
      defaultTipDocument: defaultTipDocument,
    );
  }

  Future<void> _openRequirementAiDialog() async {
    final nextOfferNumber = await widget.repository.nextOfferNumber();
    if (!mounted) return;
    await OfferRequirementAiDialog.show(
      context: context,
      aiAssistantService: _aiAssistantService,
      clients: _clients,
      jobs: _jobs,
      defaults: _offerDefaults,
      nextOfferNumber: nextOfferNumber,
      currentUserId: widget.currentUserId,
      currentUserEmail: widget.currentUserEmail,
      onCreateDraft: _createDraftFromRequirement,
    );
  }

  Future<void> _createDraftFromRequirement(OfferRecord draftOffer) async {
    final saved = await _openEditorInternal(
      draftOffer: draftOffer,
      showFeedback: true,
    );
    if (!mounted || saved == null) return;
    await _openDetails(saved);
  }

  OfferRecord? _findOfferById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  OfferRecord _buildDuplicateDraft(OfferRecord source) {
    final now = DateTime.now();
    final currentUserId = (widget.currentUserId ?? '').trim();
    final currentUserEmail = (widget.currentUserEmail ?? '').trim();
    return source.copyWith(
      id: 'offer-${now.microsecondsSinceEpoch}',
      offerNumber: '',
      status: OfferStatus.draft,
      pdfPath: '',
      clientSignatureBase64: '',
      issuerSignatureBase64: '',
      clearAgreementAcceptedAt: true,
      registryEntryId: '',
      registryNumber: '',
      clearRegisteredAt: true,
      convertedToJobId: '',
      clearConvertedAt: true,
      convertedByUserId: '',
      smartBillEstimate: const OfferSmartBillDocumentState(
        documentType: OfferSmartBillDocumentType.estimate,
      ),
      smartBillInvoice: const OfferSmartBillDocumentState(
        documentType: OfferSmartBillDocumentType.invoice,
      ),
      createdAt: now,
      updatedAt: now,
      createdByUserId:
          currentUserId.isEmpty ? source.createdByUserId : currentUserId,
      createdByUserEmail: currentUserEmail.isEmpty
          ? source.createdByUserEmail
          : currentUserEmail,
      lines:
          source.lines.map((line) => line.copyWith()).toList(growable: false),
      partners: source.partners
          .map((partner) => partner.copyWith())
          .toList(growable: false),
      partnerWorkers: source.partnerWorkers
          .map((worker) => worker.copyWith())
          .toList(growable: false),
      partnerVehicles: source.partnerVehicles
          .map((vehicle) => vehicle.copyWith())
          .toList(growable: false),
      commercialClauses: source.commercialClauses
          .map((clause) => clause.copyWith())
          .toList(growable: false),
    );
  }

  Future<OfferRecord?> _duplicateOffer(OfferRecord source) async {
    final duplicated = _buildDuplicateDraft(source);
    final saved = await _openEditorInternal(
      draftOffer: duplicated,
      showFeedback: true,
    );
    if (!mounted || saved == null) {
      return saved;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Oferta ${source.offerNumber} a fost duplicata ca ${saved.offerNumber}.${_storageModeHint()}',
        ),
      ),
    );
    return saved;
  }

  Future<OfferRecord?> _openEditorInternal({
    OfferRecord? existing,
    OfferRecord? draftOffer,
    required bool showFeedback,
    bool closePageOnSave = false,
    TipDocumentDeviz? defaultTipDocument,
  }) async {
    final creatingNew = existing == null;
    final nextOfferNumber =
        existing == null ? await widget.repository.nextOfferNumber() : null;
    if (!mounted) return null;
    final savedOffer = await showDialog<OfferRecord>(
      context: context,
      builder: (context) => OfferFormDialog(
        existing: existing,
        initialDraft: draftOffer,
        clients: _clients,
        jobs: _jobs,
        laborTemplates: _laborTemplates,
        clauseTemplates: _clauseTemplates,
        packageTemplates: _packageTemplates,
        currentUserId: widget.currentUserId,
        currentUserEmail: widget.currentUserEmail,
        nextOfferNumber: nextOfferNumber,
        defaults: _offerDefaults,
        onSave: _saveOfferResolved,
        defaultTipDocument: defaultTipDocument,
        repository: widget.repository,
      ),
    );
    if (savedOffer != null) {
      await _load();
      if (!mounted) return null;
      final resolved = _findOfferById(savedOffer.id) ?? savedOffer;
      await widget.onOfferSaved?.call(resolved);
      if (!mounted) {
        return resolved;
      }
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              creatingNew
                  ? 'Oferta a fost salvata.${_storageModeHint()}'
                  : 'Oferta a fost actualizata.${_storageModeHint()}',
            ),
          ),
        );
      }
      if (closePageOnSave) {
        Navigator.of(context).pop();
      }
      return resolved;
    }
    return null;
  }

  Future<void> _openDetails(OfferRecord offer) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OfertaDetaliuPage(
          repository: widget.repository,
          initialOffer: offer,
          clients: _clients,
          jobs: _jobs,
          laborTemplates: _laborTemplates,
          clauseTemplates: _clauseTemplates,
          packageTemplates: _packageTemplates,
          onSaveOffer: _saveOfferResolved,
          currentUserEmail: widget.currentUserEmail,
          onEditOffer: (current) =>
              _openEditorInternal(existing: current, showFeedback: false),
          onDuplicateOffer: _duplicateOffer,
          onConvertToJob: _convertOfferToJob,
        ),
      ),
    );
    await _load();
  }

  Future<OfferRecord?> _convertOfferToJob(OfferRecord offer) async {
    if (offer.status != OfferStatus.accepted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Oferta trebuie sa fie acceptata pentru transformare in lucrare.',
            ),
          ),
        );
      }
      return null;
    }

    if (offer.convertedToJobId.trim().isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Oferta este deja transformata in lucrare (${offer.convertedToJobId}).',
            ),
          ),
        );
      }
      return offer;
    }

    final now = DateTime.now();
    String nextJobCode = '';
    try {
      nextJobCode = await widget.repository.nextJobCode();
    } catch (_) {
      final stamp = now.millisecondsSinceEpoch.toString();
      final tail = stamp.length > 4 ? stamp.substring(stamp.length - 4) : stamp;
      nextJobCode = 'JOB-$tail';
    }
    final title = offer.jobTitle.trim().isNotEmpty
        ? offer.jobTitle.trim()
        : offer.title.trim();
    final notes = [
      if (offer.notes.trim().isNotEmpty) offer.notes.trim(),
      'Sursa oferta: ${offer.offerNumber}',
    ].join('\n');

    final job = JobRecord(
      id: 'job-${now.microsecondsSinceEpoch}',
      jobCode: nextJobCode.trim(),
      clientId: offer.clientId,
      title: title.isEmpty ? 'Lucrare din oferta ${offer.offerNumber}' : title,
      location: '',
      city: '',
      county: '',
      contactPerson: offer.contactPersonName.trim(),
      contactPhone: offer.contactPersonPhone.trim(),
      clientDepartmentId: offer.departmentId.trim(),
      clientDepartmentName: offer.departmentName.trim(),
      contactPersonId: offer.contactPersonId.trim(),
      contactPersonEmail: offer.contactPersonEmail.trim(),
      description: 'Generata din oferta ${offer.offerNumber}',
      category: 'oferta',
      status: JobStatus.ofertata,
      startDate: null,
      dueDate: null,
      closedDate: null,
      estimatedValue:
          _displayedOfferTotal(offer) > 0 ? _displayedOfferTotal(offer) : null,
      notes: notes,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      sourceOfferId: offer.id,
      sourceOfferNumber: offer.offerNumber,
      sourceOfferTitle: offer.title,
      createdByUserId: offer.createdByUserId,
      createdByUserEmail: offer.createdByUserEmail,
      // Procente îngheţate din ofertă — garantează că situaţia coincide cu oferta
      regiePercent: offer.regiePercent,
      profitPercent: offer.profitPercent,
      vatPercent: offer.vatPercent,
      // Populare linii planificate din liniile ofertei (excluzând linii de tip text)
      liniiPlanificate: offer.lines
          .where((l) => l.lineType != OfferLineType.text)
          .toList()
          .asMap()
          .entries
          .map((entry) {
        final l = entry.value;
        return JobLine.fromOfertaLine(
          id: '',
          ofertaLineId: l.id,
          denumire: l.name,
          um: l.unit,
          cantitate: l.quantity,
          pretUnitar: l.unitPrice,
          categorie:
              l.lineType == OfferLineType.manopera ? 'manopera' : 'material',
        );
      }).toList(growable: false),
      totalOferta: _displayedOfferTotal(offer),
    );

    await _saveJobResolved(job);

    final savedJobs = await widget.repository.listJobs();
    final savedJob = savedJobs
        .where((item) => item.id == job.id)
        .fold<JobRecord?>(null, (prev, item) => prev ?? item);
    final convertedJobId = savedJob?.id ?? job.id;

    final updatedOffer = offer.copyWith(
      convertedToJobId: convertedJobId,
      convertedAt: now,
      convertedByUserId: (widget.currentUserId ?? '').trim(),
      updatedAt: now,
    );
    await _saveOfferResolved(updatedOffer);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Oferta transformata in lucrare (${savedJob?.jobCode.isNotEmpty == true ? savedJob!.jobCode : convertedJobId}).${_storageModeHint()}',
          ),
        ),
      );
    }
    return updatedOffer;
  }

  Future<void> _deleteOffer(OfferRecord item) async {
    // Protecție: oferta convertită în lucrare nu poate fi ștearsă
    if (item.isConverted) {
      final jobCode = _findJobById(item.convertedToJobId)?.jobCode.trim() ?? '';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Nu poți șterge o ofertă cu lucrare asociată'
          '${jobCode.isNotEmpty ? " ($jobCode)" : " (${item.convertedToJobId})"}'
          '. Șterge mai întâi lucrarea.',
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Șterge oferta?'),
        content: Text(
          'Oferta ${item.offerNumber} va fi ștearsă definitiv.\n'
          'Această acțiune nu poate fi anulată.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Șterge definitiv'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    // Optimistic UI
    if (mounted) setState(() => _items.removeWhere((o) => o.id == item.id));
    _deleteOfferResolved(item.id).catchError((_) => _load());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Oferta ${item.offerNumber} ștearsă.')),
    );
  }

  Future<void> _openOfferDefaults() async {
    final updated = await showDialog<OfferEditorDefaults>(
      context: context,
      builder: (context) => OfferDefaultsDialog(initial: _offerDefaults),
    );
    if (updated == null) return;
    await _defaultsStore.save(updated);
    if (!mounted) return;
    setState(() => _offerDefaults = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Valorile implicite pentru ofertă au fost salvate.')),
    );
  }

  Future<void> _openLaborTemplatesManager() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => OfferLaborTemplatesDialog(
        items: _laborTemplates,
        onSave: (item) => _standardCatalogService.upsertLaborTemplate(item),
        onImportRecommended: () =>
            _standardCatalogService.mergeRecommendedLaborTemplates(),
      ),
    );
    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Catalogul de manoperă standard a fost actualizat.')),
      );
    }
  }

  Future<void> _openClauseTemplatesManager() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => OfferCommercialClauseTemplatesDialog(
        items: _clauseTemplates,
        onSave: (item) => _standardCatalogService.upsertClauseTemplate(item),
      ),
    );
    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Catalogul de condiții comerciale a fost actualizat.')),
      );
    }
  }

  Future<void> _openPackageTemplatesManager() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => OfferCommercialPackageTemplatesDialog(
        items: _packageTemplates,
        laborTemplates: _laborTemplates,
        clauseTemplates: _clauseTemplates,
        onSave: (item) => _standardCatalogService.upsertPackageTemplate(item),
      ),
    );
    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Pachetele comerciale standard au fost actualizate.')),
      );
    }
  }

  Future<void> _openCompanyCostProfileManager() async {
    final initial = await _companyCostProfileService.load();
    if (!mounted) {
      return;
    }
    final saved = await showDialog<CompanyCostProfile>(
      context: context,
      builder: (context) => CompanyCostProfileDialog(initial: initial),
    );
    if (saved == null) {
      return;
    }
    await _companyCostProfileService.save(saved);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Costurile reale ale societății au fost salvate.${_storageModeHint()}')),
    );
  }

  int _statusCount(OfferStatus status) =>
      _items.where((item) => item.status == status).length;

  Widget _summaryChip(
    String label,
    String value, {
    IconData? icon,
    Color? color,
  }) {
    return Chip(
      avatar: icon == null ? null : Icon(icon, size: 16, color: color),
      label: Text('$label: $value'),
      backgroundColor: color?.withValues(alpha: 0.12),
      side: color == null
          ? null
          : BorderSide(color: color.withValues(alpha: 0.45)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildOffersSidePanel(List<OfferRecord> items) {
    return SidePanelCard(
      title: 'Panou Oferte',
      footer: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          FilledButton.tonalIcon(
            onPressed: _openRequirementAiDialog,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Oferta din cerinta client'),
          ),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Reincarca'),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _statusFilter = null;
                _tipOfertaFilter = 'toate';
                _clientFilter = null;
              });
              _schedulePersistFilterPreferences();
            },
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Reset filtre'),
          ),
        ],
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Cauta dupa numar, titlu, client',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          // Filtru tip ofertă
          DropdownButtonFormField<String>(
            initialValue: _tipOfertaFilter,
            decoration: const InputDecoration(labelText: 'Tip document'),
            items: const [
              DropdownMenuItem(value: 'toate', child: Text('Toate tipurile')),
              DropdownMenuItem(
                  value: 'oferta_lucrari', child: Text('Ofertă lucrări')),
              DropdownMenuItem(
                  value: 'deviz_tehnic', child: Text('Deviz tehnic')),
              DropdownMenuItem(
                  value: 'mini_oferta', child: Text('Mini ofertă')),
              DropdownMenuItem(
                  value: 'deviz_filtre', child: Text('Filtre CTA')),
            ],
            onChanged: (v) => setState(() => _tipOfertaFilter = v ?? 'toate'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<OfferStatus?>(
            initialValue: _statusFilter,
            decoration: const InputDecoration(labelText: 'Filtru status'),
            items: [
              const DropdownMenuItem<OfferStatus?>(
                value: null,
                child: Text('Toate statusurile'),
              ),
              ...OfferStatus.values.map(
                (item) => DropdownMenuItem<OfferStatus?>(
                  value: item,
                  child: _buildOfferStatusOptionLabel(item),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() => _statusFilter = value);
              _schedulePersistFilterPreferences();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _normalizeClientFilter(),
            decoration: const InputDecoration(labelText: 'Filtru client'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Toti clientii'),
              ),
              ..._clients.map(
                (item) => DropdownMenuItem<String?>(
                  value: item.id,
                  child: Text(item.name),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() => _clientFilter = value);
              _schedulePersistFilterPreferences();
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(
                'Oferte filtrate',
                items.length.toString(),
                icon: Icons.request_quote_outlined,
              ),
              _summaryChip(
                'Draft',
                _statusCount(OfferStatus.draft).toString(),
                icon: Icons.edit_note_outlined,
                color: _offerStatusBaseColor(OfferStatus.draft),
              ),
              _summaryChip(
                'Trimise',
                _statusCount(OfferStatus.sent).toString(),
                icon: Icons.send_outlined,
                color: _offerStatusBaseColor(OfferStatus.sent),
              ),
              _summaryChip(
                'Acceptate',
                _statusCount(OfferStatus.accepted).toString(),
                icon: Icons.check_circle_outline,
                color: _offerStatusBaseColor(OfferStatus.accepted),
              ),
              _summaryChip(
                'Convertite',
                _items.where((item) => item.isConverted).length.toString(),
                icon: Icons.transform_outlined,
              ),
              Chip(
                label: Text('Sursa date: ${_dataSourceUiLabel()}'),
                visualDensity: VisualDensity.compact,
              ),
              if (_dataSourceLabel == 'local_cache' &&
                  (_fallbackReason ?? '').trim().isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.cloud_off, size: 16),
                  label: Text(
                    'Motiv fallback: ${_shortCloudError(_fallbackReason!)}',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _openOfferDefaults,
                icon: const Icon(Icons.tune),
                label: const Text('Valori implicite oferta'),
              ),
              OutlinedButton.icon(
                onPressed: _openLaborTemplatesManager,
                icon: const Icon(Icons.build_circle_outlined),
                label: const Text('Catalog manopera standard'),
              ),
              OutlinedButton.icon(
                onPressed: _openClauseTemplatesManager,
                icon: const Icon(Icons.notes_outlined),
                label: const Text('Condiții comerciale standard'),
              ),
              OutlinedButton.icon(
                onPressed: _openPackageTemplatesManager,
                icon: const Icon(Icons.inventory_outlined),
                label: const Text('Pachete comerciale standard'),
              ),
              OutlinedButton.icon(
                onPressed: _openCompanyCostProfileManager,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Costuri reale societate'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOffersToolbar({required bool showPanelButton}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _openRequirementAiDialog,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Oferta din cerinta client'),
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

  Widget _buildStatusDistributionTable(List<OfferRecord> offers) {
    final rows = OfferStatus.values
        .map((status) {
          final matches =
              offers.where((item) => item.status == status).toList();
          final count = matches.length;
          final withoutVat = matches.fold<double>(
              0, (sum, item) => sum + item.subtotalComercial);
          final percentage = offers.isEmpty ? 0.0 : count / offers.length * 100;
          return (
            status: status,
            count: count,
            withoutVat: withoutVat,
            percentage: percentage,
          );
        })
        .where((row) => row.count > 0)
        .toList();

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBarWidth = constraints.maxWidth - 220;
        return Column(
          children: rows.map((row) {
            final color = _offerStatusBaseColor(row.status);
            final barWidth = maxBarWidth <= 0
                ? 0.0
                : maxBarWidth * (row.percentage.clamp(0, 100) / 100);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      row.status.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${row.count}',
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: Text(
                      _formatCurrency(row.withoutVat),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: barWidth,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${row.percentage.toStringAsFixed(0)}%'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _analysisStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisFilters() {
    final isCustom = _analysisPerioadaFilter == 'custom';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtre analiză',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Toate'),
                  selected: _analysisStatusFilters.isEmpty,
                  onSelected: (_) => _toggleAnalysisStatus('toate'),
                ),
                ...OfferStatus.values.map(
                  (status) => FilterChip(
                    label: Text(status.label),
                    selected: _analysisStatusFilters.contains(status.value),
                    onSelected: (_) => _toggleAnalysisStatus(status.value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _analysisPerioadaFilter,
                    decoration: const InputDecoration(labelText: 'Perioadă'),
                    items: const [
                      DropdownMenuItem(value: 'toate', child: Text('Toate')),
                      DropdownMenuItem(
                          value: 'luna_curenta', child: Text('Luna aceasta')),
                      DropdownMenuItem(
                          value: 'luna_trecuta', child: Text('Luna trecută')),
                      DropdownMenuItem(
                          value: 'an_curent', child: Text('An curent')),
                      DropdownMenuItem(value: 'custom', child: Text('Custom')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      if (value == 'custom') {
                        await _pickCustomAnalysisRange();
                        return;
                      }
                      setState(() {
                        _analysisPerioadaFilter = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _analysisTipFilter,
                    decoration:
                        const InputDecoration(labelText: 'Tip document'),
                    items: [
                      const DropdownMenuItem(
                        value: 'toate',
                        child: Text('Toate'),
                      ),
                      ...TipDocumentDeviz.values.map(
                        (tip) => DropdownMenuItem(
                          value: tip.value,
                          child: Text(tip.label),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _analysisTipFilter = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _analysisClientSearchController,
                    decoration: const InputDecoration(
                      labelText: 'Client',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              ],
            ),
            if (isCustom && _analysisCustomRange != null) ...[
              const SizedBox(height: 8),
              Text(
                'Interval custom: ${DateFormat('dd.MM.yyyy').format(_analysisCustomRange!.start)} - ${DateFormat('dd.MM.yyyy').format(_analysisCustomRange!.end)}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisSelectedBar() {
    if (_tabController.index != 1 || _selectedIds.isEmpty) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '☑ ${_selectedIds.length} oferte selectate',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Fără TVA: ${_formatCurrency(_selectedWithoutVatTotal())}'),
            Text('Cu TVA: ${_formatCurrency(_selectedWithVatTotal())}'),
            OutlinedButton(
              onPressed: () => setState(() => _selectedIds.clear()),
              child: const Text('Deselectează tot'),
            ),
            FilledButton.tonal(
              onPressed: _copySelectedAnalysisTotals,
              child: const Text('Copiază val.'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisTab() {
    final items = _analysisFilteredItems;
    final grouped = _groupByClient(items);
    final totalValue =
        items.fold<double>(0, (sum, item) => sum + item.totalValue);
    final acceptedValue = items
        .where((item) => item.status == OfferStatus.accepted)
        .fold<double>(0, (sum, item) => sum + item.totalValue);
    final awaitingValue = items
        .where((item) => item.status == OfferStatus.awaiting)
        .fold<double>(0, (sum, item) => sum + item.totalValue);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + AppViewportGuard.bottomSpacing(reserveForFab: true),
      ),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;
            final cards = [
              _analysisStatCard(
                label: 'Total oferte',
                value: _formatCurrency(totalValue),
                icon: Icons.request_quote_outlined,
                color: Colors.blue.shade700,
              ),
              _analysisStatCard(
                label: 'Acceptate valoare',
                value: _formatCurrency(acceptedValue),
                icon: Icons.check_circle_outline,
                color: Colors.green.shade700,
              ),
              _analysisStatCard(
                label: 'În așteptare valoare',
                value: _formatCurrency(awaitingValue),
                icon: Icons.schedule_outlined,
                color: Colors.orange.shade700,
              ),
              _analysisStatCard(
                label: 'Rata acceptare',
                value: '${_acceptanceRate(items).toStringAsFixed(0)}%',
                icon: Icons.insights_outlined,
                color: Colors.purple.shade700,
              ),
            ];
            if (isNarrow) {
              return Column(
                children: [
                  for (final card in cards) ...[
                    card,
                    const SizedBox(height: 10),
                  ],
                ],
              );
            }
            return Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  Expanded(child: cards[i]),
                  if (i != cards.length - 1) const SizedBox(width: 12),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _buildAnalysisFilters(),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Distribuție pe status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildStatusDistributionTable(items),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (grouped.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nu există oferte pentru filtrele selectate.'),
            ),
          )
        else
          ...grouped.entries.map((entry) {
            final clientName = entry.key;
            final offers = entry.value;
            final allSelected =
                offers.every((item) => _selectedIds.contains(item.id));
            final groupTotal =
                offers.fold<double>(0, (sum, item) => sum + item.totalValue);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                initiallyExpanded: _expandedGroups[clientName] ?? false,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _expandedGroups[clientName] = expanded;
                  });
                },
                title: Text(
                  '$clientName (${offers.length} oferte)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Total grup: ${_formatCurrency(groupTotal)}'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: allSelected,
                        onChanged: (value) => _toggleSelectClientGroup(
                          clientName,
                          offers,
                          value ?? false,
                        ),
                      ),
                      const Text('Selectează tot grupul'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...offers.map((offer) {
                    final selected = _selectedIds.contains(offer.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: CheckboxListTile(
                        value: selected,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) =>
                            _toggleSelectOffer(offer.id, value ?? false),
                        title: Text(
                          '${offer.offerNumber}  [${offer.status.label}]',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                offer.title.trim().isEmpty
                                    ? offer.tipDocument.label
                                    : offer.title.trim(),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  Text(
                                    'Fără TVA: ${OfferCurrencyConverter.formatMoney(ronAmount: offer.subtotalComercial, currency: offer.currency, effectiveRate: offer.effectiveExchangeRate)}',
                                  ),
                                  Text(
                                    'TVA: ${OfferCurrencyConverter.formatMoney(ronAmount: offer.vatValue, currency: offer.currency, effectiveRate: offer.effectiveExchangeRate)}',
                                  ),
                                  Text(
                                    'Cu TVA: ${OfferCurrencyConverter.formatMoney(ronAmount: offer.totalValue, currency: offer.currency, effectiveRate: offer.effectiveExchangeRate)}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _filteredItems;
    final width = MediaQuery.sizeOf(context).width;
    final showInlineSidePanel = width >= 1280;
    final sideDrawerWidth = width >= 900 ? 380.0 : width * 0.92;

    final tabBar = TabBar(
      controller: _tabController,
      tabs: const [
        Tab(text: 'Oferte'),
        Tab(text: 'Analiză'),
      ],
    );

    final offersTab = AdaptiveSidePanelLayout(
      showSidePanel: showInlineSidePanel,
      sidePanelWidth: width >= 1480 ? 388 : 360,
      sidePanel: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 16, 16),
        child: _buildOffersSidePanel(items),
      ),
      mainContent: Padding(
        padding: EdgeInsets.only(
          bottom: AppViewportGuard.bottomSpacing(reserveForFab: true),
        ),
        child: Column(
          children: [
            _buildOffersToolbar(showPanelButton: !showInlineSidePanel),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: items.isEmpty
                    ? Center(
                        child: AppEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: _emptyStateMessage(),
                        ),
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final statusColor = _offerStatusColor(item);
                          return _buildOfferCard(item, statusColor);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              title: const Text('Oferte'),
              bottom: tabBar,
              actions: [
                IconButton(
                  tooltip: 'Baza proprie de norme',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const DevizArticoleBazaPage(),
                    ),
                  ),
                  icon: const Icon(Icons.auto_fix_high_outlined),
                ),
                IconButton(
                  tooltip: 'Ofertă din cerință client',
                  onPressed: _openRequirementAiDialog,
                  icon: const Icon(Icons.auto_awesome_outlined),
                ),
                const HelpModuleButton(moduleId: 'oferte'),
                if (!showInlineSidePanel)
                  Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Filtre și panou',
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
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildOffersSidePanel(items),
                ),
              ),
            ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Adaugă ofertă'),
            )
          : null,
      bottomNavigationBar: _buildAnalysisSelectedBar(),
      body: Column(
        children: [
          if (widget.hideAppBar)
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: tabBar,
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                offersTab,
                _buildAnalysisTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card ofertă — layout compact pentru telefoane mici.
  /// Acțiunile sunt grupate într-un singur meniu ⋮ pentru a nu ocupa spațiu horizontal.
  Widget _buildOfferCard(OfferRecord item, Color statusColor) {
    final clientName = _resolveClientName(item);
    final dept = _resolveDepartmentLabel(item);
    final contact = _resolveContactLabel(item);
    final job = _resolveJobLabel(item);

    return AppCard(
      elevated: true,
      accentColor: statusColor,
      onTap: () => _openDetails(item),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Rând 1: număr + titlu + meniu acțiuni ──────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${item.offerNumber}${item.title.trim().isNotEmpty ? ' — ${item.title.trim()}' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 4),
              // Meniu compact ⋮ — toate acțiunile în popup
              SizedBox(
                width: 36,
                height: 36,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, size: 20),
                  tooltip: 'Acțiuni',
                  onSelected: (value) {
                    switch (value) {
                      case 'open':
                        _openDetails(item);
                      case 'edit':
                        _openEditor(existing: item);
                      case 'duplicate':
                        _duplicateOffer(item);
                      case 'convert':
                        _convertOfferToJob(item);
                      case 'open_job':
                        _openConvertedJob(item);
                      case 'delete':
                        _deleteOffer(item);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'open',
                      child: ListTile(
                        leading: Icon(Icons.visibility_outlined),
                        title: Text('Deschide detaliu'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (item.isConverted)
                      const PopupMenuItem(
                        value: 'open_job',
                        child: ListTile(
                          leading: Icon(Icons.open_in_new_outlined),
                          title: Text('Deschide lucrarea'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                    else ...[
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editează'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: ListTile(
                          leading: Icon(Icons.content_copy_outlined),
                          title: Text('Duplică'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (item.status == OfferStatus.accepted)
                        const PopupMenuItem(
                          value: 'convert',
                          child: ListTile(
                            leading:
                                Icon(Icons.published_with_changes_outlined),
                            title: Text('Convertește în lucrare'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading:
                              Icon(Icons.delete_outline, color: Colors.red),
                          title: Text('Șterge',
                              style: TextStyle(color: Colors.red)),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // ── Rând 2: client ───────────────────────────────────────
          if (clientName.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.person_outline, size: 13),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    clientName,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],
          // ── Rând 3: departament + contact (dacă există) ───────────
          if (dept != '-' || contact != '-') ...[
            Text(
              [
                if (dept != '-') 'Dept: $dept',
                if (contact != '-') 'Contact: $contact',
              ].join(' • '),
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
          ],
          // ── Rând 4: lucrare (dacă există) ─────────────────────────
          if (job != '-') ...[
            Text(
              'Lucrare: $job',
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
          ],
          // ── Rând 5: date + preț ───────────────────────────────────
          Text(
            '${_formatDate(item.issueDate)} → ${_formatDate(item.validUntil)}  •  ${_offerPriceSummary(item)}',
            style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 6),
          // ── Rând 6: status + expirare + meniu status rapid ─────────
          Row(
            children: [
              _buildOfferStatusChip(item),
              const SizedBox(width: 6),
              _buildExpiryChip(item),
              const SizedBox(width: 6),
              if (item.tipOferta != 'oferta_lucrari')
                _buildTipOfertaBadge(item.tipOferta),
              const Spacer(),
              _buildOfferStatusMenu(item),
            ],
          ),
          // ── Registratură / reclamație (dacă există) ───────────────
          if (item.registryNumber.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Reg: ${item.registryNumber}',
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (item.complaintId.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Reclamație: ${item.complaintNumber.trim().isEmpty ? item.complaintId.trim() : item.complaintNumber.trim()}',
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
          if (item.isConverted) ...[
            const SizedBox(height: 4),
            Text(
              'Convertit în lucrare',
              style: TextStyle(fontSize: 11, color: Colors.green.shade700),
            ),
          ],
        ],
      ),
    );
  }

  String? _normalizeClientFilter() {
    if (_clientFilter == null) return null;
    final exists = _clients.any((item) => item.id == _clientFilter);
    return exists ? _clientFilter : null;
  }
}
