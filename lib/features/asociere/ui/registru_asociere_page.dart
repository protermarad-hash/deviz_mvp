import 'package:flutter/material.dart';

import '../asociere_operational_common.dart';
import '../cost_asociere_models.dart';
import '../cost_asociere_repository.dart';
import '../venit_asociere_models.dart';
import '../venit_asociere_repository.dart';
import 'asociere_string_autocomplete.dart';

class RegistruAsocierePage extends StatefulWidget {
  const RegistruAsocierePage({
    super.key,
    required this.projectId,
    required this.contractId,
    required this.actorId,
    required this.canEdit,
    required this.canApprove,
    this.initialMode = 'registru',
  });
  final String projectId;
  final String contractId;
  final String actorId;
  final bool canEdit;
  final bool canApprove;
  final String initialMode;
  @override
  State<RegistruAsocierePage> createState() => _RegistruAsocierePageState();
}

class _RegistruAsocierePageState extends State<RegistruAsocierePage> {
  List<CostAsociereRecord> _costs = const [];
  List<VenitAsociereRecord> _income = const [];
  bool _loading = true;
  String _category = '';
  String _party = '';
  String _status = '';
  bool _missingDocument = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait([
      CostAsociereRepository.instance.listByProject(widget.projectId),
      VenitAsociereRepository.instance.listByProject(widget.projectId),
    ]);
    if (mounted) {
      setState(() {
        _costs = values[0] as List<CostAsociereRecord>;
        _income = values[1] as List<VenitAsociereRecord>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = <_RegisterEntry>[
      if (widget.initialMode != 'venituri')
        ..._costs.where(_costVisible).map((item) => _RegisterEntry(
            item.data,
            item.categorie.label,
            item.descriere,
            -item.valoareProiect,
            item.platitor.label,
            item.status.label,
            item.documentRef,
            item)),
      if (widget.initialMode != 'costuri')
        ..._income.map((item) => _RegisterEntry(
            item.dataFactura ?? item.createdAt,
            'Venit ${item.etapa.name}',
            item.numarFactura.isEmpty ? 'Venit estimat' : item.numarFactura,
            item.etapa == VenitAsociereEtapa.incasat
                ? item.valoareProiect
                : item.valoareFaraTva * item.curs,
            item.emitent.label,
            item.status.label,
            item.documentRef,
            item)),
    ]..sort((a, b) => b.date.compareTo(a.date));
    final total = entries.fold<double>(0, (sum, item) => sum + item.value);
    return Scaffold(
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              heroTag: 'asociere_registru_add',
              onPressed: _addMenu,
              icon: const Icon(Icons.add),
              label: const Text('Înregistrare'))
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              _filters(),
              Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: ListTile(
                      title: const Text('Total registru derivat'),
                      trailing: Text('${total.toStringAsFixed(2)} RON',
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)))),
              Expanded(
                  child: entries.isEmpty
                      ? const Center(
                          child: Text(
                              'Registrul este gol. Datele se derivă din sursele canonice.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                          itemCount: entries.length,
                          itemBuilder: (_, i) => _entry(entries[i]))),
            ]),
    );
  }

  bool _costVisible(CostAsociereRecord item) {
    if (_category.isNotEmpty && item.categorie.value != _category) return false;
    if (_party.isNotEmpty && item.platitor.value != _party) return false;
    if (_status.isNotEmpty && item.status.value != _status) return false;
    if (_missingDocument && (item.documentRef ?? '').isNotEmpty) return false;
    return true;
  }

  Widget _filters() => Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        SizedBox(
            width: 190,
            child: AsociereStringAutocomplete(
                label: 'Categorie',
                optiuni: [
                  '',
                  ...AsociereCostCategorie.values.map((e) => e.value)
                ],
                value: _category,
                onChanged: (v) => setState(() => _category = v))),
        SizedBox(
            width: 180,
            child: AsociereStringAutocomplete(
                label: 'Asociat',
                optiuni: const ['', 'pro_term', 'partener', 'beneficiar'],
                value: _party,
                onChanged: (v) => setState(() => _party = v))),
        SizedBox(
            width: 180,
            child: AsociereStringAutocomplete(
                label: 'Status',
                optiuni: [
                  '',
                  ...AsociereOperationalStatus.values.map((e) => e.value)
                ],
                value: _status,
                onChanged: (v) => setState(() => _status = v))),
        FilterChip(
            label: const Text('Document lipsă'),
            selected: _missingDocument,
            onSelected: (v) => setState(() => _missingDocument = v)),
      ]));

  Widget _entry(_RegisterEntry entry) => Card(
          child: ListTile(
        leading: Icon(
            entry.value >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
            color: entry.value >= 0 ? Colors.green : Colors.red),
        title: Text('${entry.category} · ${entry.description}'),
        subtitle: Text(
            '${entry.date.day}.${entry.date.month}.${entry.date.year} · ${entry.party} · ${entry.status}${(entry.document ?? '').isEmpty ? ' · document lipsă' : ''}'),
        trailing: Text('${entry.value.toStringAsFixed(2)} RON'),
        onTap: entry.source is CostAsociereRecord && widget.canApprove
            ? () => _costActions(entry.source as CostAsociereRecord)
            : null,
      ));

  Future<void> _addMenu() async {
    final type = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.shopping_cart_outlined),
                  title: const Text('Cost draft'),
                  onTap: () => Navigator.pop(context, 'cost')),
              ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Venit'),
                  onTap: () => Navigator.pop(context, 'income')),
            ])));
    if (type == 'cost') await _newCost();
    if (type == 'income') await _newIncome();
  }

  Future<void> _newCost() async {
    final value = await showDialog<CostAsociereRecord>(
        context: context,
        builder: (_) => _CostDialog(
            projectId: widget.projectId,
            contractId: widget.contractId,
            actorId: widget.actorId));
    if (value == null) return;
    final errors = value.validate();
    if (errors.isNotEmpty) {
      _show(errors);
      return;
    }
    await CostAsociereRepository.instance.upsertCost(value);
    await _load();
  }

  Future<void> _newIncome() async {
    final value = await showDialog<VenitAsociereRecord>(
        context: context,
        builder: (_) => _IncomeDialog(
            projectId: widget.projectId,
            contractId: widget.contractId,
            actorId: widget.actorId));
    if (value == null) return;
    final errors = value.validate();
    if (errors.isNotEmpty) {
      _show(errors);
      return;
    }
    await VenitAsociereRepository.instance.upsertVenit(value);
    await _load();
  }

  void _show(List<String> errors) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(errors.join('\n'))));

  Future<void> _costActions(CostAsociereRecord item) async {
    if (item.esteAprobat) return;
    final approve = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Aprobare cost'),
                content: const Text(
                    'Aprobarea necesită document, plătitor, dată, valoare, categorie și actor.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Renunță')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Aprobă'))
                ]));
    if (approve != true) return;
    final now = DateTime.now();
    var candidate = item;
    if ((candidate.documentRef ?? '').isEmpty) {
      final document = await _askDocument();
      if (document == null) return;
      candidate = CostAsociereRecord.fromMap(
          candidate.toMap()..addAll({'document_ref': document}));
    }
    final approved = candidate.copyWith(
        status: AsociereOperationalStatus.aprobat,
        aprobatDe: widget.actorId,
        aprobatLa: now,
        updatedAt: now,
        updatedBy: widget.actorId,
        revision: item.revision + 1);
    final errors = approved.validate();
    if (errors.isNotEmpty) {
      _show(errors);
      return;
    }
    await CostAsociereRepository.instance.upsertCost(approved);
    await _load();
  }

  Future<String?> _askDocument() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Document justificativ'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Referință document',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Renunță')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Continuă')),
        ],
      ),
    );
    controller.dispose();
    return (result ?? '').isEmpty ? null : result;
  }
}

