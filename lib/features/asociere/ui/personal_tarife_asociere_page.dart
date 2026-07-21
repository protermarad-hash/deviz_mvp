import 'package:flutter/material.dart';

import '../../../core/repositories/app_data_repository.dart';
import '../asociere_operational_common.dart';
import '../pontaj_asociere_models.dart';
import '../pontaj_asociere_repository.dart';
import '../tarif_asociere_models.dart';
import '../tarif_asociere_repository.dart';
import 'asociere_string_autocomplete.dart';

/// Ecranul „Personal și tarife" — punct de acces vizibil pentru configurarea
/// tarifelor individuale (per persoană) și pe calificări, plus istoric.
class PersonalTarifeAsocierePage extends StatefulWidget {
  const PersonalTarifeAsocierePage({
    super.key,
    required this.projectId,
    required this.contractId,
    required this.appRepository,
    required this.canConfigureRates,
    required this.canViewFinancial,
  });

  final String projectId;
  final String contractId;
  final AppDataRepository appRepository;

  /// admin/birou (după politica de acces) pot crea/modifica tarife.
  final bool canConfigureRates;

  /// rolurile operaționale (șef echipă/tehnician) nu văd valorile.
  final bool canViewFinancial;

  @override
  State<PersonalTarifeAsocierePage> createState() =>
      _PersonalTarifeAsocierePageState();
}

