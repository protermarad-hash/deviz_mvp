import 'package:flutter/material.dart';

import '../decont_lunar_asociere_models.dart';
import '../decont_lunar_asociere_repository.dart';
import 'asociere_string_autocomplete.dart';

class DecontAsocierePage extends StatefulWidget {
  const DecontAsocierePage({
    super.key,
    required this.projectId,
    required this.contractId,
    required this.actorId,
    required this.canConfirm,
  });
  final String projectId;
  final String contractId;
  final String actorId;
  final bool canConfirm;
  @override
  State<DecontAsocierePage> createState() => _DecontAsocierePageState();
}

class _DecontAsocierePageState extends State<DecontAsocierePage> {
  List<DecontLunarAsociereRecord> _items = const [];
  bool _loading = true;
  bool _working = false;
  String _month = '${DateTime.now().month}';
  String _year = '${DateTime.now().year}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await DecontLunarAsociereRepository.instance
        .listByProject(widget.projectId);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Expanded(
                          child: AsociereStringAutocomplete(
                              label: 'Lună (căutare)',
                              optiuni: List.generate(12, (i) => '${i + 1}'),
                              value: _month,
                              onChanged: (v) => _month = v)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: AsociereStringAutocomplete(
                              label: 'An (căutare)',
                              optiuni: List.generate(
                                  7, (i) => '${DateTime.now().year - 3 + i}'),
                              value: _year,
                              onChanged: (v) => _year = v)),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                          onPressed: _working ? null : _generate,
                          icon: const Icon(Icons.calculate_outlined),
                          label: const Text('Generează')),
                    ])),
                Expanded(
                    child: _items.isEmpty
                        ? const Center(
                            child: Text(
                                'Nu există deconturi. Se includ numai sursele eligibile, aprobate și neduplicate.'))
                        : ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (_, i) {
                              final item = _items[i];
                              return Card(
                                  child: ListTile(
                                leading: Icon(
                                    item.status == DecontLunarStatus.confirmat
                                        ? Icons.lock_outline
                                        : Icons.edit_note),
                                title: Text(
                                    '${item.luna}/${item.an} · ${item.status.label}'),
                                subtitle: Text(
                                    'Venit ${item.veniturIncasatTotal.toStringAsFixed(2)} · Cost PT ${item.costRecunoscutProTerm.toStringAsFixed(2)} · Cost Partener ${item.costRecunoscutPartener.toStringAsFixed(2)}\nRezultat ${item.rezultat.toStringAsFixed(2)} · Rezervă ${item.sumaRezervaRetinuta.toStringAsFixed(2)} RON'),
                                trailing: item.status ==
                                            DecontLunarStatus.draft &&
                                        widget.canConfirm
                                    ? IconButton(
                                        icon:
                                            const Icon(Icons.verified_outlined),
                                        tooltip: 'Confirmă',
                                        onPressed: () => _confirm(item))
                                    : null,
                                onTap: () => _details(item),
                              ));
                            })),
              ]),
      );

  Future<void> _generate() async {
    setState(() => _working = true);
    try {
      await DecontLunarAsociereRepository.instance.genereazaDecontPentruLuna(
          projectId: widget.projectId,
          contractId: widget.contractId,
          luna: int.tryParse(_month) ?? 0,
          an: int.tryParse(_year) ?? 0,
          actor: widget.actorId);
      await _load();
    } on DecontAprobareIncompletaException catch (error) {
      if (mounted) {
        showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
                    title: const Text('Decont blocat'),
                    content: Text(
                        '${error.costuriNeaprobate.length} costuri din perioadă nu sunt aprobate. Verifică documentele și actorul aprobării.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Închide'))
                    ]));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _confirm(DecontLunarAsociereRecord item) async {
    await DecontLunarAsociereRepository.instance
        .confirma(item.id, widget.actorId);
    await _load();
  }

  void _details(DecontLunarAsociereRecord item) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
              child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(20),
                  children: [
                Text('Decont ${item.luna}/${item.an}',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                const Card(
                    color: Color(0xFFFFF3CD),
                    child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                            'Verifică manual sumele înainte de confirmarea contabilă.'))),
                _row('Venituri eligibile', item.veniturIncasatTotal),
                _row('Cost PRO TERM', item.costRecunoscutProTerm),
                _row('Cost Partener', item.costRecunoscutPartener),
                _row('Rezultat', item.rezultat),
                _row('Rambursare costuri', item.rambursareCosturi),
                _row('Distribuire imediată', item.distribuireProfitImediata),
                _row('Rezervă', item.sumaRezervaRetinuta),
                _row('Obligație netă', item.sumaDeAchitatAcum),
                const Divider(),
                Text(
                    'Intrări snapshot: ${item.inputIds.length} · Formula rev. ${item.formulaRevision} · Generator: ${item.generatDe.isEmpty ? 'necunoscut' : item.generatDe}'),
              ])));
  Widget _row(String label, double value) => ListTile(
      dense: true,
      title: Text(label),
      trailing: Text('${value.toStringAsFixed(2)} RON'));
}
