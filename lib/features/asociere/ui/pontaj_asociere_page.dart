import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../pontaj_asociere_models.dart';
import '../pontaj_asociere_repository.dart';
import '../tarif_asociere_repository.dart';
import 'asociere_string_autocomplete.dart';

/// Pontaj zilnic pe asociere. Confirmarea PRO TERM și Partener sunt SEPARATE
/// (butoane distincte) — un pontaj intră în cost doar confirmat de ambele părți.
class PontajAsocierePage extends StatefulWidget {
  const PontajAsocierePage({super.key, required this.asociereId});

  final String asociereId;

  @override
  State<PontajAsocierePage> createState() => _PontajAsocierePageState();
}

class _PontajAsocierePageState extends State<PontajAsocierePage> {
  final _uuid = const Uuid();
  List<PontajAsociereRecord> _items = [];
  List<String> _calificari = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final items = await PontajAsociereRepository.instance
        .listByAsociere(widget.asociereId);
    final tarife = await TarifAsociereRepository.instance
        .listByAsociere(widget.asociereId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _calificari = {
        ...tarife.map((t) => t.calificare),
        ...asociereCalificari,
      }.where((s) => s.isNotEmpty).toList()
        ..sort();
      _loading = false;
    });
  }

  List<String> get _lucratori =>
      _items.map((p) => p.lucratorNume).where((s) => s.isNotEmpty).toSet().toList()
        ..sort();

  Future<void> _add() async {
    final saved = await showModalBottomSheet<PontajAsociereRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PontajForm(
        asociereId: widget.asociereId,
        uuid: _uuid,
        lucratoriSugestii: _lucratori,
        calificariSugestii: _calificari,
      ),
    );
    if (saved != null) {
      await PontajAsociereRepository.instance.upsertPontaj(saved);
      await _load();
    }
  }

  Future<void> _confirma(PontajAsociereRecord p,
      {required bool proTerm}) async {
    final updated = p.copyWith(
      confirmatProTerm: proTerm ? true : p.confirmatProTerm,
      confirmatPartener: proTerm ? p.confirmatPartener : true,
      dataConfirmare: (proTerm ? true : p.confirmatProTerm) &&
              (proTerm ? p.confirmatPartener : true)
          ? DateTime.now()
          : p.dataConfirmare,
    );
    await PontajAsociereRepository.instance.upsertPontaj(updated);
    await _load();
  }

  void _delete(PontajAsociereRecord p) {
    setState(() => _items.removeWhere((i) => i.id == p.id));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Pontaj șters.')));
    PontajAsociereRepository.instance
        .deletePontaj(p.id)
        .catchError((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pontaj asociere')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Pontaj'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Niciun pontaj înregistrat.'))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (_, i) => _tile(_items[i]),
                ),
    );
  }

  Widget _tile(PontajAsociereRecord p) {
    final d = p.data;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${p.lucratorNume} · ${p.ore.toStringAsFixed(1)}h',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Text('${d.day}.${d.month}.${d.year}',
                    style: Theme.of(context).textTheme.bodySmall),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _delete(p),
                ),
              ],
            ),
            Text('${p.calificare} · ${p.angajator.label}'
                '${p.activitateZona.isNotEmpty ? ' · ${p.activitateZona}' : ''}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      p.confirmatProTerm ? null : () => _confirma(p, proTerm: true),
                  icon: Icon(p.confirmatProTerm
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked),
                  label: const Text('PRO TERM'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor:
                          p.confirmatProTerm ? Colors.green : null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: p.confirmatPartener
                      ? null
                      : () => _confirma(p, proTerm: false),
                  icon: Icon(p.confirmatPartener
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked),
                  label: const Text('Partener'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor:
                          p.confirmatPartener ? Colors.green : null),
                ),
              ),
            ]),
            if (p.esteConfirmatIntegral)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Confirmat integral — intră în cost',
                    style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sugestii de calificare implicite (aceleași ca la tarife).
const List<String> asociereCalificari = <String>[
  'manager_santier',
  'frigotehnist_fgaze',
  'instalator',
  'electrician',
  'necalificat',
];

class _PontajForm extends StatefulWidget {
  const _PontajForm({
    required this.asociereId,
    required this.uuid,
    required this.lucratoriSugestii,
    required this.calificariSugestii,
  });

  final String asociereId;
  final Uuid uuid;
  final List<String> lucratoriSugestii;
  final List<String> calificariSugestii;

  @override
  State<_PontajForm> createState() => _PontajFormState();
}

class _PontajFormState extends State<_PontajForm> {
  String _lucrator = '';
  String _calificare = '';
  AsociereAngajator _angajator = AsociereAngajator.proTerm;
  DateTime _data = DateTime.now();
  final _oreCtrl = TextEditingController();
  final _zonaCtrl = TextEditingController();

  @override
  void dispose() {
    _oreCtrl.dispose();
    _zonaCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_lucrator.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lucrătorul e obligatoriu.')));
      return;
    }
    final now = DateTime.now();
    Navigator.of(context).pop(PontajAsociereRecord(
      id: widget.uuid.v4(),
      asociereId: widget.asociereId,
      data: _data,
      lucratorNume: _lucrator.trim(),
      angajator: _angajator,
      calificare: _calificare.trim(),
      ore: double.tryParse(_oreCtrl.text.trim().replaceAll(',', '.')) ?? 0,
      activitateZona: _zonaCtrl.text.trim(),
      createdAt: now,
      updatedAt: now,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pontaj nou', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            AsociereStringAutocomplete(
              label: 'Lucrător',
              optiuni: widget.lucratoriSugestii,
              value: _lucrator,
              onChanged: (v) => _lucrator = v,
            ),
            const SizedBox(height: 12),
            AsociereStringAutocomplete(
              label: 'Calificare',
              optiuni: widget.calificariSugestii,
              value: _calificare,
              onChanged: (v) => _calificare = v,
            ),
            const SizedBox(height: 12),
            SegmentedButton<AsociereAngajator>(
              segments: const [
                ButtonSegment(
                    value: AsociereAngajator.proTerm, label: Text('PRO TERM')),
                ButtonSegment(
                    value: AsociereAngajator.partener, label: Text('Partener')),
              ],
              selected: {_angajator},
              onSelectionChanged: (s) =>
                  setState(() => _angajator = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _oreCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
              ],
              decoration: const InputDecoration(
                  labelText: 'Ore', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _zonaCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Activitate / zonă (opțional)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data'),
              subtitle: Text('${_data.day}.${_data.month}.${_data.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _data,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _data = d);
              },
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _save, child: const Text('Salvează')),
          ],
        ),
      ),
    );
  }
}
