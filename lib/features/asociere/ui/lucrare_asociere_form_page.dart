import 'package:flutter/material.dart';

import '../../../core/repositories/app_data_repository.dart';
import '../../../core/lookup_models.dart';
import '../../clients/client_models.dart';
import '../../partners/partner_models.dart';
import '../asociere_models.dart';
import '../asociere_repository.dart';
import '../lucrare_asociere_cloud_repository.dart';
import '../lucrare_asociere_local_store.dart';
import '../lucrare_asociere_models.dart';
import '../tarif_asociere_models.dart';
import '../tarif_asociere_repository.dart';
import 'asociere_string_autocomplete.dart';

class LucrareAsociereFormPage extends StatefulWidget {
  const LucrareAsociereFormPage({
    super.key,
    required this.appRepository,
    required this.actorId,
    this.initial,
  });

  final AppDataRepository appRepository;
  final String actorId;
  final LucrareAsociereRecord? initial;

  @override
  State<LucrareAsociereFormPage> createState() =>
      _LucrareAsociereFormPageState();
}

class _LucrareAsociereFormPageState extends State<LucrareAsociereFormPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _c = {};
  List<ClientRecord> _clients = const [];
  List<PartnerRecord> _partners = const [];
  List<String> _people = const [];
  List<EmployeeLookup> _employees = const [];
  int _step = 0;
  bool _loading = true;
  bool _saving = false;
  DateTime _start = DateTime.now();
  DateTime? _deadline;
  String _clientName = '';
  String _partnerName = '';
  String _responsabilName = '';
  String _managerName = '';
  String _currency = 'RON';
  String _country = 'România';
  String _status = LucrareAsociereStatus.draft.value;
  String _invoicer = 'pro_term';
  String _template = 'Ultima configurație';
  final _localStore = const LucrareAsociereLocalStore();

  TextEditingController ctrl(String key, [String value = '']) =>
      _c.putIfAbsent(key, () => TextEditingController(text: value));

  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    _start = value?.dataInceput ?? DateTime.now();
    _deadline = value?.termenEstimat;
    _clientName = value?.clientNameSnapshot ?? '';
    _partnerName = value?.partnerNameSnapshot ?? '';
    _responsabilName = value?.responsabilNameSnapshot ?? '';
    _managerName = value?.managerNameSnapshot ?? '';
    _currency = value?.moneda ?? 'RON';
    _country = value?.tara ?? 'România';
    _status = value?.status.value ?? LucrareAsociereStatus.draft.value;
    _invoicer = value?.cineFactureazaBeneficiarul ?? 'pro_term';
    _seed(value);
    _loadDefaults();
  }

  void _seed(LucrareAsociereRecord? value) {
    ctrl('numar', value?.numar ?? 'AS-${DateTime.now().year}-');
    ctrl('denumire', value?.denumire ?? '');
    ctrl('descriere', value?.descriere ?? '');
    ctrl('beneficiar', value?.beneficiar ?? '');
    ctrl('adresa', value?.adresa ?? '');
    ctrl('localitate', value?.localitate ?? '');
    ctrl('judet', value?.judet ?? '');
    ctrl('valoare', '${value?.valoareContractuala ?? 0}');
    ctrl('cotaPt', '${value?.cotaProTerm ?? 50}');
    ctrl('cotaPartener', '${value?.cotaPartener ?? 50}');
    ctrl('distribuire', '${value?.procentDistribuireIntermediara ?? 70}');
    ctrl('rezerva', '${value?.procentRezervaGarantie ?? 30}');
    ctrl('garantie', '${value?.durataGarantieLuni ?? 24}');
    ctrl('prag', '${value?.pragAprobareCost ?? 1000}');
    ctrl('tarifOra', '0');
    ctrl('tarifKm', '0');
    ctrl('observatii', value?.observatii ?? '');
  }

  Future<void> _loadDefaults() async {
    final results = await Future.wait([
      widget.appRepository.listClients(),
      widget.appRepository.listPartners(),
      widget.appRepository.listEmployeesLookup(),
      widget.appRepository.loadCompanyProfile(),
      _localStore.loadDefaults(),
    ]);
    if (!mounted) return;
    final profile = results[3] as dynamic;
    final employees = results[2] as List<EmployeeLookup>;
    setState(() {
      _clients = results[0] as List<ClientRecord>;
      _partners = results[1] as List<PartnerRecord>;
      _people = employees.map((item) => item.name).toList();
      _employees = employees;
      if (widget.initial == null) {
        final defaults = results[4] as Map<String, dynamic>;
        _template = '${defaults['sablon'] ?? 'Ultima configurație'}';
        _currency = '${profile.currency}'.trim().isEmpty
            ? 'RON'
            : '${defaults['moneda'] ?? profile.currency}';
        _country = 'România';
        ctrl('localitate').text = '${profile.city}';
        ctrl('judet').text = '${profile.county}';
        _managerName = employees
                .where((item) => item.id == widget.actorId)
                .map((item) => item.name)
                .firstOrNull ??
            '';
        _responsabilName = _managerName;
        ctrl('cotaPt').text = '${defaults['cota_pro_term'] ?? 50}';
        ctrl('cotaPartener').text = '${defaults['cota_partener'] ?? 50}';
        ctrl('rezerva').text = '${defaults['rezerva'] ?? 30}';
        ctrl('garantie').text = '${defaults['garantie_luni'] ?? 24}';
        ctrl('prag').text = '${defaults['prag_aprobare'] ?? 1000}';
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final controller in _c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.initial == null
              ? 'Proiect Asociere nou'
              : 'Editare proiect Asociere')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Stepper(
                currentStep: _step,
                onStepTapped: (value) => setState(() => _step = value),
                onStepContinue:
                    _step == 6 ? _save : () => setState(() => _step++),
                onStepCancel: _step == 0 ? null : () => setState(() => _step--),
                controlsBuilder: (context, details) => Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(children: [
                    FilledButton(
                      onPressed: _saving ? null : details.onStepContinue,
                      child: Text(
                          _step == 6 ? 'Salvează cu confirmare' : 'Continuă'),
                    ),
                    const SizedBox(width: 8),
                    if (_step > 0)
                      TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Înapoi')),
                  ]),
                ),
                steps: [
                  Step(title: const Text('Date generale'), content: _general()),
                  Step(
                      title: const Text('Client și beneficiar'),
                      content: _client()),
                  Step(
                      title: const Text('Partener și responsabilități'),
                      content: _partner()),
                  Step(
                      title: const Text('Contract și cote'),
                      content: _contract()),
                  Step(title: const Text('Logistică'), content: _logistics()),
                  Step(
                      title: const Text('Documente și observații'),
                      content: _notes()),
                  Step(title: const Text('Verificare'), content: _review()),
                ],
              ),
            ),
    );
  }

  Widget _general() => _fields([
        _requiredText('numar', 'Număr unic'),
        _requiredText('denumire', 'Denumire'),
        _text('descriere', 'Descriere', lines: 3),
        AsociereStringAutocomplete(
          label: 'Status (căutare)',
          optiuni:
              LucrareAsociereStatus.values.map((item) => item.value).toList(),
          value: _status,
          onChanged: (value) => _status = value,
        ),
        AsociereStringAutocomplete(
          label: 'Șablon (căutare)',
          optiuni: const [
            'Ultima configurație',
            'Proiect intern',
            'Proiect extern'
          ],
          value: _template,
          onChanged: (value) => _template = value,
        ),
        _dateTile('Data început', _start, (value) => _start = value),
        _dateTile('Termen estimat', _deadline, (value) => _deadline = value),
      ]);

  Widget _client() => _fields([
        AsociereStringAutocomplete(
          label: 'Client (căutare)',
          optiuni: _clients.map((item) => item.name).toList(),
          value: _clientName,
          onChanged: (value) => _clientName = value,
        ),
        _text('beneficiar', 'Beneficiar'),
        _text('adresa', 'Adresă'),
        _text('localitate', 'Localitate'),
        _text('judet', 'Județ'),
        AsociereStringAutocomplete(
          label: 'Țară (căutare)',
          optiuni: const [
            'România',
            'Ungaria',
            'Germania',
            'Austria',
            'Italia',
            'Franța'
          ],
          value: _country,
          onChanged: (value) => _country = value,
        ),
      ]);

  Widget _partner() => _fields([
        AsociereStringAutocomplete(
          label: 'Partener obligatoriu (căutare)',
          optiuni: _partners.map((item) => item.name).toList(),
          value: _partnerName,
          onChanged: (value) => _partnerName = value,
        ),
        AsociereStringAutocomplete(
            label: 'Responsabil (căutare)',
            optiuni: _people,
            value: _responsabilName,
            onChanged: (v) => _responsabilName = v),
        AsociereStringAutocomplete(
            label: 'Manager (căutare)',
            optiuni: _people,
            value: _managerName,
            onChanged: (v) => _managerName = v),
        const ListTile(
          leading: Icon(Icons.business_center_outlined),
          title: Text('Părți MVP'),
          subtitle: Text('PRO TERM + un singur Partener'),
        ),
      ]);

  Widget _contract() => _fields([
        _number('valoare', 'Valoare contractuală'),
        AsociereStringAutocomplete(
            label: 'Monedă (căutare)',
            optiuni: monedeAsociereAcceptate,
            value: _currency,
            onChanged: (v) => _currency = v.toUpperCase()),
        _number('cotaPt', 'Cota PRO TERM %'),
        _number('cotaPartener', 'Cota Partener %'),
        AsociereStringAutocomplete(
          label: 'Cine facturează beneficiarul (căutare)',
          optiuni: const ['pro_term', 'partener'],
          value: _invoicer,
          onChanged: (value) => _invoicer = value,
        ),
        _number('distribuire', 'Distribuire intermediară %'),
        _number('rezerva', 'Rezervă garanție %'),
        _number('garantie', 'Durată garanție luni'),
        _number('prag', 'Prag aprobare cost'),
      ]);

  Widget _logistics() => _fields([
        const Text(
            'Plecarea este precompletată din profilul companiei. Valorile standard de mai jos se salvează numai odată cu confirmarea proiectului.'),
        _number('tarifOra', 'Tarif standard RON/oră'),
        _number('tarifKm', 'Tarif standard RON/km'),
      ]);
  Widget _notes() => _fields([
        _text('observatii', 'Observații', lines: 5),
        const ListTile(
            leading: Icon(Icons.attach_file),
            title: Text('Documentele se atașează după salvarea proiectului.')),
      ]);
  Widget _review() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Precompletările sunt vizibile și editabile. Nimic nu este salvat automat.\n\n'
            '${ctrl('numar').text} · ${ctrl('denumire').text}\n'
            'Client: ${_clientName.isEmpty ? '—' : _clientName}\nPartener: ${_partnerName.isEmpty ? '—' : _partnerName}\n'
            'Cote: ${ctrl('cotaPt').text}% / ${ctrl('cotaPartener').text}% · Monedă: $_currency',
          ),
        ),
      );

  Widget _fields(List<Widget> fields) => Column(
      children: fields
          .map((item) =>
              Padding(padding: const EdgeInsets.only(bottom: 12), child: item))
          .toList());
  Widget _text(String key, String label, {int lines = 1}) => TextFormField(
      controller: ctrl(key),
      maxLines: lines,
      decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder()));
  Widget _requiredText(String key, String label) => TextFormField(
      controller: ctrl(key),
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: (value) =>
          (value ?? '').trim().isEmpty ? 'Câmp obligatoriu' : null);
  Widget _number(String key, String label) => TextFormField(
      controller: ctrl(key),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder()));

  Widget _dateTile(
          String label, DateTime? value, ValueChanged<DateTime> changed) =>
      ListTile(
        shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(4)),
        title: Text(label),
        subtitle: Text(value == null
            ? 'Selectează'
            : '${value.day}.${value.month}.${value.year}'),
        trailing: const Icon(Icons.calendar_month_outlined),
        onTap: () async {
          final selected = await showDatePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              initialDate: value ?? DateTime.now());
          if (selected != null) setState(() => changed(selected));
        },
      );

  double _double(String key) =>
      double.tryParse(ctrl(key).text.replaceAll(',', '.')) ?? double.nan;
  int _int(String key) => int.tryParse(ctrl(key).text) ?? -1;
  String _idByName<T>(List<T> items, String name, String Function(T) getName,
      String Function(T) getId) {
    final needle = name.trim().toLowerCase();
    for (final item in items) {
      if (getName(item).trim().toLowerCase() == needle) return getId(item);
    }
    return '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final old = widget.initial;
    final partnerId = _idByName(
        _partners, _partnerName, (item) => item.name, (item) => item.id);
    final clientId = _idByName(
        _clients, _clientName, (item) => item.name, (item) => item.id);
    final record = LucrareAsociereRecord(
      id: old?.id ?? 'la_${now.microsecondsSinceEpoch}',
      numar: ctrl('numar').text.trim(),
      denumire: ctrl('denumire').text.trim(),
      descriere: ctrl('descriere').text.trim(),
      clientId: clientId,
      clientNameSnapshot: _clientName.trim(),
      beneficiar: ctrl('beneficiar').text.trim(),
      adresa: ctrl('adresa').text.trim(),
      localitate: ctrl('localitate').text.trim(),
      judet: ctrl('judet').text.trim(),
      tara: _country.trim(),
      partnerId: partnerId,
      partnerNameSnapshot: _partnerName.trim(),
      responsabilId: _idByName(
          _employees, _responsabilName, (item) => item.name, (item) => item.id),
      responsabilNameSnapshot: _responsabilName.trim(),
      managerId: _idByName(
          _employees, _managerName, (item) => item.name, (item) => item.id),
      managerNameSnapshot: _managerName.trim(),
      dataInceput: _start,
      termenEstimat: _deadline,
      status: LucrareAsociereStatus.fromValue(_status),
      moneda: _currency.trim().toUpperCase(),
      valoareContractuala: _double('valoare'),
      cotaProTerm: _double('cotaPt'),
      cotaPartener: _double('cotaPartener'),
      cineFactureazaBeneficiarul: _invoicer,
      procentDistribuireIntermediara: _double('distribuire'),
      procentRezervaGarantie: _double('rezerva'),
      durataGarantieLuni: _int('garantie'),
      pragAprobareCost: _double('prag'),
      observatii: ctrl('observatii').text.trim(),
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
      createdBy: old?.createdBy ?? widget.actorId,
      updatedBy: widget.actorId,
      revision: (old?.revision ?? 0) + 1,
      active: old?.active ?? true,
      arhivat: old?.arhivat ?? false,
    );
    final errors = record.validate();
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errors.join('\n'))));
      return;
    }
    setState(() => _saving = true);
    try {
      if (old == null) {
        await LucrareAsociereCloudRepository.instance.create(record);
      } else {
        await LucrareAsociereCloudRepository.instance
            .update(record, expectedRevision: old.revision);
      }
      final existingContracts =
          await AsociereRepository.instance.listByProject(record.id);
      final existingContract = existingContracts.firstOrNull;
      await AsociereRepository.instance.upsertAsociere(AsociereRecord(
        id: existingContract?.id ?? 'contract_${record.id}',
        lucrareAsociereId: record.id,
        cineFactureazaBeneficiarul:
            record.cineFactureazaBeneficiarul == 'partener'
                ? AsociereIncasator.partener
                : AsociereIncasator.proTerm,
        partenerExternId: record.partnerId,
        partenerExternNume: record.partnerNameSnapshot,
        cotaProTerm: record.cotaProTerm,
        cotaPartener: record.cotaPartener,
        pragAprobareRON: record.pragAprobareCost,
        procentDistribuireIntermediara: record.procentDistribuireIntermediara,
        procentRezervaGarantie: record.procentRezervaGarantie,
        durataGarantieLuni: record.durataGarantieLuni,
        dataInceput: record.dataInceput,
        status: record.status == LucrareAsociereStatus.finalizata
            ? AsociereStatus.incheiata
            : AsociereStatus.activa,
        createdAt: existingContract?.createdAt ?? now,
        updatedAt: now,
        createdBy: existingContract?.createdBy ?? widget.actorId,
        updatedBy: widget.actorId,
        revision: (existingContract?.revision ?? 0) + 1,
      ));
      final standardHour = _double('tarifOra');
      final standardKm = _double('tarifKm');
      if (old == null &&
          standardHour.isFinite &&
          standardKm.isFinite &&
          (standardHour > 0 || standardKm > 0)) {
        await TarifAsociereRepository.instance.upsertTarif(
          TarifAsociereRecord(
            id: 'tarif_standard_${record.id}',
            projectId: record.id,
            contractId: existingContract?.id ?? 'contract_${record.id}',
            calificare: 'standard',
            tarifOra: standardHour,
            tarifKm: standardKm,
            valabilDeLa: record.dataInceput,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      await _localStore.saveDefaults({
        'moneda': record.moneda,
        'cota_pro_term': record.cotaProTerm,
        'cota_partener': record.cotaPartener,
        'rezerva': record.procentRezervaGarantie,
        'garantie_luni': record.durataGarantieLuni,
        'prag_aprobare': record.pragAprobareCost,
        'sablon': _template,
      });
      if (mounted) Navigator.of(context).pop(record);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
