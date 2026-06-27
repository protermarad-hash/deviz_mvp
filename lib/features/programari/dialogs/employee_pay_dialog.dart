import 'package:flutter/material.dart';

import '../../hr/employee_financial_models.dart';
import '../../master/master_local_store.dart';
import '../appointment_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dialog Plată angajați per programare
// ─────────────────────────────────────────────────────────────────────────────

class EmployeePayDialog extends StatefulWidget {
  const EmployeePayDialog({
    super.key,
    required this.item,
    required this.appointmentTitle,
    required this.appointmentDate,
    required this.jobTitle,
    required this.assignedEmployees,
    required this.allEmployees,
    required this.initialEntries,
    required this.currentUserId,
    required this.onSaveEntry,
    required this.onDeleteEntry,
  });

  final Appointment item;
  final String appointmentTitle;
  final String appointmentDate;
  final String jobTitle;
  final List<MasterEmployee> assignedEmployees;
  final List<MasterEmployee> allEmployees;
  final List<EmployeePayEntry> initialEntries;
  final String? currentUserId;
  final Future<void> Function(EmployeePayEntry) onSaveEntry;
  final Future<void> Function(String) onDeleteEntry;

  @override
  State<EmployeePayDialog> createState() => _EmployeePayDialogState();
}

class _EmployeePayDialogState extends State<EmployeePayDialog> {
  late List<EmployeePayEntry> _entries;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _entries = List.from(widget.initialEntries);
  }

  Future<void> _editEntry(EmployeePayEntry? existing, MasterEmployee? preselected) async {
    final amountCtrl = TextEditingController(
      text: existing != null && existing.amountDue > 0
          ? existing.amountDue.toStringAsFixed(2)
          : '',
    );
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    MasterEmployee? selectedEmployee = preselected ??
        (existing != null
            ? widget.allEmployees
                .where((e) => e.id == existing.employeeId)
                .firstOrNull
            : null);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing != null ? 'Editează sumă' : 'Adaugă sumă angajat'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (existing == null)
                  DropdownButtonFormField<MasterEmployee>(
                    initialValue: selectedEmployee,
                    decoration: const InputDecoration(labelText: 'Angajat'),
                    items: widget.allEmployees
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSt(() => selectedEmployee = v),
                  ),
                if (existing != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      existing.employeeName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Sumă datorată (RON)',
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
                if (existing == null && selectedEmployee == null) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    final amount =
        double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final employee = selectedEmployee;
    if (employee == null && existing == null) return;

    setState(() => _saving = true);
    try {
      EmployeePayEntry entry;
      if (existing != null) {
        entry = existing.copyWith(
          amountDue: amount,
          notes: notesCtrl.text.trim(),
        );
      } else {
        // BUG 1 (calea 2) — înainte de create() verifică dacă angajatul are
        // deja o intrare pe această programare (local cache = _entries, toate
        // pentru widget.item.id). Dacă da, folosește copyWith în loc de un id nou.
        final existingForEmployee = _entries
            .where((e) => e.employeeId == employee!.id)
            .firstOrNull;
        if (existingForEmployee != null) {
          entry = existingForEmployee.copyWith(
            amountDue: amount,
            notes: notesCtrl.text.trim(),
          );
        } else {
          entry = EmployeePayEntry.create(
            employeeId: employee!.id,
            employeeName: employee.name,
            appointmentId: widget.item.id,
            appointmentTitle: widget.appointmentTitle,
            appointmentDate: widget.appointmentDate,
            jobId: widget.item.jobId,
            jobTitle: widget.jobTitle,
            amountDue: amount,
            notes: notesCtrl.text.trim(),
            createdBy: widget.currentUserId ?? '',
          );
        }
      }
      await widget.onSaveEntry(entry);
      final updated = List<EmployeePayEntry>.from(_entries);
      final idx = updated.indexWhere((e) => e.id == entry.id);
      if (idx >= 0) {
        updated[idx] = entry;
      } else {
        updated.insert(0, entry);
      }
      if (mounted) setState(() => _entries = updated);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteEntry(EmployeePayEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Șterge înregistrare'),
        content: Text(
          'Ștergi suma de ${entry.amountDue.toStringAsFixed(2)} RON pentru ${entry.employeeName}?',
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
    setState(() => _entries = _entries.where((e) => e.id != entry.id).toList());
    widget.onDeleteEntry(entry.id).catchError((_) {
      if (mounted) {
        setState(() => _entries = [..._entries, entry]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final assignedNotInEntries = widget.assignedEmployees
        .where((emp) => !_entries.any((e) => e.employeeId == emp.id))
        .toList();

    return AlertDialog(
      title: const Text('Plată angajați'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.appointmentTitle.isNotEmpty)
              Text(
                widget.appointmentTitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            if (_entries.isEmpty && assignedNotInEntries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Niciun angajat alocat și nicio sumă înregistrată.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            // Angajați alocați fără sumă — pre-completare rapidă
            for (final emp in assignedNotInEntries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.person_outline),
                title: Text(emp.name),
                subtitle: const Text('Sumă necompletată'),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Adaugă sumă',
                  onPressed: _saving ? null : () => _editEntry(null, emp),
                ),
              ),
            // Sume deja salvate
            for (final entry in _entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.person),
                title: Text(entry.employeeName),
                subtitle: Text(
                  '${entry.amountDue.toStringAsFixed(2)} ${entry.currency}'
                  '${entry.notes.isNotEmpty ? ' · ${entry.notes}' : ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Editează',
                      onPressed:
                          _saving ? null : () => _editEntry(entry, null),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Șterge',
                      onPressed:
                          _saving ? null : () => _deleteEntry(entry),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _editEntry(null, null),
              icon: const Icon(Icons.add),
              label: const Text('Adaugă manual'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Închide'),
        ),
      ],
    );
  }
}
