import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../mentenanta_models.dart';
import 'firebase_interventie_repository.dart';
import 'interventie_models.dart';

/// Editor pentru o intervenție de service legată de un contract de mentenanță.
///
/// Secțiunea 1 — date generale; Secțiunea 2 — echipamentele din contract, cu
/// checkbox „inclus", status, observații și (condiționat) câmpuri F-Gas.
class InterventieEditorPage extends StatefulWidget {
  const InterventieEditorPage({
    super.key,
    required this.contract,
    required this.repository,
    this.existing,
  });

  final ContractMentenanta contract;
  final FirebaseInterventieRepository repository;
  final InterventieService? existing;

  @override
  State<InterventieEditorPage> createState() => _InterventieEditorPageState();
}

class _InterventieEditorPageState extends State<InterventieEditorPage> {
  final _uuid = const Uuid();
  final _dateFmt = DateFormat('dd.MM.yyyy');

  late final TextEditingController _numarController;
  late final TextEditingController _tehnicianController;
  late final TextEditingController _echipaController;
  late final TextEditingController _observatiiController;

  late DateTime _dataInterventie;
  late TipInterventie _tip;
  late String _id;
  late DateTime _createdAt;
  bool _saving = false;

  final List<_EchipRow> _rows = [];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _id = existing?.id ?? '';
    _createdAt = existing?.createdAt ?? DateTime.now();
    _numarController = TextEditingController(text: existing?.numar ?? '');
    _tehnicianController = TextEditingController(text: existing?.tehnician ?? '');
    _echipaController = TextEditingController(text: existing?.echipa ?? '');
    _observatiiController =
        TextEditingController(text: existing?.observatii ?? '');
    _dataInterventie = existing?.dataInterventie ?? DateTime.now();
    _tip = existing?.tipInterventie ?? TipInterventie.igienizareRevizie;

    // Construiește rândurile din echipamentele contractului; pre-completează din
    // intervenția existentă (dacă se editează).
    final existingById = <String, EchipamentInterventie>{
      for (final e in (existing?.echipamenteLucrate ?? const []))
        e.echipamentId: e,
    };
    for (final ech in widget.contract.echipamente) {
      final prev = existingById[ech.id];
      _rows.add(_EchipRow(
        echipamentId: ech.id,
        denumire: ech.tipEchipament,
        model: ech.model,
        necesitaLogFGas: ech.necesitaLogFGas,
        included: existing == null ? true : prev != null,
        status: prev?.status ?? StatusEchipamentInterventie.efectuat,
        observatii: TextEditingController(text: prev?.observatii ?? ''),
        agentFrigorific: TextEditingController(text: prev?.agentFrigorific ?? ''),
        cantitateAdaugata: TextEditingController(
            text: prev != null && prev.cantitateAdaugata > 0
                ? prev.cantitateAdaugata.toString()
                : ''),
        cantitateRecuperata: TextEditingController(
            text: prev != null && prev.cantitateRecuperata > 0
                ? prev.cantitateRecuperata.toString()
                : ''),
      ));
    }

