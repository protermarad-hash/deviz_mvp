import 'package:flutter/material.dart';

import '../decont_lunar_asociere_models.dart';
import '../decont_lunar_asociere_repository.dart';

/// Decont lunar pe asociere — generare, blocare la aprobare incompletă (cu
/// listă explicită a costurilor blocante), afișarea celor 3 componente separate
/// și banner permanent de verificare manuală.
class DecontAsocierePage extends StatefulWidget {
  const DecontAsocierePage({super.key, required this.asociereId});

  final String asociereId;

  @override
  State<DecontAsocierePage> createState() => _DecontAsocierePageState();
}

class _DecontAsocierePageState extends State<DecontAsocierePage> {
  List<DecontLunarAsociereRecord> _deconturi = [];
  bool _loading = true;
  bool _generating = false;

  int _luna = DateTime.now().month;
  int _an = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final list = await DecontLunarAsociereRepository.instance
        .listByAsociere(widget.asociereId);
    if (mounted) {
      setState(() {
        _deconturi = list;
        _loading = false;
      });
    }
  }

  Future<void> _genereaza() async {
    setState(() => _generating = true);
    try {
      final decont = await DecontLunarAsociereRepository.instance
          .genereazaDecontPentruLuna(
              asociereId: widget.asociereId, luna: _luna, an: _an);
      await _load();
      if (mounted) _showDecont(decont);
    } on DecontAprobareIncompletaException catch (e) {
      if (mounted) _showBlocante(e);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Eroare: $err')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _showBlocante(DecontAprobareIncompletaException e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Decont blocat — aprobări lipsă'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Costurile de mai jos necesită aprobare și nu sunt aprobate '
                'integral (PRO TERM + Partener). Aprobă-le în Registru, apoi '
                'regenerează decontul:'),
            const SizedBox(height: 12),
            ...e.costuriNeaprobate.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    const Icon(Icons.warning_amber,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          '${c.descriere.isEmpty ? "(fără descriere)" : c.descriere} — '
                          '${c.valoareFaraTva.toStringAsFixed(2)} RON'),
                    ),
                  ]),
                )),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Am înțeles')),
        ],
      ),
    );
  }

  void _showDecont(DecontLunarAsociereRecord d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DecontDetail(decont: d, onConfirm: () async {
        await DecontLunarAsociereRepository.instance.confirmaDecont(d.id);
        if (mounted) {
          Navigator.of(context).pop();
          await _load();
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Decont lunar')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _generator(),
                const Divider(height: 1),
                Expanded(
                  child: _deconturi.isEmpty
                      ? const Center(child: Text('Niciun decont generat.'))
                      : ListView.builder(
                          itemCount: _deconturi.length,
                          itemBuilder: (_, i) {
                            final d = _deconturi[i];
                            return ListTile(
                              leading: Icon(
                                  d.status == DecontLunarStatus.confirmat
                                      ? Icons.lock_outline
                                      : Icons.edit_note),
                              title: Text('${d.luna}/${d.an} · ${d.status.label}'),
                              subtitle: Text(
                                  'Rezultat ${d.rezultat.toStringAsFixed(2)} RON · '
                                  '${_directie(d)}'),
                              onTap: () => _showDecont(d),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _generator() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _luna,
            decoration: const InputDecoration(
                labelText: 'Luna', border: OutlineInputBorder()),
            items: List.generate(12, (i) => i + 1)
                .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
                .toList(),
            onChanged: (v) => setState(() => _luna = v ?? _luna),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _an,
            decoration: const InputDecoration(
                labelText: 'Anul', border: OutlineInputBorder()),
            items: List.generate(6, (i) => DateTime.now().year - 3 + i)
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (v) => setState(() => _an = v ?? _an),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _generating ? null : _genereaza,
          child: _generating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Generează'),
        ),
      ]),
    );
  }

  static String _directie(DecontLunarAsociereRecord d) {
    switch (d.rambursareDatorataCatre) {
      case AsociereRambursareCatre.partener:
        return 'de plată către Partener';
      case AsociereRambursareCatre.proTerm:
        return 'de plată către PRO TERM';
      case AsociereRambursareCatre.niciunul:
        return 'nicio rambursare';
    }
  }
}

class _DecontDetail extends StatelessWidget {
  const _DecontDetail({required this.decont, required this.onConfirm});

  final DecontLunarAsociereRecord decont;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final d = decont;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Decont ${d.luna}/${d.an}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            // Banner permanent, non-dismisabil.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade700),
              ),
              child: Row(children: const [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Verifică manual sumele înainte de a considera acest '
                    'decont valabil',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            _row('Venituri încasate', d.veniturIncasatTotal),
            _row('Cost recunoscut PRO TERM', d.costRecunoscutProTerm),
            _row('Cost recunoscut Partener', d.costRecunoscutPartener),
            const Divider(),
            _row('Rezultat (profit/pierdere)', d.rezultat, bold: true),
            const Divider(),
            Text('Componentele rambursării (auditabil)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            _row('(a) Rambursare costuri', d.rambursareCosturi),
            _row('(b) Distribuire profit imediată', d.distribuireProfitImediata),
            _row('Rezervă garanție reținută', d.sumaRezervaRetinuta),
            const Divider(),
            _row('Total rambursare', d.sumaRambursare),
            _row('De achitat acum', d.sumaDeAchitatAcum, bold: true),
            const SizedBox(height: 8),
            Text('Direcție: ${_DecontAsocierePageState._directie(d)}',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            if (d.status == DecontLunarStatus.draft)
              FilledButton.icon(
                onPressed: () => onConfirm(),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Confirmă decontul'),
              )
            else
              const Center(
                  child: Text('Decont confirmat (blocat la regenerare)')),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          Text('${value.toStringAsFixed(2)} RON',
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
