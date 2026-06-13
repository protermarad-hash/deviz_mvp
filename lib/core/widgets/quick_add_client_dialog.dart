import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/repositories/app_data_repository.dart';
import '../../core/widgets/anaf_company_autofill_section.dart';
import '../../features/clients/client_models.dart';

/// Bottom sheet complet pentru adăugarea unui client/partener/beneficiar.
/// Formularul este identic cu cel din modulul Clienți — nu este un formular sumar.
/// Deschis inline fără navigare, ca DraggableScrollableSheet.
class QuickAddClientSheet extends StatefulWidget {
  const QuickAddClientSheet({
    super.key,
    required this.repository,
    this.prefillName,
    this.tipEntitate = 'Client',
    required this.onCreated,
  });

  final AppDataRepository repository;
  final String? prefillName;
  final String tipEntitate;
  final void Function(ClientRecord created) onCreated;

  @override
  State<QuickAddClientSheet> createState() => _QuickAddClientSheetState();
}

class _QuickAddClientSheetState extends State<QuickAddClientSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Tip client
  ClientType _tipClient = ClientType.persoanaJuridica;

  // Date identificare
  late TextEditingController _numeCtrl;
  final _cuiCtrl = TextEditingController();
  final _regCtrl = TextEditingController();

  // Contact
  final _contactCtrl = TextEditingController();
  final List<TextEditingController> _telefoaneCtrl = [TextEditingController()];
  final _emailCtrl = TextEditingController();

  // Date bancare
  final _bancaCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();

  // Adresă
  final _adresaCtrl = TextEditingController();
  final _orasCtrl = TextEditingController();
  final _judetCtrl = TextEditingController();

  // Observații
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _numeCtrl = TextEditingController(text: widget.prefillName?.trim() ?? '');
  }

  @override
  void dispose() {
    _numeCtrl.dispose();
    _cuiCtrl.dispose();
    _regCtrl.dispose();
    _contactCtrl.dispose();
    for (final c in _telefoaneCtrl) {
      c.dispose();
    }
    _emailCtrl.dispose();
    _bancaCtrl.dispose();
    _ibanCtrl.dispose();
    _adresaCtrl.dispose();
    _orasCtrl.dispose();
    _judetCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final clientCode = await widget.repository.nextClientCode();
      final phones = _telefoaneCtrl
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final newClient = ClientRecord(
        id: 'client-${const Uuid().v4().replaceAll('-', '')}',
        clientCode: clientCode,
        externalClientCode: '',
        externalClientSource: '',
        type: _tipClient,
        name: _numeCtrl.text.trim(),
        contactPerson: _contactCtrl.text.trim(),
        phone: phones.isNotEmpty ? phones[0] : '',
        phone2: phones.length > 1 ? phones[1] : '',
        phone3: phones.length > 2 ? phones[2] : '',
        phoneNumbers: phones,
        email: _emailCtrl.text.trim(),
        cui: _cuiCtrl.text.trim(),
        regCom: _regCtrl.text.trim(),
        iban: _ibanCtrl.text.trim(),
        bank: _bancaCtrl.text.trim(),
        address: _adresaCtrl.text.trim(),
        city: _orasCtrl.text.trim(),
        county: _judetCtrl.text.trim(),
        notes: _noteCtrl.text.trim(),
        departments: const [],
        contactPeople: const [],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saved = await widget.repository.saveClient(newClient);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated(saved);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('${widget.tipEntitate} "${saved.name}" adăugat și selectat ✓'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Eroare la salvare: $e'),
          backgroundColor: Colors.red,
        ));
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Color(0xFFC62828),
            letterSpacing: 0.5,
          ),
        ),
      );

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_add_outlined,
                          color: Color(0xFFC62828)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.tipEntitate} nou',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Formular ───────────────────────────────────────────────────
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    // ── TIP CLIENT ──────────────────────────────────────────
                    _sectionTitle('Tip'),
                    SegmentedButton<ClientType>(
                      segments: const [
                        ButtonSegment(
                          value: ClientType.persoanaFizica,
                          label: Text('Persoană fizică'),
                          icon: Icon(Icons.person_outlined),
                        ),
                        ButtonSegment(
                          value: ClientType.persoanaJuridica,
                          label: Text('Persoană juridică'),
                          icon: Icon(Icons.business_outlined),
                        ),
                      ],
                      selected: {_tipClient},
                      onSelectionChanged: (s) =>
                          setState(() => _tipClient = s.first),
                    ),
                    const SizedBox(height: 16),

                    // ── DATE IDENTIFICARE ───────────────────────────────────
                    _sectionTitle('Date identificare'),
                    TextFormField(
                      controller: _numeCtrl,
                      autofocus: widget.prefillName?.isEmpty != false,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _dec(
                        _tipClient == ClientType.persoanaJuridica
                            ? 'Denumire firmă *'
                            : 'Nume și prenume *',
                        Icons.badge_outlined,
                      ),
                      validator: (v) =>
                          v?.trim().isEmpty == true ? 'Obligatoriu' : null,
                    ),
                    const SizedBox(height: 12),

                    // CUI + ANAF autofill (pt PJ)
                    if (_tipClient == ClientType.persoanaJuridica) ...[
                      AnafCompanyAutofillSection(
                        cuiController: _cuiCtrl,
                        nameController: _numeCtrl,
                        tradeRegisterController: _regCtrl,
                        phoneController: _telefoaneCtrl.first,
                        ibanController: _ibanCtrl,
                        addressController: _adresaCtrl,
                        cityController: _orasCtrl,
                        countyController: _judetCtrl,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _regCtrl,
                        textCapitalization: TextCapitalization.none,
                        decoration:
                            _dec('Nr. Reg. Com.', Icons.article_outlined),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      TextFormField(
                        controller: _cuiCtrl,
                        textCapitalization: TextCapitalization.none,
                        decoration: _dec('CNP', Icons.numbers_outlined),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── CONTACT ─────────────────────────────────────────────
                    _sectionTitle('Contact'),
                    TextFormField(
                      controller: _contactCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dec(
                          'Persoană principală de contact', Icons.person_outlined),
                    ),
                    const SizedBox(height: 12),

                    // Telefoane multiple
                    ..._telefoaneCtrl.asMap().entries.map((entry) {
                      final i = entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: entry.value,
                                keyboardType: TextInputType.phone,
                                decoration: _dec(
                                  i == 0
                                      ? 'Telefon principal'
                                      : 'Telefon ${i + 1}',
                                  Icons.phone_outlined,
                                ),
                              ),
                            ),
                            if (i > 0)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Colors.red),
                                onPressed: () => setState(() {
                                  entry.value.dispose();
                                  _telefoaneCtrl.removeAt(i);
                                }),
                              ),
                          ],
                        ),
                      );
                    }),
                    if (_telefoaneCtrl.length < 3)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.add_call, size: 18),
                          label: const Text('Adaugă număr de telefon'),
                          onPressed: () => setState(
                              () => _telefoaneCtrl.add(TextEditingController())),
                        ),
                      ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textCapitalization: TextCapitalization.none,
                      decoration: _dec('Email', Icons.email_outlined),
                    ),
                    const SizedBox(height: 16),

                    // ── DATE BANCARE ────────────────────────────────────────
                    _sectionTitle('Date bancare (opțional)'),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _bancaCtrl,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: _dec('Bancă', Icons.account_balance_outlined),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _ibanCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration:
                                _dec('IBAN', Icons.account_balance_wallet_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── ADRESĂ ──────────────────────────────────────────────
                    _sectionTitle('Adresă'),
                    TextFormField(
                      controller: _adresaCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration:
                          _dec('Stradă, număr, bloc', Icons.location_on_outlined),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _orasCtrl,
                            textCapitalization: TextCapitalization.sentences,
                            decoration:
                                _dec('Oraș / Localitate', Icons.location_city_outlined),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _judetCtrl,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: _dec('Județ', Icons.map_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── OBSERVAȚII ──────────────────────────────────────────
                    _sectionTitle('Observații'),
                    TextFormField(
                      controller: _noteCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration:
                          _dec('Note / observații', Icons.note_outlined),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // ── BUTON SALVEAZĂ ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _onSave,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          'Salvează și selectează ${widget.tipEntitate}',
                          style: const TextStyle(fontSize: 15),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFC62828),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deschide bottom sheet complet pentru adăugarea unui client/partener/beneficiar.
/// Returnează [ClientRecord] creat sau null dacă utilizatorul a închis fără salvare.
Future<ClientRecord?> showQuickAddClientDialog(
  BuildContext context, {
  required AppDataRepository repository,
  String? prefillName,
  String tipEntitate = 'Client',
}) async {
  ClientRecord? result;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => QuickAddClientSheet(
      repository: repository,
      prefillName: prefillName,
      tipEntitate: tipEntitate,
      onCreated: (c) => result = c,
    ),
  );
  return result;
}
