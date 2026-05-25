import 'package:flutter/material.dart';

import 'app_task_models.dart';
import 'app_task_repository.dart';
import 'app_task_page.dart';

/// Widget compact pentru Dashboard — arată maxim 3 taskuri active.
class TaskDashboardWidget extends StatefulWidget {
  const TaskDashboardWidget({
    super.key,
    this.currentUserId,
    this.currentUserName,
    this.isAdmin = false,
    this.onNavigateToTasks,
  });

  final String? currentUserId;
  final String? currentUserName;
  final bool isAdmin;

  /// Callback pentru navigare la pagina completă de taskuri.
  /// Dacă null, se face push direct.
  final VoidCallback? onNavigateToTasks;

  @override
  State<TaskDashboardWidget> createState() => _TaskDashboardWidgetState();
}

class _TaskDashboardWidgetState extends State<TaskDashboardWidget> {
  final _repo = AppTaskRepository.instance;
  List<AppTask> _activeTasks = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    try {
      final all = await _repo.listTasks(
        userId: widget.currentUserId,
        isAdmin: widget.isAdmin,
      );
      final active =
          sortTasksActive(all.where((t) => !t.completed).toList());
      if (mounted) setState(() => _activeTasks = active);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToTasks() {
    if (widget.onNavigateToTasks != null) {
      widget.onNavigateToTasks!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppTaskPage(
          currentUserId: widget.currentUserId,
          currentUserName: widget.currentUserName,
          isAdmin: widget.isAdmin,
        ),
      ),
    );
  }

  void _quickComplete(AppTask task) {
    setState(() {
      _activeTasks = _activeTasks.where((t) => t.id != task.id).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${task.titlu}" finalizat! ✅'),
        action: SnackBarAction(
          label: 'Anulează',
          onPressed: () {
            _repo.uncompleteTask(task).then((_) => _load());
          },
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _repo.completeTask(task).catchError((e) {
        _load();
        return task; // required by catchError return type
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = _activeTasks.take(3).toList();
    final remaining = _activeTasks.length - preview.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Icon(Icons.checklist_outlined,
                    size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '📋 Taskuri active',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (_activeTasks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_activeTasks.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _goToTasks,
                  child: const Text('Vezi toate'),
                ),
              ],
            ),
          ),

          // Loading
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          // Empty state
          else if (_activeTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 20, color: Colors.green.shade500),
                  const SizedBox(width: 8),
                  Text(
                    'Niciun task activ. Excelent! 🎉',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          // Lista taskuri preview
          else ...[
            ...preview.map((task) => _TaskPreviewTile(
                  task: task,
                  onComplete: () => _quickComplete(task),
                  onTap: _goToTasks,
                )),
            if (remaining > 0)
              InkWell(
                onTap: _goToTasks,
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    '+ $remaining taskuri mai multe...',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _TaskPreviewTile extends StatelessWidget {
  const _TaskPreviewTile({
    required this.task,
    required this.onComplete,
    required this.onTap,
  });

  final AppTask task;
  final VoidCallback onComplete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            // Dot prioritate
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: task.prioritate.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.titlu,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.deadlineLabel.isNotEmpty)
                    Text(
                      task.deadlineLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: task.isOverdue
                            ? Colors.red.shade600
                            : task.isDueToday
                                ? Colors.orange.shade700
                                : scheme.onSurfaceVariant,
                        fontWeight: task.isOverdue || task.isDueToday
                            ? FontWeight.w600
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Buton bifează rapid
            Tooltip(
              message: 'Marchează ca finalizat',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onComplete,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
