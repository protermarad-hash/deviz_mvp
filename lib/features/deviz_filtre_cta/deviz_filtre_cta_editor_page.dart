import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/company_profile.dart';
import '../../core/pdf_actions_helper.dart';
import '../../core/repositories/app_data_repository.dart';
import '../clients/client_models.dart';
import 'deviz_filtre_cta_models.dart';
import 'deviz_filtre_cta_pdf_service.dart';
import 'deviz_filtre_cta_repository.dart';

/// Pagina de creare / editare deviz filtre CTA.
/// Permite editarea header-ului, gestionarea CTA-urilor (adaugă/duplică/șterge/reordonează)
/// și editarea prețurilor per filtru.
class DevizFiltreCtaEditorPage extends StatefulWidget {
  const DevizFiltreCtaEditorPage({
    super.key,
    this.existing,
    required this.repository,
    required this.appRepository,
    this.currentUserName = '',
  });

  final DevizFiltreCta? existing;
  final DevizFiltreCtaRepository repository;
  final AppDataRepository appRepository;
  final String currentUserName;

  @override
  State<DevizFiltreCtaEditorPage> createState() =>
      _DevizFiltreCtaEditorPageState();
}

class _DevizFiltreCtaEditorPageState
    extends State<DevizFiltreCtaEditorPage> {
  // ── Controllers header ────────────────────────────────────────────────────
  final _titluCtrl = TextEditingController();
  final _anCtrl = TextEditingController();
  final _numarCtrl = TextEditingController();
  final _intocmitDeCtrl = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  DateTime _dataEmitere = DateTime.now();
  String _clientId = '';
  String _clientName = '';
  List<CtaEntry> _ctas = [];
  List<ClientRecord> _clients = [];

  bool _saving = false;
  bool _isNew = true;
  String _existingId = '';

  static const _blue = Color(0xFF1565C0);
  final _fmtEur = NumberFormat('#,##0.00', 'ro_RO');

  @override
  void initState() {
    super.initState();
    _initFromExisting();
    Future.microtask(_loadClients);
  }

  @override
  void dispose() {
    _titluCtrl.dispose();
    _anCtrl.dispose();
    _numarCtrl.dispose();
    _intocmitDeCtrl.dispose();
    super.dispose();
  }

  void _initFromExisting() {
    final e = widget.existing;
    if (e != null) {
      _isNew = false;
      _existingId = e.id;
      _titluCtrl.text = e.titluDeviz;
      _anCtrl.text = e.anDeviz;
      _numarCtrl.text = e.numar;
      _intocmitDeCtrl.text = e.intocmitDe;
      _dataEmitere = e.dataEmitere;
      _clientId = e.clientId;
      _clientName = e.clientName;
      _ctas = List.from(e.ctas);
    } else {
      _isNew = true;
      _anCtrl.text = DateTime.now().year.toString();
      _intocmitDeCtrl.text = widget.currentUserName;
      _ctas = ctaTemplateImplicit();
      _genereazaNumar();
    }
  }

  Future<void> _genereazaNumar() async {
    try {
      final nr = await widget.repository.nextNumber();
      if (mounted) setState(() => _numarCtrl.text = nr);
    } catch (_) {}
  }

  Future<void> _loadClients() async {
    try {
      final list = await widget.appRepository.listClients();
      if (!mounted) return;
      setState(() {
        _clients = [...list]
          ..sort((a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });
    } catch (_) {}
  }

  // ── Totale ─────────────────────────────────────────────────────────────────

  double _totalZona(ZonaCta zona) => _ctas
      .where((c) => c.zona == zona)
      .fold(0.0, (s, c) => s + c.totalPret);

  double get _totalGeneral => _ctas.fold(0.0, (s, c) => s + c.totalPret);

  // ── Acțiuni CTA ───────────────────────────────────────────────────────────

  void _addCtaFromTemplate(CtaEntry template) {
    setState(() {
      final newId =
          'cta-new-${DateTime.now().millisecondsSinceEpoch}-${_ctas.length}';
      final nrCrt = _ctas.isEmpty
          ? 1
          : _ctas.map((c) => c.nrCrt).reduce((a, b) => a > b ? a : b) + 1;
      _ctas.add(CtaEntry(
        id: newId,
        nrCrt: nrCrt,
        denumireCta: template.denumireCta,
        serie: template.serie,
        locatie: template.locatie,
        zona: template.zona,
        filtre: List.from(template.filtre),
      ));
    });
  }

  void _duplicateCta(int idx) {
    setState(() {
      final src = _ctas[idx];
      final newId =
          'cta-dup-${DateTime.now().millisecondsSinceEpoch}';
      final nrCrt =
          _ctas.map((c) => c.nrCrt).reduce((a, b) => a > b ? a : b) + 1;
      _ctas.insert(
        idx + 1,
        CtaEntry(
          id: newId,
          nrCrt: nrCrt,
          denumireCta: '${src.denumireCta} (copie)',
          serie: src.serie,
          locatie: src.locatie,
          zona: src.zona,
          filtre: List.from(src.filtre),
        ),
      );
      _renumeroteaza();
    });
  }

  Future<void> _deleteCta(int idx) async {
    final cta = _ctas[idx];
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Șterge CTA'),
        content: Text(
            'Ștergi "${cta.denumireCta}"?\nAceastă acțiune nu poate fi anulată.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _ctas.removeAt(idx);
      _renumeroteaza();
    });
  }

  void _renumeroteaza() {
    for (int i = 0; i < _ctas.length; i++) {
      _ctas[i] = _ctas[i].copyWith(nrCrt: i + 1);
    }
  }

  Future<void> _editPret(int ctaIdx, int filtruIdx) async {
    final f = _ctas[ctaIdx].filtre[filtruIdx];
    final ctrl = TextEditingController(
        text: f.pret > 0 ? f.pret.toStringAsFixed(2) : '');

    final val = await showDialog<double>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Editează preț: ${f.pozitie}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Preț manoperă [EUR]',
            suffixText: 'EUR',
          ),
          onSubmitted: (_) {
            final v = double.tryParse(
                    ctrl.text.replaceAll(',', '.').trim()) ??
                0;
            Navigator.pop(dialogCtx, v);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(
                      ctrl.text.replaceAll(',', '.').trim()) ??
                  0;
              Navigator.pop(dialogCtx, v);
            },
            child: const Text('Salvează'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (val == null) return;

    setState(() {
      final filtre = List<CtaFiltru>.from(_ctas[ctaIdx].filtre);
      filtre[filtruIdx] = filtre[filtruIdx].copyWith(pret: val);
      _ctas[ctaIdx] = _ctas[ctaIdx].copyWith(filtre: filtre);
    });
  }

  Future<void> _showAddCtaSheet() async {
    final template = ctaTemplateImplicit();
    final grouped = <ZonaCta, List<CtaEntry>>{};
    for (final c in template) {
      grouped.putIfAbsent(c.zona, () => []).add(c);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Adaugă CTA din template',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  for (final zona in ZonaCta.values)
                    if (grouped.containsKey(zona)) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          zona.label.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _blue,
                              letterSpacing: 0.8),
                        ),
                      ),
                      for (final cta in grouped[zona]!)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.air_outlined,
                              color: _blue),
                          title: Text(cta.denumireCta,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                              cta.locatie.isNotEmpty
                                  ? cta.locatie
                                  : '—',
                              style: const TextStyle(fontSize: 11)),
                          trailing: Text(
                            '${_fmtEur.format(cta.totalPret)} EUR',
                            style: const TextStyle(
                                fontSize: 12, color: _blue),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _addCtaFromTemplate(cta);
                          },
                        ),
                    ],
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('Adaugă CTA blank (manual)'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _addCtaBlank();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addCtaBlank() {
    final newId =
        'cta-blank-${DateTime.now().millisecondsSinceEpoch}';
    final nrCrt = _ctas.isEmpty
        ? 1
        : _ctas.map((c) => c.nrCrt).reduce((a, b) => a > b ? a : b) + 1;
    setState(() {
      _ctas.add(CtaEntry(
        id: newId,
        nrCrt: nrCrt,
        denumireCta: 'CTA nou $nrCrt',
        zona: ZonaCta.altele,
        filtre: const [
          CtaFiltru(
              pozitie: 'Introducere', marimi: [], pret: 0),
        ],
      ));
    });
  }

  void _actualizezaPreteuriDinTemplate() {
    final template = ctaTemplateImplicit();
    final templateByName = <String, CtaEntry>{};
    for (final t in template) {
      templateByName[t.denumireCta.toLowerCase().trim()] = t;
    }

    int updated = 0;
    setState(() {
      for (int i = 0; i < _ctas.length; i++) {
        final key = _ctas[i].denumireCta.toLowerCase().trim();
        final tmpl = templateByName[key];
        if (tmpl == null) continue;

        final newFiltre = <CtaFiltru>[];
        for (int fi = 0; fi < _ctas[i].filtre.length; fi++) {
          if (fi < tmpl.filtre.length) {
            newFiltre.add(_ctas[i].filtre[fi]
                .copyWith(pret: tmpl.filtre[fi].pret));
          } else {
            newFiltre.add(_ctas[i].filtre[fi]);
          }
        }
        _ctas[i] = _ctas[i].copyWith(filtre: newFiltre);
        updated++;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(updated > 0
            ? 'Prețuri actualizate pentru $updated CTA-uri din template.'
            : 'Niciun CTA potrivit cu template-ul nu a fost găsit.'),
      ),
    );
  }

  // ── Salvare + PDF ──────────────────────────────────────────────────────────

  DevizFiltreCta _buildRecord({String existingId = ''}) {
    final now = DateTime.now();
    return DevizFiltreCta(
      id: existingId.isNotEmpty ? existingId : '',
      titluDeviz: _titluCtrl.text.trim(),
      anDeviz: _anCtrl.text.trim(),
      clientId: _clientId,
      clientName: _clientName,
      numar: _numarCtrl.text.trim(),
      intocmitDe: _intocmitDeCtrl.text.trim(),
      ctas: List.from(_ctas),
      dataEmitere: _dataEmitere,
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<DevizFiltreCta?> _salveaza({bool showSnack = true}) async {
    if (_saving) return null;
    setState(() => _saving = true);
    try {
      final record = _buildRecord(existingId: _existingId);
      final saved = await widget.repository.save(record);
      _existingId = saved.id;
      _isNew = false;
      if (showSnack && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deviz salvat cu succes.')),
        );
      }
      return saved;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare la salvare: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _genereazaPdf() async {
    final saved = await _salveaza(showSnack: false);
    if (saved == null) return;
    try {
      CompanyProfile company;
      try {
        company = await widget.appRepository.loadCompanyProfile();
      } catch (_) {
        company = const CompanyProfile();
      }
      if (!mounted) return;
      final path = await FiltreCtaPdfService.generate(
        deviz: saved,
        company: company,
      );
      if (!mounted) return;
      await PdfActionsHelper.showPdfActions(
        context,
        filePath: path,
        title: 'PDF deviz filtre CTA generat',
        shareSubject:
            'Deviz Filtre CTA ${saved.numar.isNotEmpty ? saved.numar : saved.titluDeviz}',
        shareText: 'PDF deviz filtre CTA generat din aplicație.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare PDF: $e')),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Deviz filtre CTA nou' : 'Editează deviz'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              tooltip: 'Salvează',
              icon: const Icon(Icons.save_outlined),
              onPressed: () async {
                final nav = Navigator.of(context);
                final saved = await _salveaza();
                if (saved != null) nav.pop(saved);
              },
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'pdf') _genereazaPdf();
              if (v == 'actualizeaza') _actualizezaPreteuriDinTemplate();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'pdf',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('Generează PDF'),
                ),
              ),
              const PopupMenuItem(
                value: 'actualizeaza',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.sync_outlined),
                  title: Text('Actualizează prețuri din template'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeaderCard()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Text('CTA-uri',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(width: 8),
                        Text('(${_ctas.length})',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _showAddCtaSheet,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Adaugă CTA',
                              style: TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildCtaList(),
                SliverToBoxAdapter(
                    child: const SizedBox(height: 8)),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ── Header card ────────────────────────────────────────────────────────────

  Widget _buildHeaderCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informații deviz',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: _titluCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Titlu deviz',
                hintText: 'Deviz înlocuire filtre CTA-uri',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _numarCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Număr',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _anCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'An',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data emitere',
                  border: OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: Icon(Icons.calendar_today_outlined,
                      size: 18),
                ),
                child: Text(
                  DateFormat('dd.MM.yyyy').format(_dataEmitere),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildClientDropdown(),
            const SizedBox(height: 10),
            TextField(
              controller: _intocmitDeCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Întocmit de',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataEmitere,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _dataEmitere = picked);
  }

  Widget _buildClientDropdown() {
    if (_clients.isEmpty) {
      return TextField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Client',
          hintText: _clientName.isNotEmpty
              ? _clientName
              : 'Se încarcă clienții…',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      );
    }
    final selectedId = _clientId.isNotEmpty &&
            _clients.any((c) => c.id == _clientId)
        ? _clientId
        : null;
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Client',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      hint: const Text('Selectează client'),
      items: [
        const DropdownMenuItem<String>(
          value: '',
          child: Text('— Fără client —'),
        ),
        ..._clients.map(
          (c) => DropdownMenuItem<String>(
            value: c.id,
            child: Text(c.name,
                overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (v) {
        setState(() {
          _clientId = v ?? '';
          if (v != null && v.isNotEmpty) {
              final found =
                  _clients.where((c) => c.id == v).toList();
              _clientName =
                  found.isNotEmpty ? found.first.name : '';
            } else {
              _clientName = '';
            }
        });
      },
    );
  }

  // ── Lista CTA-uri (reordonabilă) ───────────────────────────────────────────

  Widget _buildCtaList() {
    if (_ctas.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(Icons.air_outlined,
                    size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                const Text('Niciun CTA adăugat.',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _showAddCtaSheet,
                  icon: const Icon(Icons.add),
                  label: const Text('Adaugă CTA din template'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => _buildCtaCard(i),
        childCount: _ctas.length,
      ),
    );
  }

  Widget _buildCtaCard(int idx) {
    final cta = _ctas[idx];
    const zonaBg = Color(0xFFBBDEFB);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFBBDEFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header CTA
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: _blue,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${cta.nrCrt}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cta.denumireCta,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Zona badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: zonaBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    cta.zona.label,
                    style: const TextStyle(
                        fontSize: 9, color: _blue),
                  ),
                ),
              ],
            ),
          ),

          // Subtitlu (serie + locatie)
          if (cta.serie.isNotEmpty || cta.locatie.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                [
                  if (cta.locatie.isNotEmpty) cta.locatie,
                  if (cta.serie.isNotEmpty) 'Seria: ${cta.serie}',
                ].join(' · '),
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey),
              ),
            ),

          // Filtre
          ...List.generate(cta.filtre.length, (fi) {
            final f = cta.filtre[fi];
            return InkWell(
              onTap: () => _editPret(idx, fi),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.pozitie,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                          if (f.marimi.isNotEmpty)
                            Text(
                              f.marimi.join(', '),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: f.pret > 0
                            ? const Color(0xFFE3F2FD)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: f.pret > 0
                              ? _blue
                              : Colors.grey.shade300,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        f.pret > 0
                            ? '${_fmtEur.format(f.pret)} EUR'
                            : '— EUR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: f.pret > 0
                              ? _blue
                              : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit_outlined,
                        size: 14, color: Colors.grey),
                  ],
                ),
              ),
            );
          }),

          // Total CTA (dacă mai multe filtre cu preț)
          if (cta.filtre.length > 1 && cta.totalPret > 0)
            Container(
              margin: const EdgeInsets.only(
                  left: 12, right: 12, bottom: 8, top: 4),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Total CTA ${cta.nrCrt}:  '
                    '${_fmtEur.format(cta.totalPret)} EUR',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20)),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Acțiuni CTA
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _duplicateCta(idx),
                icon: const Icon(Icons.copy_outlined, size: 15),
                label: const Text('Duplică',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4)),
              ),
              TextButton.icon(
                onPressed: () => _deleteCta(idx),
                icon: Icon(Icons.delete_outline,
                    size: 15, color: Colors.red.shade700),
                label: Text('Șterge',
                    style: TextStyle(
                        fontSize: 12, color: Colors.red.shade700)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4)),
              ),
              if (idx > 0)
                IconButton(
                  tooltip: 'Mută sus',
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  onPressed: () => setState(() {
                    final tmp = _ctas[idx];
                    _ctas[idx] = _ctas[idx - 1];
                    _ctas[idx - 1] = tmp;
                    _renumeroteaza();
                  }),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              if (idx < _ctas.length - 1)
                IconButton(
                  tooltip: 'Mută jos',
                  icon: const Icon(Icons.arrow_downward, size: 16),
                  onPressed: () => setState(() {
                    final tmp = _ctas[idx];
                    _ctas[idx] = _ctas[idx + 1];
                    _ctas[idx + 1] = tmp;
                    _renumeroteaza();
                  }),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom bar totaluri + acțiuni ──────────────────────────────────────────

  Widget _buildBottomBar() {
    final zones = [
      (ZonaCta.turnatorii, _totalZona(ZonaCta.turnatorii)),
      (ZonaCta.spumatorie, _totalZona(ZonaCta.spumatorie)),
      (ZonaCta.cusatorii, _totalZona(ZonaCta.cusatorii)),
      (ZonaCta.logistica, _totalZona(ZonaCta.logistica)),
      (ZonaCta.altele, _totalZona(ZonaCta.altele)),
    ].where((z) => z.$2 > 0).toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Totaluri pe zone
            if (zones.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  children: [
                    for (final z in zones)
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total ${z.$1.label}:',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '${_fmtEur.format(z.$2)} EUR',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            // Total general
            Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL GENERAL:',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(
                    '${_fmtEur.format(_totalGeneral)} EUR',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ],
              ),
            ),
            // Butoane
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _genereazaPdf,
                      icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 18),
                      label: const Text('PDF'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              final nav = Navigator.of(context);
                              final saved = await _salveaza();
                              if (saved != null) nav.pop(saved);
                            },
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.save_outlined,
                              size: 18),
                      label: Text(
                          _saving ? 'Se salvează…' : 'Salvează deviz'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
