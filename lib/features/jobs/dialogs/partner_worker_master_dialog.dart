import 'package:flutter/material.dart';

import '../partner_worker_master_models.dart';

/// Dialog auto-conținut adăugare/editare rapidă a unui muncitor partener în
/// catalogul jobs/ (PartnerWorkerMaster). Folosit atât din pagina de
/// management (`PartnerWorkerMasterPage`) cât și din butonul „Nou” al
/// câmpului de autocompletare, ca să poți adăuga un muncitor nou fără să ieși
/// din fișa lucrării.
Future<PartnerWorkerMaster?> showPartnerWorkerMasterDialog(
  BuildContext context, {
  required String partnerId,
  required void Function(String message) onValidationError,
  PartnerWorkerMaster? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
  final roleCtrl = TextEditingController(text: existing?.role ?? '');
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  var active = existing?.active ?? true;
  try {
    return await showDialog<PartnerWorkerMaster>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null
                ? 'Adaugă muncitor în catalog'
                : 'Editează muncitor',
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Nume complet'),
                  ),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: roleCtrl,
                    decoration: const InputDecoration(labelText: 'Rol'),
                  ),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: notesCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Observații'),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activ'),
                    subtitle: const Text(
                      'Inactiv = nu mai apare la alocarea pe lucrări noi',
                    ),
                    value: active,
                    onChanged: (value) =>
                        setDialogState(() => active = value),
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
                final fullName = nameCtrl.text.trim();
                if (fullName.isEmpty) {
                  onValidationError('Completează numele persoanei.');
                  return;
                }
                final now = DateTime.now();
                Navigator.of(context).pop(
                  PartnerWorkerMaster(
                    id: existing?.id ??
                        'partner-worker-master-${now.microsecondsSinceEpoch}',
                    partnerId: partnerId,
                    fullName: fullName,
                    role: roleCtrl.text.trim(),
                    active: active,
                    notes: notesCtrl.text.trim(),
                    createdAt: existing?.createdAt ?? now,
                    updatedAt: now,
                  ),
                );
              },
              child: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );
  } finally {
    nameCtrl.dispose();
    roleCtrl.dispose();
    notesCtrl.dispose();
  }
}
