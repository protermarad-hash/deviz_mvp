import 'package:flutter/material.dart';

import '../../../core/repositories/app_data_repository.dart';
import '../asociere_operational_common.dart';
import '../pontaj_asociere_models.dart';
import '../pontaj_asociere_repository.dart';
import '../tarif_asociere_repository.dart';
import 'asociere_string_autocomplete.dart';

class PontajAsocierePage extends StatefulWidget {
  const PontajAsocierePage({
    super.key,
    required this.projectId,
    required this.contractId,
    required this.appRepository,
    required this.actorId,
    required this.canEdit,
    required this.canRegisterExternalConfirmation,
  });
  final String projectId;
  final String contractId;
  final AppDataRepository appRepository;
  final String actorId;
  final bool canEdit;
  final bool canRegisterExternalConfirmation;

  @override
  State<PontajAsocierePage> createState() => _PontajAsocierePageState();
}

class _PontajAsocierePageState extends State<PontajAsocierePage> {
  List<PontajAsociereRecord> _items = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items =
        await PontajAsociereRepository.instance.listByProject(widget.projectId);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items
        .where((item) =>
            '${item.persoanaNameSnapshot} ${item.activitate} ${item.calificare}'
                .toLowerCase()
                .contains(_query.toLowerCase()))
        .toList();
    return Scaffold(
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              heroTag: 'asociere_pontaj_add',
              onPressed: _new,
              icon: const Icon(Icons.add),
              label: const Text('Pontaj'))
          : null,
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              TextField(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Caută pontaje',
                      border: OutlineInputBorder()),
                  onChanged: (value) => setState(() => _query = value)),
              if (widget.canEdit)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(spacing: 8, children: [
                      ActionChip(
                          label: const Text('Copiază pontaj ieri'),
                          onPressed: _copyYesterday),
                      ActionChip(
                          label: const Text('Aplică 8 ore echipei'),
                          onPressed: _applyEightHours),
                    ])),
            ])),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                    ? const Center(
                        child: Text(
                            'Nu există pontaje. Costul este fixat prin snapshot la salvare.'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          return Card(
                              child: ListTile(
                            title: Text(
                                '${item.persoanaNameSnapshot} · ${item.ore.toStringAsFixed(2)} ore'),
                            subtitle: Text(
                                '${item.data.day}.${item.data.month}.${item.data.year} · ${item.calificare}\n${item.activitateZona} · ${item.costCalculat.toStringAsFixed(2)} RON'),
                            trailing:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Tooltip(
                                  message: 'Confirmare PRO TERM',
                                  child: Icon(
                                      item.confirmareInterna
                                          ? Icons.verified
                                          : Icons.radio_button_unchecked,
                                      color: item.confirmareInterna
                                          ? Colors.green
                                          : null)),
                              Tooltip(
                                  message: 'Confirmare Partener înregistrată',
                                  child: Icon(
                                      item.confirmareExternaInregistrata
                                          ? Icons.verified_user
                                          : Icons.person_off_outlined,
                                      color: item.confirmareExternaInregistrata
                                          ? Colors.green
                                          : null)),
                            ]),
                            onTap: widget.canEdit ? () => _actions(item) : null,
                          ));
                        })),
      ]),
    );
  }

  Future<void> _new() async {
    final employees = await widget.appRepository.listEmployeesLookup();
    if (!mounted) return;
    final draft = await showDialog<_PontajDraft>(
        context: context,
        builder: (_) =>
            _PontajDialog(people: employees.map((item) => item.name).toList()));
    if (draft == null) return;
    final rate = await TarifAsociereRepository.instance
        .tarifOraPentru(widget.projectId, draft.qualification, draft.date);
    final now = DateTime.now();
    final person =
        employees.where((item) => item.name == draft.person).firstOrNull;
    final record = PontajAsociereRecord(
      id: 'pontaj_${now.microsecondsSinceEpoch}',
      projectId: widget.projectId,
      contractId: widget.contractId,
      persoanaId: person?.id ?? draft.person,
      persoanaNameSnapshot: draft.person,
      angajator: draft.employer == 'partener'
          ? AsociereAngajator.partener
          : AsociereAngajator.proTerm,
      calificare: draft.qualification,
      data: draft.date,
      ore: draft.hours,
      activitate: draft.activity,
      tarifSnapshot: rate,
      costCalculat: rate * draft.hours,
      createdAt: now,
      updatedAt: now,
      createdBy: widget.actorId,
      updatedBy: widget.actorId,
    );
    final errors = record.validate();
    if (errors.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errors.join('\n'))));
      }
      return;
    }
    await PontajAsociereRepository.instance.upsertPontaj(record);
    await _load();
  }

  Future<void> _actions(PontajAsociereRecord item) async {
    final action = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.verified_outlined),
                  title: const Text('Confirmă intern'),
                  onTap: () => Navigator.pop(context, 'internal')),
              if (widget.canRegisterExternalConfirmation)
                ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title:
                        const Text('Înregistrează confirmarea externă (admin)'),
                    onTap: () => Navigator.pop(context, 'external')),
              ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Duplică drept draft'),
                  onTap: () => Navigator.pop(context, 'duplicate')),
            ])));
    if (action == null) return;
    final now = DateTime.now();
    PontajAsociereRecord updated;
    if (action == 'internal') {
      updated = item.copyWith(
          confirmareInterna: true,
          confirmareInternaActor: widget.actorId,
          confirmareInternaLa: now,
          status: AsociereOperationalStatus.inAsteptare,
          updatedAt: now,
          updatedBy: widget.actorId,
          revision: item.revision + 1);
    } else if (action == 'external') {
      final document = await _askDocument();
      if (document == null) return;
      updated = item.copyWith(
          confirmareExternaInregistrata: true,
          confirmareExternaActor: widget.actorId,
          confirmareExternaLa: now,
          confirmareDocumentRef: document,
          status: AsociereOperationalStatus.confirmat,
          updatedAt: now,
          updatedBy: widget.actorId,
          revision: item.revision + 1);
    } else {
      updated = _draftCopy(item, 'pontaj_${now.microsecondsSinceEpoch}', now);
    }
    await PontajAsociereRepository.instance.upsertPontaj(updated);
    await _load();
  }

  Future<String?> _askDocument() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Referință confirmare externă'),
                content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                        labelText: 'Document/ref. justificativă',
                        border: OutlineInputBorder())),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Renunță')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('Înregistrează'))
                ]));
    controller.dispose();
    return (result ?? '').isEmpty ? null : result;
  }

  Future<void> _copyYesterday() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final source = _items
        .where((item) =>
            item.data.year == yesterday.year &&
            item.data.month == yesterday.month &&
            item.data.day == yesterday.day)
        .toList();
    final now = DateTime.now();
    for (var index = 0; index < source.length; index++) {
      final item = source[index];
      await PontajAsociereRepository.instance.upsertPontaj(
        _draftCopy(item, 'pontaj_${now.microsecondsSinceEpoch}_$index', now),
      );
    }
    await _load();
  }

  Future<void> _applyEightHours() async {
    final today = DateTime.now();
    final latestByPerson = <String, PontajAsociereRecord>{};
    for (final item in _items) {
      latestByPerson.putIfAbsent(item.persoanaId, () => item);
    }
    for (final entry in latestByPerson.entries) {
      await PontajAsociereRepository.instance.upsertPontaj(
        _draftCopy(
          entry.value,
          'pontaj_${today.microsecondsSinceEpoch}_${entry.key}',
          today,
          hours: 8,
        ),
      );
    }
    await _load();
  }

  PontajAsociereRecord _draftCopy(
    PontajAsociereRecord source,
    String id,
    DateTime date, {
    double? hours,
  }) {
    final value = hours ?? source.ore;
    return PontajAsociereRecord.fromMap(source.toMap()
      ..addAll({
        'id': id,
        'data': date.toIso8601String(),
        'ore': value,
        'cost_calculat': value * source.tarifSnapshot,
        'status': AsociereOperationalStatus.draft.value,
        'confirmare_interna': false,
        'confirmare_interna_actor': '',
        'confirmare_interna_la': null,
        'confirmare_externa_inregistrata': false,
        'confirmare_externa_actor': '',
        'confirmare_externa_la': null,
        'confirmare_document_ref': '',
        'created_at': date.toIso8601String(),
        'updated_at': date.toIso8601String(),
        'created_by': widget.actorId,
        'updated_by': widget.actorId,
        'revision': 1,
      }));
  }
}