class _PersonalTarifeAsocierePageState
    extends State<PersonalTarifeAsocierePage> {
  List<TarifAsociereRecord> _tarife = const [];
  List<PontajAsociereRecord> _pontaje = const [];
  List<({String id, String name})> _angajatiProTerm = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tarife =
        await TarifAsociereRepository.instance.listByProject(widget.projectId);
    final pontaje =
        await PontajAsociereRepository.instance.listByProject(widget.projectId);
    List<({String id, String name})> angajati = const [];
    try {
      final lookup = await widget.appRepository.listEmployeesLookup();
      angajati = lookup
          .where((e) => e.active)
          .map((e) => (id: e.id, name: e.name))
          .toList();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _tarife = tarife;
      _pontaje = pontaje;
      _angajatiProTerm = angajati;
      _loading = false;
    });
  }

  /// Muncitorii partenerului deduși din pontaje (angajator = partener).
  List<({String id, String name})> get _personalPartener {
    final map = <String, String>{};
    for (final p in _pontaje) {
      if (p.angajator == AsociereAngajator.partener) {
        map[p.persoanaId] = p.persoanaNameSnapshot;
      }
    }
    return map.entries.map((e) => (id: e.key, name: e.value)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  TarifAsociereRecord? _tarifIndividualActiv(String persoanaId) {
    final now = DateTime.now();
    for (final t in _tarife) {
      if (t.esteIndividual &&
          t.persoanaId.trim() == persoanaId.trim() &&
          t.esteValabilLa(now)) {
        return t;
      }
    }
    return null;
  }

  List<TarifAsociereRecord> get _tarifeCalificare =>
      _tarife.where((t) => !t.esteIndividual && t.activ).toList()
        ..sort((a, b) => a.calificare.compareTo(b.calificare));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final partener = _personalPartener;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        _sectionTitle(context, 'Personal PRO TERM', Icons.badge_outlined),
        if (_angajatiProTerm.isEmpty)
          const Card(
              child: ListTile(
                  title: Text('Niciun angajat activ în nomenclator.'))),
        ..._angajatiProTerm.map((p) =>
            _personCard(p.id, p.name, AsociereAngajator.proTerm)),
        const SizedBox(height: 12),
        _sectionTitle(context, 'Personal Partener', Icons.groups_outlined),
        if (partener.isEmpty)
          const Card(
              child: ListTile(
                  title: Text('Muncitorii partenerului apar aici după '
                      'primul pontaj înregistrat pentru ei.'))),
        ...partener
            .map((p) => _personCard(p.id, p.name, AsociereAngajator.partener)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _sectionTitle(
                  context, 'Tarife pe calificări', Icons.engineering_outlined)),
          if (widget.canConfigureRates)
            TextButton.icon(
                onPressed: _addCalificareRate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adaugă')),
        ]),
        if (_tarifeCalificare.isEmpty)
          const Card(
              child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Nu există tarife pe calificare.'),
                  subtitle: Text(
                      'Fără un tarif pe calificare sau individual, pontajele '
                      'rămân la 0,00 RON.'))),
        ..._tarifeCalificare.map(_calificareCard),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _sectionTitle(BuildContext context, String text, IconData icon) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(text, style: Theme.of(context).textTheme.titleMedium),
        ]),
      );

  Widget _personCard(
      String persoanaId, String nume, AsociereAngajator angajator) {
    final tarif = _tarifIndividualActiv(persoanaId);
    final areTarif = tarif != null;
    final subtitle = !widget.canViewFinancial
        ? (areTarif ? 'Tarif individual configurat' : 'Fără tarif individual')
        : areTarif
            ? '${tarif.tarifOra.toStringAsFixed(2)} ${tarif.moneda}/oră · '
                'valabil de la ${_d(tarif.valabilDeLa)}'
                '${tarif.valabilPanaLa == null ? '' : ' până la ${_d(tarif.valabilPanaLa!)}'}'
            : 'Fără tarif individual — se folosește tariful calificării';
    return Card(
      child: ListTile(
        leading: Icon(
            angajator == AsociereAngajator.proTerm
                ? Icons.badge_outlined
                : Icons.groups_outlined,
            color: areTarif ? Colors.green : Colors.orange),
        title: Text(nume),
        subtitle: Text('${angajator.label}\n$subtitle'),
        isThreeLine: true,
        trailing: widget.canConfigureRates
            ? PopupMenuButton<String>(
                onSelected: (v) =>
                    _onPersonAction(v, persoanaId, nume, angajator, tarif),
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'config',
                      child: Text(
                          areTarif ? 'Modifică tariful' : 'Configurează tarif')),
                  if (areTarif)
                    const PopupMenuItem(
                        value: 'close', child: Text('Închide tariful actual')),
                  const PopupMenuItem(
                      value: 'history', child: Text('Vezi istoricul')),
                ],
              )
            : null,
      ),
    );
  }

  Widget _calificareCard(TarifAsociereRecord t) => Card(
        child: ListTile(
          leading: const Icon(Icons.engineering_outlined),
          title: Text('${t.calificare} · ${t.asociat.label}'),
          subtitle: Text(!widget.canViewFinancial
              ? 'Tarif configurat'
              : '${t.tarifOra.toStringAsFixed(2)} ${t.moneda}/oră · '
                  'valabil de la ${_d(t.valabilDeLa)}'),
          trailing: widget.canConfigureRates
              ? IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Versiune nouă',
                  onPressed: () => _addCalificareRate(previous: t))
              : null,
        ),
      );

  Future<void> _onPersonAction(String action, String persoanaId, String nume,
      AsociereAngajator angajator, TarifAsociereRecord? tarif) async {
    switch (action) {
      case 'config':
        await showTarifAsociereForm(
          context,
          projectId: widget.projectId,
          contractId: widget.contractId,
          persoanaId: persoanaId,
          persoanaNume: nume,
          angajator: angajator,
          previous: tarif,
        );
        await _load();
      case 'close':
        if (tarif != null) {
          await _closeRate(tarif);
          await _load();
        }
      case 'history':
        _showHistory(persoanaId, nume);
    }
  }

  Future<void> _addCalificareRate({TarifAsociereRecord? previous}) async {
    await showTarifAsociereForm(
      context,
      projectId: widget.projectId,
      contractId: widget.contractId,
      previous: previous,
    );
    await _load();
  }

  Future<void> _closeRate(TarifAsociereRecord tarif) async {
    final closed = tarif.copyWith(
        activ: false,
        valabilPanaLa: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: tarif.revision + 1);
    await TarifAsociereRepository.instance.upsertTarif(closed);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tarif închis.')));
    }
  }

  void _showHistory(String persoanaId, String nume) {
    final istoric = _tarife
        .where((t) => t.persoanaId.trim() == persoanaId.trim())
        .toList()
      ..sort((a, b) => b.valabilDeLa.compareTo(a.valabilDeLa));
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(title: Text('Istoric tarife · $nume')),
          const Divider(height: 1),
          if (istoric.isEmpty)
            const ListTile(title: Text('Fără tarife individuale.')),
          ...istoric.map((t) => ListTile(
                leading: Icon(t.activ ? Icons.check_circle_outline : Icons.history,
                    color: t.activ ? Colors.green : null),
                title: Text(widget.canViewFinancial
                    ? '${t.tarifOra.toStringAsFixed(2)} ${t.moneda}/oră'
                    : 'Tarif configurat'),
                subtitle: Text('valabil de la ${_d(t.valabilDeLa)}'
                    '${t.valabilPanaLa == null ? '' : ' până la ${_d(t.valabilPanaLa!)}'}'
                    '${t.observatii.isEmpty ? '' : '\n${t.observatii}'}'),
              )),
        ]),
      ),
    );
  }

  static String _d(DateTime d) => '${d.day}.${d.month}.${d.year}';
}

