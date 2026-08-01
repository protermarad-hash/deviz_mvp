import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/app_data_repository.dart';
import '../master/master_local_store.dart';
import '../partners/partner_models.dart';
import 'pontaj_lucrare_widgets.dart';
import 'pontaj_persoana_autocomplete.dart';
import 'pontaj_pontare_dialog.dart';
import 'pontaj_zi_lucrare_models.dart';
import 'pontaj_zi_lucrare_repository.dart';

/// Tab "Pontaj" din fișa lucrării — evidență zilnică de sine stătătoare.
///
/// NU se leagă de calculele economice existente ale lucrării
/// (_buildEconomicTab, partner profit, teamMembers) — are totalurile proprii.
class PontajLucrareTab extends StatefulWidget {
  const PontajLucrareTab({
    super.key,
    required this.lucrareId,
    required this.repository,
  });

  final String lucrareId;
  final AppDataRepository repository;

  @override
  State<PontajLucrareTab> createState() => _PontajLucrareTabState();
}

class _PontajLucrareTabState extends State<PontajLucrareTab> {
  static final _dateFormat = DateFormat('dd.MM.yyyy');

  final PontajZiLucrareRepository _repo = PontajZiLucrareRepository();

  List<PontajZiLucrare> _items = [];
  List<PersoanaPontajOption> _options = [];
  bool _loading = true;
  bool _syncing = false;
  bool _summaryExpanded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        _repo.listForLucrare(widget.lucrareId),
        MasterLocalStore.readEmployees(),
        widget.repository.listPartnerWorkers(),
        widget.repository.listPartners(),
      ]);
      if (!mounted) return;
      final pontaje = results[0] as List<PontajZiLucrare>;
      final employees = results[1] as List<MasterEmployee>;
      final workers = results[2] as List<PartnerWorkerRecord>;
      final partners = results[3] as List<PartnerRecord>;
      setState(() {
        _items = pontaje;
        _options = buildPersoanaOptions(
          employees: employees,
          partnerWorkers: workers,
          partnerNamesById: {for (final p in partners) p.id: p.name},
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare la încărcarea pontajului: $e')),
      );
    }
  }

  Future<void> _forceSyncToCloud() async {
    setState(() => _syncing = true);
    try {
      final synced = await _repo.forceSyncLocalToCloud();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sincronizate $synced pontaje în cloud.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare sincronizare: $e')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _addPontaj({DateTime? initialDate}) async {
    final record = await showDialog<PontajZiLucrare>(
      context: context,
      builder: (_) => PontajPontareDialog(
        lucrareId: widget.lucrareId,
        options: _options,
        initialDate: initialDate,
      ),
    );
    if (record == null) return;
    final saved = await _repo.save(record);
    if (!mounted) return;
    setState(() => _items = _mergeItem(_items, saved));
  }

  Future<void> _editPontaj(PontajZiLucrare item) async {
    final record = await showDialog<PontajZiLucrare>(
      context: context,
      builder: (_) => PontajPontareDialog(
        lucrareId: widget.lucrareId,
        options: _options,
        existing: item,
      ),
    );
    if (record == null) return;
    final saved = await _repo.save(record);
    if (!mounted) return;
    setState(() => _items = _mergeItem(_items, saved));
  }

  List<PontajZiLucrare> _mergeItem(
      List<PontajZiLucrare> items, PontajZiLucrare saved) {
    final next = [...items.where((r) => r.id != saved.id), saved];
    next.sort((a, b) {
      final byDate = b.ziCalendaristica.compareTo(a.ziCalendaristica);
      if (byDate != 0) return byDate;
      return a.persoanaNume
          .toLowerCase()
          .compareTo(b.persoanaNume.toLowerCase());
    });
    return next;
  }

  Future<void> _deletePontaj(PontajZiLucrare item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Șterge pontaj?'),
        content: Text(
          '${item.persoanaNume}\n'
          'Data: ${_dateFormat.format(item.ziCalendaristica)}\n'
          'Valoare: ${item.costZi.toStringAsFixed(2)} RON',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Optimistic UI (BUG 9): actualizare imediată + operația async în fundal.
    setState(() => _items = _items.where((r) => r.id != item.id).toList());
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Pontaj șters.')));
    _repo.delete(item.id).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Eroare la ștergere: $e')));
        _load();
      }
    });
  }

  /// Copiază toate pontajele din cea mai recentă zi pontată pe o dată nouă.
  Future<void> _copyPreviousDay() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu există zile pontate de copiat.')),
      );
      return;
    }
    final lastDay = _items.first.ziCalendaristica;
    final sourceItems =
        _items.where((r) => r.ziCalendaristica == lastDay).toList();

    final targetDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText:
          'Copiază ${sourceItems.length} pontaje din ${_dateFormat.format(lastDay)} pe:',
    );
    if (targetDate == null || !mounted) return;
    final normalized =
        DateTime(targetDate.year, targetDate.month, targetDate.day);

    final now = DateTime.now();
    var next = [..._items];
    for (final source in sourceItems) {
      final saved = await _repo.save(source.copyWith(
        id: '',
        data: normalized,
        revision: 1,
        createdAt: now,
        updatedAt: now,
      ));
      next = _mergeItem(next, saved);
    }
    if (!mounted) return;
    setState(() => _items = next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${sourceItems.length} pontaje copiate pe ${_dateFormat.format(normalized)}.',
        ),
      ),
    );
  }

  double get _totalGeneral => _items.fold(0.0, (sum, r) => sum + r.costZi);

  Map<String, double> get _totalPerPersoana {
    final totals = <String, double>{};
    for (final r in _items) {
      totals[r.persoanaNume] = (totals[r.persoanaNume] ?? 0) + r.costZi;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Fără Scaffold/FAB propriu — părintele (fișa lucrării) are deja FAB;
    // butonul "Adaugă pontaj" e în bara de acțiuni de sus.
    return RefreshIndicator(
      onRefresh: _load,
      child: _items.isEmpty ? _buildEmptyState() : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 32),
        Icon(Icons.event_note_outlined,
            size: 56, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        const Center(
          child: Text('Nicio zi pontată pe această lucrare.'),
        ),
        const SizedBox(height: 12),
        Center(
          child: FilledButton.icon(
            onPressed: () => _addPontaj(),
            icon: const Icon(Icons.add),
            label: const Text('Adaugă pontaj'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Reîncarcă din cloud'),
          ),
        ),
        const SizedBox(height: 8),
        if (PontajZiLucrareRepository.lastLocalCount > 0)
          Center(
            child: OutlinedButton.icon(
              onPressed: _syncing ? null : _forceSyncToCloud,
              icon: const Icon(Icons.cloud_upload_outlined, size: 16),
              label: Text(
                  'Trimite la cloud (${PontajZiLucrareRepository.lastLocalCount} doc.)'),
            ),
          ),
        if (PontajZiLucrareRepository.lastFirestoreError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Eroare Firestore: ${PontajZiLucrareRepository.lastFirestoreError}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildList() {
    final grouped = <DateTime, List<PontajZiLucrare>>{};
    for (final item in _items) {
      grouped.putIfAbsent(item.ziCalendaristica, () => []).add(item);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _addPontaj(),
                icon: const Icon(Icons.add),
                label: const Text('Adaugă pontaj'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PontajSummaryCard(
          totalGeneral: _totalGeneral,
          totalPerPersoana: _totalPerPersoana,
          itemCount: _items.length,
          expanded: _summaryExpanded,
          syncing: _syncing,
          onToggleExpanded: () =>
              setState(() => _summaryExpanded = !_summaryExpanded),
          onForceSync: _forceSyncToCloud,
          onCopyPreviousDay: _copyPreviousDay,
        ),
        const SizedBox(height: 8),
        for (final day in days) ...[
          PontajDayHeader(day: day, items: grouped[day]!),
          ...grouped[day]!.map(
            (item) => PontajRow(
              item: item,
              onEdit: () => _editPontaj(item),
              onDelete: () => _deletePontaj(item),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
