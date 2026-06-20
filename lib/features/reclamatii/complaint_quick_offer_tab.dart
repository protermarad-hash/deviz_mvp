import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/company_profile.dart';
import '../../core/pdf_actions_helper.dart';
import '../../core/pdf/pdf_font_helper.dart';
import '../../core/repositories/app_data_repository.dart';
import '../master/master_local_store.dart';
import '../materials/materials_catalog_service.dart';
import '../oferte/local_oferte_repository.dart';
import '../oferte/offer_models.dart';
import 'complaint_models.dart';
import 'complaint_quick_offer_pdf_service.dart';

class ComplaintQuickOfferTab extends StatefulWidget {
  const ComplaintQuickOfferTab({
    super.key,
    required this.complaint,
    required this.repository,
    this.isAdmin = false,
  });

  final ComplaintRecord complaint;
  final AppDataRepository repository;
  final bool isAdmin;

  @override
  State<ComplaintQuickOfferTab> createState() => _ComplaintQuickOfferTabState();
}

class _ComplaintQuickOfferTabState extends State<ComplaintQuickOfferTab> {
  static const double _defaultTva = 21.0;

  List<ComplaintOfferLine> _liniiClient = [];
  List<ComplaintOfferLine> _liniiColaborator = [];
  double _tvaPercent = _defaultTva;
  String _notaClient = '';
  String _notaColaborator = '';
  bool _isSaving = false;
  bool _isGeneratingPdf = false;
  List<MasterMaterial> _catalog = [];
  CompanyProfile? _companyProfile;
  // Referință OfferRecord salvat (pentru update-uri ulterioare)
  String? _existingOfertaId;
  String? _existingOfertaNumar;
  final LocalOferteRepository _ofertaRepo = LocalOferteRepository();

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadAll);
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadSavedOffers(),
      _loadCatalog(),
      _loadCompanyProfile(),
    ]);
  }

  String get _prefKeyClient =>
      'complaint_offer_client_${widget.complaint.id}';
  String get _prefKeyColaborator =>
      'complaint_offer_colaborator_${widget.complaint.id}';
  String get _prefKeyMeta =>
      'complaint_offer_meta_${widget.complaint.id}';

  Future<void> _loadSavedOffers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientJson = prefs.getString(_prefKeyClient);
      final colaboratorJson = prefs.getString(_prefKeyColaborator);
      final metaJson = prefs.getString(_prefKeyMeta);
      if (!mounted) return;
      setState(() {
        if (clientJson != null) {
          final list = jsonDecode(clientJson) as List;
          _liniiClient = list
              .whereType<Map>()
              .map((m) =>
                  ComplaintOfferLine.fromMap(Map<String, dynamic>.from(m)))
              .toList();
        }
        if (colaboratorJson != null) {
          final list = jsonDecode(colaboratorJson) as List;
          _liniiColaborator = list
              .whereType<Map>()
              .map((m) =>
                  ComplaintOfferLine.fromMap(Map<String, dynamic>.from(m)))
              .toList();
        }
        if (metaJson != null) {
          final meta = jsonDecode(metaJson) as Map<String, dynamic>;
          _tvaPercent = (meta['tva_percent'] as num? ?? 21).toDouble();
          _notaClient = (meta['nota_client'] ?? '').toString();
          _notaColaborator =
              (meta['nota_colaborator'] ?? '').toString();
          _existingOfertaId = (meta['oferta_id'] ?? '').toString();
          if (_existingOfertaId?.isEmpty == true) _existingOfertaId = null;
          _existingOfertaNumar = (meta['oferta_numar'] ?? '').toString();
          if (_existingOfertaNumar?.isEmpty == true) _existingOfertaNumar = null;
        }
      });
    } catch (e) {
      debugPrint('[ComplaintQuickOffer] încărcare draft ofertă eșuată: $e');
    }
  }

  Future<void> _loadCatalog() async {
    try {
      final mats = await MaterialsCatalogService().listMaterials();
      if (mounted) setState(() => _catalog = mats);
    } catch (e) {
      debugPrint('[ComplaintQuickOffer] încărcare catalog materiale eșuată: $e');
    }
  }

  Future<void> _loadCompanyProfile() async {
    try {
      final profile = await widget.repository.loadCompanyProfile();
      if (mounted) setState(() => _companyProfile = profile);
    } catch (e) {
      debugPrint('[ComplaintQuickOffer] încărcare profil firmă eșuată: $e');
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _isSaving = true);
    try {
      // 1. Generează sau reutilizează un ID și nr. de ofertă
      final ofertaId = _existingOfertaId ?? const Uuid().v4();
      final ofertaNumar = _existingOfertaNumar ??
          await widget.repository.nextOfferNumber().catchError((_) =>
              'MINI-${widget.complaint.complaintNumber}');

      // 2. Construiește OfferRecord din liniile mini ofertei
      final now = DateTime.now();
      final totalFaraTva =
          _liniiClient.fold(0.0, (s, l) => s + l.total);
      final tva = totalFaraTva * _tvaPercent / 100;
      final ofertaLines = _liniiClient.asMap().entries.map((entry) {
        final l = entry.value;
        return OfferLineItem(
          id: l.id,
          name: l.denumire,
          description: l.categorie,
          unit: l.um,
          quantity: l.cantitate,
          unitPrice: l.pretUnitar,
          lineTotal: l.total,
          sortOrder: entry.key,
          lineType: l.categorie == 'manopera'
              ? OfferLineType.manopera
              : OfferLineType.material,
        );
      }).toList();

      final oferta = OfferRecord(
        id: ofertaId,
        offerNumber: ofertaNumar,
        title: 'Mini ofertă — ${widget.complaint.complaintNumber}',
        clientId: widget.complaint.beneficiaryClientId,
        clientName: widget.complaint.beneficiaryName,
        jobId: '',
        jobCode: '',
        jobTitle: '',
        status: OfferStatus.draft,
        issueDate: now,
        validUntil: null,
        currency: 'RON',
        exchangeRateSource: OfferExchangeRateSource.manual,
        bnrRate: 0,
        manualRate: 5.0,
        exchangeCommissionPercent: 0,
        effectiveExchangeRate: 5.0,
        notes: _notaClient,
        materialSubtotal: totalFaraTva,
        laborSubtotal: 0,
        subtotalDirect: totalFaraTva,
        regiePercent: 0,
        regieValue: 0,
        profitPercent: 0,
        profitValue: 0,
        subtotalComercial: totalFaraTva,
        subtotal: totalFaraTva,
        vatPercent: _tvaPercent,
        vatValue: tva,
        totalValue: totalFaraTva + tva,
        lines: ofertaLines,
        createdAt: now,
        updatedAt: now,
        createdByUserId: '',
        createdByUserEmail: '',
        complaintId: widget.complaint.id,
        complaintNumber: widget.complaint.complaintNumber,
        tipOferta: 'mini_oferta',
        sursa: 'reclamatie',
        sursaId: widget.complaint.id,
        sursaNumar: widget.complaint.complaintNumber,
      );

      // 3. Salvează local (SharedPreferences + LocalOferteRepository)
      await _ofertaRepo.upsertOffer(oferta);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyClient,
          jsonEncode(_liniiClient.map((l) => l.toMap()).toList()));
      await prefs.setString(_prefKeyColaborator,
          jsonEncode(_liniiColaborator.map((l) => l.toMap()).toList()));
      await prefs.setString(
          _prefKeyMeta,
          jsonEncode({
            'tva_percent': _tvaPercent,
            'nota_client': _notaClient,
            'nota_colaborator': _notaColaborator,
            'oferta_id': ofertaId,
            'oferta_numar': ofertaNumar,
          }));

      if (mounted) {
        setState(() {
          _existingOfertaId = ofertaId;
          _existingOfertaNumar = ofertaNumar;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Draft salvat în Oferte ($ofertaNumar) ✓'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare la salvare: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _generatePdf({bool forColaborator = false}) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final linii = forColaborator ? _liniiColaborator : _liniiClient;
      if (linii.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Adaugă cel puțin o linie în ofertă'),
        ));
        return;
      }
      await PdfFontHelper.initialize();
      final path = await ComplaintQuickOfferPdfService.export(
        complaint: widget.complaint,
        linii: linii,
        tvaPercent: _tvaPercent,
        nota: forColaborator ? _notaColaborator : _notaClient,
        companyProfile: _companyProfile,
        forColaborator: forColaborator,
      );
      if (!mounted) return;
      await PdfActionsHelper.showPdfActions(
        context,
        filePath: path,
        title: forColaborator
            ? 'Ofertă colaborator ${widget.complaint.complaintNumber}'
            : 'Ofertă client ${widget.complaint.complaintNumber}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _trimiteWhatsApp() async {
    final telefon = widget.complaint.colaboratorTelefon.trim();
    if (telefon.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Telefonul colaboratorului nu este completat'),
      ));
      return;
    }
    final colaborator = widget.complaint.colaboratorNume.trim();
    final ref = widget.complaint.colaboratorRefNumber.trim();
    final total = (_totalColaborator * (1 + _tvaPercent / 100))
        .toStringAsFixed(2);
    final msg = Uri.encodeComponent(
      'Bună ziua,\nAlăturat găsiți oferta pentru intervenția '
      '${widget.complaint.complaintNumber}'
      '${ref.isNotEmpty ? " ref. $ref" : ""}.\n'
      'Total: $total RON (incl. TVA ${_tvaPercent.toStringAsFixed(0)}%).\n'
      'SC PRO TERM SRL',
    );
    // Normalizare telefon: 07x → +407x
    String normalized = telefon.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (normalized.startsWith('0')) {
      normalized = '+4$normalized';
    } else if (!normalized.startsWith('+')) {
      normalized = '+$normalized';
    }
    final url = Uri.parse('https://wa.me/$normalized?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    debugPrint('[QuickOffer] WhatsApp → $colaborator $telefon');
  }

  double get _totalClient =>
      _liniiClient.fold(0.0, (s, l) => s + l.total);
  double get _totalColaborator =>
      _liniiColaborator.fold(0.0, (s, l) => s + l.total);

  @override
  Widget build(BuildContext context) {
    final showColaboratorSection = widget.isAdmin &&
        widget.complaint.tipSursa != 'client_direct' &&
        widget.complaint.colaboratorNume.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── TVA selector ─────────────────────────────────────────────────
          Row(
            children: [
              const Text('TVA %:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              for (final pct in [0.0, 5.0, 9.0, 19.0, 21.0])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${pct.toStringAsFixed(0)}%'),
                    selected: _tvaPercent == pct,
                    onSelected: (_) => setState(() => _tvaPercent = pct),
                    selectedColor: const Color(0xFFFFCDD2),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Ofertă client ─────────────────────────────────────────────────
          _buildOfertaSection(
            titlu: 'Ofertă către client',
            subtitlu: 'Produse și servicii facturate clientului',
            linii: _liniiClient,
            onAddLine: () => _showAddLineDialog(_liniiClient),
            onRemoveLine: (i) => setState(() => _liniiClient.removeAt(i)),
            totalFaraTva: _totalClient,
            nota: _notaClient,
            onNotaChanged: (v) => setState(() => _notaClient = v),
            accentColor: Colors.blue[700]!,
            icon: Icons.person_outlined,
          ),

          const SizedBox(height: 16),

          // ── Ofertă colaborator (ADMIN ONLY) ──────────────────────────────
          if (showColaboratorSection) ...[
            _buildOfertaSection(
              titlu:
                  'Ofertă către ${widget.complaint.colaboratorNume}',
              subtitlu:
                  'VIZIBIL DOAR ADMIN — decontare cu societatea parteneră',
              linii: _liniiColaborator,
              onAddLine: () =>
                  _showAddLineDialog(_liniiColaborator),
              onRemoveLine: (i) =>
                  setState(() => _liniiColaborator.removeAt(i)),
              totalFaraTva: _totalColaborator,
              nota: _notaColaborator,
              onNotaChanged: (v) =>
                  setState(() => _notaColaborator = v),
              accentColor: const Color(0xFFC62828),
              icon: Icons.handshake_outlined,
              isAdminOnly: true,
            ),
            const SizedBox(height: 16),
          ],

          // ── Acțiuni ───────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Salvează draft'),
                  onPressed:
                      (_isSaving || _isGeneratingPdf) ? null : _saveDraft,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  icon: _isGeneratingPdf
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ))
                      : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('PDF client'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                  ),
                  onPressed: (_isSaving || _isGeneratingPdf)
                      ? null
                      : () => _generatePdf(forColaborator: false),
                ),
              ),
            ],
          ),
          if (showColaboratorSection) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('PDF colaborator'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      side: const BorderSide(color: Color(0xFFC62828)),
                    ),
                    onPressed: (_isSaving || _isGeneratingPdf)
                        ? null
                        : () => _generatePdf(forColaborator: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.send_outlined, size: 18,
                        color: Colors.green),
                    label: const Text('WhatsApp collab.',
                        style: TextStyle(color: Colors.green)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                    ),
                    onPressed: _trimiteWhatsApp,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildOfertaSection({
    required String titlu,
    required String subtitlu,
    required List<ComplaintOfferLine> linii,
    required VoidCallback onAddLine,
    required void Function(int) onRemoveLine,
    required double totalFaraTva,
    required String nota,
    required void Function(String) onNotaChanged,
    required Color accentColor,
    required IconData icon,
    bool isAdminOnly = false,
  }) {
    final totalCuTva = totalFaraTva * (1 + _tvaPercent / 100);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(icon, color: accentColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titlu,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(subtitlu,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
                if (isAdminOnly)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red[200]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ADMIN',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.red[700],
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Linii
            if (linii.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('Nicio linie adăugată',
                      style: TextStyle(color: Colors.grey[500])),
                ),
              )
            else
              ...linii.asMap().entries.map((entry) =>
                  _buildLine(entry.value, entry.key, onRemoveLine, accentColor)),

            // Buton adaugă linie
            TextButton.icon(
              icon: Icon(Icons.add_circle_outline, size: 16,
                  color: accentColor),
              label: Text('Adaugă produs/serviciu',
                  style: TextStyle(color: accentColor)),
              onPressed: onAddLine,
            ),

            // Total
            if (linii.isNotEmpty) ...[
              const Divider(),
              _totalRow('Total fără TVA:',
                  '${totalFaraTva.toStringAsFixed(2)} RON'),
              _totalRow(
                  'TVA ${_tvaPercent.toStringAsFixed(0)}%:',
                  '${(totalCuTva - totalFaraTva).toStringAsFixed(2)} RON'),
              _totalRow(
                'TOTAL:',
                '${totalCuTva.toStringAsFixed(2)} RON',
                bold: true,
                color: accentColor,
              ),
              const SizedBox(height: 10),
            ],

            // Notă
            TextFormField(
              initialValue: nota,
              decoration: const InputDecoration(
                labelText: 'Notă / condiții (opțional)',
                prefixIcon: Icon(Icons.notes_outlined, size: 18),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              onChanged: onNotaChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLine(ComplaintOfferLine line, int index,
      void Function(int) onRemove, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.denumire,
                    style:
                        const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                Text(
                  '${line.cantitate} ${line.um} × ${line.pretUnitar.toStringAsFixed(2)} RON'
                  '  [${line.categorie}]',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '${line.total.toStringAsFixed(2)} RON',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: accentColor,
                fontSize: 13),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: Colors.red, size: 18),
            onPressed: () => onRemove(index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value,
      {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 15 : 13,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }

  void _showAddLineDialog(List<ComplaintOfferLine> targetList) {
    final denumireCtrl = TextEditingController();
    final cantCtrl = TextEditingController(text: '1');
    final pretCtrl = TextEditingController();
    String um = 'buc';
    String categorie = 'manopera';

    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Adaugă produs / serviciu'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Autocompletare din catalog materiale
                  Autocomplete<MasterMaterial>(
                    displayStringForOption: (m) => m.name,
                    optionsBuilder: (tv) {
                      if (tv.text.trim().isEmpty) {
                        return const Iterable.empty();
                      }
                      final q = tv.text.toLowerCase();
                      return _catalog
                          .where((m) => m.name.toLowerCase().contains(q))
                          .take(10);
                    },
                    onSelected: (m) {
                      setDlg(() {
                        denumireCtrl.text = m.name;
                        pretCtrl.text =
                            m.price.toStringAsFixed(2);
                        um = m.unit.isNotEmpty ? m.unit : 'buc';
                      });
                    },
                    fieldViewBuilder: (ctx, ctrl, fn, onSubmit) =>
                        TextFormField(
                      controller: ctrl,
                      focusNode: fn,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Caută în catalog sau scrie manual',
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                      onChanged: (v) => denumireCtrl.text = v,
                    ),
                    optionsViewBuilder: (ctx, onSelected, options) =>
                        Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxHeight: 220, maxWidth: 380),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (_, i) {
                              final m = options.elementAt(i);
                              return ListTile(
                                dense: true,
                                title: Text(m.name),
                                subtitle: Text(
                                    '${m.price.toStringAsFixed(2)} RON / ${m.unit}'),
                                onTap: () => onSelected(m),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: um,
                          decoration: const InputDecoration(labelText: 'UM'),
                          items: ['buc', 'ml', 'm', 'm²', 'kg', 'ore',
                              'set', 'l']
                              .map((u) => DropdownMenuItem(
                                  value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) => setDlg(() => um = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: categorie,
                          decoration:
                              const InputDecoration(labelText: 'Categorie'),
                          items: const [
                            DropdownMenuItem(
                                value: 'material', child: Text('Material')),
                            DropdownMenuItem(
                                value: 'manopera', child: Text('Manoperă')),
                            DropdownMenuItem(
                                value: 'transport',
                                child: Text('Transport')),
                            DropdownMenuItem(
                                value: 'altul', child: Text('Altul')),
                          ],
                          onChanged: (v) => setDlg(() => categorie = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cantCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Cantitate'),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: pretCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Preț unitar (RON)'),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () {
                final cant =
                    double.tryParse(cantCtrl.text.replaceAll(',', '.')) ??
                        1;
                final pret =
                    double.tryParse(pretCtrl.text.replaceAll(',', '.')) ??
                        0;
                final denumire = denumireCtrl.text.trim();
                if (denumire.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Completează denumirea')));
                  return;
                }
                if (pret <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Prețul trebuie să fie > 0')));
                  return;
                }
                setState(() {
                  targetList.add(ComplaintOfferLine.create(
                    denumire: denumire,
                    um: um,
                    cantitate: cant,
                    pretUnitar: pret,
                    categorie: categorie,
                  ));
                });
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828)),
              child: const Text('Adaugă'),
            ),
          ],
        ),
      ),
    );
  }
}
