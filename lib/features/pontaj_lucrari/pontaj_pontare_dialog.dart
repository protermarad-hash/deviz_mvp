import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'pontaj_persoana_autocomplete.dart';
import 'pontaj_zi_lucrare_models.dart';

/// Dialog de adăugare / editare pontaj zilnic pe lucrare.
///
/// Returnează un [PontajZiLucrare] (fără id la creare) sau null la anulare.
class PontajPontareDialog extends StatefulWidget {
  const PontajPontareDialog({
    super.key,
    required this.lucrareId,
    required this.options,
    this.existing,
    this.initialDate,
  });

  final String lucrareId;
  final List<PersoanaPontajOption> options;
  final PontajZiLucrare? existing;
  final DateTime? initialDate;

  @override
  State<PontajPontareDialog> createState() => _PontajPontareDialogState();
}

class _PontajPontareDialogState extends State<PontajPontareDialog> {
  static final _dateFormat = DateFormat('dd.MM.yyyy');

  late DateTime _data;
  late final TextEditingController _numeController;
  late final TextEditingController _tarifController;
  late final TextEditingController _diurnaController;
  late final TextEditingController _cazareController;
  late final TextEditingController _observatiiController;
  final FocusNode _numeFocusNode = FocusNode();

  SursaPersoanaPontaj _sursa = SursaPersoanaPontaj.liber;
  String? _refId;
  String? _partenerNume;
  bool _includeDiurna = false;
  bool _includeCazare = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _data = existing?.ziCalendaristica ??
        widget.initialDate ??
        DateTime.now();
    _data = DateTime(_data.year, _data.month, _data.day);
    _numeController =
        TextEditingController(text: existing?.persoanaNume ?? '');
    _tarifController = TextEditingController(
      text: existing == null || existing.tarifZilnicSnapshot <= 0
          ? ''
          : _fmtNum(existing.tarifZilnicSnapshot),
    );
    _diurnaController = TextEditingController(
      text: existing == null || existing.diurnaSnapshot <= 0
          ? ''
          : _fmtNum(existing.diurnaSnapshot),
    );
    _cazareController = TextEditingController(
      text: existing == null || existing.cazareSnapshot <= 0
          ? ''
          : _fmtNum(existing.cazareSnapshot),
    );
    _observatiiController =
        TextEditingController(text: existing?.observatii ?? '');
    if (existing != null) {
      _sursa = existing.sursaPersoana;
      _refId = existing.persoanaRefId;
      _partenerNume = existing.partenerNume;
      _includeDiurna = existing.includeDiurna;
      _includeCazare = existing.includeCazare;
    }
  }

  @override
  void dispose() {
    _numeController.dispose();
    _tarifController.dispose();
    _diurnaController.dispose();
    _cazareController.dispose();
    _observatiiController.dispose();
    _numeFocusNode.dispose();
    super.dispose();
  }

  static String _fmtNum(double value) =>
      value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);

  double _parse(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0.0;

  void _applyOption(PersoanaPontajOption option) {
    setState(() {
      _numeController.text = option.nume;
      _sursa = option.sursa;
      _refId = option.refId;
      _partenerNume = option.partenerNume;
      // Precompletare — TOATE rămân editabile înainte de salvare.
      _tarifController.text = option.tarifPrefill == null ||
              option.tarifPrefill! <= 0
          ? ''
          : _fmtNum(option.tarifPrefill!);
      _diurnaController.text =
          option.diurnaPrefill <= 0 ? '' : _fmtNum(option.diurnaPrefill);
      _cazareController.text =
          option.cazarePrefill <= 0 ? '' : _fmtNum(option.cazarePrefill);
      // Implicit bifate doar dacă valoarea precompletată > 0.
      _includeDiurna = option.diurnaPrefill > 0;
      _includeCazare = option.cazarePrefill > 0;
    });
  }

  void _onNumeChanged(String text) {
    // Dacă textul nu mai corespunde persoanei selectate → nume liber.
    if (_refId != null &&
        !widget.options.any(
            (o) => o.refId == _refId && o.nume == text.trim())) {
      setState(() {
        _sursa = SursaPersoanaPontaj.liber;
        _refId = null;
        _partenerNume = null;
      });
    } else if (_refId == null && _sursa != SursaPersoanaPontaj.liber) {
      setState(() => _sursa = SursaPersoanaPontaj.liber);
    } else {
      setState(() {});
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _data = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _submit() {
    final nume = _numeController.text.trim();
    if (nume.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completează numele persoanei.')),
      );
      return;
    }
    final now = DateTime.now();
    final existing = widget.existing;
    final record = PontajZiLucrare(
      id: existing?.id ?? '',
      lucrareId: widget.lucrareId,
      data: _data,
      persoanaNume: nume,
      sursaPersoana: _sursa,
      persoanaRefId: _refId,
      partenerNume:
          _sursa == SursaPersoanaPontaj.partener ? _partenerNume : null,
      tarifZilnicSnapshot: _parse(_tarifController),
      diurnaSnapshot: _parse(_diurnaController),
      cazareSnapshot: _parse(_cazareController),
      includeDiurna: _includeDiurna,
      includeCazare: _includeCazare,
      observatii: _observatiiController.text.trim(),
      revision: (existing?.revision ?? 0) + 1,
      createdBy: existing?.createdBy ?? '',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.of(context).pop(record);
  }

  double get _costZiPreview =>
      _parse(_tarifController) +
      (_includeDiurna ? _parse(_diurnaController) : 0) +
      (_includeCazare ? _parse(_cazareController) : 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLiber =
        _sursa == SursaPersoanaPontaj.liber && _numeController.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(_isEdit ? 'Editează pontaj' : 'Adaugă pontaj'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          primary: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Data
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text('Data: ${_dateFormat.format(_data)}'),
              ),
              const SizedBox(height: 12),
              PersoanaPontajAutocomplete(
                controller: _numeController,
                focusNode: _numeFocusNode,
                options: widget.options,
                onSelected: _applyOption,
                onChanged: _onNumeChanged,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(
                      _sursa == SursaPersoanaPontaj.propriu
                          ? Icons.badge_outlined
                          : _sursa == SursaPersoanaPontaj.partener
                              ? Icons.handshake_outlined
                              : Icons.person_outline,
                      size: 16,
                    ),
                    label: Text(
                      _sursa == SursaPersoanaPontaj.partener &&
                              (_partenerNume ?? '').isNotEmpty
                          ? '${_sursa.label} · $_partenerNume'
                          : _sursa.label,
                    ),
                  ),
                ],
              ),
              if (isLiber)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_outlined,
                          size: 16, color: theme.colorScheme.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Persoană neînregistrată în cataloage.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _tarifController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Tarif zilnic (RON)'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _includeDiurna,
                    onChanged: (v) =>
                        setState(() => _includeDiurna = v ?? false),
                  ),
                  const Text('Diurnă'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _diurnaController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Diurnă / zi (RON)'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Checkbox(
                    value: _includeCazare,
                    onChanged: (v) =>
                        setState(() => _includeCazare = v ?? false),
                  ),
                  const Text('Cazare'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _cazareController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Cazare / noapte (RON)'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _observatiiController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Observații (opțional)'),
              ),
              const SizedBox(height: 12),
              Text(
                'Cost zi: ${_costZiPreview.toStringAsFixed(2)} RON',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEdit ? 'Salvează' : 'Adaugă'),
        ),
      ],
    );
  }

}
