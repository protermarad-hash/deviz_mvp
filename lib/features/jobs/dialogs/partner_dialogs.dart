import 'package:flutter/material.dart';

import '../../../core/widgets/anaf_company_autofill_section.dart';
import '../../partners/partner_models.dart';
import '../job_partner_models.dart';
import '../lucrare_format_utils.dart';

/// Dialoguri auto-conținute pentru parteneri (companie / personal / autovehicul)
/// din fișa lucrării. Starea necesară (liste master, jobId, callback validare)
/// este pasată ca parametri — funcțiile nu accesează direct starea paginii.
/// Extrase din `lucrare_detalii_page.dart` (Faza 1).

String _newPartnerEntityId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}';

PartnerRecord? _partnerById(List<PartnerRecord> list, String partnerId) {
  for (final partner in list) {
    if (partner.id == partnerId) return partner;
  }
  return null;
}

Future<JobPartner?> showPartnerDialog(
  BuildContext context, {
  required List<PartnerRecord> masterPartners,
  required String jobId,
  required void Function(String message) onValidationError,
  JobPartner? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final cuiCtrl = TextEditingController(text: existing?.cui ?? '');
  final regCtrl =
      TextEditingController(text: existing?.tradeRegisterNumber ?? '');
  final contactCtrl =
      TextEditingController(text: existing?.contactPerson ?? '');
  final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
  final emailCtrl = TextEditingController(text: existing?.email ?? '');
  final addressCtrl = TextEditingController(text: existing?.address ?? '');
  final cityCtrl = TextEditingController(text: existing?.city ?? '');
  final countyCtrl = TextEditingController(text: existing?.county ?? '');
  final ibanCtrl = TextEditingController(text: existing?.iban ?? '');
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  String? selectedMasterPartnerId =
      existing?.masterPartnerId.trim().isNotEmpty == true
          ? existing!.masterPartnerId.trim()
          : null;
  try {
    return await showDialog<JobPartner>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
                existing == null ? 'Adauga partener' : 'Editeaza partener'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (masterPartners.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        initialValue: selectedMasterPartnerId != null &&
                                masterPartners.any(
                                  (item) =>
                                      item.id == selectedMasterPartnerId,
                                )
                            ? selectedMasterPartnerId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Partener salvat',
                          helperText:
                              'Optional: preia datele din registrul de parteneri',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Introducere manuala'),
                          ),
                          ...masterPartners.map(
                            (item) => DropdownMenuItem<String?>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedMasterPartnerId = value;
                            final selected = value == null
                                ? null
                                : _partnerById(masterPartners, value);
                            if (selected == null) return;
                            nameCtrl.text = selected.name;
                            cuiCtrl.text = selected.cui;
                            regCtrl.text = selected.tradeRegisterNumber;
                            contactCtrl.text = selected.contactPerson;
                            phoneCtrl.text = selected.phone;
                            emailCtrl.text = selected.email;
                            addressCtrl.text = selected.address;
                            cityCtrl.text = selected.city;
                            countyCtrl.text = selected.county;
                            ibanCtrl.text = selected.iban;
                            notesCtrl.text = selected.notes;
                          });
                        },
                      ),
                    if (selectedMasterPartnerId == null)
                      AnafCompanyAutofillSection(
                        cuiController: cuiCtrl,
                        nameController: nameCtrl,
                        tradeRegisterController: regCtrl,
                        phoneController: phoneCtrl,
                        ibanController: ibanCtrl,
                        addressController: addressCtrl,
                        cityController: cityCtrl,
                        countyController: countyCtrl,
                      ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Partener / companie'),
                    ),
                    if (selectedMasterPartnerId != null)
                      TextField(
                        controller: cuiCtrl,
                        decoration: const InputDecoration(labelText: 'CUI'),
                      ),
                    TextField(
                      controller: regCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nr. Reg. Com.',
                      ),
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: contactCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Persoana contact'),
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Telefon'),
                    ),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: addressCtrl,
                      decoration: const InputDecoration(labelText: 'Adresa'),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: cityCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Localitate'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: countyCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Judet'),
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: ibanCtrl,
                      decoration: const InputDecoration(labelText: 'IBAN'),
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
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    onValidationError('Completeaza numele partenerului.');
                    return;
                  }
                  Navigator.of(context).pop(
                    JobPartner(
                      id: existing?.id ?? _newPartnerEntityId('job-partner'),
                      jobId: jobId,
                      name: name,
                      masterPartnerId: selectedMasterPartnerId ?? '',
                      cui: cuiCtrl.text.trim(),
                      tradeRegisterNumber: regCtrl.text.trim(),
                      contactPerson: contactCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                      city: cityCtrl.text.trim(),
                      county: countyCtrl.text.trim(),
                      iban: ibanCtrl.text.trim(),
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
    cuiCtrl.dispose();
    regCtrl.dispose();
    contactCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    addressCtrl.dispose();
    cityCtrl.dispose();
    countyCtrl.dispose();
    ibanCtrl.dispose();
    notesCtrl.dispose();
  }
}