class _PontajDraft {
  const _PontajDraft(this.person, this.qualification, this.employer, this.date,
      this.hours, this.activity);
  final String person;
  final String qualification;
  final String employer;
  final DateTime date;
  final double hours;
  final String activity;
}

class _PontajDialog extends StatefulWidget {
  const _PontajDialog({required this.people});
  final List<String> people;
  @override
  State<_PontajDialog> createState() => _PontajDialogState();
}

class _PontajDialogState extends State<_PontajDialog> {
  String _person = '', _qualification = '', _employer = 'pro_term';
  final DateTime _date = DateTime.now();
  final _hours = TextEditingController(text: '8'),
      _activity = TextEditingController();
  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Pontaj draft'),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            AsociereStringAutocomplete(
                label: 'Persoană (căutare)',
                optiuni: widget.people,
                value: _person,
                onChanged: (v) => _person = v),
            const SizedBox(height: 8),
            AsociereStringAutocomplete(
                label: 'Calificare (căutare)',
                optiuni: const [
                  'manager_santier',
                  'frigotehnist_fgaze',
                  'instalator',
                  'electrician',
                  'necalificat'
                ],
                value: _qualification,
                onChanged: (v) => _qualification = v),
            const SizedBox(height: 8),
            AsociereStringAutocomplete(
                label: 'Angajator (căutare)',
                optiuni: const ['pro_term', 'partener'],
                value: _employer,
                onChanged: (v) => _employer = v),
            const SizedBox(height: 8),
            TextField(
                controller: _hours,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Ore', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _activity,
                decoration: const InputDecoration(
                    labelText: 'Activitate', border: OutlineInputBorder())),
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Renunță')),
            FilledButton(
                onPressed: () => Navigator.pop(
                    context,
                    _PontajDraft(
                        _person,
                        _qualification,
                        _employer,
                        _date,
                        double.tryParse(_hours.text.replaceAll(',', '.')) ??
                            double.nan,
                        _activity.text.trim())),
                child: const Text('Adaugă'))
          ]);
}