class _RegisterEntry {
  const _RegisterEntry(this.date, this.category, this.description, this.value,
      this.party, this.status, this.document, this.source);
  final DateTime date;
  final String category, description, party, status;
  final double value;
  final String? document;
  final Object source;
}

double _num(TextEditingController c) =>
    double.tryParse(c.text.replaceAll(',', '.')) ?? double.nan;

class _CostDialog extends StatefulWidget {
  const _CostDialog(
      {required this.projectId,
      required this.contractId,
      required this.actorId});
  final String projectId, contractId, actorId;
  @override
  State<_CostDialog> createState() => _CostDialogState();
}

class _CostDialogState extends State<_CostDialog> {
  final description = TextEditingController(),
      value = TextEditingController(text: '0'),
      document = TextEditingController(),
      supplier = TextEditingController();
  String category = 'materiale', payer = 'pro_term';
  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Cost draft'),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            AsociereStringAutocomplete(
                label: 'Categorie (căutare)',
                optiuni:
                    AsociereCostCategorie.values.map((e) => e.value).toList(),
                value: category,
                onChanged: (v) => category = v),
            const SizedBox(height: 8),
            AsociereStringAutocomplete(
                label: 'Plătitor (căutare)',
                optiuni: const ['pro_term', 'partener', 'beneficiar'],
                value: payer,
                onChanged: (v) => payer = v),
            const SizedBox(height: 8),
            TextField(
                controller: description,
                decoration: const InputDecoration(
                    labelText: 'Descriere', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: supplier,
                decoration: const InputDecoration(
                    labelText: 'Furnizor', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: value,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Valoare fără TVA',
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: document,
                decoration: const InputDecoration(
                    labelText: 'Document/ref. (opțional în draft)',
                    border: OutlineInputBorder())),
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Renunță')),
            FilledButton(onPressed: _save, child: const Text('Salvează draft'))
          ]);
  void _save() {
    final now = DateTime.now();
    Navigator.pop(
        context,
        CostAsociereRecord(
            id: 'cost_${now.microsecondsSinceEpoch}',
            projectId: widget.projectId,
            contractId: widget.contractId,
            sourceType: 'manual',
            sourceId: 'manual_${now.microsecondsSinceEpoch}',
            categorie: AsociereCostCategorie.fromValue(category),
            descriere: description.text.trim(),
            data: now,
            furnizor: supplier.text.trim(),
            documentRef:
                document.text.trim().isEmpty ? null : document.text.trim(),
            valoareFaraTva: _num(value),
            valoareProiect: _num(value),
            platitor: AsociereParteX.fromValue(payer),
            createdAt: now,
            updatedAt: now,
            createdBy: widget.actorId,
            updatedBy: widget.actorId));
  }
}

