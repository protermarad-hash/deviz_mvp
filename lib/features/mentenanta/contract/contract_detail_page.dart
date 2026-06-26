import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/cloud/firebase_bootstrap.dart';
import '../../../core/pdf_actions_helper.dart';
import '../../../core/repositories/app_data_repository.dart';
import '../interventii/firebase_interventie_repository.dart';
import '../interventii/interventie_editor_page.dart';
import '../interventii/interventie_models.dart';
import '../interventii/log_fgas_pdf_service.dart';
import '../interventii/pv_interventie_pdf_service.dart';
import '../mentenanta_models.dart';
import 'contract_pdf_service.dart';
import '../oferta/oferta_mentenanta_pdf_service.dart';

/// Pagina de detalii a unui contract de mentenanță: rezumat + acțiuni PDF
/// contract + lista intervențiilor efectuate.
class ContractDetailPage extends StatefulWidget {
  const ContractDetailPage({
    super.key,
    required this.contract,
    required this.repository,
  });

  final ContractMentenanta contract;
  final AppDataRepository repository;

  @override
  State<ContractDetailPage> createState() => _ContractDetailPageState();
}

class _ContractDetailPageState extends State<ContractDetailPage> {
  final FirebaseInterventieRepository _repo = FirebaseInterventieRepository();
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'ro_RO');
  final DateFormat _dateFmt = DateFormat('dd.MM.yyyy');

  List<InterventieService> _interventii = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    FirebaseBootstrap.onlineNotifier.addListener(_onOnlineChanged);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    FirebaseBootstrap.onlineNotifier.removeListener(_onOnlineChanged);
    super.dispose();
  }

  void _onOnlineChanged() {
    if (FirebaseBootstrap.onlineNotifier.value &&
        _interventii.isEmpty &&
        !_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final items = await _repo.listInterventii(widget.contract.id);
      if (!mounted) return;
      setState(() {
        _interventii = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Acțiuni intervenții ──────────────────────────────────────────────────────

  Future<void> _openEditor({InterventieService? existing}) async {
    final result = await Navigator.of(context).push<InterventieService>(
      MaterialPageRoute(
        builder: (_) => InterventieEditorPage(
          contract: widget.contract,
          repository: _repo,
          existing: existing,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final idx = _interventii.indexWhere((i) => i.id == result.id);
      if (idx >= 0) {
        _interventii[idx] = result;
      } else {
        _interventii.insert(0, result);
      }
      _interventii.sort((a, b) => b.dataInterventie.compareTo(a.dataInterventie));
    });
  }

  Future<void> _delete(InterventieService i) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Șterge intervenția'),
        content: Text('Sigur ștergi intervenția '
            '${i.numar.isEmpty ? '(fără număr)' : i.numar}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anulează')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _interventii.removeWhere((x) => x.id == i.id));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Intervenție ștearsă.')));
    _repo.deleteInterventie(i.id).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Eroare ștergere: $e')));
        _load();
      }
    });
  }

  void _replace(InterventieService updated) {
    final idx = _interventii.indexWhere((x) => x.id == updated.id);
    if (idx >= 0) _interventii[idx] = updated;
  }

  // ── Acțiuni PDF intervenție (PV + Log F-Gas) ─────────────────────────────────

  Future<void> _generatePv(InterventieService i) async {
    try {
      final path = await PvInterventiePdfService.export(
        repository: widget.repository,
        contract: widget.contract,
        interventie: i,
      );
      final updated =
          i.copyWith(pvGenerat: true, pvPath: path, updatedAt: DateTime.now());
      _repo.saveInterventie(updated).catchError((_) => updated);
      if (!mounted) return;
      setState(() => _replace(updated));
      await PdfActionsHelper.showPdfActions(context,
          filePath: path, title: 'PV intervenție ${i.numar}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Eroare generare PV: $e')));
    }
  }

  Future<void> _generateFGas(InterventieService i) async {
    try {
      final path = await LogFGasPdfService.export(
        repository: widget.repository,
        contract: widget.contract,
        interventie: i,
      );
      final updated = i.copyWith(
          logFGasGenerat: true, logFGasPath: path, updatedAt: DateTime.now());
      _repo.saveInterventie(updated).catchError((_) => updated);
      if (!mounted) return;
      setState(() => _replace(updated));
      await PdfActionsHelper.showPdfActions(context,
          filePath: path, title: 'Log F-Gas ${i.numar}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Eroare generare F-Gas: $e')));
    }
  }

  // ── Acțiuni PDF contract ─────────────────────────────────────────────────────

  Future<void> _generateOferta() async {
    try {
      final path = await OfertaMentenantaPdfService.export(
        repository: widget.repository,
        contract: widget.contract,
      );
      if (!mounted) return;
      await PdfActionsHelper.showPdfActions(context,
          filePath: path, title: 'Ofertă mentenanță ${widget.contract.numar}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Eroare generare PDF: $e')));
    }
  }

  Future<void> _generateContract() async {
    try {
      final path = await ContractPdfService.export(
        repository: widget.repository,
        contract: widget.contract,
      );
      if (!mounted) return;
      await PdfActionsHelper.showPdfActions(context,
          filePath: path,
          title: 'Contract mentenanță ${widget.contract.numar}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare generare contract: $e')));
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = widget.contract;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.numar.isEmpty ? 'Detalii contract' : c.numar),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Intervenție nouă'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            _buildHeader(c),
            const SizedBox(height: 12),
            _buildSummary(c),
            const SizedBox(height: 12),
            _buildPdfButtons(),
            const SizedBox(height: 16),
            Text('Intervenții efectuate',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_interventii.isEmpty)
              _buildEmptyInterventii()
            else
              ..._interventii.map(_buildInterventieCard),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ContractMentenanta c) {
    final color = c.status.color;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(c.numar.isEmpty ? '(fără număr)' : c.numar,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Text(c.status.label,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(c.clientName.isEmpty ? 'Client neselectat' : c.clientName,
                style: const TextStyle(fontSize: 15)),
            if (c.titlu.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(c.titlu,
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.date_range, size: 15, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                    '${_dateFmt.format(c.dataStart)} – ${_dateFmt.format(c.dataEnd)}',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                const Spacer(),
                Text('${_fmt.format(c.totalCuTVA)} RON',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(ContractMentenanta c) {
    Widget item(IconData icon, String label, String value) {
      return Expanded(
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          ],
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            item(Icons.payments_outlined, 'Total cu TVA',
                '${_fmt.format(c.totalCuTVA)} RON'),
            item(Icons.inventory_2_outlined, 'Echipamente',
                '${c.echipamente.length}'),
            item(Icons.event_repeat_outlined, 'Intervenții/an',
                '${c.interventiiPlanificate}'),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _generateOferta,
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Ofertă PDF'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _generateContract,
            icon: const Icon(Icons.assignment_outlined, size: 18),
            label: const Text('Contract PDF'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyInterventii() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.build_circle_outlined,
              size: 56, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text('Nicio intervenție înregistrată.',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInterventieCard(InterventieService i) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(i.numar.isEmpty ? '(fără număr)' : i.numar,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Text(_dateFmt.format(i.dataInterventie),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                _buildMenu(i),
              ],
            ),
            Text(i.tipInterventie.label, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              children: [
                if (i.tehnician.isNotEmpty) ...[
                  Icon(Icons.person_outline,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 3),
                  Text(i.tehnician,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade700)),
                  const SizedBox(width: 10),
                ],
                Icon(Icons.inventory_2_outlined,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 3),
                Text('${i.echipamenteLucrate.length} echip.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _generatePv(i),
                  icon: Icon(
                    i.pvGenerat
                        ? Icons.check_circle_outline
                        : Icons.picture_as_pdf_outlined,
                    size: 16,
                    color: i.pvGenerat ? Colors.green : null,
                  ),
                  label: const Text('PDF PV'),
                ),
                if (i.necesitaLogFGas)
                  TextButton.icon(
                    onPressed: () => _generateFGas(i),
                    icon: Icon(
                      i.logFGasGenerat
                          ? Icons.check_circle_outline
                          : Icons.ac_unit_outlined,
                      size: 16,
                      color: i.logFGasGenerat ? Colors.green : null,
                    ),
                    label: const Text('PDF F-Gas'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(InterventieService i) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (v) {
        switch (v) {
          case 'edit':
            _openEditor(existing: i);
            break;
          case 'delete':
            _delete(i);
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Editează')),
        PopupMenuItem(value: 'delete', child: Text('Șterge')),
      ],
    );
  }
}
