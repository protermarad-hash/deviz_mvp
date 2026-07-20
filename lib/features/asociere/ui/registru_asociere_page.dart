import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../cost_asociere_models.dart';
import '../cost_asociere_repository.dart';
import '../venit_asociere_models.dart';
import '../venit_asociere_repository.dart';

/// Registrul Asocierii — costuri + venituri, filtrabile, cu indicator vizual
/// pe costurile care necesită aprobare și nu sunt aprobate integral.
/// Conținut financiar — ecranul e deschis DOAR pentru admin (gating în tab).
class RegistruAsocierePage extends StatefulWidget {
  const RegistruAsocierePage({
    super.key,
    required this.asociereId,
    required this.pragAprobareRON,
  });

  final String asociereId;
  final double pragAprobareRON;

  @override
  State<RegistruAsocierePage> createState() => _RegistruAsocierePageState();
}

class _RegistruAsocierePageState extends State<RegistruAsocierePage> {
  final _uuid = const Uuid();
  List<CostAsociereRecord> _costuri = [];
  List<VenitAsociereRecord> _venituri = [];
  bool _loading = true;

  AsociereCostCategorie? _filtruCategorie;
  AsociereParte? _filtruPlatitor;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final c =
        await CostAsociereRepository.instance.listByAsociere(widget.asociereId);
    final v =
        await VenitAsociereRepository.instance.listByAsociere(widget.asociereId);
    if (!mounted) return;
    setState(() {
      _costuri = c;
      _venituri = v;
      _loading = false;
    });
  }

  List<CostAsociereRecord> get _costuriFiltrate => _costuri.where((c) {
        if (_filtruCategorie != null && c.categorie != _filtruCategorie) {
          return false;
        }
        if (_filtruPlatitor != null && c.asociatPlatitor != _filtruPlatitor) {
          return false;
        }
        return true;
      }).toList();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Registru asociere'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Costuri', icon: Icon(Icons.receipt_long_outlined)),
            Tab(text: 'Venituri', icon: Icon(Icons.payments_outlined)),
          ]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_costuriTab(), _venituriTab()]),
      ),
    );
  }

  // ── Costuri ────────────────────────────────────────────────────────────────

  Widget _costuriTab() {
    final items = _costuriFiltrate;
    return Column(
      children: [
        _filtre(),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('Niciun cost.'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) => _costTile(items[i]),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _addCost,
            icon: const Icon(Icons.add),
            label: const Text('Adaugă cost'),
          ),
        ),
      ],
    );
  }

  Widget _filtre() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(
          child: DropdownButtonFormField<AsociereCostCategorie?>(
            initialValue: _filtruCategorie,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Categorie', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Toate')),
              ...AsociereCostCategorie.values.map((c) =>
                  DropdownMenuItem(value: c, child: Text(c.label))),
            ],
            onChanged: (v) => setState(() => _filtruCategorie = v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<AsociereParte?>(
            initialValue: _filtruPlatitor,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Plătitor', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Toți')),
              ...AsociereParte.values.map((p) =>
                  DropdownMenuItem(value: p, child: Text(p.label))),
            ],
            onChanged: (v) => setState(() => _filtruPlatitor = v),
          ),
        ),
      ]),
    );
  }

  Widget _costTile(CostAsociereRecord c) {
    final blocheaza = c.necesitaAprobare && !c.esteAprobatIntegral;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      color: blocheaza ? Colors.orange.withValues(alpha: 0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: blocheaza
            ? BorderSide(color: Colors.orange.shade400)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(c.descriere.isEmpty ? '(fără descriere)' : c.descriere,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Text('${c.valoareFaraTva.toStringAsFixed(2)} RON'),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _deleteCost(c),
              ),
            ]),
            Text('${c.categorie.label} · plătit de ${c.asociatPlatitor.label} · '
                '${c.data.day}.${c.data.month}.${c.data.year}',
                style: Theme.of(context).textTheme.bodySmall),
            if (blocheaza) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                const Expanded(
                    child: Text('Necesită aprobare — neconfirmat integral',
                        style: TextStyle(color: Colors.orange, fontSize: 12))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: c.aprobatProTerm
                        ? null
                        : () => _aproba(c, proTerm: true),
                    child: Text(c.aprobatProTerm
                        ? 'PRO TERM ✓'
                        : 'Aprobă PRO TERM'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: c.aprobatPartener
                        ? null
                        : () => _aproba(c, proTerm: false),
                    child: Text(c.aprobatPartener
                        ? 'Partener ✓'
                        : 'Aprobă Partener'),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _aproba(CostAsociereRecord c, {required bool proTerm}) async {
    final aprobatPt = proTerm ? true : c.aprobatProTerm;
    final aprobatPartener = proTerm ? c.aprobatPartener : true;
    final integral = aprobatPt && aprobatPartener;
    final updated = c.copyWith(
      aprobatProTerm: aprobatPt,
      aprobatPartener: aprobatPartener,
      dataAprobare: integral ? DateTime.now() : c.dataAprobare,
    );
    await CostAsociereRepository.instance.upsertCost(updated);
    await _load();
  }

  void _deleteCost(CostAsociereRecord c) {
    setState(() => _costuri.removeWhere((i) => i.id == c.id));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Cost șters.')));
    CostAsociereRepository.instance.deleteCost(c.id).catchError((_) => _load());
  }

  Future<void> _addCost() async {
    final saved = await showModalBottomSheet<CostAsociereRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CostForm(
        asociereId: widget.asociereId,
        uuid: _uuid,
        prag: widget.pragAprobareRON,
      ),
    );
    if (saved != null) {
      await CostAsociereRepository.instance.upsertCost(saved);
      await _load();
    }
  }

  // ── Venituri ───────────────────────────────────────────────────────────────

  Widget _venituriTab() {
    return Column(
      children: [
        Expanded(
          child: _venituri.isEmpty
              ? const Center(child: Text('Niciun venit.'))
              : ListView.builder(
                  itemCount: _venituri.length,
                  itemBuilder: (_, i) {
                    final v = _venituri[i];
                    return ListTile(
                      leading: Icon(v.esteIncasat
                          ? Icons.check_circle_outline
                          : Icons.schedule),
                      title: Text('${v.nrFactura} · '
                          '${v.valoareFaraTva.toStringAsFixed(2)} RON'),
                      subtitle: Text(v.esteIncasat
                          ? 'Încasat ${v.dataIncasare!.day}.${v.dataIncasare!.month}.${v.dataIncasare!.year}'
                          : 'Neîncasat (nu intră în decont)'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteVenit(v),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _addVenit,
            icon: const Icon(Icons.add),
            label: const Text('Adaugă venit'),
          ),
        ),
      ],
    );
  }

  void _deleteVenit(VenitAsociereRecord v) {
    setState(() => _venituri.removeWhere((i) => i.id == v.id));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Venit șters.')));
    VenitAsociereRepository.instance
        .deleteVenit(v.id)
        .catchError((_) => _load());
  }

  Future<void> _addVenit() async {
    final saved = await showModalBottomSheet<VenitAsociereRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VenitForm(asociereId: widget.asociereId, uuid: _uuid),
    );
    if (saved != null) {
      await VenitAsociereRepository.instance.upsertVenit(saved);
      await _load();
    }
  }
}

// ── Formular cost ────────────────────────────────────────────────────────────

class _CostForm extends StatefulWidget {
  const _CostForm(
      {required this.asociereId, required this.uuid, required this.prag});

  final String asociereId;
  final Uuid uuid;
  final double prag;

  @override
  State<_CostForm> createState() => _CostFormState();
}

class _CostFormState extends State<_CostForm> {
  AsociereCostCategorie _categorie = AsociereCostCategorie.material;
  AsociereParte _platitor = AsociereParte.proTerm;
  DateTime _data = DateTime.now();
  final _descCtrl = TextEditingController();
  final _valCtrl = TextEditingController();

  @override
  void dispose() {
    _descCtrl.dispose();
    _valCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final val = double.tryParse(_valCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final necesitaAprobare =
        CostAsociereRecord.computeNecesitaAprobare(val, widget.prag);
    final now = DateTime.now();
    Navigator.of(context).pop(CostAsociereRecord(
      id: widget.uuid.v4(),
      asociereId: widget.asociereId,
      categorie: _categorie,
      data: _data,
      descriere: _descCtrl.text.trim(),
      valoareFaraTva: val,
      asociatPlatitor: _platitor,
      necesitaAprobare: necesitaAprobare,
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
            Text('Cost nou', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<AsociereCostCategorie>(
              initialValue: _categorie,
              decoration: const InputDecoration(
                  labelText: 'Categorie', border: OutlineInputBorder()),
              items: AsociereCostCategorie.values
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (v) => setState(() => _categorie = v ?? _categorie),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Descriere', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
              ],
              decoration: const InputDecoration(
                  labelText: 'Valoare fără TVA (RON)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SegmentedButton<AsociereParte>(
              segments: const [
                ButtonSegment(
                    value: AsociereParte.proTerm, label: Text('PRO TERM')),
                ButtonSegment(
                    value: AsociereParte.partener, label: Text('Partener')),
              ],
              selected: {_platitor},
              onSelectionChanged: (s) => setState(() => _platitor = s.first),
            ),
            const SizedBox(height: 8),
            Text('Plătit efectiv de partea selectată.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
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

// ── Formular venit ───────────────────────────────────────────────────────────

class _VenitForm extends StatefulWidget {
  const _VenitForm({required this.asociereId, required this.uuid});

  final String asociereId;
  final Uuid uuid;

  @override
  State<_VenitForm> createState() => _VenitFormState();
}

class _VenitFormState extends State<_VenitForm> {
  final _nrCtrl = TextEditingController();
  final _valCtrl = TextEditingController();
  final _sitCtrl = TextEditingController();
  DateTime _dataFactura = DateTime.now();
  DateTime? _dataIncasare;

  @override
  void dispose() {
    _nrCtrl.dispose();
    _valCtrl.dispose();
    _sitCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final now = DateTime.now();
    Navigator.of(context).pop(VenitAsociereRecord(
      id: widget.uuid.v4(),
      asociereId: widget.asociereId,
      nrFactura: _nrCtrl.text.trim(),
      dataFactura: _dataFactura,
      valoareFaraTva:
          double.tryParse(_valCtrl.text.trim().replaceAll(',', '.')) ?? 0,
      situatieLucrariAferenta: _sitCtrl.text.trim(),
      dataIncasare: _dataIncasare,
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
            Text('Venit nou', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _nrCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Nr. factură', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
              ],
              decoration: const InputDecoration(
                  labelText: 'Valoare fără TVA (RON)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sitCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Situație lucrări aferentă (opțional)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data factură'),
              subtitle: Text(
                  '${_dataFactura.day}.${_dataFactura.month}.${_dataFactura.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dataFactura,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _dataFactura = d);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data încasare'),
              subtitle: Text(_dataIncasare == null
                  ? 'Neîncasat — nu intră în decont'
                  : '${_dataIncasare!.day}.${_dataIncasare!.month}.${_dataIncasare!.year}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_dataIncasare != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _dataIncasare = null),
                  ),
                const Icon(Icons.calendar_today),
              ]),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dataIncasare ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _dataIncasare = d);
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
