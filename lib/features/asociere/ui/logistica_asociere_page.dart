import 'package:flutter/material.dart';

import '../asociere_logistica_repository.dart';
import '../asociere_operational_common.dart';
import '../cazare_asociere_models.dart';
import '../cost_asociere_models.dart';
import '../cost_asociere_repository.dart';
import '../deplasare_asociere_models.dart';
import '../diurna_asociere_models.dart';
import 'asociere_string_autocomplete.dart';

class LogisticaAsocierePage extends StatefulWidget {
  const LogisticaAsocierePage(
      {super.key,
      required this.projectId,
      required this.actorId,
      required this.canEdit,
      this.initialTab = 0});
  final String projectId;
  final String actorId;
  final bool canEdit;
  final int initialTab;
  @override
  State<LogisticaAsocierePage> createState() => _LogisticaAsocierePageState();
}

class _LogisticaAsocierePageState extends State<LogisticaAsocierePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
      length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
  List<DeplasareAsociereRecord> _travel = const [];
  List<CazareAsociereRecord> _lodging = const [];
  List<DiurnaAsociereRecord> _allowances = const [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final values = await Future.wait([
      DeplasareAsociereRepository.instance.listByProject(widget.projectId),
      CazareAsociereRepository.instance.listByProject(widget.projectId),
      DiurnaAsociereRepository.instance.listByProject(widget.projectId),
    ]);
    if (mounted) {
      setState(() {
        _travel = values[0] as List<DeplasareAsociereRecord>;
        _lodging = values[1] as List<CazareAsociereRecord>;
        _allowances = values[2] as List<DiurnaAsociereRecord>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'Deplasări'),
          Tab(text: 'Cazare'),
          Tab(text: 'Diurnă')
        ]),
        floatingActionButton: widget.canEdit
            ? FloatingActionButton.extended(
                heroTag: 'asociere_logistica_add',
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Adaugă'))
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabs,
                children: [_travelList(), _lodgingList(), _allowanceList()]),
      );

  Widget _travelList() => _travel.isEmpty
      ? const Center(child: Text('Nu există deplasări.'))
      : ListView.builder(
          padding: const EdgeInsets.only(bottom: 90),
          itemCount: _travel.length,
          itemBuilder: (_, i) {
            final item = _travel[i];
            return Card(
                child: ListTile(
              leading: const Icon(Icons.route_outlined),
              title: Text('${item.punctPlecare} → ${item.destinatie}'),
              subtitle: Text(
                  '${item.metodaCalcul.name} · ${item.kilometriReali.toStringAsFixed(1)} km · ${item.calculeazaTransport().toStringAsFixed(2)} RON'),
              trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'cost') _costFromTravel(item);
                    if (value == 'duplicate') _duplicateTravel(item);
                  },
                  itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'cost', child: Text('Creează cost')),
                        PopupMenuItem(
                            value: 'duplicate',
                            child: Text('Duplică drept draft'))
                      ]),
            ));
          });
  Widget _lodgingList() => _lodging.isEmpty
      ? const Center(child: Text('Nu există cazări.'))
      : ListView.builder(
          padding: const EdgeInsets.only(bottom: 90),
          itemCount: _lodging.length,
          itemBuilder: (_, i) {
            final item = _lodging[i];
            return Card(
                child: ListTile(
              leading: const Icon(Icons.hotel_outlined),
              title: Text('${item.furnizor} · ${item.localitate}'),
              subtitle: Text(
                  '${item.nopti} nopți · ${item.calculeazaCost().toStringAsFixed(2)} RON'),
              trailing: IconButton(
                  icon: const Icon(Icons.add_shopping_cart),
                  tooltip: 'Creează cost',
                  onPressed: () => _costFromLodging(item)),
            ));
          });
  Widget _allowanceList() => _allowances.isEmpty
      ? const Center(
          child: Text('Nu există diurne. Tariful nu este hardcodat.'))
      : ListView.builder(
          padding: const EdgeInsets.only(bottom: 90),
          itemCount: _allowances.length,
          itemBuilder: (_, i) {
            final item = _allowances[i];
            return Card(
                child: ListTile(
              leading: const Icon(Icons.person_pin_circle_outlined),
              title: Text(item.persoanaSnapshot),
              subtitle: Text(
                  '${item.zileEligibile} zile · ${item.calculeazaValoare().toStringAsFixed(2)} ${item.moneda}'),
              trailing: IconButton(
                  icon: const Icon(Icons.add_shopping_cart),
                  tooltip: 'Creează cost',
                  onPressed: () => _costFromAllowance(item)),
            ));
          });

  Future<void> _add() async {
    final index = _tabs.index;
    if (index == 0) {
      final value = await showDialog<DeplasareAsociereRecord>(
          context: context,
          builder: (_) => _TravelDialog(
              projectId: widget.projectId, actorId: widget.actorId));
      if (value != null) {
        final errors = value.validate();
        if (errors.isEmpty) {
          await DeplasareAsociereRepository.instance.upsert(value);
        } else {
          _show(errors);
        }
      }
    } else if (index == 1) {
      final value = await showDialog<CazareAsociereRecord>(
          context: context,
          builder: (_) => _LodgingDialog(
              projectId: widget.projectId, actorId: widget.actorId));
      if (value != null) {
        final errors = value.validate();
        if (errors.isEmpty) {
          await CazareAsociereRepository.instance.upsert(value);
        } else {
          _show(errors);
        }
      }
    } else {
      final value = await showDialog<DiurnaAsociereRecord>(
          context: context,
          builder: (_) => _AllowanceDialog(
              projectId: widget.projectId, actorId: widget.actorId));
      if (value != null) {
        final errors = value.validate();
        if (errors.isEmpty) {
          await DiurnaAsociereRepository.instance.upsert(value);
        } else {
          _show(errors);
        }
      }
    }
    await _load();
  }

  void _show(List<String> errors) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(errors.join('\n'))));
  Future<void> _createCost(
      String sourceType,
      String sourceId,
      AsociereCostCategorie category,
      String description,
      double value,
      AsociereParte payer) async {
    final now = DateTime.now();
    try {
      await CostAsociereRepository.instance.upsertCost(CostAsociereRecord(
          id: 'cost_${now.microsecondsSinceEpoch}',
          projectId: widget.projectId,
          sourceType: sourceType,
          sourceId: sourceId,
          categorie: category,
          descriere: description,
          data: now,
          valoareFaraTva: value,
          valoareProiect: value,
          platitor: payer,
          createdAt: now,
          updatedAt: now,
          createdBy: widget.actorId,
          updatedBy: widget.actorId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Cost draft creat din sursa logistică.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _costFromTravel(DeplasareAsociereRecord item) => _createCost(
      'deplasare',
      item.id,
      AsociereCostCategorie.transport,
      '${item.punctPlecare} – ${item.destinatie}',
      item.calculeazaTransport(),
      item.platitor);
  Future<void> _costFromLodging(CazareAsociereRecord item) => _createCost(
      'cazare',
      item.id,
      AsociereCostCategorie.cazare,
      '${item.furnizor} · ${item.localitate}',
      item.calculeazaCost(),
      item.platitor);
  Future<void> _costFromAllowance(DiurnaAsociereRecord item) => _createCost(
      'diurna',
      item.id,
      AsociereCostCategorie.diurna,
      'Diurnă ${item.persoanaSnapshot}',
      item.calculeazaValoare(),
      item.asociat);
  Future<void> _duplicateTravel(DeplasareAsociereRecord item) async {
    final now = DateTime.now();
    final map = item.toMap()
      ..addAll({
        'id': 'deplasare_${now.microsecondsSinceEpoch}',
        'status': 'draft',
        'document_ref': '',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'created_by': widget.actorId,
        'updated_by': widget.actorId,
        'revision': 1
      });
    await DeplasareAsociereRepository.instance
        .upsert(DeplasareAsociereRecord.fromMap(map));
    await _load();
  }
}

double _value(TextEditingController c) =>
    double.tryParse(c.text.replaceAll(',', '.')) ?? double.nan;

class _TravelDialog extends StatefulWidget {
  const _TravelDialog({required this.projectId, required this.actorId});
  final String projectId, actorId;
  @override
  State<_TravelDialog> createState() => _TravelDialogState();
}

class _TravelDialogState extends State<_TravelDialog> {
  final _from = TextEditingController(),
      _to = TextEditingController(),
      _km = TextEditingController(text: '0'),
      _rate = TextEditingController(text: '0'),
      _fuel = TextEditingController(text: '0'),
      _consumption = TextEditingController(text: '0'),
      _extras = TextEditingController(text: '0');
  String _method = 'tarifKm';
  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Deplasare'),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _from,
                decoration: const InputDecoration(
                    labelText: 'Punct plecare', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _to,
                decoration: const InputDecoration(
                    labelText: 'Destinație', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            AsociereStringAutocomplete(
                label: 'Metodă calcul (căutare)',
                optiuni: DeplasareCalcul.values.map((e) => e.name).toList(),
                value: _method,
                onChanged: (v) => _method = v),
            const SizedBox(height: 8),
            TextField(
                controller: _km,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Kilometri reali',
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _rate,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Tarif/km sau sumă reală',
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _consumption,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Consum l/100km', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _fuel,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Preț combustibil',
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _extras,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Taxe/parcări/altele',
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
    final method = DeplasareCalcul.values.firstWhere((e) => e.name == _method,
        orElse: () => DeplasareCalcul.tarifKm);
    Navigator.pop(
        context,
        DeplasareAsociereRecord(
            id: 'deplasare_${now.microsecondsSinceEpoch}',
            projectId: widget.projectId,
            dataPlecare: now,
            dataRevenire: now,
            punctPlecare: _from.text.trim(),
            destinatie: _to.text.trim(),
            metodaCalcul: method,
            kilometriEstimati: _value(_km),
            kilometriReali: _value(_km),
            tarifKmSnapshot:
                method == DeplasareCalcul.tarifKm ? _value(_rate) : 0,
            consum: method == DeplasareCalcul.combustibil
                ? _value(_consumption)
                : 0,
            pretCombustibil:
                method == DeplasareCalcul.combustibil ? _value(_fuel) : 0,
            alteCosturi: _value(_extras),
            costReal: method == DeplasareCalcul.documentat ||
                    method == DeplasareCalcul.sumaFixa
                ? _value(_rate)
                : 0,
            createdAt: now,
            updatedAt: now,
            createdBy: widget.actorId,
            updatedBy: widget.actorId));
  }
}

class _LodgingDialog extends StatelessWidget {
  _LodgingDialog({required this.projectId, required this.actorId});
  final String projectId, actorId;
  final provider = TextEditingController(),
      city = TextEditingController(),
      nights = TextEditingController(text: '1'),
      people = TextEditingController(text: '1'),
      rooms = TextEditingController(text: '1'),
      rate = TextEditingController(text: '0');
  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Cazare'),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final pair in [
              (provider, 'Furnizor'),
              (city, 'Localitate'),
              (nights, 'Nopți'),
              (people, 'Persoane'),
              (rooms, 'Camere'),
              (rate, 'Tarif')
            ])
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                      controller: pair.$1,
                      decoration: InputDecoration(
                          labelText: pair.$2,
                          border: const OutlineInputBorder())))
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Renunță')),
            FilledButton(
                onPressed: () {
                  final now = DateTime.now();
                  Navigator.pop(
                      context,
                      CazareAsociereRecord(
                          id: 'cazare_${now.microsecondsSinceEpoch}',
                          projectId: projectId,
                          furnizor: provider.text,
                          localitate: city.text,
                          checkIn: now,
                          checkOut: now.add(
                              Duration(days: int.tryParse(nights.text) ?? 1)),
                          nopti: int.tryParse(nights.text) ?? -1,
                          persoane: int.tryParse(people.text) ?? -1,
                          camere: int.tryParse(rooms.text) ?? -1,
                          tarif: _value(rate),
                          createdAt: now,
                          updatedAt: now,
                          createdBy: actorId,
                          updatedBy: actorId));
                },
                child: const Text('Salvează draft'))
          ]);
}