class _IncomeDialog extends StatefulWidget {
  const _IncomeDialog(
      {required this.projectId,
      required this.contractId,
      required this.actorId});
  final String projectId, contractId, actorId;
  @override
  State<_IncomeDialog> createState() => _IncomeDialogState();
}

class _IncomeDialogState extends State<_IncomeDialog> {
  final invoice = TextEditingController(),
      value = TextEditingController(text: '0'),
      received = TextEditingController(text: '0'),
      beneficiary = TextEditingController();
  String stage = 'estimat';
  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Venit'),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            AsociereStringAutocomplete(
                label: 'Etapă (căutare)',
                optiuni: VenitAsociereEtapa.values.map((e) => e.name).toList(),
                value: stage,
                onChanged: (v) => stage = v),
            const SizedBox(height: 8),
            TextField(
                controller: invoice,
                decoration: const InputDecoration(
                    labelText: 'Număr factură', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: beneficiary,
                decoration: const InputDecoration(
                    labelText: 'Beneficiar', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: value,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Valoare fără TVA',
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: received,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Sumă încasată', border: OutlineInputBorder())),
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Renunță')),
            FilledButton(onPressed: _save, child: const Text('Salvează'))
          ]);
  void _save() {
    final now = DateTime.now();
    final parsed = VenitAsociereEtapa.values.firstWhere((e) => e.name == stage,
        orElse: () => VenitAsociereEtapa.estimat);
    Navigator.pop(
        context,
        VenitAsociereRecord(
            id: 'venit_${now.microsecondsSinceEpoch}',
            projectId: widget.projectId,
            contractId: widget.contractId,
            etapa: parsed,
            numarFactura: invoice.text.trim(),
            dataFactura: parsed == VenitAsociereEtapa.estimat ? null : now,
            valoareFaraTva: _num(value),
            beneficiar: beneficiary.text.trim(),
            sumaIncasata: _num(received),
            dataIncasarii: parsed == VenitAsociereEtapa.incasat ? now : null,
            status: parsed == VenitAsociereEtapa.estimat
                ? AsociereOperationalStatus.draft
                : AsociereOperationalStatus.confirmat,
            createdAt: now,
            updatedAt: now,
            createdBy: widget.actorId,
            updatedBy: widget.actorId));
  }
}