Future<JobPartnerWorker?> showPartnerWorkerDialog(
  BuildContext context, {
  required JobPartner partner,
  required List<PartnerWorkerRecord> masterWorkers,
  required String jobId,
  required void Function(String message) onValidationError,
  JobPartnerWorker? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
  final roleCtrl = TextEditingController(text: existing?.role ?? '');
  final hoursCtrl =
      TextEditingController(text: (existing?.workedHours ?? 0).toString());
  final rateCtrl =
      TextEditingController(text: (existing?.hourlyRate ?? 0).toString());
  final currencyCtrl = TextEditingController(
      text: existing?.currency.trim().isNotEmpty == true
          ? existing!.currency
          : 'RON');
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  String? selectedMasterWorkerId =
      existing?.masterWorkerId.trim().isNotEmpty == true
          ? existing!.masterWorkerId.trim()
          : null;
  try {
    return await showDialog<JobPartnerWorker>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              existing == null
                  ? 'Adauga personal partener'
                  : 'Editeaza personal partener',
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        partner.name,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    if (masterWorkers.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        initialValue: selectedMasterWorkerId != null &&
                                masterWorkers.any(
                                  (item) => item.id == selectedMasterWorkerId,
                                )
                            ? selectedMasterWorkerId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Personal salvat',
                          helperText:
                              'Optional: precompleteaza din registrul partenerului',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Introducere manuala'),
                          ),
                          ...masterWorkers.map(
                            (item) => DropdownMenuItem<String?>(
                              value: item.id,
                              child: Text(item.fullName),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedMasterWorkerId = value;
                            final selected = value == null
                                ? null
                                : masterWorkers.firstWhere(
                                    (item) => item.id == value,
                                  );
                            if (selected == null) return;
                            nameCtrl.text = selected.fullName;
                            roleCtrl.text = selected.role;
                            rateCtrl.text =
                                selected.hourlyRate.toStringAsFixed(2);
                            currencyCtrl.text = selected.currency;
                            notesCtrl.text = selected.notes;
                          });
                        },
                      ),
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
                      controller: hoursCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Ore lucrate'),
                    ),
                    TextField(
                      controller: rateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Tarif negociat / ora',
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
                  final fullName = nameCtrl.text.trim();
                  if (fullName.isEmpty) {
                    onValidationError('Completeaza numele persoanei.');
                    return;
                  }
                  Navigator.of(context).pop(
                    JobPartnerWorker(
                      id: existing?.id ??
                          _newPartnerEntityId('job-partner-worker'),
                      jobId: jobId,
                      partnerId: partner.id,
                      fullName: fullName,
                      masterWorkerId: selectedMasterWorkerId ?? '',
                      role: roleCtrl.text.trim(),
                      workedHours: lucrareAsDouble(hoursCtrl.text),
                      hourlyRate: lucrareAsDouble(rateCtrl.text),
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
    roleCtrl.dispose();
    hoursCtrl.dispose();
    rateCtrl.dispose();
    currencyCtrl.dispose();
    notesCtrl.dispose();
  }
}

Future<JobPartnerVehicle?> showPartnerVehicleDialog(
  BuildContext context, {
  required JobPartner partner,
  required List<PartnerVehicleRecord> masterVehicles,
  required String jobId,
  required void Function(String message) onValidationError,
  JobPartnerVehicle? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.vehicleName ?? '');
  final registrationCtrl =
      TextEditingController(text: existing?.registrationNumber ?? '');
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
          : 'RON');
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  String? selectedMasterVehicleId =
      existing?.masterVehicleId.trim().isNotEmpty == true
          ? existing!.masterVehicleId.trim()
          : null;
  try {
    return await showDialog<JobPartnerVehicle>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              existing == null
                  ? 'Adauga autovehicul partener'
                  : 'Editeaza autovehicul partener',
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        partner.name,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    if (masterVehicles.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        initialValue: selectedMasterVehicleId != null &&
                                masterVehicles.any(
                                  (item) =>
                                      item.id == selectedMasterVehicleId,
                                )
                            ? selectedMasterVehicleId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Autovehicul salvat',
                          helperText:
                              'Optional: precompleteaza din registrul partenerului',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Introducere manuala'),
                          ),
                          ...masterVehicles.map(
                            (item) => DropdownMenuItem<String?>(
                              value: item.id,
                              child: Text(item.vehicleName),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedMasterVehicleId = value;
                            final selected = value == null
                                ? null
                                : masterVehicles.firstWhere(
                                    (item) => item.id == value,
                                  );
                            if (selected == null) return;
                            nameCtrl.text = selected.vehicleName;
                            registrationCtrl.text =
                                selected.registrationNumber;
                            consumptionCtrl.text = selected
                                .fuelConsumptionPer100Km
                                .toStringAsFixed(2);
                            fuelPriceCtrl.text =
                                selected.fuelPricePerLiter.toStringAsFixed(2);
                            currencyCtrl.text = selected.currency;
                            notesCtrl.text = selected.notes;
                          });
                        },
                      ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Autovehicul'),
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: registrationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Numar inmatriculare',
                      ),
                    ),
                    TextField(
                      controller: kmCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(labelText: 'Km'),
                    ),
                    TextField(
                      controller: consumptionCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Consum L / 100 km',
                      ),
                    ),
                    TextField(
                      controller: fuelPriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
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
                  if (vehicleName.isEmpty) {
                    onValidationError('Completeaza numele autovehiculului.');
                    return;
                  }
                  Navigator.of(context).pop(
                    JobPartnerVehicle(
                      id: existing?.id ??
                          _newPartnerEntityId('job-partner-vehicle'),
                      jobId: jobId,
                      partnerId: partner.id,
                      vehicleName: vehicleName,
                      masterVehicleId: selectedMasterVehicleId ?? '',
                      registrationNumber: registrationCtrl.text.trim(),
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
    registrationCtrl.dispose();
    kmCtrl.dispose();
    consumptionCtrl.dispose();
    fuelPriceCtrl.dispose();
    currencyCtrl.dispose();
    notesCtrl.dispose();
  }
}
