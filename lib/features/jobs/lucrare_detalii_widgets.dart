import 'package:flutter/material.dart';

import '../oferte/offer_models.dart';
import '../deviz_tehnic/deviz_tehnic_models.dart';
import 'lucrare_detalii_models.dart';

/// Dialog picker combinat: oferte simple + devize tehnice.
/// Returnează `LucrareSourceDocument` selectat (sau null la anulare).
class LucrareSourcePickerDialog extends StatefulWidget {
  const LucrareSourcePickerDialog(
      {super.key, required this.offers, required this.devize});
  final List<OfferRecord> offers;
  final List<DevizTehnicRecord> devize;

  @override
  State<LucrareSourcePickerDialog> createState() =>
      _LucrareSourcePickerDialogState();
}

class _LucrareSourcePickerDialogState extends State<LucrareSourcePickerDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final all = [
      ...widget.offers.map(LucrareSourceDocument.fromOffer),
      ...widget.devize.map(LucrareSourceDocument.fromDeviz),
    ];
    final filtered = _search.isEmpty
        ? all
        : all.where((s) =>
            s.numar.toLowerCase().contains(_search.toLowerCase()) ||
            s.titlu.toLowerCase().contains(_search.toLowerCase()) ||
            s.client.toLowerCase().contains(_search.toLowerCase())).toList();

    return AlertDialog(
      title: const Text('Selectează documentul sursă'),
      content: SizedBox(
        width: 520,
        height: 440,
        child: Column(
          children: [
            TextField(
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Caută după număr, titlu sau client...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Niciun document găsit.'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final s = filtered[i];
                        return ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: s.tipColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: s.tipColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(s.tipLabel,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: s.tipColor,
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Text('${s.numar} — ${s.titlu}',
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(s.client,
                              overflow: TextOverflow.ellipsis),
                          trailing: Text(
                            '${s.nrArticole} art.',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () => Navigator.of(ctx).pop(s),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anulează'),
        ),
      ],
    );
  }
}

/// Câmp observații per linie (stateful, controller propriu).
class LineObservationsField extends StatefulWidget {
  const LineObservationsField({
    super.key,
    required this.initial,
    required this.onSave,
  });
  final String initial;
  final ValueChanged<String> onSave;
  @override
  State<LineObservationsField> createState() => _LineObservationsFieldState();
}

class _LineObservationsFieldState extends State<LineObservationsField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void didUpdateWidget(LineObservationsField old) {
    super.didUpdateWidget(old);
    // Sincronizează controllerul dacă valoarea externă s-a schimbat
    // (ex: după re-populare din ofertă)
    if (old.initial != widget.initial && _ctrl.text != widget.initial) {
      _ctrl.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'Observații',
        hintText: 'notă per articol (apare în PDF)...',
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        suffixIcon: IconButton(
          icon: const Icon(Icons.check, size: 18),
          tooltip: 'Salvează',
          onPressed: () => widget.onSave(_ctrl.text.trim()),
        ),
      ),
      style: const TextStyle(fontSize: 12),
      onSubmitted: (v) => widget.onSave(v.trim()),
    );
  }
}
