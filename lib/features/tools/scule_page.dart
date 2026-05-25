import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/field_auth_models.dart';
import '../../core/help_content.dart';
import '../../core/pdf_actions_helper.dart';
import '../../core/widgets/help_button.dart';
import '../../core/auth/field_auth_repository.dart';
import '../../core/auth/field_auth_repository_factory.dart';
import '../../core/lookup_models.dart';
import '../../core/repositories/app_data_repository.dart';
import '../../core/team_models.dart';
import '../master/master_local_store.dart';
import '../notifications/notification_models.dart';
import '../notifications/notification_service.dart';
import 'scule_catalog_service.dart';
import 'scule_handover_pdf_service.dart';
import 'scule_models.dart';

class SculePage extends StatefulWidget {
  const SculePage({
    super.key,
    required this.repository,
    this.currentUserId,
    this.currentUserEmail,
  });

  final AppDataRepository repository;
  final String? currentUserId;
  final String? currentUserEmail;

  @override
  State<SculePage> createState() => _SculePageState();
}

class _SculePageState extends State<SculePage> {
  static const String _prefKeyStatus = 'scule_filter_status_v1';
  static const String _prefKeyCategory = 'scule_filter_category_v1';
  static const String _prefKeyTeam = 'scule_filter_team_v1';
  static const String _prefKeySearch = 'scule_filter_search_v1';
  static const Duration _preferencesDebounceDuration =
      Duration(milliseconds: 300);

  final SculeCatalogService _catalogService = SculeCatalogService();
  final TextEditingController _searchController = TextEditingController();
  late final FieldAuthRepository _authRepository;
  final NotificationCenterService _notificationService =
      NotificationCenterService();
  Timer? _preferencesDebounce;

  bool _loading = true;
  List<ToolInventoryItem> _items = const <ToolInventoryItem>[];
  List<String> _savedCategories = const <String>[];
  List<MasterTeam> _teams = const <MasterTeam>[];
  List<MasterEmployee> _employees = const <MasterEmployee>[];
  List<ToolHandoverDocument> _handoverDocs = const <ToolHandoverDocument>[];
  List<ToolTransferRequest> _transferRequests = const <ToolTransferRequest>[];
  List<ToolTransferNotification> _transferNotifications =
      const <ToolTransferNotification>[];
  FieldAuthSession? _authSession;
  FieldAuthUser? _authUser;
  final Set<String> _selectedToolIds = <String>{};
  ToolInventoryStatus? _statusFilter;
  String? _categoryFilter;
  String? _teamFilter;
  String? _lookupFallbackReason;
  bool _filtersVisible = false;

  int get _activeFilterCount {
    int count = 0;
    if (_statusFilter != null) count++;
    if ((_categoryFilter ?? '').isNotEmpty) count++;
    if ((_teamFilter ?? '').isNotEmpty) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return '-';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  String _dateTimeLabel(DateTime? value) {
    if (value == null) return '-';
    final date = _dateLabel(value);
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$date $hh:$mm';
  }

  @override
  void initState() {
    super.initState();
    _authRepository = FieldAuthRepositoryFactory.create();
    _searchController.addListener(() {
      setState(() {});
      _schedulePersistFilterPreferences();
    });
    _loadFilterPreferences();
    _load();
  }

  Future<void> _loadFilterPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final statusName = prefs.getString(_prefKeyStatus);
    final category = prefs.getString(_prefKeyCategory);
    final team = prefs.getString(_prefKeyTeam);
    final search = prefs.getString(_prefKeySearch) ?? '';
    setState(() {
      if (statusName != null) {
        try {
          _statusFilter = ToolInventoryStatus.values.firstWhere(
            (e) => e.name == statusName,
          );
        } catch (_) {
          _statusFilter = null;
        }
      }
      _categoryFilter = category?.isEmpty == true ? null : category;
      _teamFilter = team?.isEmpty == true ? null : team;
      if (search.isNotEmpty) {
        _searchController.text = search;
      }
    });
  }