/// Formular reutilizabil pentru un tarif Asociere (individual sau pe calificare).
/// Salvează singur prin repository (închizând versiunea anterioară dacă există).
/// Returnează recordul salvat sau null la renunțare / eroare.
Future<TarifAsociereRecord?> showTarifAsociereForm(
  BuildContext context, {
  required String projectId,
  required String contractId,
  String? persoanaId,
  String? persoanaNume,
  AsociereAngajator? angajator,
  String? calificare,
  TarifAsociereRecord? previous,
}) async {
  final result = await showDialog<TarifAsociereRecord>(
    context: context,
    builder: (_) => _TarifForm(
      projectId: projectId,
      contractId: contractId,
      persoanaId: persoanaId ?? previous?.persoanaId ?? '',
      persoanaNume: persoanaNume ?? previous?.persoanaNume ?? '',
      angajator: angajator,
      calificare: calificare ?? previous?.calificare ?? '',
      previous: previous,
    ),
  );
  if (result == null) return null;
  final errors = result.validate();
  if (errors.isNotEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errors.join('\n'))));
    }
    return null;
  }
  try {
    if (previous != null) {
      final closed = previous.copyWith(
          activ: false,
          valabilPanaLa: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now(),
          revision: previous.revision + 1);
      await TarifAsociereRepository.instance.upsertTarif(closed);
    }
    await TarifAsociereRepository.instance.upsertTarif(result);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tarif salvat.')));
    }
    return result;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Eroare: $e')));
    }
    return null;
  }
}

class _TarifForm extends StatefulWidget {
  const _TarifForm({
    required this.projectId,
    required this.contractId,
    required this.persoanaId,
    required this.persoanaNume,
    required this.angajator,
    required this.calificare,
    required this.previous,
  });
  final String projectId;
  final String contractId;
  final String persoanaId;
  final String persoanaNume;
  final AsociereAngajator? angajator;
  final String calificare;
  final TarifAsociereRecord? previous;

  @override
  State<_TarifForm> createState() => _TarifFormState();
}

class _TarifFormState extends State<_TarifForm> {
  late final TextEditingController _calificare =
      TextEditingController(text: widget.calificare);
  late final TextEditingController _hour = TextEditingController(
      text: widget.previous == null
          ? ''
          : widget.previous!.tarifOra.toStringAsFixed(2));
  late final TextEditingController _km = TextEditingController(
      text: widget.previous == null
          ? '0'
          : widget.previous!.tarifKm.toStringAsFixed(2));
  late final TextEditingController _obs =
      TextEditingController(text: widget.previous?.observatii ?? '');
  String _currency = 'RON';
  late String _party = switch (widget.angajator) {
    AsociereAngajator.partener => 'partener',
    _ => (widget.previous?.asociat.value ?? 'pro_term'),
  };
  DateTime _validFrom = DateTime.now();

  bool get _individual => widget.persoanaId.trim().isNotEmpty;

  @override
  void dispose() {
    _calificare.dispose();
    _hour.dispose();
    _km.dispose();
    _obs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(_individual
            ? 'Tarif individual · ${widget.persoanaNume}'
            : (widget.previous == null
                ? 'Tarif pe calificare'
                : 'Versiune nouă tarif')),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_individual)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                  'Selectează angajatul PRO TERM sau muncitorul partenerului. '
                  'Acest tarif are prioritate față de tariful calificării.',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          AsociereStringAutocomplete(
              label: 'Calificare (căutare)',
              optiuni: asociereCalificariPredefinite,
              value: _calificare.text,
              onChanged: (v) => _calificare.text = v),
          const SizedBox(height: 10),
          TextField(
              controller: _hour,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Cost/tarif orar',
                  helperText: 'Valoarea recunoscută în Asociere pentru o oră.',
                  border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(
              controller: _km,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Tarif/km', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          AsociereStringAutocomplete(
              label: 'Monedă (căutare)',
              optiuni: const ['RON', 'EUR', 'USD', 'GBP', 'HUF'],
              value: _currency,
              onChanged: (v) => _currency = v.toUpperCase()),
          const SizedBox(height: 10),
          AsociereStringAutocomplete(
              label: 'Angajator (căutare)',
              optiuni: const ['pro_term', 'partener'],
              value: _party,
              onChanged: (v) => _party = v),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Valabil de la'),
            subtitle: Text(
                '${_validFrom.day}.${_validFrom.month}.${_validFrom.year} · '
                'pontajele începând cu această dată vor utiliza acest tarif'),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
          TextField(
              controller: _obs,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Observații',
                  helperText: 'Ex.: tarif negociat pentru proiectul VRV.',
                  border: OutlineInputBorder())),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Renunță')),
          FilledButton(onPressed: _save, child: const Text('Salvează')),
        ],
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _validFrom,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (picked != null) setState(() => _validFrom = picked);
  }

  void _save() {
    final now = DateTime.now();
    Navigator.pop(
        context,
        TarifAsociereRecord(
          id: 'tarif_${now.microsecondsSinceEpoch}',
          projectId: widget.projectId,
          contractId: widget.contractId,
          persoanaId: widget.persoanaId,
          persoanaNume: widget.persoanaNume,
          calificare: _calificare.text.trim(),
          tarifOra:
              double.tryParse(_hour.text.replaceAll(',', '.')) ?? double.nan,
          tarifKm: double.tryParse(_km.text.replaceAll(',', '.')) ?? 0,
          moneda: _currency,
          asociat: AsociereParteX.fromValue(_party),
          valabilDeLa: _validFrom,
          observatii: _obs.text.trim(),
          createdAt: now,
          updatedAt: now,
          revision: (widget.previous?.revision ?? 0) + 1,
        ));
  }
}
