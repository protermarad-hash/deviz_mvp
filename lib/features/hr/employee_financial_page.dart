import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/repositories/app_data_repository.dart';
import '../master/master_local_store.dart';
import '../programari/programari_page.dart';
import 'employee_financial_models.dart';
import 'employee_financial_repository.dart';

class EmployeeFinancialPage extends StatefulWidget {
  const EmployeeFinancialPage({
    super.key,
    this.repository,
    this.fieldAuthRoleKey,
    this.fieldAuthUserEmail,
    this.fieldAuthUserId,
    this.fieldAuthTeamId,
  });

  /// Opțional — necesar pentru navigarea directă la o programare specifică
  /// din lista de costuri expandată. Dacă lipsește, drill-down-ul afișează
  /// un dialog cu detaliile programării (fallback).
  final AppDataRepository? repository;
  final String? fieldAuthRoleKey;
  final String? fieldAuthUserEmail;
  final String? fieldAuthUserId;
  final String? fieldAuthTeamId;

  @override
  State<EmployeeFinancialPage> createState() => _EmployeeFinancialPageState();
}

class _EmployeeFinancialPageState extends State<EmployeeFinancialPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repo = EmployeeFinancialRepository.instance;

  // Perioadă selectată (Tab 1)
  _Period _selectedPeriod = _Period.thisMonth;
  DateTimeRange? _customRange;

  // Date
  List<MasterEmployee> _employees = const [];
  List<EmployeePayEntry> _payEntries = const [];
  List<EmployeePayment> _payments = const [];

  // Filtre Tab 2
  String _filterEmployeeId = '';
  _Period _historyPeriod = _Period.thisMonth;
  DateTimeRange? _historyCustomRange;

  // Tab 3 — Tarife prestabilite
  Map<String, EmployeeSettings> _settingsMap = {};
  final Map<String, TextEditingController> _tarifControllers = {};
  bool _savingTarif = false;

  bool _loading = false;
  bool _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    FirebaseBootstrap.onlineNotifier.addListener(_onOnlineChanged);
    Future.microtask(() async {
      await _cleanupOrphanedPayEntries();
      await _load();
    });
  }

  @override
  void dispose() {
    FirebaseBootstrap.onlineNotifier.removeListener(_onOnlineChanged);
    _tabController.dispose();
    for (final ctrl in _tarifControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _onOnlineChanged() {
    if (FirebaseBootstrap.isOnline &&
        mounted &&
        _payEntries.isEmpty &&
        !_loading) {
      _load();
    }
  }

  /// Migrare one-shot: șterge PayEntry-urile angajaților dezalocați.
  /// Construiește harta appointmentId-employeeIds din cache-ul local
  /// de programări și deleagă ștergerea la repository.
  Future<void> _cleanupOrphanedPayEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ultra_appointments_v1');
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final map = <String, Set<String>>{};
      for (final item in decoded) {
        if (item is! Map) continue;
        final apptMap = Map<String, dynamic>.from(item);
        final id = (apptMap['id'] as String?)?.trim() ?? '';
        if (id.isEmpty) continue;
        final raw2 = apptMap['assigned_employee_ids'] ??
            apptMap['assignedEmployeeIds'];
        final empIds = (raw2 is List)
            ? raw2
                .whereType<String>()
                .where((s) => s.trim().isNotEmpty)
                .toSet()
            : <String>{};
        map[id] = empIds;
      }
      if (map.isEmpty) return;
      final deleted = await _repo.cleanupOrphanedPayEntries(map);
      if (deleted > 0) {
        debugPrint('[FinanciarAngajati] cleanup: $deleted intrări orfane șterse');
      }
    } catch (e) {
      debugPrint('[FinanciarAngajati] cleanup error: $e');
    }
  }

  DateTimeRange _rangeForPeriod(_Period period, DateTimeRange? custom) {
    final now = DateTime.now();
    switch (period) {
      case _Period.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case _Period.lastMonth:
        final first = DateTime(now.year, now.month - 1, 1);
        final last = DateTime(now.year, now.month, 0, 23, 59, 59);
        return DateTimeRange(start: first, end: last);
      case _Period.custom:
        return custom ??
            DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: now,
            );
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final range = _rangeForPeriod(_selectedPeriod, _customRange);
      final results = await Future.wait([
        MasterLocalStore.readEmployees(),
        _repo.listAllPayEntries(from: range.start, to: range.end),
        _repo.listAllPayments(),
        _repo.loadAllEmployeeSettings(),
      ]);
      if (!mounted) return;
      final employees = results[0] as List<MasterEmployee>;
      final settingsMap =
          results[3] as Map<String, EmployeeSettings>;

      // Populează controllere de tarif pentru angajații noi
      for (final emp in employees) {
        _tarifControllers.putIfAbsent(
          emp.id,
          () => TextEditingController(
            text: settingsMap[emp.id]
                    ?.defaultPayPerAppointment
                    .toStringAsFixed(2) ??
                '',
          ),
        );
        // Actualizează valoarea dacă s-a schimbat în cloud
        final cloudVal =
            settingsMap[emp.id]?.defaultPayPerAppointment;
        if (cloudVal != null) {
          final existing = _tarifControllers[emp.id];
          final parsed = double.tryParse(
            existing?.text.replaceAll(',', '.') ?? '',
          );
          if (parsed != cloudVal) {
            existing?.text = cloudVal.toStringAsFixed(2);
          }
        }
      }

      setState(() {
        _employees = employees;
        _payEntries = results[1] as List<EmployeePayEntry>;
        _payments = results[2] as List<EmployeePayment>;
        _settingsMap = settingsMap;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forceSyncToCloud() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final count = await _repo.forceSyncLocalToCloud();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sincronizat $count înregistrări.')),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Eroare sync: $e')));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _deduplicateEntries() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deduplică intrări'),
        content: const Text(
          'Elimină plățile dublate pentru aceeași programare și același '
          'angajat, păstrând cea mai recentă. Acțiunea nu poate fi anulată.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Deduplică'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final removed = await _repo.deduplicatePayEntries();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removed > 0
                ? '$removed intrări dublate eliminate.'
                : 'Nicio intrare dublată găsită.',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare la deduplicare: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financiar angajați'),
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined),
            tooltip: 'Sincronizează la cloud',
            onPressed: (_loading || _syncing) ? null : _forceSyncToCloud,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reîncarcă',
            onPressed: _loading ? null : _load,
          ),
          PopupMenuButton<String>(
            tooltip: 'Mai multe',
            onSelected: (value) {
              if (value == 'dedup') _deduplicateEntries();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'dedup',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cleaning_services_outlined),
                  title: Text('Deduplică intrări'),
                  subtitle: Text('Elimină plățile dublate per programare'),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart_outlined), text: 'Costuri perioadă'),
            Tab(icon: Icon(Icons.history_outlined), text: 'Istoric plăți'),
            Tab(icon: Icon(Icons.tune_outlined), text: 'Tarife'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCosturiTab(),
                _buildIstoricTab(),
                _buildTarifeTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPaymentDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Înregistrează plată'),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1 — Costuri perioadă
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCosturiTab() {
    final range = _rangeForPeriod(_selectedPeriod, _customRange);
    final entriesInPeriod = _payEntries.where((e) {
      final dt = DateTime.tryParse(e.appointmentDate) ?? e.createdAt;
      return !dt.isBefore(range.start) && !dt.isAfter(range.end);
    }).toList();

    // Grupăm sumele datorate pe angajat
    final dueByEmployee = <String, double>{};
    for (final e in entriesInPeriod) {
      dueByEmployee[e.employeeId] =
          (dueByEmployee[e.employeeId] ?? 0) + e.amountDue;
    }

    // Plăți efectuate în perioadă
    final paymentsInPeriod = _payments.where((p) {
      return !p.paymentDate.isBefore(range.start) &&
          !p.paymentDate.isAfter(range.end);
    }).toList();
    final paidByEmployee = <String, double>{};
    for (final p in paymentsInPeriod) {
      paidByEmployee[p.employeeId] =
          (paidByEmployee[p.employeeId] ?? 0) + p.amount;
    }

    // Angajați cu activitate în perioadă
    final activeEmployeeIds =
        {...dueByEmployee.keys, ...paidByEmployee.keys}.toList();
    final activeEmployees = activeEmployeeIds
        .map((id) =>
            _employees.where((e) => e.id == id).firstOrNull ??
            MasterEmployee(
              id: id,
              name: _nameFromEntries(id),
              role: '',
              active: true,
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final totalDue = dueByEmployee.values.fold<double>(0, (a, b) => a + b);
    final totalPaid = paidByEmployee.values.fold<double>(0, (a, b) => a + b);
    final totalBalance = totalDue - totalPaid;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Filtre perioadă
              if (isWide)
                _buildPeriodFilter()
              else
                ExpansionTile(
                  title: const Text('Perioadă'),
                  children: [_buildPeriodFilter()],
                ),
              const SizedBox(height: 12),

              // Card total general
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _summaryChip(
                            'Total de plătit', totalDue, Colors.orange),
                      ),
                      Expanded(
                        child: _summaryChip(
                            'Total plătit', totalPaid, Colors.green),
                      ),
                      Expanded(
                        child: _summaryChip(
                            'Sold', totalBalance, Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              if (_error != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Eroare: $_error'),
                  ),
                ),

              // Info Firebase
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: Text(
                    'Firebase: init=${FirebaseBootstrap.isInitialized} '
                    'online=${FirebaseBootstrap.isOnline} '
                    'local=${EmployeeFinancialRepository.lastLocalCount} '
                    'cloud=${EmployeeFinancialRepository.lastFirestoreCount}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              if (activeEmployees.isEmpty)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      const Icon(Icons.people_outline,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('Niciun cost înregistrat în această perioadă.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reîncarcă din cloud'),
                      ),
                    ],
                  ),
                )
              else
                for (final emp in activeEmployees) ...[
                  _buildEmployeeCostCard(
                    emp: emp,
                    due: dueByEmployee[emp.id] ?? 0,
                    paid: paidByEmployee[emp.id] ?? 0,
                    range: range,
                    entries: (entriesInPeriod
                        .where((e) => e.employeeId == emp.id)
                        .toList()
                      ..sort((a, b) {
                        final da = DateTime.tryParse(a.appointmentDate) ??
                            a.createdAt;
                        final db = DateTime.tryParse(b.appointmentDate) ??
                            b.createdAt;
                        return db.compareTo(da);
                      })),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ChoiceChip(
          label: const Text('Luna curentă'),
          selected: _selectedPeriod == _Period.thisMonth,
          onSelected: (_) =>
              setState(() => _selectedPeriod = _Period.thisMonth),
        ),
        ChoiceChip(
          label: const Text('Luna trecută'),
          selected: _selectedPeriod == _Period.lastMonth,
          onSelected: (_) =>
              setState(() => _selectedPeriod = _Period.lastMonth),
        ),
        ChoiceChip(
          label: const Text('Personalizat'),
          selected: _selectedPeriod == _Period.custom,
          onSelected: (_) async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: _customRange,
            );
            if (picked != null) {
              setState(() {
                _selectedPeriod = _Period.custom;
                _customRange = picked;
              });
              await _load();
            }
          },
        ),
      ],
    );
  }

  Widget _summaryChip(String label, double value, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(2)} RON',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: color, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildEmployeeCostCard({
    required MasterEmployee emp,
    required double due,
    required double paid,
    required DateTimeRange range,
    required List<EmployeePayEntry> entries,
  }) {
    final balance = due - paid;

    final header = Row(
      children: [
        const Icon(Icons.person_outline),
        const SizedBox(width: 8),
        Expanded(
          child: Text(emp.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        FilledButton.tonalIcon(
          onPressed: () => _showPaymentDialog(context, employee: emp),
          icon: const Icon(Icons.payments_outlined, size: 16),
          label: const Text('Plătește'),
        ),
      ],
    );

    final chipsRow = Row(
      children: [
        _infoChip('De plătit', due, Colors.orange),
        const SizedBox(width: 12),
        _infoChip('Plătit', paid, Colors.green),
        const SizedBox(width: 12),
        _infoChip(
            'Sold', balance, balance > 0.01 ? Colors.red : Colors.grey),
      ],
    );

    // Fără intrări detaliate → card simplu, ne-expandabil (ca înainte).
    if (entries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 8),
              chipsRow,
            ],
          ),
        ),
      );
    }

    // Cu intrări → card expandabil cu defalcarea per programare.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.only(bottom: 4),
        title: header,
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: chipsRow,
        ),
        children: [
          const Divider(height: 1),
          for (final entry in entries) _buildPayEntryTile(entry),
        ],
      ),
    );
  }

  Widget _buildPayEntryTile(EmployeePayEntry entry) {
    final dt = DateTime.tryParse(entry.appointmentDate);
    final dateStr = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}'
        : entry.appointmentDate;
    final title = entry.appointmentTitle.trim().isNotEmpty
        ? entry.appointmentTitle.trim()
        : (entry.jobTitle.trim().isNotEmpty
            ? entry.jobTitle.trim()
            : 'Programare');
    return ListTile(
      dense: true,
      leading: const Icon(Icons.event_outlined, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        '$dateStr · ${entry.amountDue.toStringAsFixed(2)} ${entry.currency}'
        '${entry.notes.trim().isNotEmpty ? '\n${entry.notes.trim()}' : ''}',
        style: const TextStyle(fontSize: 12),
      ),
      isThreeLine: entry.notes.trim().isNotEmpty,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Editează suma',
            onPressed: () => _showEditPayEntryDialog(entry),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 14),
            tooltip: 'Deschide programarea',
            onPressed: () => _openAppointment(entry),
          ),
        ],
      ),
      onTap: () => _openAppointment(entry),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FIX 2 — Navigare la programarea specifică
  // ─────────────────────────────────────────────────────────────────────────

  void _openAppointment(EmployeePayEntry entry) {
    final apptId = entry.appointmentId.trim();
    final repo = widget.repository;
    // Navigare directă dacă avem repository (pattern din role_ready_shell).
    if (repo != null && apptId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProgramariPage(
            repository: repo,
            fieldAuthRoleKey: widget.fieldAuthRoleKey,
            fieldAuthUserEmail: widget.fieldAuthUserEmail,
            fieldAuthUserId: widget.fieldAuthUserId,
            fieldAuthTeamId: widget.fieldAuthTeamId,
            initialFocusAppointmentId: apptId,
          ),
        ),
      );
      return;
    }
    // Fallback — fără repository sau fără id: dialog cu detaliile programării.
    _showAppointmentDetailDialog(entry);
  }

  void _showAppointmentDetailDialog(EmployeePayEntry entry) {
    final dt = DateTime.tryParse(entry.appointmentDate);
    final dateStr = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}'
        : entry.appointmentDate;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          entry.appointmentTitle.trim().isNotEmpty
              ? entry.appointmentTitle.trim()
              : 'Detalii programare',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dateStr.isNotEmpty) Text('Data: $dateStr'),
            const SizedBox(height: 4),
            Text(
                'Sumă: ${entry.amountDue.toStringAsFixed(2)} ${entry.currency}'),
            if (entry.jobTitle.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Lucrare: ${entry.jobTitle.trim()}'),
            ],
            if (entry.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Note: ${entry.notes.trim()}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Închide'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FIX 3 — Editare rapidă sumă/note pentru o intrare de cost
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _showEditPayEntryDialog(EmployeePayEntry entry) async {
    final amountCtrl =
        TextEditingController(text: entry.amountDue.toStringAsFixed(2));
    final notesCtrl = TextEditingController(text: entry.notes);
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editează cost programare'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.appointmentTitle.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    entry.appointmentTitle.trim(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Sumă datorată (RON) *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observații',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () {
              if (amountCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Salvează'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;
    final newAmount =
        double.tryParse(amountCtrl.text.trim().replaceAll(',', '.'));
    if (newAmount == null || newAmount < 0) return;

    final updated = entry.copyWith(
      amountDue: newAmount,
      notes: notesCtrl.text.trim(),
    );

    // Optimistic UI — actualizează lista locală imediat.
    setState(() {
      _payEntries = _payEntries
          .map((e) => e.id == updated.id ? updated : e)
          .toList();
    });
    messenger.showSnackBar(
      const SnackBar(content: Text('Cost programare actualizat.')),
    );

    _repo.savePayEntry(updated).catchError((e) {
      if (!mounted) return;
      // Rollback la eroare.
      setState(() {
        _payEntries =
            _payEntries.map((x) => x.id == entry.id ? entry : x).toList();
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Eroare la salvare: $e')),
      );
    });
  }

  Widget _infoChip(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          '${value.toStringAsFixed(2)} RON',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2 — Istoric plăți
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildIstoricTab() {
    final range = _rangeForPeriod(_historyPeriod, _historyCustomRange);
    final filtered = _payments.where((p) {
      if (_filterEmployeeId.isNotEmpty &&
          p.employeeId != _filterEmployeeId) {
        return false;
      }
      return !p.paymentDate.isBefore(range.start) &&
          !p.paymentDate.isAfter(range.end);
    }).toList()
      ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isWide)
                Row(
                  children: [
                    Expanded(child: _buildHistoryFilters()),
                  ],
                )
              else
                ExpansionTile(
                  title: const Text('Filtre'),
                  children: [_buildHistoryFilters()],
                ),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        const Text('Nicio plată în această perioadă.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reîncarcă din cloud'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final payment in filtered) ...[
                  _buildPaymentCard(payment),
                  const SizedBox(height: 6),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        DropdownButton<String>(
          value: _filterEmployeeId.isEmpty ? '' : _filterEmployeeId,
          hint: const Text('Toți angajații'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Toți angajații')),
            ..._employees.map(
              (e) => DropdownMenuItem(value: e.id, child: Text(e.name)),
            ),
          ],
          onChanged: (v) =>
              setState(() => _filterEmployeeId = v ?? ''),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Luna curentă'),
          selected: _historyPeriod == _Period.thisMonth,
          onSelected: (_) =>
              setState(() => _historyPeriod = _Period.thisMonth),
        ),
        ChoiceChip(
          label: const Text('Luna trecută'),
          selected: _historyPeriod == _Period.lastMonth,
          onSelected: (_) =>
              setState(() => _historyPeriod = _Period.lastMonth),
        ),
        ChoiceChip(
          label: const Text('Personalizat'),
          selected: _historyPeriod == _Period.custom,
          onSelected: (_) async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: _historyCustomRange,
            );
            if (picked != null) {
              setState(() {
                _historyPeriod = _Period.custom;
                _historyCustomRange = picked;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildPaymentCard(EmployeePayment payment) {
    final dateStr =
        '${payment.paymentDate.day.toString().padLeft(2, '0')}.${payment.paymentDate.month.toString().padLeft(2, '0')}.${payment.paymentDate.year}';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.payments_outlined),
        title: Text(payment.employeeName),
        subtitle: Text(
          '$dateStr${payment.notes.isNotEmpty ? ' · ${payment.notes}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${payment.amount.toStringAsFixed(2)} ${payment.currency}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Șterge plata',
              onPressed: () => _deletePayment(payment),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 3 — Tarife prestabilite per angajat
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTarifeTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Tariful prestabilit se completează automat în dialogul '
              '"Plată angajați" la crearea unei programări.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_employees.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  const Icon(Icons.people_outline,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text('Niciun angajat găsit.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reîncarcă'),
                  ),
                ],
              ),
            )
          else
            for (final emp in _employees) ...[
              _buildTarifCard(emp),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _buildTarifCard(MasterEmployee emp) {
    final ctrl = _tarifControllers.putIfAbsent(
      emp.id,
      () => TextEditingController(
        text: _settingsMap[emp.id]
                ?.defaultPayPerAppointment
                .toStringAsFixed(2) ??
            '',
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.person_outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(emp.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              width: 110,
              child: TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'Tarif / prog.',
                  suffixText: 'RON',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: _savingTarif
                  ? null
                  : () => _saveTarif(emp, ctrl.text),
              child: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTarif(MasterEmployee emp, String rawValue) async {
    final value =
        double.tryParse(rawValue.trim().replaceAll(',', '.')) ?? 0.0;
    if (value < 0) return;
    setState(() => _savingTarif = true);
    try {
      final settings = EmployeeSettings(
        employeeId: emp.id,
        employeeName: emp.name,
        defaultPayPerAppointment: value,
        updatedAt: DateTime.now(),
      );
      await _repo.saveEmployeeSettings(settings);
      if (!mounted) return;
      setState(() => _settingsMap = {..._settingsMap, emp.id: settings});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Tarif ${value.toStringAsFixed(2)} RON/programare salvat pentru ${emp.name}.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare la salvare tarif: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingTarif = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DIALOG PLATĂ
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _showPaymentDialog(
    BuildContext context, {
    MasterEmployee? employee,
  }) async {
    MasterEmployee? selectedEmployee = employee;
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime paymentDate = DateTime.now();
    // Capturăm messenger ÎNAINTE de orice await — context-ul e parametru local,
    // deci sigur de folosit după gap-urile async chiar dacă ecranul se închide.
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Înregistrează plată'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (employee == null)
                  DropdownButtonFormField<MasterEmployee>(
                    initialValue: selectedEmployee,
                    decoration:
                        const InputDecoration(labelText: 'Angajat *'),
                    items: _employees
                        .map(
                          (e) => DropdownMenuItem(
                              value: e, child: Text(e.name)),
                        )
                        .toList(),
                    onChanged: (v) => setSt(() => selectedEmployee = v),
                  ),
                if (employee != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      employee.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Sumă (RON) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: paymentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setSt(() => paymentDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data plății',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      '${paymentDate.day.toString().padLeft(2, '0')}.${paymentDate.month.toString().padLeft(2, '0')}.${paymentDate.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Observații',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () {
                if (selectedEmployee == null) return;
                if (amountCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;
    final emp = selectedEmployee;
    if (emp == null) return;

    final amount =
        double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0) return;

    final payment = EmployeePayment.create(
      employeeId: emp.id,
      employeeName: emp.name,
      amount: amount,
      paymentDate: paymentDate,
      notes: notesCtrl.text.trim(),
    );

    await _repo.savePayment(payment);
    if (!mounted) return;

    // Optimistic UI — adaugă direct în listă
    setState(() {
      _payments = [payment, ..._payments];
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Plată de ${amount.toStringAsFixed(2)} RON înregistrată pentru ${emp.name}.',
        ),
      ),
    );
  }

  Future<void> _deletePayment(EmployeePayment payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Șterge plata'),
        content: Text(
          'Ștergi plata de ${payment.amount.toStringAsFixed(2)} RON pentru ${payment.employeeName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Nu'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Da, șterge'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    // Optimistic UI
    setState(() {
      _payments = _payments.where((p) => p.id != payment.id).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plată ștearsă.')),
    );
    _repo.deletePayment(payment.id).catchError((e) {
      if (mounted) {
        setState(() => _payments = [..._payments, payment]);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare la ștergere: $e')),
        );
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILITARE
  // ─────────────────────────────────────────────────────────────────────────

  String _nameFromEntries(String employeeId) {
    for (final e in _payEntries) {
      if (e.employeeId == employeeId && e.employeeName.isNotEmpty) {
        return e.employeeName;
      }
    }
    for (final p in _payments) {
      if (p.employeeId == employeeId && p.employeeName.isNotEmpty) {
        return p.employeeName;
      }
    }
    return employeeId;
  }
}

enum _Period { thisMonth, lastMonth, custom }
