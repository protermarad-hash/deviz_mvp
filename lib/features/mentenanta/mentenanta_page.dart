import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/pdf_actions_helper.dart';
import '../../core/repositories/app_data_repository.dart';
import 'contract/contract_editor_dialog.dart';
import 'contract/contract_pdf_service.dart';
import 'firebase_mentenanta_repository.dart';
import 'mentenanta_models.dart';
import 'oferta/oferta_mentenanta_pdf_service.dart';

/// Pagina principală a modulului Service & Mentenanță — listă de contracte.
class MentenantaPage extends StatefulWidget {
  const MentenantaPage({super.key, required this.repository});

  final AppDataRepository repository;

  @override
  State<MentenantaPage> createState() => _MentenantaPageState();
}

enum _FiltruContract { toate, oferte, acceptate, active, expirate }

class _MentenantaPageState extends State<MentenantaPage> {
  final FirebaseMentenantaRepository _repo = FirebaseMentenantaRepository();
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'ro_RO');
  final DateFormat _dateFmt = DateFormat('dd.MM.yyyy');

  List<ContractMentenanta> _contracte = [];
  bool _loading = true;
  _FiltruContract _filtru = _FiltruContract.toate;

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
    if (FirebaseBootstrap.onlineNotifier.value && _contracte.isEmpty && !_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final items = await _repo.listContracte();
      if (!mounted) return;
      setState(() {
        _contracte = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ContractMentenanta> get _filtered {
    final now = DateTime.now();
    bool isExpirat(ContractMentenanta c) =>
        c.status == ContractMentenantaStatus.expirat ||
        (c.status == ContractMentenantaStatus.activ && c.dataEnd.isBefore(now));
    switch (_filtru) {
      case _FiltruContract.toate:
        return _contracte;
      case _FiltruContract.oferte:
        return _contracte
            .where((c) => c.status == ContractMentenantaStatus.oferta)
            .toList();
      case _FiltruContract.acceptate:
        return _contracte
            .where((c) => c.status == ContractMentenantaStatus.acceptata)
            .toList();
      case _FiltruContract.active:
        return _contracte
            .where((c) =>
                c.status == ContractMentenantaStatus.activ && !isExpirat(c))
            .toList();
      case _FiltruContract.expirate:
        return _contracte.where(isExpirat).toList();
    }
  }

  Color _statusColor(ContractMentenanta c) {
    final now = DateTime.now();
    // Contract activ cu data sfârșit trecută = vizual expirat (roșu).
    if (c.status == ContractMentenantaStatus.activ &&
        c.dataEnd.isBefore(now)) {
      return Colors.red;
    }
    return c.status.color;
  }

  String _statusLabel(ContractMentenanta c) {
    final now = DateTime.now();
    if (c.status == ContractMentenantaStatus.activ && c.dataEnd.isBefore(now)) {
      return 'Expirat';
    }
    return c.status.label;
  }

  // ── Acțiuni ───────────────────────────────────────────────────────────────────

  Future<void> _openEditor({ContractMentenanta? existing}) async {
    final result = await showDialog<ContractMentenanta>(
      context: context,
      builder: (_) => ContractEditorDialog(
        repository: widget.repository,
        cloudRepository: _repo,
        existing: existing,
      ),
    );
    if (result == null) return;
    // Optimistic: actualizează lista imediat.
    setState(() {
      final idx = _contracte.indexWhere((c) => c.id == result.id);
      if (idx >= 0) {
        _contracte[idx] = result;
      } else {
        _contracte.insert(0, result);
      }
    });
  }

  Future<void> _generatePdf(ContractMentenanta c) async {
    try {
      final path = await OfertaMentenantaPdfService.export(
        repository: widget.repository,
        contract: c,
      );
      if (!mounted) return;
      await PdfActionsHelper.showPdfActions(
        context,
        filePath: path,
        title: 'Ofertă mentenanță ${c.numar}',
        shareSubject: 'Ofertă service & mentenanță ${c.numar}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Eroare generare PDF: $e')));
    }
  }

  Future<void> _generateContractPdf(ContractMentenanta c) async {
    try {
      final path = await ContractPdfService.export(
        repository: widget.repository,
        contract: c,
      );
      if (!mounted) return;
      await PdfActionsHelper.showPdfActions(
        context,
        filePath: path,
        title: 'Contract mentenanță ${c.numar}',
        shareSubject: 'Contract prestări servicii ${c.numar}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Eroare generare contract: $e')));
    }
  }

  /// Schimbă statusul contractului (optimistic UI + salvare best-effort).
  void _changeStatus(ContractMentenanta c, ContractMentenantaStatus status) {
    final updated = c.copyWith(status: status, updatedAt: DateTime.now());
    setState(() {
      final idx = _contracte.indexWhere((x) => x.id == c.id);
      if (idx >= 0) _contracte[idx] = updated;
    });
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status actualizat: ${status.label}.')));
    _repo.saveContract(updated).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Eroare salvare status: $e')));
        _load();
      }
      return updated;
    });
  }

  Future<void> _delete(ContractMentenanta c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Șterge contract'),
        content: Text(
            'Sigur ștergi contractul ${c.numar.isEmpty ? c.titlu : c.numar}?'),
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
    // Optimistic UI: scoate din listă imediat.
    setState(() => _contracte.removeWhere((x) => x.id == c.id));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Contract șters.')));
    _repo.deleteContract(c.id).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Eroare ștergere: $e')));
        _load();
      }
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service & Mentenanță'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reîncarcă',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Contract nou'),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _filtered.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _buildCard(_filtered[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    Widget chip(String label, _FiltruContract value) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _filtru == value,
          onSelected: (_) => setState(() => _filtru = value),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          chip('Toate', _FiltruContract.toate),
          chip('Oferte', _FiltruContract.oferte),
          chip('Acceptate', _FiltruContract.acceptate),
          chip('Active', _FiltruContract.active),
          chip('Expirate', _FiltruContract.expirate),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.handyman_outlined,
            size: 72, color: Colors.grey.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Niciun contract de mentenanță. Apasă + pentru a crea primul.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(ContractMentenanta c) {
    final color = _statusColor(c);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openEditor(existing: c),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.numar.isEmpty ? '(fără număr)' : c.numar,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      _statusLabel(c),
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ),
                  _buildMenu(c),
                ],
              ),
              const SizedBox(height: 4),
              Text(c.clientName.isEmpty ? 'Client neselectat' : c.clientName,
                  style: const TextStyle(fontSize: 14)),
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
                  Icon(Icons.date_range,
                      size: 15, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${_dateFmt.format(c.dataStart)} – ${_dateFmt.format(c.dataEnd)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const Spacer(),
                  Icon(Icons.inventory_2_outlined,
                      size: 15, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('${c.echipamente.length} echip.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade700)),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total cu TVA: ${_fmt.format(c.totalCuTVA)} RON',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(ContractMentenanta c) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (v) {
        switch (v) {
          case 'edit':
            _openEditor(existing: c);
            break;
          case 'pdf':
            _generatePdf(c);
            break;
          case 'contract':
            _generateContractPdf(c);
            break;
          case 'accept':
            _changeStatus(c, ContractMentenantaStatus.acceptata);
            break;
          case 'activate':
            _changeStatus(c, ContractMentenantaStatus.activ);
            break;
          case 'delete':
            _delete(c);
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Editează')),
        const PopupMenuItem(value: 'pdf', child: Text('Generează Ofertă PDF')),
        const PopupMenuItem(
            value: 'contract', child: Text('Generează Contract PDF')),
        if (c.status == ContractMentenantaStatus.oferta)
          const PopupMenuItem(
              value: 'accept', child: Text('Marchează ca Acceptat')),
        if (c.status == ContractMentenantaStatus.acceptata)
          const PopupMenuItem(
              value: 'activate', child: Text('Activează contract')),
        const PopupMenuItem(value: 'delete', child: Text('Șterge')),
      ],
    );
  }
}