    if (existing == null) {
      Future.microtask(_assignNumber);
    }
  }

  Future<void> _assignNumber() async {
    final next = await widget.repository.nextNumber(DateTime.now().year);
    if (!mounted || _numarController.text.trim().isNotEmpty) return;
    setState(() => _numarController.text = next);
  }

  @override
  void dispose() {
    _numarController.dispose();
    _tehnicianController.dispose();
    _echipaController.dispose();
    _observatiiController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataInterventie,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _dataInterventie = DateTime(
        picked.year, picked.month, picked.day,
        _dataInterventie.hour, _dataInterventie.minute));
  }

  double _parse(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    final included = _rows.where((r) => r.included).toList();
    if (included.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Include cel puțin un echipament în intervenție.')));
      return;
    }
    setState(() => _saving = true);

    final echipamente = included
        .map((r) => EchipamentInterventie(
              echipamentId: r.echipamentId,
              denumire: r.denumire,
              model: r.model,
              status: r.status,
              observatii: r.observatii.text.trim(),
              agentFrigorific: r.agentFrigorific.text.trim(),
              cantitateAdaugata: _parse(r.cantitateAdaugata.text),
              cantitateRecuperata: _parse(r.cantitateRecuperata.text),
              necesitaLogFGas: r.necesitaLogFGas,
            ))
        .toList();

    final interventie = InterventieService(
      id: _id.isEmpty ? _uuid.v4() : _id,
      contractId: widget.contract.id,
      numar: _numarController.text.trim(),
      dataInterventie: _dataInterventie,
      tehnician: _tehnicianController.text.trim(),
      echipa: _echipaController.text.trim(),
      tipInterventie: _tip,
      echipamenteLucrate: echipamente,
      observatii: _observatiiController.text.trim(),
      pvGenerat: widget.existing?.pvGenerat ?? false,
      pvPath: widget.existing?.pvPath ?? '',
      logFGasGenerat: widget.existing?.logFGasGenerat ?? false,
      logFGasPath: widget.existing?.logFGasPath ?? '',
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
    );

    final saved = await widget.repository.saveInterventie(interventie);
    if (!mounted) return;
    Navigator.of(context).pop(saved);
  }

  // ── UI ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null
            ? 'Intervenție nouă'
            : 'Editează intervenția'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Se salvează...' : 'Salvează intervenția'),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDateGenerale(),
            const SizedBox(height: 12),
            _buildEchipamente(),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDateGenerale() {
    return _section('1. Date generale', [
      TextField(
        controller: _numarController,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Număr intervenție',
          hintText: 'IS-AAAA-NNNN',
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _pickDate,
        icon: const Icon(Icons.event_outlined),
        label: Text('Data intervenției: ${_dateFmt.format(_dataInterventie)}'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _tehnicianController,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Tehnician'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _echipaController,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Echipă'),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<TipInterventie>(
        initialValue: _tip,
        decoration: const InputDecoration(labelText: 'Tip intervenție'),
        items: TipInterventie.values
            .map((t) =>
                DropdownMenuItem(value: t, child: Text(t.label)))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _tip = v);
        },
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _observatiiController,
        textCapitalization: TextCapitalization.sentences,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Observații generale'),
      ),
    ]);
  }

  Widget _buildEchipamente() {
    if (_rows.isEmpty) {
      return _section('2. Echipamente lucrate', const [
        Text('Contractul nu are echipamente. Adaugă echipamente în contract '
            'înainte de a înregistra intervenția.'),
      ]);
    }
    return _section(
      '2. Echipamente lucrate (${_rows.where((r) => r.included).length}/${_rows.length})',
      [
        for (var i = 0; i < _rows.length; i++) ...[
          _buildEchipRow(_rows[i]),
          if (i < _rows.length - 1) const Divider(height: 20),
        ],
      ],
    );
  }

  Widget _buildEchipRow(_EchipRow row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: row.included,
              onChanged: (v) => setState(() => row.included = v ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.denumire.isEmpty ? '(fără denumire)' : row.denumire,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (row.model.isNotEmpty)
                    Text(row.model,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700)),
                ],
              ),
            ),
            if (row.necesitaLogFGas)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('F-Gas',
                    style: TextStyle(fontSize: 11, color: Colors.blue)),
              ),
          ],
        ),
        if (row.included) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<StatusEchipamentInterventie>(
            initialValue: row.status,
            decoration: const InputDecoration(
                labelText: 'Status', isDense: true),
            items: StatusEchipamentInterventie.values
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.label,
                          style: TextStyle(color: s.color)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => row.status = v);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.observatii,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: 'Observații echipament', isDense: true),
          ),
          if (row.necesitaLogFGas) ...[
            const SizedBox(height: 8),
            TextField(
              controller: row.agentFrigorific,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Agent frigorific (ex: R32, R410A)',
                  isDense: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.cantitateAdaugata,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Adăugat (kg)', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: row.cantitateRecuperata,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Recuperat (kg)', isDense: true),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// Stare mutabilă per echipament în editor (controllers + status + inclus).
class _EchipRow {
  _EchipRow({
    required this.echipamentId,
    required this.denumire,
    required this.model,
    required this.necesitaLogFGas,
    required this.included,
    required this.status,
    required this.observatii,
    required this.agentFrigorific,
    required this.cantitateAdaugata,
    required this.cantitateRecuperata,
  });

  final String echipamentId;
  final String denumire;
  final String model;
  final bool necesitaLogFGas;
  bool included;
  StatusEchipamentInterventie status;
  final TextEditingController observatii;
  final TextEditingController agentFrigorific;
  final TextEditingController cantitateAdaugata;
  final TextEditingController cantitateRecuperata;

  void dispose() {
    observatii.dispose();
    agentFrigorific.dispose();
    cantitateAdaugata.dispose();
    cantitateRecuperata.dispose();
  }
}
