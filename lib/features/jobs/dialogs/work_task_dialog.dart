import 'package:flutter/material.dart';

import '../lucrare_format_utils.dart';

/// Dialog auto-conținut pentru adăugarea/editarea unei etape de lucru (work task)
/// din tab-ul Execuție. Lista inițială de lucrători și callback-ul de validare
/// sunt pasate ca parametri. Extras din `lucrare_detalii_page.dart` (Faza 1).
Future<Map<String, dynamic>?> showWorkTaskDialog(
  BuildContext context, {
  Map<String, dynamic>? initial,
  required List<String> initialWorkers,
  required void Function(String message) onValidationError,
}) {
  final now = DateTime.now();
  final titleController =
      TextEditingController(text: '${initial?['title'] ?? ''}'.trim());
  final notesController =
      TextEditingController(text: '${initial?['notes'] ?? ''}'.trim());
  final workersController =
      TextEditingController(text: initialWorkers.join(', '));
  DateTime start =
      DateTime.tryParse('${initial?['startAt'] ?? ''}'.trim()) ?? now;
  DateTime end = DateTime.tryParse('${initial?['endAt'] ?? ''}'.trim()) ??
      now.add(const Duration(minutes: 30));
  var completed = initial?['completed'] == true;

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickStart() async {
            final picked = await _pickDateTime(context, start);
            if (picked == null) return;
            setModalState(() {
              start = picked;
              if (!end.isAfter(start)) {
                end = start.add(const Duration(minutes: 30));
              }
            });
          }

          Future<void> pickEnd() async {
            final picked = await _pickDateTime(context, end);
            if (picked == null) return;
            setModalState(() => end = picked);
          }

          return AlertDialog(
            title: Text(initial == null ? 'Etapa noua' : 'Editeaza etapa'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Denumire etapa/task',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            'Start: ${lucrareFormatDate(start)} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'),
                      ),
                      TextButton.icon(
                        onPressed: pickStart,
                        icon: const Icon(Icons.schedule),
                        label: const Text('Seteaza'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            'Final: ${lucrareFormatDate(end)} ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'),
                      ),
                      TextButton.icon(
                        onPressed: pickEnd,
                        icon: const Icon(Icons.schedule_outlined),
                        label: const Text('Seteaza'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: workersController,
                    decoration: const InputDecoration(
                      labelText: 'Cine a lucrat (separat prin virgula)',
                    ),
                    minLines: 1,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Observatii',
                    ),
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: completed,
                    title: const Text('Task finalizat'),
                    onChanged: (value) {
                      setModalState(() => completed = value == true);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Renunta'),
              ),
              FilledButton(
                onPressed: () {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    onValidationError('Completeaza denumirea etapei.');
                    return;
                  }
                  if (!end.isAfter(start)) {
                    onValidationError(
                        'Ora de final trebuie sa fie dupa ora de start.');
                    return;
                  }
                  final workers = workersController.text
                      .split(RegExp(r'[,;\n]+'))
                      .map((entry) => entry.trim())
                      .where((entry) => entry.isNotEmpty)
                      .toList(growable: false);
                  Navigator.of(dialogContext).pop(
                    <String, dynamic>{
                      'id':
                          '${initial?['id'] ?? 'task-${DateTime.now().microsecondsSinceEpoch}'}',
                      'title': title,
                      'startAt': start.toIso8601String(),
                      'endAt': end.toIso8601String(),
                      'workers': workers,
                      'notes': notesController.text.trim(),
                      'completed': completed,
                      'updatedAt': DateTime.now().toIso8601String(),
                    },
                  );
                },
                child: const Text('Salveaza'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<DateTime?> _pickDateTime(
  BuildContext context,
  DateTime initial,
) async {
  final pickedDate = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  if (pickedDate == null) {
    return null;
  }
  if (!context.mounted) {
    return null;
  }
  final pickedTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (pickedTime == null) {
    return null;
  }
  return DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    pickedTime.hour,
    pickedTime.minute,
  );
}
