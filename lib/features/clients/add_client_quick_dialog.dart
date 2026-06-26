import 'package:flutter/material.dart';

import '../../core/repositories/app_data_repository.dart';
import '../../core/widgets/anaf_company_autofill_section.dart';
import '../../core/widgets/client_duplicate_check.dart';
import 'client_models.dart';

/// Dialog rapid pentru adăugarea unui client nou direct din module
class AddClientQuickDialog {
  const AddClientQuickDialog._();

  /// Deschide un dialog pentru adăugarea rapidă a unui client nou.
  /// Returnează clientul creat și selectat, sau null dacă renunță.
  /// [existingClients] — lista clienților existenți pentru detecție duplicate după NUME.
  static Future<ClientRecord?> show({
    required BuildContext context,
    required AppDataRepository repository,
    ClientType? defaultType,
    List<ClientRecord> existingClients = const [],
  }) async {
    return showDialog<ClientRecord?>(
      context: context,
      builder: (dialogContext) {
        return _AddClientQuickDialogContent(
          repository: repository,
          defaultType: defaultType,
          existingClients: existingClients,
        );
      },
    );
  }
}

class _AddClientQuickDialogContent extends StatefulWidget {
  const _AddClientQuickDialogContent({
    required this.repository,
    this.defaultType,
    this.existingClients = const [],
  });

  final AppDataRepository repository;
  final ClientType? defaultType;
  final List<ClientRecord> existingClients;

  @override
  State<_AddClientQuickDialogContent> createState() =>
      _AddClientQuickDialogContentState();
}

class _AddClientQuickDialogContentState
    extends State<_AddClientQuickDialogContent> {
  final TextEditingController _nameController = TextEditingController();
  // Lista dinamică de controllere pentru telefoane
  final List<TextEditingController> _phoneControllers = [TextEditingController()];
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cuiController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countyController = TextEditingController();
  final TextEditingController _regComController = TextEditingController();

  late ClientType _selectedType;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.defaultType ?? ClientType.persoanaJuridica;
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _phoneControllers) {
      c.dispose();
    }
    _emailController.dispose();
    _cuiController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countyController.dispose();
    _regComController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Completează numele clientului.';
      });
      return;
    }

    // ── Detecție duplicat unificată (nume, telefon, email, cod extern) ─────
    final existingList = widget.existingClients.isNotEmpty
        ? widget.existingClients
        : await widget.repository.listClients();
    if (!mounted) return;
    final dup = findClientDuplicate(
      existing: existingList,
      name: name,
      phones: _phoneControllers
          .map((c) => c.text.trim())
          .where((p) => p.isNotEmpty)
          .toList(),
      email: _emailController.text.trim(),
    );
    if (dup != null && mounted) {
      final action = await showClientDuplicateDialog(context, dup);
      if (!mounted) return;
      if (action != ClientDuplicateAction.saveAnyway) {
        // "Mergi la clientul existent" → întoarce clientul existent (selectat)
        if (action == ClientDuplicateAction.goToExisting) {
          Navigator.of(context).pop(dup.existing);
        }
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final clientCode = await widget.repository.nextClientCode();

      final newClient = ClientRecord(
        id: 'client-${DateTime.now().millisecondsSinceEpoch}',
        clientCode: clientCode,
        externalClientCode: '',
        externalClientSource: '',
        name: name,
        type: _selectedType,
        contactPerson: '',
        phone: _phoneControllers.isNotEmpty ? _phoneControllers.first.text.trim() : '',
        email: _emailController.text.trim(),
        cui: _cuiController.text.trim(),
        regCom: _regComController.text.trim(),
        bank: '',
        iban: '',
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        county: _countyController.text.trim(),
        isActive: true,
        notes: '',
        departments: const [],
        contactPeople: const [],
        phoneNumbers: _phoneControllers
            .map((c) => c.text.trim())
            .where((p) => p.isNotEmpty)
            .toList(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saved = await widget.repository.saveClient(newClient);

      if (!mounted) return;

      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Eroare la salvare: $error';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adaugă client nou'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tip client
              DropdownButtonFormField<ClientType>(
                initialValue: _selectedType,
                decoration: const InputDecoration(labelText: 'Tip client'),
                items: ClientType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Nume (obligatoriu)
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nume *',
                  hintText: 'Obligatoriu',
                ),
              ),
              const SizedBox(height: 12),

              // Sectiunea ANAF pentru persoana juridica (identica cu Programari)
              if (_selectedType == ClientType.persoanaJuridica)
                AnafCompanyAutofillSection(
                  cuiController: _cuiController,
                  nameController: _nameController,
                  tradeRegisterController: _regComController,
                  phoneController: _phoneControllers.first,
                  addressController: _addressController,
                  cityController: _cityController,
                  countyController: _countyController,
                )
              else
                TextField(
                  controller: _cuiController,
                  decoration: const InputDecoration(labelText: 'CUI'),
                ),
              const SizedBox(height: 12),

              // Numere de telefon (dinamice)
              ...List.generate(_phoneControllers.length, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.phone,
                        controller: _phoneControllers[i],
                        decoration: InputDecoration(
                          labelText: i == 0 ? 'Telefon principal' : 'Telefon ${i + 1}',
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                      ),
                    ),
                    if (_phoneControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => setState(() {
                          _phoneControllers[i].dispose();
                          _phoneControllers.removeAt(i);
                        }),
                      ),
                  ],
                ),
              )),
              if (_phoneControllers.length < 5)
                TextButton.icon(
                  icon: const Icon(Icons.add_call, size: 16),
                  label: const Text('Adaugă număr de telefon'),
                  onPressed: () => setState(() => _phoneControllers.add(TextEditingController())),
                ),
              const SizedBox(height: 6),

              // Email
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // Adresa
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Adresă'),
              ),
              const SizedBox(height: 12),

              // Localitate si Judet
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _cityController,
                      decoration:
                          const InputDecoration(labelText: 'Localitate'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _countyController,
                      decoration: const InputDecoration(labelText: 'Județ'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Nr. Reg. Com. (vizibil pentru PJ)
              if (_selectedType == ClientType.persoanaJuridica) ...[
                TextField(
                  controller: _regComController,
                  decoration: const InputDecoration(labelText: 'Nr. Reg. Com.'),
                ),
                const SizedBox(height: 12),
              ],

              // Mesaj eroare
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Info box
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Clientul va fi creat și selectat automat în formular.',
                        style: TextStyle(
                            color: Colors.blue.shade700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvează'),
        ),
      ],
    );
  }
}
