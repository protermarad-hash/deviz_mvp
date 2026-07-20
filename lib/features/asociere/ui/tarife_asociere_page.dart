import 'package:flutter/material.dart';

import '../asociere_operational_common.dart';
import '../tarif_asociere_models.dart';
import '../tarif_asociere_repository.dart';
import 'asociere_string_autocomplete.dart';

class TarifeAsocierePage extends StatefulWidget {
  const TarifeAsocierePage({
    super.key,
    required this.projectId,
    required this.contractId,
    required this.canEdit,
  });
  final String projectId;
  final String contractId;
  final bool canEdit;

  @override
  State<TarifeAsocierePage> createState() => _TarifeAsocierePageState();
}

class _TarifeAsocierePageState extends State<TarifeAsocierePage> {
  List<TarifAsociereRecord> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items =
        await TarifAsociereRepository.instance.listByProject(widget.projectId);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: widget.canEdit
            ? FloatingActionButton.extended(
                heroTag: 'asociere_tarif_add',
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Tarif nou'))
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(
                    child: Text(
                        'Nu există tarife configurate. Pontajele păstrează snapshotul tarifului selectat.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                          child: ListTile(
                        title:
                            Text('${item.calificare} · ${item.asociat.label}'),
                        subtitle: Text(
                            '${item.tarifOra.toStringAsFixed(2)} ${item.moneda}/oră · ${item.tarifKm.toStringAsFixed(2)} ${item.moneda}/km\nValabil de la ${item.valabilDeLa.day}.${item.valabilDeLa.month}.${item.valabilDeLa.year}${item.valabilPanaLa == null ? '' : ' până la ${item.valabilPanaLa!.day}.${item.valabilPanaLa!.month}.${item.valabilPanaLa!.year}'}'),
                        trailing: item.activ
                            ? const Icon(Icons.check_circle_outline,
                                color: Colors.green)
                            : const Icon(Icons.history),
                        onTap: widget.canEdit ? () => _openForm(item) : null,
                      ));
                    }),
      );

  Future<void> _openForm([TarifAsociereRecord? old]) async {
    final result = await showDialog<TarifAsociereRecord>(
        context: context,
        builder: (_) => _TarifDialog(
            projectId: widget.projectId,
            contractId: widget.contractId,
            previous: old));
    if (result == null) return;
    final errors = result.validate();
    if (errors.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errors.join('\n'))));
      }
      return;
    }
    if (old != null) {
      final closed = old.copyWith(
          activ: false,
          valabilPanaLa: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now(),
          revision: old.revision + 1);
      await TarifAsociereRepository.instance.upsertTarif(closed);
    }
    await TarifAsociereRepository.instance.upsertTarif(result);
    await _load();
  }
}

class _TarifDialog extends StatefulWidget {
  const _TarifDialog(
      {required this.projectId, required this.contractId, this.previous});
  final String projectId;
  final String contractId;
  final TarifAsociereRecord? previous;
  @override
  State<_TarifDialog> createState() => _TarifDialogState();
}

class _TarifDialogState extends State<_TarifDialog> {
  late final TextEditingController _qualification =
      TextEditingController(text: widget.previous?.calificare ?? '');
  late final TextEditingController _hour =
      TextEditingController(text: '${widget.previous?.tarifOra ?? 0}');
  late final TextEditingController _km =
      TextEditingController(text: '${widget.previous?.tarifKm ?? 0}');
  String _currency = 'RON';
  String _party = 'pro_term';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title:
            Text(widget.previous == null ? 'Tarif nou' : 'Versiune nouă tarif'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          AsociereStringAutocomplete(
              label: 'Calificare (căutare)',
              optiuni: asociereCalificariPredefinite,
              value: _qualification.text,
              onChanged: (value) => _qualification.text = value),
          const SizedBox(height: 10),
          TextField(
              controller: _hour,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Tarif/oră', border: OutlineInputBorder())),
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
              onChanged: (value) => _currency = value.toUpperCase()),
          const SizedBox(height: 10),
          AsociereStringAutocomplete(
              label: 'Asociat (căutare)',
              optiuni: const ['pro_term', 'partener'],
              value: _party,
              onChanged: (value) => _party = value),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Renunță')),
          FilledButton(
              onPressed: _save, child: const Text('Salvează versiunea'))
        ],
      );

  void _save() {
    final now = DateTime.now();
    Navigator.pop(
        context,
        TarifAsociereRecord(
          id: 'tarif_${now.microsecondsSinceEpoch}',
          projectId: widget.projectId,
          contractId: widget.contractId,
          calificare: _qualification.text.trim(),
          tarifOra:
              double.tryParse(_hour.text.replaceAll(',', '.')) ?? double.nan,
          tarifKm: double.tryParse(_km.text.replaceAll(',', '.')) ?? double.nan,
          moneda: _currency,
          asociat: AsociereParteX.fromValue(_party),
          valabilDeLa: now,
          createdAt: now,
          updatedAt: now,
          revision: (widget.previous?.revision ?? 0) + 1,
        ));
  }
}
