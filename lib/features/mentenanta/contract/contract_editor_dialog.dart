import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/repositories/app_data_repository.dart';
import '../../../core/widgets/client_autocomplete_field.dart';
import '../../clients/client_models.dart';
import '../echipamente/echipament_editor_dialog.dart';
import '../firebase_mentenanta_repository.dart';
import '../mentenanta_models.dart';

/// Editor complet de contract de mentenanță (creare / editare).
class ContractEditorDialog extends StatefulWidget {
  const ContractEditorDialog({
    super.key,
    required this.repository,
    required this.cloudRepository,
    this.existing,
  });

  final AppDataRepository repository;
  final FirebaseMentenantaRepository cloudRepository;
  final ContractMentenanta? existing;

  @override
  State<ContractEditorDialog> createState() => _ContractEditorDialogState();
}

class _ContractEditorDialogState extends State<ContractEditorDialog> {
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'ro_RO');
  final DateFormat _dateFmt = DateFormat('dd.MM.yyyy');

  late final TextEditingController _titluCtrl;
  late final TextEditingController _numarCtrl;
  late final TextEditingController _observatiiCtrl;

  String _clientId = '';
  String _clientName = '';
  late DateTime _dataStart;
  late DateTime _dataEnd;
  int _interventii = 1;
  late ContractMentenantaStatus _status;
  late List<EchipamentMentenanta> _echipamente;

  List<ClientRecord> _clienti = const [];
  bool _saving = false;
  bool _loadingClients = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    _titluCtrl = TextEditingController(text: e?.titlu ?? '');
    _numarCtrl = TextEditingController(text: e?.numar ?? '');
    _observatiiCtrl = TextEditingController(text: e?.observatii ?? '');
    _clientId = e?.clientId ?? '';
    _clientName = e?.clientName ?? '';
    _dataStart = e?.dataStart ?? now;
    _dataEnd = e?.dataEnd ?? DateTime(now.year + 1, now.month, now.day);
    _interventii = e?.interventiiPlanificate ?? 1;
    _status = e?.status ?? ContractMentenantaStatus.oferta;
    _echipamente = List<EchipamentMentenanta>.from(e?.echipamente ?? const []);
    Future.microtask(_loadClients);
    if (e == null) Future.microtask(_generateNumber);
  }

  @override
  void dispose() {
    _titluCtrl.dispose();
    _numarCtrl.dispose();
    _observatiiCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final list = await widget.repository.listClients();
      if (mounted) setState(() => _clienti = list);
    } catch (e) {
      debugPrint('loadClients error: $e');
      if (mounted) {
        _toast('Nu s-au putut încărca clienții. Verifică conexiunea.');
      }
    } finally {
      if (mounted) setState(() => _loadingClients = false);
    }
  }

  Future<void> _generateNumber() async {
    try {
      final n = await widget.cloudRepository.nextNumber();
      if (mounted && _numarCtrl.text.trim().isEmpty) _numarCtrl.text = n;
    } catch (_) {/* best-effort */}
  }

  ClientRecord? _clientById(String id) =>
      _clienti.where((c) => c.id == id).firstOrNull;

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? _dataStart : _dataEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _dataStart = picked;
      } else {
        _dataEnd = picked;
      }
    });
  }

  Future<void> _addEchipament() async {
    final result = await showDialog<EchipamentMentenanta>(
      context: context,
      builder: (_) => const EchipamentEditorDialog(),
    );
    if (result == null) return;
    setState(() => _echipamente.add(result));
  }

  Future<void> _editEchipament(int index) async {
    final result = await showDialog<EchipamentMentenanta>(
      context: context,
      builder: (_) => EchipamentEditorDialog(existing: _echipamente[index]),
    );
    if (result == null) return;
    setState(() => _echipamente[index] = result);
  }

  void _removeEchipament(int index) {
    setState(() => _echipamente.removeAt(index));
  }

  double get _totalFaraTVA =>
      _echipamente.fold<double>(0, (s, e) => s + e.valoareTotala);
  double get _tva => _totalFaraTVA * ContractMentenanta.cotaTva;
  double get _totalCuTVA => _totalFaraTVA + _tva;

  Future<void> _save() async {
    if (_clientId.isEmpty) {
      _toast('Selectează un client.');
      return;
    }
    if (_echipamente.isEmpty) {
      _toast('Adaugă cel puțin un echipament.');
      return;
    }
    setState(() => _saving = true);

    // Renumerotează nrCrt secvențial.
    final renumbered = <EchipamentMentenanta>[];
    for (var i = 0; i < _echipamente.length; i++) {
      renumbered.add(_echipamente[i].copyWith(nrCrt: i + 1));
    }

    final now = DateTime.now();
    final contract = ContractMentenanta(
      id: widget.existing?.id ?? const Uuid().v4(),
      numar: _numarCtrl.text.trim(),
      clientId: _clientId,
      clientName: _clientName,
      titlu: _titluCtrl.text.trim(),
      dataStart: _dataStart,
      dataEnd: _dataEnd,
      status: _status,
      echipamente: renumbered,
      interventiiPlanificate: _interventii,
      observatii: _observatiiCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final saved = await widget.cloudRepository.saveContract(contract);
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast('Eroare salvare: $e');
      }
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 4),
      backgroundColor: Colors.red.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existing == null
              ? 'Contract nou'
              : 'Editează contract'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  foregroundColor: Colors.white,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Salvează',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _sectionTitle('1. Date generale'),
            const SizedBox(height: 8),
            ClientAutocompleteField(
              key: ValueKey('mentenanta-client-${_clientId.isEmpty ? "none" : _clientId}'),
              clients: _clienti,
              initialClient: _clientById(_clientId),
              labelText: 'Client',
              repository: widget.repository,
              tipEntitate: 'Client',
              onClientSelected: (c) => setState(() {
                _clientId = c?.id ?? '';
                _clientName = c?.name ?? '';
                if (_titluCtrl.text.trim().isEmpty && c != null) {
                  _titluCtrl.text = 'Contract mentenanță ${c.name}';
                }
              }),
              onClientAdded: (c) => setState(() {
                _clienti = [..._clienti, c];
                _clientId = c.id;
                _clientName = c.name;
              }),
            ),
            if (_loadingClients)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Se încarcă lista de clienți...',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _titluCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Titlu contract', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _numarCtrl,
              decoration: const InputDecoration(
                  labelText: 'Număr contract (CM-AAAA-NNNN)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _dateField('Data început', _dataStart, true)),
                const SizedBox(width: 12),
                Expanded(child: _dateField('Data sfârșit', _dataEnd, false)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _interventii,
                    decoration: const InputDecoration(
                        labelText: 'Intervenții/an',
                        border: OutlineInputBorder()),
                    items: const [1, 2, 4]
                        .map((n) => DropdownMenuItem(
                            value: n, child: Text('$n / an')))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _interventii = v ?? 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<ContractMentenantaStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                        labelText: 'Status', border: OutlineInputBorder()),
                    items: const [
                      ContractMentenantaStatus.oferta,
                      ContractMentenantaStatus.acceptata,
                      ContractMentenantaStatus.activ,
                      ContractMentenantaStatus.expirat,
                      ContractMentenantaStatus.anulat,
                    ]
                        .map((s) => DropdownMenuItem(
                            value: s, child: Text(s.label)))
                        .toList(),
                    onChanged: (v) => setState(
                        () => _status = v ?? ContractMentenantaStatus.oferta),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _observatiiCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Observații', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _sectionTitle('2. Echipamente')),
                FilledButton.icon(
                  onPressed: _addEchipament,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adaugă echipament'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_echipamente.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Niciun echipament adăugat.',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ..._buildEchipamenteGrouped(),
            const SizedBox(height: 16),
            _buildTotals(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  foregroundColor: Colors.white,
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _saving ? 'Se salvează...' : 'Salvează contractul',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      );

  Widget _dateField(String label, DateTime value, bool start) {
    return InkWell(
      onTap: () => _pickDate(start: start),
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        child: Text(_dateFmt.format(value)),
      ),
    );
  }

  List<Widget> _buildEchipamenteGrouped() {
    final widgets = <Widget>[];
    final grupate = <CategorieMentenanta, List<int>>{};
    for (var i = 0; i < _echipamente.length; i++) {
      grupate.putIfAbsent(_echipamente[i].categorie, () => []).add(i);
    }
    for (final cat in CategorieMentenanta.values) {
      final indices = grupate[cat];
      if (indices == null || indices.isEmpty) continue;
      final subtotal = indices.fold<double>(
          0, (s, idx) => s + _echipamente[idx].valoareTotala);
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text('── ${cat.label.toUpperCase()} ──',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
      ));
      for (final idx in indices) {
        widgets.add(_buildEchipamentTile(idx));
      }
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 6),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text('Subtotal ${cat.label}: ${_fmt.format(subtotal)} RON',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 12)),
        ),
      ));
    }
    return widgets;
  }

  Widget _buildEchipamentTile(int index) {
    final e = _echipamente[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        title: Text(
          '${e.tipEchipament}${e.model.isEmpty ? '' : ' — ${e.model}'}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${_fmt.format(e.cantitate)} ${e.um} × ${_fmt.format(e.pretTotal)} '
          '(ig. ${_fmt.format(e.pretIgienizare)} + rev. ${_fmt.format(e.pretRevizie)})'
          '${e.necesitaLogFGas ? '  •  F-Gas' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_fmt.format(e.valoareTotala),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () => _editEchipament(index)),
            IconButton(
                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                onPressed: () => _removeEchipament(index)),
          ],
        ),
      ),
    );
  }

  Widget _buildTotals() {
    Widget row(String label, double value, {bool bold = false}) {
      final style = TextStyle(
          fontSize: bold ? 16 : 14,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: style),
            Text('${_fmt.format(value)} RON', style: style),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          row('Total fără TVA', _totalFaraTVA),
          row('TVA (21%)', _tva),
          const Divider(),
          row('TOTAL CU TVA', _totalCuTVA, bold: true),
        ],
      ),
    );
  }
}
