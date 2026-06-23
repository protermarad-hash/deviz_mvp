import 'package:flutter/material.dart';

import '../../../core/repositories/app_data_repository.dart';
import '../../../core/widgets/anaf_company_autofill_section.dart';
import '../../clients/client_models.dart';
import '../../partners/partner_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dialoguri auto-conținute pentru creare rapidă client / partener.
// Extrase din programari_page.dart (Faza 1 refactor) — primesc date doar prin
// parametri (context + repository) și returnează rezultatul prin return value.
// NU referențiază starea paginii Programări.
// ─────────────────────────────────────────────────────────────────────────────

/// Deschide dialogul „Client nou rapid". Returnează clientul salvat sau `null`
/// dacă utilizatorul renunță.
Future<ClientRecord?> openQuickCreateClientDialog(
  BuildContext context,
  AppDataRepository repository,
) async {
  final codeController = TextEditingController(
    text: await repository.nextClientCode(),
  );
  final externalClientCodeController = TextEditingController();
  final externalClientSourceController = TextEditingController();
  final nameController = TextEditingController();
  final cuiController = TextEditingController();
  final regController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final countyController = TextEditingController();
  final notesController = TextEditingController();
  final type = ValueNotifier<ClientType>(ClientType.persoanaJuridica);
  final useAutomaticCode = ValueNotifier<bool>(true);
  String? formError;

  if (!context.mounted) {
    return null;
  }

  final saved = await showDialog<ClientRecord>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Client nou rapid'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: codeController,
                      enabled: !useAutomaticCode.value,
                      decoration: InputDecoration(
                        labelText: 'Cod client intern',
                        helperText: useAutomaticCode.value
                            ? 'Generat automat'
                            : 'Editare manuala',
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: useAutomaticCode,
                      builder: (_, value, __) {
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Cod client intern automat'),
                          value: value,
                          onChanged: (newValue) async {
                            useAutomaticCode.value = newValue;
                            if (newValue) {
                              codeController.text =
                                  await repository.nextClientCode();
                            }
                            setDialogState(() {});
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<ClientType>(
                      valueListenable: type,
                      builder: (_, value, __) {
                        return DropdownButtonFormField<ClientType>(
                          initialValue: value,
                          decoration:
                              const InputDecoration(labelText: 'Tip client'),
                          items: ClientType.values
                              .map(
                                (item) => DropdownMenuItem<ClientType>(
                                  value: item,
                                  child: Text(item.label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (newValue) {
                            if (newValue == null) return;
                            type.value = newValue;
                            setDialogState(() {});
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Nume client'),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<ClientType>(
                      valueListenable: type,
                      builder: (_, value, __) {
                        if (value == ClientType.persoanaJuridica) {
                          return AnafCompanyAutofillSection(
                            cuiController: cuiController,
                            nameController: nameController,
                            tradeRegisterController: regController,
                            phoneController: phoneController,
                            addressController: addressController,
                            cityController: cityController,
                            countyController: countyController,
                          );
                        }
                        return TextField(
                          controller: cuiController,
                          decoration: const InputDecoration(labelText: 'CUI'),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: phoneController,
                            decoration:
                                const InputDecoration(labelText: 'Telefon'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: emailController,
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Adresa'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: cityController,
                            decoration: const InputDecoration(
                                labelText: 'Localitate'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: countyController,
                            decoration:
                                const InputDecoration(labelText: 'Judet'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: regController,
                      decoration:
                          const InputDecoration(labelText: 'Nr. Reg. Com.'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: notesController,
                            decoration: const InputDecoration(
                                labelText: 'Observatii'),
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
                            controller: externalClientCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Cod client extern',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: externalClientSourceController,
                            decoration: const InputDecoration(
                              labelText: 'Sursa cod extern / Partener',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((formError ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        formError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Renunță'),
              ),
              FilledButton(
                onPressed: () async {
                  final trimmedName = nameController.text.trim();
                  final trimmedCode = codeController.text.trim();
                  if (trimmedName.isEmpty) {
                    setDialogState(() {
                      formError = 'Completeaza numele clientului.';
                    });
                    return;
                  }
                  if (trimmedCode.isEmpty) {
                    setDialogState(() {
                      formError = 'Completeaza codul clientului.';
                    });
                    return;
                  }

                  final now = DateTime.now();
                  final client = ClientRecord(
                    id: 'client-${now.microsecondsSinceEpoch}',
                    clientCode: trimmedCode,
                    externalClientCode:
                        externalClientCodeController.text.trim(),
                    externalClientSource:
                        externalClientSourceController.text.trim(),
                    type: type.value,
                    name: trimmedName,
                    contactPerson: '',
                    cui: cuiController.text.trim(),
                    regCom: regController.text.trim(),
                    phone: phoneController.text.trim(),
                    email: emailController.text.trim(),
                    address: addressController.text.trim(),
                    city: cityController.text.trim(),
                    county: countyController.text.trim(),
                    notes: notesController.text.trim(),
                    isActive: true,
                    createdAt: now,
                    updatedAt: now,
                  );
                  final savedClient =
                      await repository.saveClient(client);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(savedClient);
                  }
                },
                child: const Text('Salveaza clientul'),
              ),
            ],
          );
        },
      );
    },
  );

  codeController.dispose();
  externalClientCodeController.dispose();
  externalClientSourceController.dispose();
  nameController.dispose();
  cuiController.dispose();
  regController.dispose();
  phoneController.dispose();
  emailController.dispose();
  addressController.dispose();
  cityController.dispose();
  countyController.dispose();
  notesController.dispose();
  type.dispose();
  useAutomaticCode.dispose();
  return saved;
}

/// Deschide dialogul „Partener nou rapid". Returnează partenerul salvat sau
/// `null` dacă utilizatorul renunță.
Future<PartnerRecord?> openQuickCreatePartnerDialog(
  BuildContext context,
  AppDataRepository repository,
) async {
  final nameController = TextEditingController();
  final cuiController = TextEditingController();
  final regController = TextEditingController();
  final contactController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final countyController = TextEditingController();
  final ibanController = TextEditingController();
  String? formError;

  if (!context.mounted) {
    return null;
  }

  final saved = await showDialog<PartnerRecord>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Partener nou rapid'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnafCompanyAutofillSection(
                      cuiController: cuiController,
                      nameController: nameController,
                      tradeRegisterController: regController,
                      phoneController: phoneController,
                      ibanController: ibanController,
                      addressController: addressController,
                      cityController: cityController,
                      countyController: countyController,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Partener / companie',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: regController,
                      decoration: const InputDecoration(
                        labelText: 'Nr. Reg. Com.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: contactController,
                      decoration: const InputDecoration(
                        labelText: 'Persoana contact',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: phoneController,
                            decoration:
                                const InputDecoration(labelText: 'Telefon'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: emailController,
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Adresa'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: cityController,
                            decoration: const InputDecoration(
                              labelText: 'Localitate',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: countyController,
                            decoration:
                                const InputDecoration(labelText: 'Judet'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ibanController,
                      decoration: const InputDecoration(labelText: 'IBAN'),
                    ),
                    if ((formError ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        formError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Renunță'),
              ),
              FilledButton(
                onPressed: () async {
                  final trimmedName = nameController.text.trim();
                  if (trimmedName.isEmpty) {
                    setDialogState(() {
                      formError = 'Completeaza numele partenerului.';
                    });
                    return;
                  }
                  final now = DateTime.now();
                  final partner = PartnerRecord(
                    id: 'partner-${now.microsecondsSinceEpoch}',
                    name: trimmedName,
                    cui: cuiController.text.trim(),
                    tradeRegisterNumber: regController.text.trim(),
                    contactPerson: contactController.text.trim(),
                    phone: phoneController.text.trim(),
                    email: emailController.text.trim(),
                    address: addressController.text.trim(),
                    city: cityController.text.trim(),
                    county: countyController.text.trim(),
                    iban: ibanController.text.trim(),
                    notes: '',
                    createdAt: now,
                    updatedAt: now,
                  );
                  final savedPartner =
                      await repository.savePartner(partner);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(savedPartner);
                  }
                },
                child: const Text('Salveaza partenerul'),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
  cuiController.dispose();
  regController.dispose();
  contactController.dispose();
  phoneController.dispose();
  emailController.dispose();
  addressController.dispose();
  cityController.dispose();
  countyController.dispose();
  ibanController.dispose();
  return saved;
}
