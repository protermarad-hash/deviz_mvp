import 'package:flutter/material.dart';

import '../../../core/repositories/app_data_repository.dart';
import '../asociere_operational_common.dart';
import '../pontaj_asociere_models.dart';
import '../pontaj_asociere_repository.dart';
import '../tarif_asociere_models.dart';
import '../tarif_asociere_repository.dart';
import 'asociere_string_autocomplete.dart';
import 'personal_tarife_asociere_page.dart';

class PontajAsocierePage extends StatefulWidget {
  const PontajAsocierePage({
    super.key,
    required this.projectId,
    required this.contractId,
    required this.appRepository,
    required this.actorId,
    required this.canEdit,
    required this.canRegisterExternalConfirmation,
    required this.canViewFinancial,
    required this.canConfigureRates,
    this.onOpenTarife,
  });
  final String projectId;
  final String contractId;
  final AppDataRepository appRepository;
  final String actorId;
  final bool canEdit;
  final bool canRegisterExternalConfirmation;

  /// Rolurile operaționale (șef echipă/tehnician) NU văd valorile.
  final bool canViewFinancial;

  /// admin/birou pot deschide/configura tarife.
  final bool canConfigureRates;

  /// Deschide ecranul „Personal și tarife" (butonul din cardul de avertizare).
  final VoidCallback? onOpenTarife;

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

  bool _intentionalZero(PontajAsociereRecord item) =>
      item.tarifSnapshot == 0 &&
      item.confirmareDocumentRef.toUpperCase().contains('COST 0');

  bool _rateMissing(PontajAsociereRecord item) =>
      item.tarifSnapshot == 0 && !_intentionalZero(item);

  /// Pontaje care nu pot fi valorizate (tarif lipsă), grupate pe persoană.
  List<PontajAsociereRecord> get _missingRateDrafts =>
      _items.where((i) => _rateMissing(i)).toList();

