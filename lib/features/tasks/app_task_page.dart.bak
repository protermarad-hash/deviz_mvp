import 'package:flutter/material.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/help_content.dart';
import '../../core/widgets/help_button.dart';
import 'app_task_models.dart';
import 'app_task_repository.dart';
import 'app_task_form_dialog.dart';

class AppTaskPage extends StatefulWidget {
  const AppTaskPage({
    super.key,
    this.currentUserId,
    this.currentUserName,
    this.isAdmin = false,
  });

  final String? currentUserId;
  final String? currentUserName;
  final bool isAdmin;

  @override
  State<AppTaskPage> createState() => _AppTaskPageState();
}

class _AppTaskPageState extends State<AppTaskPage> {
  final _repo = AppTaskRepository.instance;

  List<AppTask> _allTasks = const [];
  bool _loading = true;
  bool _syncing = false;

  // Filtre
  String _filterChip = 'toate'; // toate | urgente | azi | categorie name
  bool _completedExpanded = false;

  @override
  void initState() {
    super.initState();
    FirebaseBootstrap.onlineNotifier.addListener(_onOnlineChanged);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    FirebaseBootstrap.onlineNotifier.removeListener(_onOnlineChanged);
    super.dispose();
  }

  void _onOnlineChanged() {
    if (FirebaseBootstrap.isOnline && mounted && _allTasks.isEmpty && !_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final tasks = await _repo.listTasks(
        userId: widget.currentUserId,
        isAdmin: widget.isAdmin,
      );
      if (mounted) setState(() => _allTasks = tasks);
    } catch (e) {
      debugPrint('[AppTask] _load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forceSyncToCloud() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final n = await _repo.forceSyncLocalToCloud();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sincronizat $n taskuri în cloud.')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare sincronizare: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  // ── Filtrare ───────────────────────────────────────────────────────────────

  List<AppTask> get _activeTasks =>
      _allTasks.where((t) => !t.completed).toList();
  List<AppTask> get _completedTasks =>
      _allTasks.where((t) => t.completed).toList();

  List<AppTask> _applyFilter(List<AppTask> tasks) {
    switch (_filterChip) {
      case 'urgente':
        return tasks
            .where((t) => t.prioritate == TaskPrioritate.urgent)
            .toList();
      case 'azi':
        return tasks.where((t) => t.isDueToday || t.isOverdue).toList();
      default:
        // Poate fi un name de categorie
        final cat = TaskCategorie.values
            .where((c) => c.name == _filterChip)
            .firstOrNull;
        if (cat != null) {
          return tasks.where((t) => t.categorie == cat).toList();
        }
        return tasks;
    }
  }

  // ── Complete / Uncomplete (optimistic) ────────────────────────────────────

  void _toggleComplete(AppTask task) {
    final updated = task.completed
        ? task.copyWith(completed: false, clearCompletedAt: true)
        : task.copyWith(completed: true, completedAt: DateTime.now());

    setState(() {
      final idx = _allTasks.indexWhere((t) => t.id == task.id);
      if (idx >= 0) {
        _allTasks = List<AppTask>.from(_allTasks)..[idx] = updated;
      }
    });

    final action = task.completed ? 'reactivat' : 'finalizat';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Task $action.')),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      (task.completed
              ? _repo.uncompleteTask(task)
              : _repo.completeTask(task))
          .catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Eroare: $e')),
          );
          _load();
        }
        return task; // required by catchError return type
      });
    });
  }

  // ── Delete (optimistic) ────────────────────────────────────────────────────

  void _deleteTask(AppTask task) {
    setState(() => _allTasks = _allTasks.where((t) => t.id != task.id).toList());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task șters.')),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _repo.deleteTask(task.id).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Eroare la ștergere: $e')),
          );
          _load();
        }
      });
    });
  }

  // ── Adăugare / Editare ────────────────────────────────────────────────────

  Future<void> _openAddDialog({AppTask? existing}) async {
    final result = await showDialog<AppTask>(
      context: context,
      builder: (_) => AppTaskFormDialog(
        task: existing,
        currentUserId: widget.currentUserId ?? '',
        currentUserName: widget.currentUserName ?? '',
      ),
    );
    if (result == null || !mounted) return;
    final saved = await _repo.saveTask(result);
    setState(() {
      final idx = _allTasks.indexWhere((t) => t.id == saved.id);
      final updated = List<AppTask>.from(_allTasks);
      if (idx >= 0) {
        updated[idx] = saved;
      } else {
        updated.add(saved);
      }
      _allTasks = updated;
    });
  }

  Future<void> _confirmDelete(AppTask task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Șterge task'),
        content: Text('Ștergi "${task.titlu}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _deleteTask(task);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    final activeFiltered =
        sortTasksActive(_applyFilter(_activeTasks));
    final completedFiltered =
        sortTasksCompleted(_applyFilter(_completedTasks));

    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Taskurile mele'),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.cloud_sync_outlined),
              tooltip: 'Sincronizează la cloud',
              onPressed: _loading ? null : _forceSyncToCloud,
            ),
          HelpButton(content: AppHelp.taskuri),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Adaugă'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  // ── Filtre rapide ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _FilterChipsRow(
                      selected: _filterChip,
                      onChanged: (v) => setState(() => _filterChip = v),
                      isWide: isWide,
                    ),
                  ),

                  // ── Debug card ─────────────────────────────────────────
                  if (AppTaskRepository.lastFirestoreError != null ||
                      AppTaskRepository.lastFirestoreCount >= 0)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Card(
                          color: AppTaskRepository.lastFirestoreError != null
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              AppTaskRepository.lastFirestoreError != null
                                  ? '⚠️ Firestore: ${AppTaskRepository.lastFirestoreError}'
                                  : '✅ Firestore: ${AppTaskRepository.lastFirestoreCount} taskuri | Local: ${AppTaskRepository.lastLocalCount}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Secțiunea DE FĂCUT ────────────────────────────────
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      label: 'DE FĂCUT',
                      count: activeFiltered.length,
                      color: scheme.primary,
                    ),
                  ),

                  if (activeFiltered.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 48,
                                color: Colors.green.shade400),
                            const SizedBox(height: 8),
                            Text(
                              _filterChip == 'toate'
                                  ? 'Niciun task de făcut. 🎉'
                                  : 'Niciun task pentru filtrul selectat.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            if (AppTaskRepository.lastLocalCount > 0)
                              OutlinedButton.icon(
                                onPressed: _loading ? null : _forceSyncToCloud,
                                icon: const Icon(Icons.cloud_upload_outlined,
                                    size: 16),
                                label: Text(
                                    'Trimite la cloud (${AppTaskRepository.lastLocalCount} doc.)'),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _TaskCard(
                          task: activeFiltered[index],
                          onComplete: () =>
                              _toggleComplete(activeFiltered[index]),
                          onEdit: () =>
                              _openAddDialog(existing: activeFiltered[index]),
                          onDelete: () =>
                              _confirmDelete(activeFiltered[index]),
                        ),
                        childCount: activeFiltered.length,
                      ),
                    ),

                  // ── Secțiunea EFECTUATE (colapsabilă) ────────────────
                  SliverToBoxAdapter(
                    child: _CollapsibleSectionHeader(
                      label: 'EFECTUATE',
                      count: completedFiltered.length,
                      expanded: _completedExpanded,
                      onToggle: () => setState(
                          () => _completedExpanded = !_completedExpanded),
                    ),
                  ),

                  if (_completedExpanded)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _CompletedTaskCard(
                          task: completedFiltered[index],
                          onUncomplete: () =>
                              _toggleComplete(completedFiltered[index]),
                          onDelete: () =>
                              _confirmDelete(completedFiltered[index]),
                        ),
                        childCount: completedFiltered.length,
                      ),
                    ),

                  const SliverToBoxAdapter(
                      child: SizedBox(height: 80)), // FAB clearance
                ],
              ),
            ),
    );
  }
}

