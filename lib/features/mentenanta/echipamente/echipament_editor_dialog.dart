import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../mentenanta_models.dart';
import 'pret_catalog_service.dart';

/// Dialog pentru adăugarea/editarea unui echipament dintr-un contract.
class EchipamentEditorDialog extends StatefulWidget {
  const EchipamentEditorDialog({super.key, this.existing});

  final EchipamentMentenanta? existing;

  @override
  State<EchipamentEditorDialog> createState() => _EchipamentEditorDialogState();
}

class _EchipamentEditorDialogState extends State<EchipamentEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'ro_RO');

  late CategorieMentenanta _categorie;
  late final TextEditingController _tipCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _umCtrl;
  late final TextEditingController _cantitateCtrl;
  late final TextEditingController _igienizareCtrl;
  late final TextEditingController _revizieCtrl;
  late final TextEditingController _observatiiCtrl;
  late bool _necesitaLogFGas;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _categorie = e?.categorie ?? CategorieMentenanta.vrfDaikin;
    _tipCtrl = TextEditingController(text: e?.tipEchipament ?? '');
    _modelCtrl = TextEditingController(text: e?.model ?? '');
    _umCtrl = TextEditingController(text: e?.um ?? 'buc');
    _cantitateCtrl =
        TextEditingController(text: (e?.cantitate ?? 1).toString());
    _igienizareCtrl = TextEditingController(
        text: (e?.pretIgienizare ?? PretCatalogService.pretIgienizare(_categorie))
            .toString());
    _revizieCtrl = TextEditingController(
        text: (e?.pretRevizie ?? PretCatalogService.pretRevizie(_categorie))
            .toString());
    _observatiiCtrl = TextEditingController(text: e?.observatii ?? '');
    _necesitaLogFGas = e?.necesitaLogFGas ??
        PretCatalogService.necesitaLogFGasImplicit(_categorie);
  }

  @override
  void dispose() {
    _tipCtrl.dispose();
    _modelCtrl.dispose();
    _umCtrl.dispose();
    _cantitateCtrl.dispose();
    _igienizareCtrl.dispose();
    _revizieCtrl.dispose();
    _observatiiCtrl.dispose();
    super.dispose();
  }

  double get _cantitate => double.tryParse(_cantitateCtrl.text.trim()) ?? 0;
  double get _igienizare => double.tryParse(_igienizareCtrl.text.trim()) ?? 0;
  double get _revizie => double.tryParse(_revizieCtrl.text.trim()) ?? 0;
  double get _pretTotal => _igienizare + _revizie;
  double get _valoareTotala => _pretTotal * _cantitate;

  void _onCategorieChanged(CategorieMentenanta? cat) {
    if (cat == null) return;
    setState(() {
      _categorie = cat;
      // Pre-completează prețurile orientative doar dacă sunt încă goale/zero.
      if (_igienizare == 0) {
        _igienizareCtrl.text =
            PretCatalogService.pretIgienizare(cat).toString();
      }
      if (_revizie == 0) {
        _revizieCtrl.text = PretCatalogService.pretRevizie(cat).toString();
      }
      _necesitaLogFGas = PretCatalogService.necesitaLogFGasImplicit(cat);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final result = EchipamentMentenanta(
      id: widget.existing?.id ?? const Uuid().v4(),
      nrCrt: widget.existing?.nrCrt ?? 0,
      tipEchipament: _tipCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      um: _umCtrl.text.trim().isEmpty ? 'buc' : _umCtrl.text.trim(),
      cantitate: _cantitate,
      pretIgienizare: _igienizare,
      pretRevizie: _revizie,
      observatii: _observatiiCtrl.text.trim(),
      categorie: _categorie,
      necesitaLogFGas: _necesitaLogFGas,
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    const decimal = TextInputType.numberWithOptions(decimal: true);
    final decimalFmt = <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
    ];

    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Adaugă echipament'
          : 'Editează echipament'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<CategorieMentenanta>(
                  initialValue: _categorie,
                  decoration: const InputDecoration(
                      labelText: 'Categorie', border: OutlineInputBorder()),
                  items: CategorieMentenanta.values
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(c.label)))
                      .toList(),
                  onChanged: _onCategorieChanged,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tipCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Tip echipament',
                      border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatoriu' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _modelCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Model / Descriere',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _umCtrl,
                        decoration: const InputDecoration(
                            labelText: 'UM', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cantitateCtrl,
                        keyboardType: decimal,
                        inputFormatters: decimalFmt,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'Cantitate',
                            border: OutlineInputBorder()),
                        validator: (v) => (double.tryParse(
                                    (v ?? '').trim()) ??
                                0) <=
                            0
                            ? '> 0'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _igienizareCtrl,
                        keyboardType: decimal,
                        inputFormatters: decimalFmt,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'Preț igienizare (RON)',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _revizieCtrl,
                        keyboardType: decimal,
                        inputFormatters: decimalFmt,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'Preț revizie (RON)',
                            border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCalculatedRow(),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Necesită log F-Gas'),
                  value: _necesitaLogFGas,
                  onChanged: (v) => setState(() => _necesitaLogFGas = v),
                ),
                TextFormField(
                  controller: _observatiiCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Observații', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulează')),
        FilledButton(onPressed: _save, child: const Text('Salvează')),
      ],
    );
  }

  Widget _buildCalculatedRow() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Preț unitar total',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('${_fmt.format(_pretTotal)} RON',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Valoare totală',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('${_fmt.format(_valoareTotala)} RON',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