  @override
  Widget build(BuildContext context) {
    final visible = _items
        .where((item) =>
            '${item.persoanaNameSnapshot} ${item.activitate} ${item.calificare}'
                .toLowerCase()
                .contains(_query.toLowerCase()))
        .toList();
    final missing = _missingRateDrafts;
    final missingNames =
        missing.map((e) => e.persoanaNameSnapshot).toSet().toList();
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
                      if (missing.isNotEmpty)
                        ActionChip(
                            avatar: const Icon(Icons.calculate_outlined,
                                size: 18),
                            label: const Text('Recalculează pontaje draft'),
                            onPressed: _recalcDrafts),
                    ])),
            ])),
        if (missingNames.isNotEmpty) _missingRateBanner(missingNames),
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
                        itemBuilder: (context, index) =>
                            _pontajCard(visible[index]))),
      ]),
    );
  }

  Widget _missingRateBanner(List<String> names) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber),
          const SizedBox(width: 8),
          Expanded(
              child: Text('${names.length} persoane fără tarif configurat',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 4),
        const Text('Pontajele acestor persoane nu pot fi valorizate corect '
            'până la configurarea unui tarif activ.'),
        const SizedBox(height: 6),
        Text(names.join(', '),
            style: Theme.of(context).textTheme.bodySmall),
        if (widget.canConfigureRates && widget.onOpenTarife != null)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
                onPressed: widget.onOpenTarife,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Configurează tarifele')),
          ),
      ]),
    );
  }

  Widget _pontajCard(PontajAsociereRecord item) {
    return Card(
      child: ListTile(
        title: Text(
            '${item.persoanaNameSnapshot} · ${item.ore.toStringAsFixed(2)} ore'),
        subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${item.data.day}.${item.data.month}.${item.data.year} · '
                  '${item.calificare}'),
              if (item.activitateZona.isNotEmpty) Text(item.activitateZona),
              const SizedBox(height: 4),
              _valueLine(item),
            ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Tooltip(
              message: 'Confirmare PRO TERM',
              child: Icon(
                  item.confirmareInterna
                      ? Icons.verified
                      : Icons.radio_button_unchecked,
                  color: item.confirmareInterna ? Colors.green : null)),
          Tooltip(
              message: 'Confirmare Partener înregistrată',
              child: Icon(
                  item.confirmareExternaInregistrata
                      ? Icons.verified_user
                      : Icons.person_off_outlined,
                  color:
                      item.confirmareExternaInregistrata ? Colors.green : null)),
        ]),
        onTap: widget.canEdit ? () => _actions(item) : null,
      ),
    );
  }

  Widget _valueLine(PontajAsociereRecord item) {
    // Rolurile operaționale nu văd valorile — doar starea tarifului.
    if (!widget.canViewFinancial) {
      return _rateMissing(item)
          ? const _RateChip(text: 'Tarif lipsă', color: Colors.orange)
          : const _RateChip(text: 'Tarif configurat', color: Colors.green);
    }
    if (_intentionalZero(item)) {
      return const _RateChip(text: '0,00 RON (intenționat)', color: Colors.blueGrey);
    }
    if (_rateMissing(item)) {
      return const _RateChip(text: 'Tarif lipsă', color: Colors.red);
    }
    return Text('${item.costCalculat.toStringAsFixed(2)} RON',
        style: const TextStyle(fontWeight: FontWeight.w600));
  }

  Future<void> _new() async {
    final employees = await widget.appRepository.listEmployeesLookup();
    if (!mounted) return;
    final draft = await showDialog<_PontajDraft>(
        context: context,
        builder: (_) =>
            _PontajDialog(people: employees.map((item) => item.name).toList()));
    if (draft == null) return;
    final person =
        employees.where((item) => item.name == draft.person).firstOrNull;
    final angajator = draft.employer == 'partener'
        ? AsociereAngajator.partener
        : AsociereAngajator.proTerm;
    final rez = await TarifAsociereRepository.instance.rezolva(
      projectId: widget.projectId,
      persoanaId: person?.id ?? draft.person,
      calificare: draft.qualification,
      angajator: angajator == AsociereAngajator.partener
          ? AsociereParte.partener
          : AsociereParte.proTerm,
      data: draft.date,
    );
    final now = DateTime.now();
    final record = PontajAsociereRecord(
      id: 'pontaj_${now.microsecondsSinceEpoch}',
      projectId: widget.projectId,
      contractId: widget.contractId,
      persoanaId: person?.id ?? draft.person,
      persoanaNameSnapshot: draft.person,
      angajator: angajator,
      calificare: draft.qualification,
      data: draft.date,
      ore: draft.hours,
      activitate: draft.activity,
      tarifSnapshot: rez.tarifOra,
      costCalculat: rez.tarifOra * draft.hours,
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
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(rez.sursa.mesaj)));
    }
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
              if (widget.canConfigureRates && _rateMissing(item))
                ListTile(
                    leading: const Icon(Icons.tune),
                    title: const Text('Configurează tarif'),
                    onTap: () => Navigator.pop(context, 'configure')),
              ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Duplică drept draft'),
                  onTap: () => Navigator.pop(context, 'duplicate')),
            ])));
    if (action == null) return;
    if (action == 'configure') {
      await _configureRateFor(item);
      return;
    }
    if ((action == 'internal' || action == 'external') && _rateMissing(item)) {
      await _handleMissingRateOnConfirm(item, action);
      return;
    }
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

  /// Confirmarea e blocată dacă tariful lipsește. Adminul poate confirma cost 0
  /// intenționat, dar numai cu motiv (audit în confirmareDocumentRef).
  Future<void> _handleMissingRateOnConfirm(
      PontajAsociereRecord item, String action) async {
    final choice = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Tarif lipsă'),
              content: const Text(
                  'Pontajul nu poate fi valorizat corect (cost 0 fără tarif). '
                  'Configurează un tarif sau, dacă valoarea 0 este intenționată, '
                  'confirmă cu motiv.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Renunță')),
                if (widget.canConfigureRates)
                  TextButton(
                      onPressed: () => Navigator.pop(context, 'configure'),
                      child: const Text('Configurează tarif')),
                if (widget.canRegisterExternalConfirmation)
                  FilledButton(
                      onPressed: () => Navigator.pop(context, 'intentional'),
                      child: const Text('Cost 0 intenționat')),
              ],
            ));
    if (choice == 'configure') {
      await _configureRateFor(item);
    } else if (choice == 'intentional') {
      final reason = await _askText('Motiv cost 0 intenționat');
      if (reason == null) return;
      final now = DateTime.now();
      final updated = item.copyWith(
          confirmareInterna: true,
          confirmareInternaActor: widget.actorId,
          confirmareInternaLa: now,
          confirmareExternaInregistrata: action == 'external',
          confirmareExternaActor: action == 'external' ? widget.actorId : null,
          confirmareExternaLa: action == 'external' ? now : null,
          confirmareDocumentRef: 'COST 0 INTENȚIONAT: $reason',
          status: action == 'external'
              ? AsociereOperationalStatus.confirmat
              : AsociereOperationalStatus.inAsteptare,
          updatedAt: now,
          updatedBy: widget.actorId,
          revision: item.revision + 1);
      await PontajAsociereRepository.instance.upsertPontaj(updated);
      await _load();
    }
  }

  Future<void> _configureRateFor(PontajAsociereRecord item) async {
    final saved = await showTarifAsociereForm(
      context,
      projectId: widget.projectId,
      contractId: widget.contractId,
      persoanaId: item.persoanaId,
      persoanaNume: item.persoanaNameSnapshot,
      angajator: item.angajator,
      calificare: item.calificare,
    );
    if (saved == null || !mounted) return;
    // Oferă recalcularea acestui pontaj draft cu tariful nou.
    if (!item.esteConfirmatIntegral) {
      final rez = await TarifAsociereRepository.instance.rezolva(
        projectId: widget.projectId,
        persoanaId: item.persoanaId,
        calificare: item.calificare,
        angajator: item.angajator == AsociereAngajator.partener
            ? AsociereParte.partener
            : AsociereParte.proTerm,
        data: item.data,
      );
      if (rez.tarifOra != item.tarifSnapshot) {
        await _applyRate(item, rez.tarifOra);
      }
    }
    await _load();
  }

  Future<void> _applyRate(PontajAsociereRecord item, double rate) async {
    final now = DateTime.now();
    final updated = PontajAsociereRecord.fromMap(item.toMap()
      ..addAll({
        'tarif_snapshot': rate,
        'cost_calculat': rate * item.ore,
        'updated_at': now.toIso8601String(),
        'updated_by': widget.actorId,
        'revision': item.revision + 1,
      }));
    await PontajAsociereRepository.instance.upsertPontaj(updated);
  }

  /// Recalculează tariful pentru pontajele DRAFT (neconfirmate integral).
  /// Pontajele confirmate integral sunt protejate — nu se ating.
  Future<void> _recalcDrafts() async {
    final drafts = _items.where((i) => !i.esteConfirmatIntegral).toList();
    final changes = <(PontajAsociereRecord, double)>[];
    for (final item in drafts) {
      final rez = await TarifAsociereRepository.instance.rezolva(
        projectId: widget.projectId,
        persoanaId: item.persoanaId,
        calificare: item.calificare,
        angajator: item.angajator == AsociereAngajator.partener
            ? AsociereParte.partener
            : AsociereParte.proTerm,
        data: item.data,
      );
      if (rez.tarifOra != item.tarifSnapshot) changes.add((item, rez.tarifOra));
    }
    if (!mounted) return;
    if (changes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Niciun pontaj draft de recalculat.')));
      return;
    }
    final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: Text('Recalculează ${changes.length} pontaje draft'),
              content: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: changes
                          .map((c) => Text(
                              '${c.$1.persoanaNameSnapshot} · '
                              '${c.$1.tarifSnapshot.toStringAsFixed(2)} → '
                              '${c.$2.toStringAsFixed(2)} RON/oră'))
                          .toList()),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Renunță')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Recalculează')),
              ],
            ));
    if (confirm != true) return;
    for (final c in changes) {
      await _applyRate(c.$1, c.$2);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${changes.length} pontaje recalculate.')));
    }
    await _load();
  }

  Future<String?> _askDocument() =>
      _askText('Referință confirmare externă', label: 'Document/ref.');

  Future<String?> _askText(String title, {String? label}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
                title: Text(title),
                content: TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                        labelText: label ?? 'Motiv',
                        border: const OutlineInputBorder())),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Renunță')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('OK'))
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

class _RateChip extends StatelessWidget {
  const _RateChip({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      );
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
  void dispose() {
    _hours.dispose();
    _activity.dispose();
    super.dispose();
  }

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
                optiuni: asociereCalificariPredefinite,
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
                textCapitalization: TextCapitalization.sentences,
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
