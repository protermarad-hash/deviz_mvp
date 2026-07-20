import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../core/repositories/app_data_repository.dart';
import '../../../core/widgets/partner_autocomplete_field.dart';
import '../../partners/partner_models.dart';
import '../asociere_models.dart';
import '../asociere_repository.dart';

/// Configurare asociere pentru o lucrare — creare sau editare.
class AsociereConfigPage extends StatefulWidget {
  const AsociereConfigPage({
    super.key,
    required this.repository,
    required this.lucrareId,
    this.existing,
  });

  final AppDataRepository repository;
  final String lucrareId;
  final AsociereRecord? existing;

  @override
  State<AsociereConfigPage> createState() => _AsociereConfigPageState();
}

class _AsociereConfigPageState extends State<AsociereConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  List<PartnerRecord> _parteneri = const [];
  String _partenerId = '';

  late final TextEditingController _numeCtrl;
  late final TextEditingController _cuiCtrl;
  late final TextEditingController _ibanCtrl;
  late final TextEditingController _telefonCtrl;
  late final TextEditingController _cotaPtCtrl;
  late final TextEditingController _cotaPartenerCtrl;
  late final TextEditingController _pragCtrl;
  late final TextEditingController _distribuireCtrl;
  late final TextEditingController _rezervaCtrl;
  late final TextEditingController _garantieCtrl;

  AsociereIncasator? _incasator;
  AsociereStatus _status = AsociereStatus.activa;
  DateTime _dataInceput = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _partenerId = e?.partenerExternId ?? '';
    _numeCtrl = TextEditingController(text: e?.partenerExternNume ?? '');
    _cuiCtrl = TextEditingController(text: e?.partenerExternCUI ?? '');
    _ibanCtrl = TextEditingController(text: e?.partenerExternIBAN ?? '');
    _telefonCtrl = TextEditingController(text: e?.partenerExternTelefon ?? '');
    _cotaPtCtrl =
        TextEditingController(text: e != null ? _fmt(e.cotaProTerm) : '');
    _cotaPartenerCtrl =
        TextEditingController(text: e != null ? _fmt(e.cotaPartener) : '');
    _pragCtrl = TextEditingController(text: _fmt(e?.pragAprobareRON ?? 1000));
    _distribuireCtrl =
        TextEditingController(text: _fmt(e?.procentDistribuireIntermediara ?? 70));
    _rezervaCtrl =
        TextEditingController(text: _fmt(e?.procentRezervaGarantie ?? 30));
    _garantieCtrl =
        TextEditingController(text: '${e?.durataGarantieLuni ?? 24}');
    _incasator = e?.cineFactureazaBeneficiarul;
    _status = e?.status ?? AsociereStatus.activa;
    _dataInceput = e?.dataInceput ?? DateTime.now();
    Future.microtask(_loadPartners);
  }

  @override
  void dispose() {
    for (final c in [
      _numeCtrl,
      _cuiCtrl,
      _ibanCtrl,
      _telefonCtrl,
      _cotaPtCtrl,
      _cotaPartenerCtrl,
      _pragCtrl,
      _distribuireCtrl,
      _rezervaCtrl,
      _garantieCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _loadPartners() async {
    try {
      final list = await widget.repository.listPartners();
      if (mounted) setState(() => _parteneri = list);
    } catch (_) {}
  }

  PartnerRecord? _partenerById(String id) {
    if (id.isEmpty) return null;
    for (final p in _parteneri) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _onPartnerSelected(PartnerRecord? p) {
    if (p == null) return;
    setState(() {
      _partenerId = p.id;
      _numeCtrl.text = p.name;
      _cuiCtrl.text = p.cui;
      _ibanCtrl.text = p.iban;
      _telefonCtrl.text = p.phone;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_incasator == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Alege cine facturează Beneficiarul (obligatoriu).'),
      ));
      return;
    }
    final cotaPt = _parse(_cotaPtCtrl);
    final cotaPartener = _parse(_cotaPartenerCtrl);
    if ((cotaPt + cotaPartener - 100).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cotele PRO TERM + Partener trebuie să însumeze 100%.'),
      ));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final e = widget.existing;
    final record = AsociereRecord(
      id: e?.id ?? _uuid.v4(),
      lucrareId: widget.lucrareId,
      cineFactureazaBeneficiarul: _incasator!,
      partenerExternId: _partenerId,
      partenerExternNume: _numeCtrl.text.trim(),
      partenerExternCUI: _cuiCtrl.text.trim(),
      partenerExternIBAN: _ibanCtrl.text.trim(),
      partenerExternTelefon: _telefonCtrl.text.trim(),
      cotaProTerm: cotaPt,
      cotaPartener: cotaPartener,
      pragAprobareRON: _parse(_pragCtrl),
      procentDistribuireIntermediara: _parse(_distribuireCtrl),
      procentRezervaGarantie: _parse(_rezervaCtrl),
      durataGarantieLuni: int.tryParse(_garantieCtrl.text.trim()) ?? 24,
      dataInceput: _dataInceput,
      dataReceptieFinala: e?.dataReceptieFinala,
      status: _status,
      createdAt: e?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      await AsociereRepository.instance.upsertAsociere(record);
      if (mounted) Navigator.of(context).pop(record);
    } catch (err) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Eroare la salvare: $err')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
          title: Text(isEdit ? 'Editează asociere' : 'Adaugă asociere')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Partener extern',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            PartnerAutocompleteField(
              partners: _parteneri,
              initialPartner: _partenerById(_partenerId),
              labelText: 'Selectează partener (opțional)',
              helperText: 'Sau completează manual câmpurile de mai jos',
              onPartnerSelected: _onPartnerSelected,
            ),
            const SizedBox(height: 12),
            _text(_numeCtrl, 'Nume partener', requiredField: true),
            _text(_cuiCtrl, 'CUI', keyboard: TextInputType.text),
            _text(_ibanCtrl, 'IBAN'),
            _text(_telefonCtrl, 'Telefon', keyboard: TextInputType.phone),
            const Divider(height: 32),
            Text('Cote profit/pierdere',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _number(_cotaPtCtrl, 'Cotă PRO TERM %',
                      requiredField: true)),
              const SizedBox(width: 12),
              Expanded(
                  child: _number(_cotaPartenerCtrl, 'Cotă Partener %',
                      requiredField: true)),
            ]),
            const SizedBox(height: 8),
            Text('Trebuie să însumeze 100%.',
                style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: 32),
            Text('Cine facturează Beneficiarul (încasează) *',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<AsociereIncasator>(
              segments: const [
                ButtonSegment(
                    value: AsociereIncasator.proTerm, label: Text('PRO TERM')),
                ButtonSegment(
                    value: AsociereIncasator.partener, label: Text('Partener')),
              ],
              selected: _incasator == null ? <AsociereIncasator>{} : {_incasator!},
              emptySelectionAllowed: true,
              onSelectionChanged: (s) =>
                  setState(() => _incasator = s.isEmpty ? null : s.first),
            ),
            if (_incasator == null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Obligatoriu — determină direcția rambursării.',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            const Divider(height: 32),
            Row(children: [
              Expanded(child: _number(_pragCtrl, 'Prag aprobare (RON)')),
              const SizedBox(width: 12),
              Expanded(child: _number(_garantieCtrl, 'Garanție (luni)')),
            ]),
            Row(children: [
              Expanded(
                  child: _number(_distribuireCtrl, 'Distribuire imediată %')),
              const SizedBox(width: 12),
              Expanded(child: _number(_rezervaCtrl, 'Rezervă garanție %')),
            ]),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data început'),
              subtitle: Text(
                  '${_dataInceput.day}.${_dataInceput.month}.${_dataInceput.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            if (isEdit)
              DropdownButtonFormField<AsociereStatus>(
                initialValue: _status,
                decoration: const InputDecoration(
                    labelText: 'Status', border: OutlineInputBorder()),
                items: AsociereStatus.values
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text(s.label)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(isEdit ? 'Salvează' : 'Creează asociere'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dataInceput,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _dataInceput = d);
  }

  Widget _text(TextEditingController c, String label,
      {bool requiredField = false, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        textCapitalization: keyboard == null
            ? TextCapitalization.sentences
            : TextCapitalization.none,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        validator: requiredField
            ? (v) => (v == null || v.trim().isEmpty) ? 'Obligatoriu' : null
            : null,
      ),
    );
  }

  Widget _number(TextEditingController c, String label,
      {bool requiredField = false}) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder()),
      validator: requiredField
          ? (v) => (v == null || v.trim().isEmpty) ? 'Obligatoriu' : null
          : null,
    );
  }
}