  Future<void> _persistFilterPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_statusFilter == null) {
        await prefs.remove(_prefKeyStatus);
      } else {
        await prefs.setString(_prefKeyStatus, _statusFilter!.name);
      }
      await prefs.setString(_prefKeyCategory, _categoryFilter ?? '');
      await prefs.setString(_prefKeyTeam, _teamFilter ?? '');
      await prefs.setString(_prefKeySearch, _searchController.text.trim());
    } catch (error) {
      debugPrint('[Scule] persist filter preferences failed: $error');
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

  @override
  void dispose() {
    _preferencesDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _lookupFallbackReason = null;
    final tools = await _catalogService.listTools();
    final categories = await _catalogService.listToolCategories();
    final teams = await _loadTeams();
    final employees = await _loadEmployees();
    final docs = await _catalogService.listHandoverDocuments();
    final transferRequests = await _catalogService.listTransferRequests();
    final transferNotifications =
        await _catalogService.listTransferNotifications();
    FieldAuthSession? authSession;
    FieldAuthUser? authUser;
    try {
      authSession = await _authRepository.loadSession();
      authUser = await _resolveCurrentAuthUser(authSession);
    } catch (_) {
      authSession = null;
      authUser = null;
    }
    if (!mounted) return;
    setState(() {
      _items = [...tools]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _savedCategories = categories;
      _teams = teams;
      _employees = employees;
      _handoverDocs = docs;
      _transferRequests = transferRequests;
      _transferNotifications = transferNotifications;
      _authSession = authSession;
      _authUser = authUser;
      _selectedToolIds.removeWhere(
        (id) => !_items.any((item) => item.id == id),
      );
      _loading = false;
    });
  }

  Future<void> _notifyTransferCreated(ToolTransferRequest request) async {
    await _notificationService.dispatchEvent(
      NotificationDispatchRequest(
        eventType: NotificationEventType.toolTransferCreated,
        title: 'Cerere transfer scula',
        message:
            '${request.toolName} (${request.inventoryCode.isEmpty ? '-' : request.inventoryCode}) | ${request.sourceEmployeeName} -> ${request.targetEmployeeName} | Status: ${request.status.label}',
        sourceModule: 'tools',
        sourceEntityId: request.id,
        sourceLabel: request.toolName.trim().isEmpty
            ? 'Transfer scula'
            : request.toolName.trim(),
        recipientEmployeeIds: <String>[
          if (request.sourceEmployeeId.trim().isNotEmpty)
            request.sourceEmployeeId.trim(),
          if (request.targetEmployeeId.trim().isNotEmpty)
            request.targetEmployeeId.trim(),
        ],
        recipientUserIds: request.createdByUserId.trim().isEmpty
            ? const <String>[]
            : <String>[request.createdByUserId.trim()],
        recipientEmails: request.createdByUserEmail.trim().isEmpty
            ? const <String>[]
            : <String>[request.createdByUserEmail.trim()],
        metadata: <String, dynamic>{
          'transfer_status': request.status.value,
          'tool_id': request.toolId,
        },
      ),
    );
  }

  Future<void> _notifyTransferProcessed(
    ToolTransferRequest request, {
    required bool approved,
  }) async {
    await _notificationService.dispatchEvent(
      NotificationDispatchRequest(
        eventType: NotificationEventType.toolTransferReceived,
        title: approved ? 'Transfer scula aprobat' : 'Transfer scula respins',
        message:
            '${request.toolName} | ${request.sourceEmployeeName} -> ${request.targetEmployeeName} | Status: ${request.status.label}${request.decisionNotes.trim().isEmpty ? '' : ' | Observatii: ${request.decisionNotes.trim()}'}',
        sourceModule: 'tools',
        sourceEntityId: request.id,
        sourceLabel: request.toolName.trim().isEmpty
            ? 'Transfer scula'
            : request.toolName.trim(),
        recipientEmployeeIds: <String>[
          if (request.sourceEmployeeId.trim().isNotEmpty)
            request.sourceEmployeeId.trim(),
          if (request.targetEmployeeId.trim().isNotEmpty)
            request.targetEmployeeId.trim(),
        ],
        recipientUserIds: request.processedByUserId.trim().isEmpty
            ? const <String>[]
            : <String>[request.processedByUserId.trim()],
        recipientEmails: request.processedByUserEmail.trim().isEmpty
            ? const <String>[]
            : <String>[request.processedByUserEmail.trim()],
        metadata: <String, dynamic>{
          'transfer_status': request.status.value,
          'tool_id': request.toolId,
          'decision_notes': request.decisionNotes,
        },
      ),
    );
  }

  Future<List<MasterTeam>> _loadTeams() async {
    try {
      final rows = await widget.repository.listTeams();
      final mapped = rows
          .where((row) => row.id.trim().isNotEmpty)
          .map(_masterTeamFromRepository)
          .toList(growable: false);
      if (mapped.isNotEmpty) {
        await MasterLocalStore.writeTeams(mapped);
        return mapped;
      }
      return MasterLocalStore.readTeams();
    } catch (error) {
      _lookupFallbackReason = _shortError(error);
      return MasterLocalStore.readTeams();
    }
  }

  Future<List<MasterEmployee>> _loadEmployees() async {
    try {
      final rows = await widget.repository.listEmployeesLookup();
      final mapped = rows
          .where((row) => row.id.trim().isNotEmpty)
          .map(_masterEmployeeFromLookup)
          .toList(growable: false);
      if (mapped.isNotEmpty) {
        await MasterLocalStore.writeEmployees(mapped);
        return mapped;
      }
      return MasterLocalStore.readEmployees();
    } catch (error) {
      _lookupFallbackReason ??= _shortError(error);
      return MasterLocalStore.readEmployees();
    }
  }

  MasterTeam _masterTeamFromRepository(Team row) {
    return MasterTeam(
      id: row.id.trim(),
      name: row.name.trim(),
      notes: row.notes.trim(),
      memberIds: row.memberEmployeeIds
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
    );
  }

  MasterEmployee _masterEmployeeFromLookup(EmployeeLookup row) {
    return MasterEmployee(
      id: row.id.trim(),
      name: row.name.trim(),
      role: row.role.trim(),
      active: row.active,
      laborCostType: row.laborCostType,
      costLunar: row.costLunar,
      tarifOrar: row.tarifOrar,
      oreLunareStandard: row.oreLunareStandard,
      dailyAllowance: row.perDiemPerDay,
      defaultLodgingCost: row.lodgingPerDay,
      requiresLodgingByDefault: row.requiresLodgingByDefault,
    );
  }

  String _shortError(Object error) {
    final raw = error.toString().replaceAll('\n', ' ').trim();
    if (raw.isEmpty) return 'necunoscuta';
    return raw.length > 140 ? '${raw.substring(0, 140)}...' : raw;
  }

  Future<FieldAuthUser?> _resolveCurrentAuthUser(
    FieldAuthSession? session,
  ) async {
    if (session == null) return null;
    try {
      final users = await _authRepository.listUsers();
      for (final user in users) {
        if (user.id.trim() == session.userId.trim()) return user;
      }
      final email = session.email.trim().toLowerCase();
      for (final user in users) {
        if (user.email.trim().toLowerCase() == email) return user;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  FieldUserRole? get _currentRole => _authSession?.role ?? _authUser?.role;

  _ToolCurrentHolder _currentHolderOf(ToolInventoryItem item) {
    final employeeId = item.assignedEmployeeId.trim();
    final employeeName = item.assignedEmployeeName.trim();
    if (employeeId.isNotEmpty || employeeName.isNotEmpty) {
      return _ToolCurrentHolder.employee;
    }
    final teamId = item.assignedTeamId.trim();
    final teamName = item.assignedTeamName.trim();
    if (teamId.isNotEmpty || teamName.isNotEmpty) {
      return _ToolCurrentHolder.team;
    }
    return _ToolCurrentHolder.none;
  }

  bool get _canApproveTransfers {
    final role = _currentRole;
    return role == FieldUserRole.admin || role == FieldUserRole.office;
  }

  bool _canRequestTransfer(ToolInventoryItem item) {
    if (item.status != ToolInventoryStatus.atribuita) return false;
    if (_currentHolderOf(item) != _ToolCurrentHolder.employee) return false;
    final role = _currentRole;
    if (role == FieldUserRole.admin || role == FieldUserRole.office) {
      return true;
    }
    final currentEmployeeId = _authUser?.employeeId.trim() ?? '';
    final currentTeamId = _authUser?.teamId.trim() ?? '';
    final assignedEmployeeId = item.assignedEmployeeId.trim();
    if (assignedEmployeeId.isNotEmpty && currentEmployeeId.isNotEmpty) {
      return assignedEmployeeId == currentEmployeeId;
    }
    if (currentTeamId.isNotEmpty && item.assignedTeamId.trim().isNotEmpty) {
      return currentTeamId == item.assignedTeamId.trim();
    }
    if (role == FieldUserRole.teamLead) {
      return currentTeamId.isNotEmpty &&
          currentTeamId == item.assignedTeamId.trim();
    }
    return false;
  }

  Future<MasterEmployee?> _pickEmployeeDialog({
    required String title,
    required List<MasterEmployee> employees,
    String? initialEmployeeId,
  }) async {
    if (employees.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu exista angajati disponibili.')),
      );
      return null;
    }
    String? selectedId = (initialEmployeeId ?? '').trim();
    if (selectedId.isEmpty ||
        !employees.any((row) => row.id.trim() == selectedId)) {
      selectedId = employees.first.id;
    }
    final selected = await showDialog<MasterEmployee>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: DropdownButtonFormField<String>(
          initialValue: selectedId,
          decoration: const InputDecoration(labelText: 'Angajat'),
          items: employees
              .map(
                (row) => DropdownMenuItem<String>(
                  value: row.id,
                  child: Text(row.name),
                ),
              )
              .toList(growable: false),
          onChanged: (value) => selectedId = (value ?? '').trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () {
              final value = (selectedId ?? '').trim();
              if (value.isEmpty) return;
              MasterEmployee? found;
              for (final row in employees) {
                if (row.id == value) {
                  found = row;
                  break;
                }
              }
              if (found == null) return;
              Navigator.of(context).pop(found);
            },
            child: const Text('Continua'),
          ),
        ],
      ),
    );
    return selected;
  }

  MasterEmployee? _employeeById(String employeeId) {
    final id = employeeId.trim();
    if (id.isEmpty) return null;
    for (final row in _employees) {
      if (row.id == id) return row;
    }
    return null;
  }

  MasterTeam? _teamById(String teamId) {
    final id = teamId.trim();
    if (id.isEmpty) return null;
    for (final row in _teams) {
      if (row.id == id) return row;
    }
    return null;
  }

  List<String> get _categoryOptions {
    final values = <String>{
      ..._savedCategories
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
      ..._items
          .map((item) => item.category.trim())
          .where((value) => value.isNotEmpty),
    }.toList(growable: false);
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  String _nextInventoryCode() {
    var max = 0;
    final regex = RegExp(r'^SC-(\d+)$', caseSensitive: false);
    for (final item in _items) {
      final code = item.inventoryCode.trim().toUpperCase();
      final match = regex.firstMatch(code);
      if (match == null) continue;
      final parsed = int.tryParse(match.group(1) ?? '');
      if (parsed != null && parsed > max) {
        max = parsed;
      }
    }
    return 'SC-${(max + 1).toString().padLeft(4, '0')}';
  }

  List<ToolInventoryItem> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    return _items.where((item) {
      if (_statusFilter != null && item.status != _statusFilter) {
        return false;
      }
      if ((_teamFilter ?? '').trim().isNotEmpty &&
          item.assignedTeamId.trim() != _teamFilter!.trim()) {
        return false;
      }
      if ((_categoryFilter ?? '').trim().isNotEmpty &&
          item.category.trim().toLowerCase() !=
              _categoryFilter!.trim().toLowerCase()) {
        return false;
      }
      if (query.isEmpty) return true;
      final name = item.name.toLowerCase();
      final code = item.inventoryCode.toLowerCase();
      final serial = item.serialNumber.toLowerCase();
      return name.contains(query) ||
          code.contains(query) ||
          serial.contains(query);
    }).toList(growable: false);
  }

  Future<void> _saveTool(ToolInventoryItem item) async {
    await _catalogService.saveToolCategory(item.category);
    await _catalogService.upsertTool(item);
    await _load();
  }

  Future<void> _deleteTool(ToolInventoryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ștergere sculă'),
        content: Text('Sigur stergi "${item.name}"?'),
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
    await _catalogService.deleteTool(item.id);
    await _load();
  }

  Future<void> _openEditor([ToolInventoryItem? existing]) async {
    final saved = await showDialog<ToolInventoryItem>(
      context: context,
      builder: (_) => _ToolEditorDialog(
        existing: existing,
        categoryOptions: _categoryOptions,
        initialInventoryCode: existing == null ? _nextInventoryCode() : null,
      ),
    );
    if (saved == null) return;
    await _saveTool(saved);
    if (existing == null) return;

    if (existing.status != saved.status) {
      ToolMovementEventType? type;
      if (saved.status == ToolInventoryStatus.service) {
        type = ToolMovementEventType.service;
      } else if (saved.status == ToolInventoryStatus.lipsa) {
        type = ToolMovementEventType.lipsa;
      } else if (saved.status == ToolInventoryStatus.casata) {
        type = ToolMovementEventType.casata;
      }
      if (type != null) {
        await _appendMovementEvent(
          tool: saved,
          eventType: type,
          notes: 'Status actualizat din editor la ${saved.status.label}.',
        );
        return;
      }
    }

    if (_hasEditableChanges(existing, saved)) {
      await _appendMovementEvent(
        tool: saved,
        eventType: ToolMovementEventType.editata,
        notes: 'Datele sculei au fost actualizate din editor.',
      );
    }
  }

  bool _hasEditableChanges(ToolInventoryItem before, ToolInventoryItem after) {
    return before.name != after.name ||
        before.category != after.category ||
        before.brand != after.brand ||
        before.model != after.model ||
        before.description != after.description ||
        before.serialNumber != after.serialNumber ||
        before.inventoryCode != after.inventoryCode ||
        before.purchaseDate != after.purchaseDate ||
        before.purchaseValue != after.purchaseValue ||
        before.unit != after.unit ||
        before.notes != after.notes;
  }

  Future<MasterTeam?> _pickTeamDialog({
    String title = 'Selecteaza echipa',
    MasterTeam? initial,
  }) async {
    if (_teams.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu exista echipe definite.')),
      );
      return null;
    }
    String? selectedId = initial?.id ?? _teams.first.id;
    final selected = await showDialog<MasterTeam>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: DropdownButtonFormField<String>(
          initialValue: selectedId,
          decoration: const InputDecoration(labelText: 'Echipa'),
          items: _teams
              .map(
                (team) => DropdownMenuItem<String>(
                  value: team.id,
                  child: Text(team.name),
                ),
              )
              .toList(growable: false),
          onChanged: (value) => selectedId = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () {
              final value = (selectedId ?? '').trim();
              MasterTeam? found;
              for (final team in _teams) {
                if (team.id == value) {
                  found = team;
                  break;
                }
              }
              if (found == null) return;
              Navigator.of(context).pop(found);
            },
            child: const Text('Continua'),
          ),
        ],
      ),
    );
    return selected;
  }

  Future<void> _assignTool(ToolInventoryItem item) async {
    final holder = _currentHolderOf(item);
    if (holder != _ToolCurrentHolder.none ||
        item.status != ToolInventoryStatus.disponibila) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Atribuirea initiala este permisa doar cand scula nu are holder si este Disponibila.',
          ),
        ),
      );
      return;
    }
    final pick = await _pickTeamDialog(title: 'Atribuie echipei');
    if (pick == null) return;
    final now = DateTime.now();
    final updated = item.copyWith(
      status: ToolInventoryStatus.atribuita,
      assignedTeamId: pick.id,
      assignedTeamName: pick.name,
      assignedEmployeeId: '',
      assignedEmployeeName: '',
      assignedAt: now,
      assignedByUserId: (widget.currentUserId ?? '').trim(),
      assignedByUserEmail: (widget.currentUserEmail ?? '').trim(),
      updatedAt: now,
    );
    await _saveTool(updated);
    await _appendMovementEvent(
      tool: updated,
      eventType: ToolMovementEventType.atribuita,
      notes: 'Scula atribuita echipei ${pick.name}.',
    );
  }

  Future<void> _handoverToolToEmployee(ToolInventoryItem item) async {
    if (_currentHolderOf(item) != _ToolCurrentHolder.team ||
        item.status != ToolInventoryStatus.atribuita) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Predarea catre angajat este permisa doar pentru scule aflate la echipa.',
          ),
        ),
      );
      return;
    }
    final teamId = item.assignedTeamId.trim();
    final candidates = _employees.where((row) {
      if (!row.active) return false;
      if (teamId.isEmpty) return true;
      return row.teamId.trim() == teamId;
    }).toList(growable: false);
    final selected = await _pickEmployeeDialog(
      title: 'Preda angajatului',
      employees: candidates,
    );
    if (selected == null) return;
    final now = DateTime.now();
    final updated = item.copyWith(
      assignedEmployeeId: selected.id,
      assignedEmployeeName: selected.name.trim(),
      assignedAt: now,
      assignedByUserId: (widget.currentUserId ?? '').trim(),
      assignedByUserEmail: (widget.currentUserEmail ?? '').trim(),
      updatedAt: now,
    );
    await _saveTool(updated);
    await _appendMovementEvent(
      tool: updated,
      eventType: ToolMovementEventType.editata,
      notes: 'Scula predata angajatului ${selected.name}.',
    );
  }

  Future<void> _returnToolToTeam(ToolInventoryItem item) async {
    if (_currentHolderOf(item) != _ToolCurrentHolder.employee ||
        item.status != ToolInventoryStatus.atribuita) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Returnarea la echipa este permisa doar pentru scule aflate la angajat.',
          ),
        ),
      );
      return;
    }
    final now = DateTime.now();
    final updated = item.copyWith(
      assignedEmployeeId: '',
      assignedEmployeeName: '',
      assignedAt: now,
      assignedByUserId: (widget.currentUserId ?? '').trim(),
      assignedByUserEmail: (widget.currentUserEmail ?? '').trim(),
      updatedAt: now,
    );
    await _saveTool(updated);
    await _appendMovementEvent(
      tool: updated,
      eventType: ToolMovementEventType.editata,
      notes:
          'Scula returnata la echipa ${updated.assignedTeamName.trim().isEmpty ? "-" : updated.assignedTeamName.trim()}.',
    );
  }

  Future<void> _moveToolToAnotherTeam(ToolInventoryItem item) async {
    final holder = _currentHolderOf(item);
    if (holder == _ToolCurrentHolder.none ||
        item.status != ToolInventoryStatus.atribuita) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mutarea la alta echipa este permisa doar pentru scule deja atribuite.',
          ),
        ),
      );
      return;
    }
    MasterTeam? initial;
    final currentTeamId = item.assignedTeamId.trim();
    if (currentTeamId.isNotEmpty) {
      initial = _teamById(currentTeamId);
    }
    final pick = await _pickTeamDialog(
      title: 'Muta la alta echipa',
      initial: initial,
    );
    if (pick == null) return;
    if (currentTeamId.isNotEmpty && pick.id == currentTeamId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecteaza o echipa diferita.')),
      );
      return;
    }
    final now = DateTime.now();
    final updated = item.copyWith(
      assignedTeamId: pick.id,
      assignedTeamName: pick.name,
      assignedEmployeeId: '',
      assignedEmployeeName: '',
      assignedAt: now,
      assignedByUserId: (widget.currentUserId ?? '').trim(),
      assignedByUserEmail: (widget.currentUserEmail ?? '').trim(),
      updatedAt: now,
    );
    await _saveTool(updated);
    await _appendMovementEvent(
      tool: updated,
      eventType: ToolMovementEventType.atribuita,
      notes: 'Scula mutata la echipa ${pick.name}.',
    );
  }

  Future<void> _retractTool(ToolInventoryItem item) async {
    final now = DateTime.now();
    final updated = item.copyWith(
      status: ToolInventoryStatus.disponibila,
      assignedTeamId: '',
      assignedTeamName: '',
      assignedEmployeeId: '',
      assignedEmployeeName: '',
      clearAssignedAt: true,
      assignedByUserId: '',
      assignedByUserEmail: '',
      updatedAt: now,
    );
    await _saveTool(updated);
    await _appendMovementEvent(
      tool: updated,
      eventType: ToolMovementEventType.retrasa,
      notes: 'Scula retrasa de la echipa.',
    );
  }

  Future<void> _appendMovementEvent({
    required ToolInventoryItem tool,
    required ToolMovementEventType eventType,
    String notes = '',
  }) async {
    final now = DateTime.now();
    final event = ToolMovementEvent(
      id: 'tool-move-${now.microsecondsSinceEpoch}',
      toolId: tool.id,
      eventType: eventType,
      eventDate: now,
      teamId: tool.assignedTeamId.trim(),
      teamName: tool.assignedTeamName.trim(),
      performedByUserId: (widget.currentUserId ?? '').trim(),
      performedByUserEmail: (widget.currentUserEmail ?? '').trim(),
      notes: notes.trim(),
    );
    await _catalogService.appendMovementEvent(event);
  }

  List<ToolTransferRequest> get _pendingTransferRequests {
    return _transferRequests
        .where(
          (row) => row.status == ToolTransferRequestStatus.inAsteptareAprobare,
        )
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  ToolTransferNotification? _pendingNotificationForRequest(String requestId) {
    final id = requestId.trim();
    if (id.isEmpty) return null;
    for (final row in _transferNotifications) {
      if (row.requestId.trim() == id && row.processed == false) {
        return row;
      }
    }
    return null;
  }

  bool _isTransferRequestSourceStillValid(
    ToolTransferRequest request,
    ToolInventoryItem tool,
  ) {
    final requestSourceEmployeeId = request.sourceEmployeeId.trim();
    if (requestSourceEmployeeId.isEmpty) {
      return true;
    }
    return tool.assignedEmployeeId.trim() == requestSourceEmployeeId;
  }

  _TransferApprovalUiState _transferApprovalUiState(
    ToolTransferRequest request,
  ) {
    if (!_canApproveTransfers) {
      return const _TransferApprovalUiState(
        canApprove: false,
        reason: 'Doar admin/office pot aproba.',
      );
    }
    if (request.status != ToolTransferRequestStatus.inAsteptareAprobare) {
      return const _TransferApprovalUiState(
        canApprove: false,
        reason: 'Cererea nu mai este in asteptare aprobare.',
      );
    }

    ToolInventoryItem? tool;
    for (final row in _items) {
      if (row.id == request.toolId) {
        tool = row;
        break;
      }
    }
    if (tool == null) {
      return const _TransferApprovalUiState(
        canApprove: false,
        reason: 'Scula nu mai exista.',
      );
    }
    if (tool.status != ToolInventoryStatus.atribuita) {
      return _TransferApprovalUiState(
        canApprove: false,
        reason: 'Status invalid pentru mutare: ${tool.status.label}.',
      );
    }
    if (!_isTransferRequestSourceStillValid(request, tool)) {
      return const _TransferApprovalUiState(
        canApprove: false,
        reason: 'Scula nu mai apartine angajatului sursa din cerere.',
      );
    }
    if (tool.assignedEmployeeId.trim() == request.targetEmployeeId.trim() &&
        request.targetEmployeeId.trim().isNotEmpty) {
      return const _TransferApprovalUiState(
        canApprove: false,
        reason: 'Scula este deja la angajatul tinta.',
      );
    }
    return const _TransferApprovalUiState(canApprove: true);
  }

  Future<void> _requestTransfer(ToolInventoryItem item) async {
    if (!_canRequestTransfer(item)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nu ai dreptul sa initiezi mutarea pentru aceasta scula.',
          ),
        ),
      );
      return;
    }
    if (item.status != ToolInventoryStatus.atribuita) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Mutarea se poate solicita doar pentru scule atribuite.'),
        ),
      );
      return;
    }
    if (_currentHolderOf(item) != _ToolCurrentHolder.employee) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mutarea intre angajati este permisa doar cand scula este la un angajat.',
          ),
        ),
      );
      return;
    }
    final hasPendingForTool = _transferRequests.any(
      (row) =>
          row.toolId == item.id &&
          row.status == ToolTransferRequestStatus.inAsteptareAprobare,
    );
    if (hasPendingForTool) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Exista deja o cerere de mutare in asteptare pentru aceasta scula.',
          ),
        ),
      );
      return;
    }

    final activeEmployees =
        _employees.where((row) => row.active).toList(growable: false);
    if (activeEmployees.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu exista angajati activi disponibili.')),
      );
      return;
    }

    final sourceEmployeeId = item.assignedEmployeeId.trim().isNotEmpty
        ? item.assignedEmployeeId.trim()
        : (_authUser?.employeeId.trim() ?? '');
    String sourceEmployeeName = item.assignedEmployeeName.trim();
    if (sourceEmployeeName.isEmpty && sourceEmployeeId.isNotEmpty) {
      sourceEmployeeName = _employeeById(sourceEmployeeId)?.name.trim() ?? '';
    }
    if (sourceEmployeeName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sursa angajat lipseste pe scula. Completeaza intai holderul de tip angajat.',
          ),
        ),
      );
      return;
    }

    String? targetEmployeeId;
    for (final row in activeEmployees) {
      if (row.id != sourceEmployeeId) {
        targetEmployeeId = row.id;
        break;
      }
    }
    targetEmployeeId ??= activeEmployees.first.id;
    final notesCtrl = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        String selectedTargetId = targetEmployeeId ?? '';
        return AlertDialog(
          title: const Text('Solicita mutare scula'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scula: ${item.name}'),
                Text(
                  'Cod inventar: ${item.inventoryCode.trim().isEmpty ? '-' : item.inventoryCode.trim()}',
                ),
                const SizedBox(height: 8),
                Text('Sursa: $sourceEmployeeName'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedTargetId,
                  decoration: const InputDecoration(
                    labelText: 'Angajat destinatie',
                  ),
                  items: activeEmployees
                      .map(
                        (row) => DropdownMenuItem<String>(
                          value: row.id,
                          child: Text(
                            row.teamId.trim().isEmpty
                                ? row.name
                                : '${row.name} (${row.teamId})',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    selectedTargetId = (value ?? '').trim();
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: notesCtrl,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motiv / observatii (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Renunță'),
            ),
            FilledButton(
              onPressed: () {
                final target = selectedTargetId.trim();
                if (target.isEmpty) return;
                Navigator.of(
                  dialogContext,
                ).pop(<String>[target, notesCtrl.text.trim()]);
              },
              child: const Text('Trimite cererea'),
            ),
          ],
        );
      },
    );
    notesCtrl.dispose();
    if (result == null) return;

    final targetId = result.isNotEmpty ? result.first : '';
    final notes = result.length > 1 ? result[1] : '';
    if (targetId.trim().isEmpty) return;
    if (sourceEmployeeId.isNotEmpty && targetId.trim() == sourceEmployeeId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Destinatia trebuie sa fie un alt angajat.'),
        ),
      );
      return;
    }
    final target = _employeeById(targetId);
    if (target == null || !target.active) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Angajatul destinatie nu mai este valid.'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final request = ToolTransferRequest(
      id: 'tool-transfer-${now.microsecondsSinceEpoch}',
      toolId: item.id,
      inventoryCode: item.inventoryCode.trim(),
      toolName: item.name.trim(),
      sourceEmployeeId: sourceEmployeeId,
      sourceEmployeeName: sourceEmployeeName,
      targetEmployeeId: target.id,
      targetEmployeeName: target.name.trim(),
      notes: notes,
      status: ToolTransferRequestStatus.inAsteptareAprobare,
      createdAt: now,
      createdByUserId: (widget.currentUserId ?? '').trim(),
      createdByUserEmail: (widget.currentUserEmail ?? '').trim(),
    );
    final notification = ToolTransferNotification(
      id: 'tool-transfer-notif-${now.microsecondsSinceEpoch}',
      requestId: request.id,
      toolId: request.toolId,
      inventoryCode: request.inventoryCode,
      toolName: request.toolName,
      sourceEmployeeId: request.sourceEmployeeId,
      sourceEmployeeName: request.sourceEmployeeName,
      targetEmployeeId: request.targetEmployeeId,
      targetEmployeeName: request.targetEmployeeName,
      message:
          'Cerere mutare scula: ${request.toolName} (${request.inventoryCode.isEmpty ? '-' : request.inventoryCode}) din ${request.sourceEmployeeName} catre ${request.targetEmployeeName}.',
      createdAt: now,
      createdByUserId: request.createdByUserId,
      createdByUserEmail: request.createdByUserEmail,
      processed: false,
    );
    await _catalogService.saveTransferRequest(request);
    await _catalogService.saveTransferNotification(notification);
    await _notifyTransferCreated(request);
    await _appendMovementEvent(
      tool: item,
      eventType: ToolMovementEventType.cerereMutareCreata,
      notes:
          'Cerere mutare creata: ${request.sourceEmployeeName} -> ${request.targetEmployeeName}.',
    );
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cererea de mutare a fost trimisa pentru aprobare.'),
      ),
    );
  }

  Future<void> _approveTransferRequest(ToolTransferRequest request) async {
    if (!_canApproveTransfers) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu ai drept de aprobare.')),
      );
      return;
    }
    if (request.status != ToolTransferRequestStatus.inAsteptareAprobare) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cererea nu mai este in asteptare.')),
      );
      return;
    }
    ToolInventoryItem? tool;
    for (final row in _items) {
      if (row.id == request.toolId) {
        tool = row;
        break;
      }
    }
    if (tool == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scula nu mai exista. Cererea nu poate fi aprobata.'),
        ),
      );
      return;
    }
    if (tool.status != ToolInventoryStatus.atribuita) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mutarea nu este permisa pentru statusul ${tool.status.label}.',
          ),
        ),
      );
      return;
    }
    if (!_isTransferRequestSourceStillValid(request, tool)) {
      final currentHolderName = tool.assignedEmployeeName.trim().isEmpty
          ? '-'
          : tool.assignedEmployeeName.trim();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cererea nu mai este valida: scula nu mai este la sursa initiala (${request.sourceEmployeeName} -> acum: $currentHolderName).',
          ),
        ),
      );
      return;
    }
    final targetEmployee = _employeeById(request.targetEmployeeId);
    if (targetEmployee == null || !targetEmployee.active) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Angajatul destinatie nu mai este valid.'),
        ),
      );
      return;
    }
    final currentAssignedEmployeeId = tool.assignedEmployeeId.trim();
    if (currentAssignedEmployeeId.isNotEmpty &&
        currentAssignedEmployeeId == targetEmployee.id) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scula este deja alocata acestui angajat.'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final targetTeam = _teamById(targetEmployee.teamId);
    final updatedTool = tool.copyWith(
      assignedEmployeeId: targetEmployee.id,
      assignedEmployeeName: targetEmployee.name.trim(),
      assignedTeamId: targetEmployee.teamId.trim().isEmpty
          ? tool.assignedTeamId
          : targetEmployee.teamId.trim(),
      assignedTeamName: targetTeam?.name.trim().isNotEmpty == true
          ? targetTeam!.name.trim()
          : tool.assignedTeamName,
      assignedAt: now,
      assignedByUserId: (widget.currentUserId ?? '').trim(),
      assignedByUserEmail: (widget.currentUserEmail ?? '').trim(),
      updatedAt: now,
    );
    await _catalogService.upsertTool(updatedTool);

    final updatedRequest = request.copyWith(
      status: ToolTransferRequestStatus.aprobata,
      processedAt: now,
      processedByUserId: (widget.currentUserId ?? '').trim(),
      processedByUserEmail: (widget.currentUserEmail ?? '').trim(),
      decisionNotes: 'Aprobata in aplicatie.',
    );
    await _catalogService.saveTransferRequest(updatedRequest);
    await _notifyTransferProcessed(updatedRequest, approved: true);

    final pendingNotification = _pendingNotificationForRequest(request.id);
    if (pendingNotification != null) {
      final processedNotification = pendingNotification.copyWith(
        processed: true,
        processedAt: now,
        processedByUserId: (widget.currentUserId ?? '').trim(),
        processedByUserEmail: (widget.currentUserEmail ?? '').trim(),
      );
      await _catalogService.saveTransferNotification(processedNotification);
    }

    await _appendMovementEvent(
      tool: updatedTool,
      eventType: ToolMovementEventType.cerereMutareAprobata,
      notes:
          'Cerere mutare aprobata: ${request.sourceEmployeeName} -> ${request.targetEmployeeName}.',
    );
    await _appendMovementEvent(
      tool: updatedTool,
      eventType: ToolMovementEventType.mutareEfectuata,
      notes: 'Mutare efectuata la ${request.targetEmployeeName}.',
    );
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Cererea a fost aprobata. Mutarea aplicata.')),
    );
  }

  Future<void> _rejectTransferRequest(ToolTransferRequest request) async {
    if (!_canApproveTransfers) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu ai drept de aprobare.')),
      );
      return;
    }
    if (request.status != ToolTransferRequestStatus.inAsteptareAprobare) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cererea nu mai este in asteptare.')),
      );
      return;
    }
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Respinge cererea de mutare'),
        content: TextField(
          textCapitalization: TextCapitalization.sentences,
          controller: reasonCtrl,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motiv respingere (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Respinge'),
          ),
        ],
      ),
    );
    final decisionNotes = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (confirmed != true) return;

    final now = DateTime.now();
    final updatedRequest = request.copyWith(
      status: ToolTransferRequestStatus.respinsa,
      processedAt: now,
      processedByUserId: (widget.currentUserId ?? '').trim(),
      processedByUserEmail: (widget.currentUserEmail ?? '').trim(),
      decisionNotes: decisionNotes,
    );
    await _catalogService.saveTransferRequest(updatedRequest);
    await _notifyTransferProcessed(updatedRequest, approved: false);

    final pendingNotification = _pendingNotificationForRequest(request.id);
    if (pendingNotification != null) {
      final processedNotification = pendingNotification.copyWith(
        processed: true,
        processedAt: now,
        processedByUserId: (widget.currentUserId ?? '').trim(),
        processedByUserEmail: (widget.currentUserEmail ?? '').trim(),
      );
      await _catalogService.saveTransferNotification(processedNotification);
    }

    ToolInventoryItem? tool;
    for (final row in _items) {
      if (row.id == request.toolId) {
        tool = row;
        break;
      }
    }
    if (tool != null) {
      await _appendMovementEvent(
        tool: tool,
        eventType: ToolMovementEventType.cerereMutareRespinsa,
        notes:
            'Cerere mutare respinsa (${request.sourceEmployeeName} -> ${request.targetEmployeeName})'
            '${decisionNotes.isEmpty ? '' : ': $decisionNotes'}',
      );
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cererea a fost respinsa.')),
    );
  }

  String _responsibleNameForTeam(String teamId) {
    final value = teamId.trim();
    if (value.isEmpty) return '-';
    MasterTeam? selected;
    for (final team in _teams) {
      if (team.id == value) {
        selected = team;
        break;
      }
    }
    if (selected == null || selected.memberIds.isEmpty) return '-';
    for (final employeeId in selected.memberIds) {
      for (final employee in _employees) {
        if (employee.id == employeeId && employee.name.trim().isNotEmpty) {
          return employee.name.trim();
        }
      }
    }
    return '-';
  }

  String _nextHandoverNumber(DateTime date) {
    final year = date.year;
    final prefix = 'PV-SCULE-$year-';
    var max = 0;
    for (final item in _handoverDocs) {
      final number = item.documentNumber.trim().toUpperCase();
      if (!number.startsWith(prefix)) continue;
      final seq = int.tryParse(number.substring(prefix.length));
      if (seq != null && seq > max) {
        max = seq;
      }
    }
    return '$prefix${(max + 1).toString().padLeft(4, '0')}';
  }

  ToolHandoverLine _toHandoverLine(ToolInventoryItem item) {
    final brandModel = [
      item.brand.trim(),
      item.model.trim(),
    ].where((value) => value.isNotEmpty).join(' / ');
    final notesParts = <String>[];
    if (item.description.trim().isNotEmpty) {
      notesParts.add(item.description.trim());
    }
    if (item.notes.trim().isNotEmpty) {
      notesParts.add(item.notes.trim());
    }
    return ToolHandoverLine(
      name: item.name,
      category: item.category.trim().isEmpty ? '-' : item.category,
      brandModel: brandModel.isEmpty ? '-' : brandModel,
      inventoryCode:
          item.inventoryCode.trim().isEmpty ? '-' : item.inventoryCode,
      serialNumber: item.serialNumber.trim().isEmpty ? '-' : item.serialNumber,
      statusLabel: item.status.label,
      notes: notesParts.join(' | '),
    );
  }

  Future<void> _generateHandoverForTool(ToolInventoryItem item) async {
    await _generateHandover(sourceTools: <ToolInventoryItem>[item]);
  }

  Future<void> _generateHandover({
    required List<ToolInventoryItem> sourceTools,
    MasterTeam? forcedTeam,
  }) async {
    if (sourceTools.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu exista scule selectate pentru PV.')),
      );
      return;
    }

    MasterTeam? team;
    if (forcedTeam != null) {
      team = forcedTeam;
    } else if (sourceTools.length == 1) {
      final assignedId = sourceTools.first.assignedTeamId.trim();
      if (assignedId.isNotEmpty) {
        for (final row in _teams) {
          if (row.id == assignedId) {
            team = row;
            break;
          }
        }
      }
    } else {
      final assignedTeamIds = sourceTools
          .map((row) => row.assignedTeamId.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      if (assignedTeamIds.length == 1) {
        final singleId = assignedTeamIds.first;
        for (final row in _teams) {
          if (row.id == singleId) {
            team = row;
            break;
          }
        }
      }
    }
    team ??= await _pickTeamDialog(title: 'Echipa pentru PV');
    if (team == null) return;

    final documentDate = DateTime.now();
    final number = _nextHandoverNumber(documentDate);
    final lines = sourceTools.map(_toHandoverLine).toList(growable: false);
    final company = await widget.repository.loadCompanyProfile();
    final predatDe = (widget.currentUserEmail ?? '').trim().isEmpty
        ? 'Operator'
        : widget.currentUserEmail!.trim();
    final primitDe = _responsibleNameForTeam(team.id);

    try {
      final path = await SculeHandoverPdfService.export(
        repository: widget.repository,
        company: company,
        documentNumber: number,
        documentDate: documentDate,
        teamName: team.name,
        responsibleName: _responsibleNameForTeam(team.id),
        lines: lines,
        predatDe: predatDe,
        primitDe: primitDe,
      );

      final doc = ToolHandoverDocument(
        id: 'pv-scule-${documentDate.microsecondsSinceEpoch}',
        documentNumber: number,
        documentDate: documentDate,
        teamId: team.id,
        teamName: team.name,
        responsibleName: _responsibleNameForTeam(team.id),
        toolIds: sourceTools.map((row) => row.id).toList(growable: false),
        lines: lines,
        filePath: path,
        createdByUserId: (widget.currentUserId ?? '').trim(),
        createdByUserEmail: (widget.currentUserEmail ?? '').trim(),
        createdAt: documentDate,
      );
      await _catalogService.saveHandoverDocument(doc);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PV generat: $path')),
      );
      await PdfActionsHelper.showPdfActions(
        context,
        filePath: path,
        title: 'PV Scule generat',
        shareSubject: 'Proces-verbal predare scule',
        shareText: 'PV predare scule generat din aplicație.',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare generare PV: ${_shortError(error)}')),
      );
    }
  }

  Future<void> _openHistory(ToolInventoryItem item) async {
    final events = await _catalogService.listMovementEvents(item.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Istoric scula: ${item.name}'),
        content: SizedBox(
          width: 760,
          child: events.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                        'Nu exista miscari inregistrate pentru aceasta scula.'),
                  ),
                )
              : ListView.separated(
                  primary: false,
                  shrinkWrap: true,
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = events[index];
                    final user = row.performedByUserEmail.trim().isEmpty
                        ? '-'
                        : row.performedByUserEmail.trim();
                    final team =
                        row.teamName.trim().isEmpty ? '-' : row.teamName.trim();
                    return ListTile(
                      dense: true,
                      title: Text(
                        '${_dateTimeLabel(row.eventDate)} • ${row.eventType.label}',
                      ),
                      subtitle: Text(
                        'Echipa: $team\n'
                        'Utilizator: $user'
                        '${row.notes.trim().isEmpty ? '' : '\nObs: ${row.notes.trim()}'}',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Închide'),
          ),
        ],
      ),
    );
  }

  Widget _rowActions(ToolInventoryItem item) {
    final holder = _currentHolderOf(item);
    return Wrap(
      spacing: 4,
      children: [
        IconButton(
          tooltip: 'Editeaza',
          onPressed: () => _openEditor(item),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Șterge',
          onPressed: () => _deleteTool(item),
          icon: const Icon(Icons.delete_outline),
        ),
        if (holder == _ToolCurrentHolder.none)
          IconButton(
            tooltip: 'Atribuie echipei',
            onPressed: () => _assignTool(item),
            icon: const Icon(Icons.assignment_ind_outlined),
          ),
        if (holder == _ToolCurrentHolder.team)
          IconButton(
            tooltip: 'Preda angajatului',
            onPressed: () => _handoverToolToEmployee(item),
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
        if (holder == _ToolCurrentHolder.team)
          IconButton(
            tooltip: 'Muta la alta echipa',
            onPressed: () => _moveToolToAnotherTeam(item),
            icon: const Icon(Icons.swap_horizontal_circle_outlined),
          ),
        if (holder == _ToolCurrentHolder.employee)
          IconButton(
            tooltip: 'Muta la alt angajat',
            onPressed:
                _canRequestTransfer(item) ? () => _requestTransfer(item) : null,
            icon: const Icon(Icons.swap_horiz_outlined),
          ),
        if (holder == _ToolCurrentHolder.employee)
          IconButton(
            tooltip: 'Returneaza la echipa',
            onPressed: () => _returnToolToTeam(item),
            icon: const Icon(Icons.assignment_returned_outlined),
          ),
        if (holder == _ToolCurrentHolder.employee)
          IconButton(
            tooltip: 'Muta la alta echipa',
            onPressed: () => _moveToolToAnotherTeam(item),
            icon: const Icon(Icons.swap_horizontal_circle_outlined),
          ),
        if (holder != _ToolCurrentHolder.none)
          IconButton(
            tooltip: 'Retrage',
            onPressed: () => _retractTool(item),
            icon: const Icon(Icons.assignment_return_outlined),
          ),
        IconButton(
          tooltip: 'Genereaza PV predare-primire',
          onPressed: () => _generateHandoverForTool(item),
          icon: const Icon(Icons.picture_as_pdf_outlined),
        ),
        IconButton(
          tooltip: 'Istoric',
          onPressed: () => _openHistory(item),
          icon: const Icon(Icons.history),
        ),
      ],
    );
  }

  List<ToolInventoryItem> _selectedTools() {
    return _items
        .where((item) => _selectedToolIds.contains(item.id))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredItems;
    final categories = _categoryOptions;
    final selectedTools = _selectedTools();
    final hasSelection = selectedTools.isNotEmpty;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Pe ecrane largi (Windows/tablet ≥600px) filtrele sunt mereu vizibile
                final isWide = constraints.maxWidth >= 600;
                final showFilters = isWide || _filtersVisible;
                final cs = Theme.of(context).colorScheme;
                final hasFilters = _activeFilterCount > 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Rândul 1: search + acțiuni + buton filtre (doar pe mobil)
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                textCapitalization:
                                    TextCapitalization.sentences,
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText:
                                      'Caută denumire / cod inventar / serie...',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _searchController.text
                                          .trim()
                                          .isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {});
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
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                            ),
                            if (hasSelection) ...[
                              const SizedBox(width: 4),
                              OutlinedButton.icon(
                                onPressed: () => _generateHandover(
                                    sourceTools: selectedTools),
                                icon: const Icon(
                                    Icons.picture_as_pdf_outlined,
                                    size: 16),
                                label: const Text('PV'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                ),
                              ),
                            ],
                            // Buton filtre: DOAR pe mobil
                            if (!isWide) ...[
                              const SizedBox(width: 8),
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => setState(() =>
                                        _filtersVisible = !_filtersVisible),
                                    icon: Icon(
                                      _filtersVisible
                                          ? Icons.filter_list_off
                                          : Icons.filter_list,
                                      size: 18,
                                    ),
                                    label: Text(_filtersVisible
                                        ? 'Ascunde'
                                        : 'Filtre'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: hasFilters
                                          ? cs.primary
                                          : null,
                                      side: hasFilters
                                          ? BorderSide(
                                              color: cs.primary,
                                              width: 1.5)
                                          : null,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
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
                              ),
                            ],
                            const SizedBox(width: 4),
                            HelpButton(content: AppHelp.scule),
                          ],
                        ),
                        // Rândul 2: filtre (mereu pe desktop, colapsabile pe mobil)
                        if (showFilters) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: 180,
                                child:
                                    DropdownButtonFormField<ToolInventoryStatus?>(
                                  initialValue: _statusFilter,
                                  decoration: const InputDecoration(
                                      labelText: 'Status'),
                                  items: [
                                    const DropdownMenuItem<
                                        ToolInventoryStatus?>(
                                      value: null,
                                      child: Text('Toate'),
                                    ),
                                    ...ToolInventoryStatus.values.map(
                                      (status) => DropdownMenuItem<
                                          ToolInventoryStatus?>(
                                        value: status,
                                        child: Text(status.label),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _statusFilter = value);
                                    _schedulePersistFilterPreferences();
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 200,
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _categoryFilter,
                                  decoration: const InputDecoration(
                                      labelText: 'Categorie'),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Toate categoriile'),
                                    ),
                                    ...categories.map(
                                      (category) => DropdownMenuItem<String?>(
                                        value: category,
                                        child: Text(category),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _categoryFilter = value);
                                    _schedulePersistFilterPreferences();
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 200,
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _teamFilter,
                                  decoration: const InputDecoration(
                                      labelText: 'Echipă'),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Toate echipele'),
                                    ),
                                    ..._teams.map(
                                      (team) => DropdownMenuItem<String?>(
                                        value: team.id,
                                        child: Text(team.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _teamFilter = value);
                                    _schedulePersistFilterPreferences();
                                  },
                                ),
                              ),
                              if ((_teamFilter ?? '').trim().isNotEmpty)
                                OutlinedButton.icon(
                                  onPressed: () {
                                    final teamId = _teamFilter!.trim();
                                    MasterTeam? team;
                                    for (final row in _teams) {
                                      if (row.id == teamId) {
                                        team = row;
                                        break;
                                      }
                                    }
                                    if (team == null) return;
                                    final tools = _items
                                        .where((row) =>
                                            row.assignedTeamId.trim() ==
                                            teamId)
                                        .toList(growable: false);
                                    _generateHandover(
                                      sourceTools: tools,
                                      forcedTeam: team,
                                    );
                                  },
                                  icon: const Icon(
                                      Icons.picture_as_pdf_outlined,
                                      size: 16),
                                  label: const Text('PV echipă'),
                                ),
                              if (_activeFilterCount > 0)
                                TextButton.icon(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _statusFilter = null;
                                      _categoryFilter = null;
                                      _teamFilter = null;
                                    });
                                    _schedulePersistFilterPreferences();
                                  },
                                  icon: const Icon(
                                      Icons.filter_alt_off_outlined,
                                      size: 16),
                                  label: const Text('Resetează filtrele'),
                                ),
                              if ((_catalogService.fallbackReason ?? '')
                                  .trim()
                                  .isNotEmpty)
                                Text(
                                  'Fallback: ${_catalogService.fallbackReason}',
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
            if (_canApproveTransfers)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _pendingTransferRequests.isEmpty
                      ? const Text(
                          'Cereri mutare scule: nu exista in asteptare.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cereri mutare scule (${_pendingTransferRequests.length})',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            ..._pendingTransferRequests.take(6).map((request) {
                              final notification =
                                  _pendingNotificationForRequest(request.id);
                              final approvalUi =
                                  _transferApprovalUiState(request);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_dateTimeLabel(request.createdAt)} - '
                                      '${request.toolName} '
                                      '(${request.inventoryCode.isEmpty ? '-' : request.inventoryCode})\n'
                                      '${request.sourceEmployeeName} -> ${request.targetEmployeeName}'
                                      '${request.notes.isEmpty ? '' : '\nMotiv: ${request.notes}'}'
                                      '${notification == null ? '' : '\nNotificare: ${notification.message}'}'
                                      '${approvalUi.canApprove ? '' : '\nBlocat: ${approvalUi.reason}'}',
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        FilledButton(
                                          onPressed: approvalUi.canApprove
                                              ? () => _approveTransferRequest(
                                                    request,
                                                  )
                                              : null,
                                          child: const Text('Aproba'),
                                        ),
                                        OutlinedButton(
                                          onPressed: () =>
                                              _rejectTransferRequest(request),
                                          child: const Text('Respinge'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                ),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Nu exista scule in inventar.'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final brandModel = [
                          item.brand.trim(),
                          item.model.trim(),
                        ].where((value) => value.isNotEmpty).join(' / ');
                        return Card(
                          child: ListTile(
                            leading: Checkbox(
                              value: _selectedToolIds.contains(item.id),
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedToolIds.add(item.id);
                                  } else {
                                    _selectedToolIds.remove(item.id);
                                  }
                                });
                              },
                            ),
                            title: Text(item.name),
                            subtitle: Text(
                              'Categorie: ${item.category.isEmpty ? '-' : item.category}\n'
                              'Brand/Model: ${brandModel.isEmpty ? '-' : brandModel}\n'
                              'Cod inv.: ${item.inventoryCode.isEmpty ? '-' : item.inventoryCode} | '
                              'Serie: ${item.serialNumber.isEmpty ? '-' : item.serialNumber}\n'
                              'Data achizitie: ${_dateLabel(item.purchaseDate)}\n'
                              'Status: ${item.status.label} | '
                              'Holder: ${_currentHolderOf(item).label} | '
                              'Echipa: ${item.assignedTeamName.trim().isEmpty ? '-' : item.assignedTeamName.trim()} | '
                              'Angajat: ${item.assignedEmployeeName.trim().isEmpty ? '-' : item.assignedEmployeeName.trim()}',
                            ),
                            isThreeLine: false,
                            trailing: _rowActions(item),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Adauga scula'),
      ),
    );
  }
}

