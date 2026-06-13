import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'complaint_models.dart';

class ComplaintInterventionEditorPage extends StatefulWidget {
  const ComplaintInterventionEditorPage({
    super.key,
    required this.complaint,
    this.existing,
  });

  final ComplaintRecord complaint;
  final ComplaintInterventionEntry? existing;

  @override
  State<ComplaintInterventionEditorPage> createState() =>
      _ComplaintInterventionEditorPageState();
}

class _ComplaintInterventionEditorPageState
    extends State<ComplaintInterventionEditorPage> {
  final Uuid _uuid = const Uuid();

  late final TextEditingController _teamController;
  late final TextEditingController _technicianController;
  late final TextEditingController _findingController;
  late final TextEditingController _workController;
  late final TextEditingController _materialsController;
  late final TextEditingController _partsController;
  late final TextEditingController _notesController;

  late DateTime _date;
  ComplaintInterventionOutcome? _outcome;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final seed = widget.existing;
    _date = seed?.interventionDate ?? DateTime.now();
    _outcome = seed?.outcome;
    _teamController = TextEditingController(text: seed?.teamId ?? '');
    _technicianController = TextEditingController(text: seed?.technicianId ?? '');
    _findingController = TextEditingController(text: seed?.finding ?? '');
    _workController = TextEditingController(text: seed?.workPerformed ?? '');
    _materialsController = TextEditingController(text: seed?.materialsUsed ?? '');
    _partsController = TextEditingController(text: seed?.partsChanged ?? '');
    _notesController = TextEditingController(text: seed?.technicianNotes ?? '');
  }

  @override
  void dispose() {
    _teamController.dispose();
    _technicianController.dispose();
    _findingController.dispose();
    _workController.dispose();
    _materialsController.dispose();
    _partsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  void _save() {
    if (_saving) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final seed = widget.existing;
    final result = ComplaintInterventionEntry(
      id: seed?.id ?? 'ci-${_uuid.v4()}',
      interventionDate: _date,
      teamId: _teamController.text.trim(),
      technicianId: _technicianController.text.trim(),
      finding: _findingController.text.trim(),
      workPerformed: _workController.text.trim(),
      materialsUsed: _materialsController.text.trim(),
      partsChanged: _partsController.text.trim(),
      technicianNotes: _notesController.text.trim(),
      outcome: _outcome,
      createdAt: seed?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editează intervenție' : 'Adaugă intervenție'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Salvează', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Data
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Data intervenției'),
              subtitle: Text(
                '${_date.day.toString().padLeft(2,'0')}.${_date.month.toString().padLeft(2,'0')}.${_date.year}',
              ),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: _pickDate,
            ),
          ),
          const SizedBox(height: 12),

          // Echipă / Tehnician
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _teamController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Echipă',
                    prefixIcon: Icon(Icons.group_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _technicianController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Tehnician',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Constatare
          TextField(
            controller: _findingController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Constatare tehnică',
              prefixIcon: Icon(Icons.search_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Lucrări efectuate
          TextField(
            controller: _workController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Lucrări efectuate',
              prefixIcon: Icon(Icons.build_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Materiale
          TextField(
            controller: _materialsController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Materiale folosite',
              prefixIcon: Icon(Icons.inventory_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Piese schimbate
          TextField(
            controller: _partsController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Piese schimbate',
              prefixIcon: Icon(Icons.settings_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Note tehnician
          TextField(
            controller: _notesController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note tehnician',
              prefixIcon: Icon(Icons.notes_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Outcome
          const Text('Rezultat intervenție', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: ComplaintInterventionOutcome.values.map((o) {
              final selected = _outcome == o;
              return ChoiceChip(
                label: Text(o.label, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (_) => setState(() => _outcome = selected ? null : o),
              );
            }).toList(),
          ),
          const SizedBox(height: 60),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.check),
        label: const Text('Salvează'),
      ),
    );
  }
}