class _AllowanceDialog extends StatelessWidget {
  _AllowanceDialog({required this.projectId, required this.actorId});
  final String projectId, actorId;
  final person = TextEditingController(),
      days = TextEditingController(text: '1'),
      rate = TextEditingController(text: '0');
  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Diurnă'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: person,
                decoration: const InputDecoration(
                    labelText: 'Persoană', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: days,
                decoration: const InputDecoration(
                    labelText: 'Zile eligibile', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: rate,
                decoration: const InputDecoration(
                    labelText: 'Tarif/zi configurabil',
                    border: OutlineInputBorder()))
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Renunță')),
            FilledButton(
                onPressed: () {
                  final now = DateTime.now();
                  Navigator.pop(
                      context,
                      DiurnaAsociereRecord(
                          id: 'diurna_${now.microsecondsSinceEpoch}',
                          projectId: projectId,
                          persoanaId: person.text.trim(),
                          persoanaSnapshot: person.text.trim(),
                          dataInceput: now,
                          dataSfarsit: now.add(Duration(
                              days: (double.tryParse(days.text) ?? 1).ceil())),
                          zileEligibile: _value(days),
                          tarifZi: _value(rate),
                          createdAt: now,
                          updatedAt: now,
                          createdBy: actorId,
                          updatedBy: actorId));
                },
                child: const Text('Salvează draft'))
          ]);
}
