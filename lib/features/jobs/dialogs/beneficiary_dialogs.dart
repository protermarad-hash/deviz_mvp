import 'package:flutter/material.dart';

import '../job_models.dart';
import '../lucrare_format_utils.dart';

/// Dialoguri auto-conținute pentru echipamentele/materialele puse la dispoziție
/// de beneficiar. Singura dependență externă este callback-ul de validare.
/// Extrase din `lucrare_detalii_page.dart` (Faza 1).

Future<BeneficiarySuppliedEquipment?> showBeneficiaryEquipmentDialog(
  BuildContext context, {
  required void Function(String message) onValidationError,
  BeneficiarySuppliedEquipment? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final typeCtrl = TextEditingController(text: existing?.equipmentType ?? '');
  final brandCtrl = TextEditingController(text: existing?.brand ?? '');
  final modelCtrl = TextEditingController(text: existing?.model ?? '');
  final serialCtrl =
      TextEditingController(text: existing?.serialNumber ?? '');
  final quantityCtrl = TextEditingController(
    text: existing == null ? '1' : existing.quantity.toString(),
  );
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');

  try {
    return await showDialog<BeneficiarySuppliedEquipment>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null
            ? 'Adauga echipament furnizat de beneficiar'
            : 'Editeaza echipament furnizat de beneficiar'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Denumire'),
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: typeCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Tip / categorie'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: brandCtrl,
                        decoration: const InputDecoration(labelText: 'Brand'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: modelCtrl,
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
                        controller: serialCtrl,
                        decoration: const InputDecoration(labelText: 'Serie'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: quantityCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(labelText: 'Cantitate'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: notesCtrl,
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
            child: const Text('Renunta'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                onValidationError('Completeaza denumirea echipamentului.');
                return;
              }
              Navigator.of(context).pop(
                BeneficiarySuppliedEquipment(
                  id: existing?.id ??
                      'beneficiary-equipment-${DateTime.now().microsecondsSinceEpoch}',
                  name: name,
                  equipmentType: typeCtrl.text.trim(),
                  brand: brandCtrl.text.trim(),
                  model: modelCtrl.text.trim(),
                  serialNumber: serialCtrl.text.trim(),
                  quantity: lucrareAsDouble(quantityCtrl.text),
                  notes: notesCtrl.text.trim(),
                ),
              );
            },
            child: const Text('Salveaza'),
          ),
        ],
      ),
    );
  } finally {
    nameCtrl.dispose();
    typeCtrl.dispose();
    brandCtrl.dispose();
    modelCtrl.dispose();
    serialCtrl.dispose();
    quantityCtrl.dispose();
    notesCtrl.dispose();
  }
}

Future<BeneficiarySuppliedMaterial?> showBeneficiaryMaterialDialog(
  BuildContext context, {
  required void Function(String message) onValidationError,
  BeneficiarySuppliedMaterial? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final unitCtrl = TextEditingController(text: existing?.unit ?? '');
  final quantityCtrl = TextEditingController(
    text: existing == null ? '1' : existing.quantity.toString(),
  );
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');

  try {
    return await showDialog<BeneficiarySuppliedMaterial>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null
            ? 'Adauga material furnizat de beneficiar'
            : 'Editeaza material furnizat de beneficiar'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Denumire'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: unitCtrl,
                        decoration: const InputDecoration(labelText: 'UM'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: quantityCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(labelText: 'Cantitate'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: notesCtrl,
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
            child: const Text('Renunta'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                onValidationError('Completeaza denumirea materialului.');
                return;
              }
              Navigator.of(context).pop(
                BeneficiarySuppliedMaterial(
                  id: existing?.id ??
                      'beneficiary-material-${DateTime.now().microsecondsSinceEpoch}',
                  name: name,
                  unit: unitCtrl.text.trim(),
                  quantity: lucrareAsDouble(quantityCtrl.text),
                  notes: notesCtrl.text.trim(),
                ),
              );
            },
            child: const Text('Salveaza'),
          ),
        ],
      ),
    );
  } finally {
    nameCtrl.dispose();
    unitCtrl.dispose();
    quantityCtrl.dispose();
    notesCtrl.dispose();
  }
}
