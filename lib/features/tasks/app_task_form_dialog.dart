import 'package:flutter/material.dart';

import 'app_task_models.dart';

/// Dialog pentru adăugarea rapidă sau editarea unui task.
/// Returnează un [AppTask] gata de salvat, sau null dacă s-a anulat.
class AppTaskFormDialog extends StatefulWidget {
  const AppTaskFormDialog({
    super.key,
    this.task,
    required this.currentUserId,
    required this.currentUserName,
  });

  /// Dacă e furnizat, dialogul funcționează în modul editare.
  final AppTask? task;
  final String currentUserId;
  final String currentUserName;

  @override
  State<AppTaskFormDialog> createState() => _AppTaskFormDialogState();
}

class _AppTaskFormDialogState extends State<AppTaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titluCtrl = TextEditingController();
  final _descriereCtrl = TextEditingController();

  TaskCategorie _categorie = TaskCategorie.altele;
  TaskPrioritate _prioritate = TaskPrioritate.normal;
  DateTime? _deadline;
  bool _showDescriere = false;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final t = widget.task!;
      _titluCtrl.text = t.titlu;
      _descriereCtrl.text = t.descriere ?? '';
      _categorie = t.categorie;
      _prioritate = t.prioritate;
      _deadline = t.deadline;
      _showDescriere = (t.descriere ?? '').isNotEmpty;
    }
  }

  @override
  void dispose() {
    _titluCtrl.dispose();
    _descriereCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      helpText: 'Alege deadline',
    );
    if (picked != null && mounted) {
      setState(() => _deadline = picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final id = _isEdit
        ? widget.task!.id
        : 'local-${now.millisecondsSinceEpoch}-${widget.currentUserId}';

    final task = AppTask(
      id: id,
      titlu: _titluCtrl.text.trim(),
      descriere: _descriereCtrl.text.trim().isEmpty
          ? null
          : _descriereCtrl.text.trim(),
      categorie: _categorie,
      prioritate: _prioritate,
      createdAt: _isEdit ? widget.task!.createdAt : now,
      deadline: _deadline,
      completed: _isEdit ? widget.task!.completed : false,
      completedAt: _isEdit ? widget.task!.completedAt : null,
      createdBy: _isEdit
          ? widget.task!.createdBy
          : widget.currentUserId,
    );

    Navigator.of(context).pop(task);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(_isEdit ? '✏️ Editează task' : '+ Task nou'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titlu
                TextFormField(
                  controller: _titluCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Titlu task *',
                    hintText: 'Ex: Ofertă client Ionescu',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Titlul este obligatoriu'
                          : null,
                ),
                const SizedBox(height: 12),

                // Categorie + Prioritate pe același rând
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<TaskCategorie>(
                        initialValue: _categorie,
                        decoration: const InputDecoration(
                          labelText: 'Categorie',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: TaskCategorie.values
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    '${c.emoji} ${c.label}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _categorie = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<TaskPrioritate>(
                        initialValue: _prioritate,
                        decoration: const InputDecoration(
                          labelText: 'Prioritate',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: TaskPrioritate.values
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    '${p.emoji} ${p.label}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _prioritate = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Deadline
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDeadline,
                        icon: const Icon(Icons.calendar_today_outlined,
                            size: 16),
                        label: Text(
                          _deadline == null
                              ? 'Deadline (opțional)'
                              : '${_deadline!.day.toString().padLeft(2, '0')}.${_deadline!.month.toString().padLeft(2, '0')}.${_deadline!.year}',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _deadline == null
                              ? scheme.onSurfaceVariant
                              : scheme.primary,
                        ),
                      ),
                    ),
                    if (_deadline != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Elimină deadline',
                        onPressed: () =>
                            setState(() => _deadline = null),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Toggle descriere
                if (!_showDescriere)
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showDescriere = true),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+ Adaugă descriere'),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  TextFormField(
                    controller: _descriereCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Descriere (opțional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    minLines: 2,
                  ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Anulează'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEdit ? 'Salvează' : 'Salvează rapid'),
        ),
      ],
    );
  }
}