class _TransferApprovalUiState {
  const _TransferApprovalUiState({
    required this.canApprove,
    this.reason = '',
  });

  final bool canApprove;
  final String reason;
}

enum _ToolCurrentHolder {
  none,
  team,
  employee;

  String get label {
    switch (this) {
      case _ToolCurrentHolder.none:
        return 'Disponibil';
      case _ToolCurrentHolder.team:
        return 'Echipa';
      case _ToolCurrentHolder.employee:
        return 'Angajat';
    }
  }
}

class _ToolEditorDialog extends StatefulWidget {
  const _ToolEditorDialog({
    this.existing,
    required this.categoryOptions,
    this.initialInventoryCode,
  });

  final ToolInventoryItem? existing;
  final List<String> categoryOptions;
  final String? initialInventoryCode;

  @override
  State<_ToolEditorDialog> createState() => _ToolEditorDialogState();
}

class _ToolEditorDialogState extends State<_ToolEditorDialog> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _brandCtrl =
      TextEditingController(text: widget.existing?.brand ?? '');
  late final TextEditingController _modelCtrl =
      TextEditingController(text: widget.existing?.model ?? '');
  late final TextEditingController _serialCtrl =
      TextEditingController(text: widget.existing?.serialNumber ?? '');
  late final TextEditingController _inventoryCodeCtrl = TextEditingController(
    text: widget.existing?.inventoryCode ?? (widget.initialInventoryCode ?? ''),
  );
  late final TextEditingController _descriptionCtrl =
      TextEditingController(text: widget.existing?.description ?? '');
  late final TextEditingController _purchaseDateCtrl = TextEditingController(
    text: _dateLabel(widget.existing?.purchaseDate),
  );
  late final TextEditingController _purchaseValueCtrl = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.purchaseValue.toStringAsFixed(2),
  );
  late final TextEditingController _usefulLifeMonthsCtrl =
      TextEditingController(
    text: (widget.existing?.usefulLifeMonths ?? 36).toString(),
  );
  late final TextEditingController _unitCtrl =
      TextEditingController(text: widget.existing?.unit ?? 'buc');
  late final TextEditingController _notesCtrl =
      TextEditingController(text: widget.existing?.notes ?? '');

  ToolInventoryStatus _status = ToolInventoryStatus.disponibila;
  late final List<String> _categoryOptions = [
    ...widget.categoryOptions,
  ];
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _status = widget.existing?.status ?? ToolInventoryStatus.disponibila;
    final existingCategory = widget.existing?.category.trim() ?? '';
    if (existingCategory.isNotEmpty &&
        !_categoryOptions.any(
          (item) => item.toLowerCase() == existingCategory.toLowerCase(),
        )) {
      _categoryOptions.add(existingCategory);
      _categoryOptions
          .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    if (existingCategory.isNotEmpty) {
      _selectedCategory = existingCategory;
    } else if (_categoryOptions.isNotEmpty) {
      _selectedCategory = _categoryOptions.first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    _inventoryCodeCtrl.dispose();
    _descriptionCtrl.dispose();
    _purchaseDateCtrl.dispose();
    _purchaseValueCtrl.dispose();
    _usefulLifeMonthsCtrl.dispose();
    _unitCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  static String _dateLabel(DateTime? value) {
    if (value == null) return '';
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d.$m.${value.year}';
  }

  DateTime? _parseDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;
    final match = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(text);
    if (match == null) return null;
    final day = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    final year = int.tryParse(match.group(3) ?? '');
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final created = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Categorie noua'),
        content: TextField(
          textCapitalization: TextCapitalization.sentences,
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nume categorie',
            hintText: 'Ex: Masini de gaurit',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Adauga'),
          ),
        ],
      ),
    );
    controller.dispose();
    final value = (created ?? '').trim();
    if (value.isEmpty) return;
    if (!_categoryOptions
        .any((item) => item.toLowerCase() == value.toLowerCase())) {
      setState(() {
        _categoryOptions.add(value);
        _categoryOptions
            .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _selectedCategory = value;
      });
      return;
    }
    for (final item in _categoryOptions) {
      if (item.toLowerCase() == value.toLowerCase()) {
        setState(() => _selectedCategory = item);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Adauga scula' : 'Editeaza scula'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          primary: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Denumire scula'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Categorie'),
                      items: _categoryOptions
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) =>
                          setState(() => _selectedCategory = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _addCategory,
                    icon: const Icon(Icons.add),
                    label: const Text('Categorie noua'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<ToolInventoryStatus>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: ToolInventoryStatus.values
                          .map(
                            (item) => DropdownMenuItem<ToolInventoryStatus>(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _status = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _descriptionCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descriere'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _brandCtrl,
                      decoration: const InputDecoration(labelText: 'Brand'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _modelCtrl,
                      decoration: const InputDecoration(labelText: 'Model'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _serialCtrl,
                      decoration: const InputDecoration(labelText: 'Serie'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _inventoryCodeCtrl,
                      readOnly: widget.existing != null,
                      decoration:
                          const InputDecoration(labelText: 'Cod inventar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _purchaseDateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Data achizitie (zz.ll.aaaa)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _purchaseValueCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Valoare achizitie'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _unitCtrl,
                      decoration: const InputDecoration(labelText: 'UM'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _usefulLifeMonthsCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
                decoration: const InputDecoration(
                  labelText: 'Durata de viata (luni)',
                  helperText: 'Implicit 36 luni / 3 ani',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _notesCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Observatii'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            final category = (_selectedCategory ?? '').trim();
            if (category.isEmpty) return;
            final now = DateTime.now();
            final price = double.tryParse(
                  _purchaseValueCtrl.text.trim().replaceAll(',', '.'),
                ) ??
                0.0;
            final usefulLifeMonths =
                int.tryParse(_usefulLifeMonthsCtrl.text.trim()) ?? 36;
            final parsedDate = _parseDate(_purchaseDateCtrl.text);
            final existing = widget.existing;
            Navigator.of(context).pop(
              ToolInventoryItem(
                id: existing?.id ?? 'tool-${now.microsecondsSinceEpoch}',
                name: name,
                category: category,
                brand: _brandCtrl.text.trim(),
                model: _modelCtrl.text.trim(),
                description: _descriptionCtrl.text.trim(),
                serialNumber: _serialCtrl.text.trim(),
                inventoryCode: _inventoryCodeCtrl.text.trim().isEmpty
                    ? (widget.initialInventoryCode ?? '')
                    : _inventoryCodeCtrl.text.trim(),
                purchaseDate: parsedDate,
                purchaseValue: price,
                usefulLifeMonths: usefulLifeMonths > 0 ? usefulLifeMonths : 36,
                unit: _unitCtrl.text.trim().isEmpty
                    ? 'buc'
                    : _unitCtrl.text.trim(),
                status: _status,
                notes: _notesCtrl.text.trim(),
                assignedTeamId: existing?.assignedTeamId ?? '',
                assignedTeamName: existing?.assignedTeamName ?? '',
                assignedEmployeeId: existing?.assignedEmployeeId ?? '',
                assignedEmployeeName: existing?.assignedEmployeeName ?? '',
                assignedAt: existing?.assignedAt,
                assignedByUserId: existing?.assignedByUserId ?? '',
                assignedByUserEmail: existing?.assignedByUserEmail ?? '',
                createdAt: existing?.createdAt ?? now,
                updatedAt: now,
              ),
            );
          },
          child: const Text('Salveaza'),
        ),
      ],
    );
  }
}
