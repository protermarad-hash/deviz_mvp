import 'package:flutter/material.dart';

import '../../../core/app_models.dart';
import '../job_partner_models.dart';
import '../lucrare_format_utils.dart';

/// Dialog auto-conținut pentru autoturismele proprii alocate lucrării.
/// Registrul de autoturisme și callback-ul de validare sunt pasate ca parametri.
/// Extras din `lucrare_detalii_page.dart` (Faza 1).
Future<JobOwnVehicle?> showOwnVehicleDialog(
  BuildContext context, {
  required List<VehicleRecord> masterOwnVehicles,
  required String jobId,
  required void Function(String message) onValidationError,
  JobOwnVehicle? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.vehicleName ?? '');
  final plateCtrl = TextEditingController(text: existing?.plateNumber ?? '');
  final kmCtrl = TextEditingController(text: (existing?.km ?? 0).toString());
  final consumptionCtrl = TextEditingController(
    text: (existing?.fuelConsumptionPer100Km ?? 0).toString(),
  );
  final fuelPriceCtrl = TextEditingController(
    text: (existing?.fuelPricePerLiter ?? 0).toString(),
  );
  final currencyCtrl = TextEditingController(
    text: existing?.currency.trim().isNotEmpty == true
        ? existing!.currency
        : 'RON',
  );
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  String? selectedMasterVehicleId =
      existing?.masterVehicleId.trim().isNotEmpty == true
          ? existing!.masterVehicleId.trim()
          : null;
  try {
    return await showDialog<JobOwnVehicle>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              existing == null
                  ? 'Adauga autoturism propriu'
                  : 'Editeaza autoturism propriu',
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (masterOwnVehicles.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        initialValue: selectedMasterVehicleId != null &&
                                masterOwnVehicles.any(
                                  (item) =>
                                      item.id == selectedMasterVehicleId,
                                )
                            ? selectedMasterVehicleId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Autoturism din registru',
                          helperText:
                              'Optional: precompleteaza din autoturismele proprii',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Introducere manuala'),
                          ),
                          ...masterOwnVehicles.map(
                            (item) => DropdownMenuItem<String?>(
                              value: item.id,
                              child: Text(
                                item.name.isNotEmpty
                                    ? '${item.name} (${item.plateNumber})'
                                    : item.plateNumber,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedMasterVehicleId = value;
                            final selected = value == null
                                ? null
                                : masterOwnVehicles.firstWhere(
                                    (item) => item.id == value,
                                  );
                            if (selected == null) return;
                            nameCtrl.text = selected.name;
                            plateCtrl.text = selected.plateNumber;
                            consumptionCtrl.text = selected
                                .fuelConsumptionLPer100Km
                                .toStringAsFixed(2);
                            fuelPriceCtrl.text =
                                selected.fuelPricePerLiter.toStringAsFixed(2);
                          });
                        },
                      ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Denumire autoturism',
                      ),
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: plateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Numar inmatriculare',
                      ),
                    ),
                    TextField(
                      controller: kmCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Km'),
                    ),
                    TextField(
                      controller: consumptionCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Consum L / 100 km',
                      ),
                    ),
                    TextField(
                      controller: fuelPriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Pret combustibil / litru',
                      ),
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: currencyCtrl,
                      decoration: const InputDecoration(labelText: 'Moneda'),
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: notesCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Observatii'),
                      minLines: 2,
                      maxLines: 4,
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
                  final vehicleName = nameCtrl.text.trim();
                  if (vehicleName.isEmpty && plateCtrl.text.trim().isEmpty) {
                    onValidationError(
                        'Completeaza denumirea sau numarul de inmatriculare.');
                    return;
                  }
                  Navigator.of(context).pop(
                    JobOwnVehicle(
                      id: existing?.id ??
                          'job-own-vehicle-${DateTime.now().microsecondsSinceEpoch}',
                      jobId: jobId,
                      masterVehicleId: selectedMasterVehicleId ?? '',
                      vehicleName: vehicleName.isNotEmpty
                          ? vehicleName
                          : plateCtrl.text.trim(),
                      plateNumber: plateCtrl.text.trim(),
                      km: lucrareAsDouble(kmCtrl.text),
                      fuelConsumptionPer100Km:
                          lucrareAsDouble(consumptionCtrl.text),
                      fuelPricePerLiter: lucrareAsDouble(fuelPriceCtrl.text),
                      currency: currencyCtrl.text.trim().isEmpty
                          ? 'RON'
                          : currencyCtrl.text.trim().toUpperCase(),
                      notes: notesCtrl.text.trim(),
                    ),
                  );
                },
                child: const Text('Salveaza'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    nameCtrl.dispose();
    plateCtrl.dispose();
    kmCtrl.dispose();
    consumptionCtrl.dispose();
    fuelPriceCtrl.dispose();
    currencyCtrl.dispose();
    notesCtrl.dispose();
  }
}