// ── Widget filtre rapide ──────────────────────────────────────────────────────

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
    required this.selected,
    required this.onChanged,
    required this.isWide,
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final chips = [
      ('toate', 'Toate', null),
      ('urgente', '🔴 Urgente', null),
      ('azi', '📅 Azi', null),
      (TaskCategorie.ofertare.name, '📋 Ofertare', null),
      (TaskCategorie.apel.name, '📞 Apel', null),
      (TaskCategorie.financiar.name, '💰 Financiar', null),
      (TaskCategorie.programare.name, '📅 Programare', null),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: chips
            .map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(c.$2),
                    selected: selected == c.$1,
                    onSelected: (_) => onChanged(c.$1),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Header secțiune ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              thickness: 1,
              color: color.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header secțiune colapsabilă ───────────────────────────────────────────────

class _CollapsibleSectionHeader extends StatelessWidget {
  const _CollapsibleSectionHeader({
    required this.label,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final String label;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Divider(
                thickness: 1,
                color: scheme.outlineVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card task activ ───────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onComplete,
    required this.onEdit,
    required this.onDelete,
  });

  final AppTask task;
  final VoidCallback onComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final priorityColor = task.prioritate.color;
    final isOverdue = task.isOverdue;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverdue
              ? Colors.red.shade300
              : priorityColor.withValues(alpha: 0.35),
          width: isOverdue ? 1.5 : 1,
        ),
      ),
      color: isOverdue
          ? Colors.red.shade50
          : priorityColor.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicator prioritate
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${task.prioritate.emoji} ${task.titlu}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '${task.categorie.emoji} ${task.categorie.label}',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (task.deadlineLabel.isNotEmpty) ...[
                            Text(
                              ' · ',
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant),
                            ),
                            Text(
                              task.deadlineLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: isOverdue
                                    ? Colors.red.shade700
                                    : task.isDueToday
                                        ? Colors.orange.shade700
                                        : scheme.onSurfaceVariant,
                                fontWeight: isOverdue || task.isDueToday
                                    ? FontWeight.w600
                                    : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (task.descriere != null &&
                          task.descriere!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            task.descriere!,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Bifează'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Editează',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: Colors.red.shade400),
                  tooltip: 'Șterge',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card task efectuat ────────────────────────────────────────────────────────

class _CompletedTaskCard extends StatelessWidget {
  const _CompletedTaskCard({
    required this.task,
    required this.onUncomplete,
    required this.onDelete,
  });

  final AppTask task;
  final VoidCallback onUncomplete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completedStr = task.completedAt != null
        ? 'Finalizat: ${task.completedAt!.day.toString().padLeft(2, '0')}.${task.completedAt!.month.toString().padLeft(2, '0')}.${task.completedAt!.year} ${task.completedAt!.hour.toString().padLeft(2, '0')}:${task.completedAt!.minute.toString().padLeft(2, '0')}'
        : 'Finalizat';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: GestureDetector(
          onTap: onUncomplete,
          child: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 22,
          ),
        ),
        title: Text(
          '✅ ${task.titlu}',
          style: TextStyle(
            decoration: TextDecoration.lineThrough,
            color: scheme.onSurfaceVariant,
            fontSize: 13.5,
          ),
        ),
        subtitle: Text(
          completedStr,
          style:
              TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline,
              size: 18, color: Colors.red.shade300),
          onPressed: onDelete,
          tooltip: 'Șterge',
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
