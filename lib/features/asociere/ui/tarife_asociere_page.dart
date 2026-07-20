import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../tarif_asociere_models.dart';
import '../tarif_asociere_repository.dart';
import 'asociere_string_autocomplete.dart';

/// Tarife unificate per calificare (RON/oră + RON/km), negociate per asociere.
class TarifeAsocierePage extends StatefulWidget {
  const TarifeAsocierePage({super.key, required this.asociereId});

  final String asociereId;

  @override
  State<TarifeAsocierePage> createState() => _TarifeAsocierePageState();
}

class _TarifeAsocierePageState extends State<TarifeAsocierePage> {
  final _uuid = const Uuid();
  List<TarifAsociereRecord> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final list =
        await TarifAsociereRepository.instance.listByAsociere(widget.asociereId);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _edit([TarifAsociereRecord? existing]) async {
    final saved = await showModalBottomSheet<TarifAsociereRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TarifForm(
        asociereId: widget.asociereId,
        uuid: _uuid,
        existing: existing,
      ),
    );
    if (saved != null) {
      await TarifAsociereRepository.instance.upsertTarif(saved);
      await _load();
    }
  }

  void _delete(TarifAsociereRecord t) {
    setState(() => _items.removeWhere((i) => i.id == t.id));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Tarif șters.')));
    TarifAsociereRepository.instance.deleteTarif(t.id).catchError((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tarife asociere')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Tarif'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Text('Niciun tarif. Adaugă calificări și tarife.'))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final t = _items[i];
                    return ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(t.calificare),
                      subtitle: Text(
                          '${t.tarifRonOra.toStringAsFixed(2)} RON/oră'
                          '${t.tarifRonKm > 0 ? ' · ${t.tarifRonKm.toStringAsFixed(2)} RON/km' : ''}'),
                      onTap: () => _edit(t),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(t),
                      ),
                    );
                  },
                ),
    );
  }
}

class _TarifForm extends StatefulWidget {
  const _TarifForm(
      {required this.asociereId, required this.uuid, this.existing});

  final String asociereId;
  final Uuid uuid;
  final TarifAsociereRecord? existing;

  @override
  State<_TarifForm> createState() => _TarifFormState();
}

class _TarifFormState extends State<_TarifForm> {
  late String _calificare;
  late final TextEditingController _oraCtrl;
  late final TextEditingController _kmCtrl;

  @override
  void initState() {
    super.initState();
    _calificare = widget.existing?.calificare ?? '';
    _oraCtrl = TextEditingController(
        text: widget.existing != null
            ? widget.existing!.tarifRonOra.toString()
            : '');
    _kmCtrl = TextEditingController(
        text: widget.existing != null && widget.existing!.tarifRonKm > 0
            ? widget.existing!.tarifRonKm.toString()
            : '');
  }

  @override
  void dispose() {
    _oraCtrl.dispose();
    _kmCtrl.dispose();
    super.dispose();
  }

  double _p(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  void _save() {
    if (_calificare.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calificarea e obligatorie.')));
      return;
    }
    final now = DateTime.now();
    final e = widget.existing;
    Navigator.of(context).pop(TarifAsociereRecord(
      id: e?.id ?? widget.uuid.v4(),
      asociereId: widget.asociereId,
      calificare: _calificare.trim(),
      tarifRonOra: _p(_oraCtrl),
      tarifRonKm: _p(_kmCtrl),
      createdAt: e?.createdAt ?? now,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? 'Tarif nou' : 'Editează tarif',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          AsociereStringAutocomplete(
            label: 'Calificare',
            optiuni: asociereCalificariPredefinite,
            value: _calificare,
            onChanged: (v) => _calificare = v,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _oraCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: const InputDecoration(
                labelText: 'Tarif RON/oră', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _kmCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: const InputDecoration(
                labelText: 'Tarif RON/km (opțional)',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Salvează')),
        ],
      ),
    );
  }
}
