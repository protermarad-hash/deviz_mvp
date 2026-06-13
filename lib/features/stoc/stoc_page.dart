import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/help/help_module_button.dart';
import 'stoc_models.dart';
import 'stoc_repository.dart';

class StocPage extends StatefulWidget {
  const StocPage({super.key});

  @override
  State<StocPage> createState() => _StocPageState();
}

class _StocPageState extends State<StocPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _repo = StocRepository.instance;

  List<StocItem> _items = [];
  List<StocMiscare> _miscari = [];
  bool _loading = true;
  bool _syncing = false;
  String _search = '';
  String _filtru = 'Toate'; // 'Toate', 'Critic', 'Comanda', 'OK'

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final items = await _repo.listMerged();
    final miscari = await _repo.listMiscariLocal();
    if (!mounted) return;
    setState(() {
      _items = items;
      _miscari = miscari;
      _loading = false;
    });
  }

  Future<void> _syncToCloud() async {
    setState(() => _syncing = true);
    final count = await _repo.forceSyncLocalToCloud();
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sincronizat $count articole la cloud.')),
    );
  }

  List<StocItem> get _filtered {
    var list = _items;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((i) {
        return i.productName.toLowerCase().contains(q) ||
            i.sku.toLowerCase().contains(q) ||
            i.categorie.toLowerCase().contains(q);
      }).toList();
    }
    switch (_filtru) {
      case 'Critic':
        return list.where((i) => i.esteStocCritic).toList();
      case 'Comanda':
        return list.where((i) => i.necesitaComanda).toList();
      case 'OK':
        return list.where((i) => !i.necesitaComanda).toList();
      default:
        return list;
    }
  }

  @override
  Widget build(BuildContext context) {
    final critic = _items.where((i) => i.esteStocCritic).length;
    final comanda = _items.where((i) => i.necesitaComanda).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stoc materiale'),
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_sync_outlined),
            tooltip: 'Sincronizeaza la cloud',
            onPressed: (_loading || _syncing) ? null : _syncToCloud,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Adauga produs',
            onPressed: _loading ? null : () => _showEditDialog(null),
          ),
          const HelpModuleButton(moduleId: 'stoc'),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(
              icon: const Icon(Icons.inventory_2_outlined),
              text: critic > 0 ? 'Stoc ($critic⚠️)' : 'Stoc',
            ),
            const Tab(icon: Icon(Icons.swap_vert_outlined), text: 'Miscari'),
            Tab(
              icon: const Icon(Icons.shopping_cart_outlined),
              text: comanda > 0 ? 'Comanda ($comanda)' : 'Comanda',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildStocTab(),
                _buildMiscariTab(),
                _buildComandaTab(),
              ],
            ),
    );
  }

  // ── TAB 0 — Stoc curent ──────────────────────────────────────────────────────

  Widget _buildStocTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Cauta produs, SKU, categorie...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Toate', 'Critic', 'Comanda', 'OK'].map((f) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(f),
                        selected: _filtru == f,
                        onSelected: (_) => setState(() => _filtru = f),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _filtered.isEmpty
                ? _buildEmptyStoc()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _buildStocCard(_filtered[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStoc() {
    return ListView(
      children: [
        const SizedBox(height: 40),
        const Center(child: Icon(Icons.inventory_2_outlined, size: 48)),
        const SizedBox(height: 12),
        const Center(child: Text('Nicio inregistrare de stoc.')),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.tonalIcon(
            onPressed: () => _showImportDialog(),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Importa din catalog produse'),
          ),
        ),
      ],
    );
  }

  Widget _buildStocCard(StocItem item) {
    final color = item.esteStocCritic
        ? Colors.red
        : item.necesitaComanda
            ? Colors.orange
            : Colors.green;
    final ratio = item.pragComanda > 0
        ? (item.cantitate / item.pragComanda).clamp(0.0, 1.0)
        : 1.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showEditDialog(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item.productName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (item.sku.isNotEmpty)
                    Text(item.sku,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
              if (item.categorie.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Chip(
                    label: Text(item.categorie,
                        style: const TextStyle(fontSize: 10)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: ratio,
                backgroundColor: Colors.grey.shade200,
                color: color,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: item.cantitate.toStringAsFixed(
                              item.cantitate == item.cantitate.roundToDouble()
                                  ? 0
                                  : 1),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 16),
                        ),
                        TextSpan(
                            text: ' ${item.unitate}',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Min: ${item.pragMinim.toStringAsFixed(0)} | '
                    'Comanda: ${item.pragComanda.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showMiscareDialog(item, 'achizitie'),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Intrare', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
                  TextButton.icon(
                    onPressed: () => _showMiscareDialog(item, 'consum'),
                    icon: const Icon(Icons.remove, size: 14),
                    label: const Text('Iesire', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TAB 1 — Mișcări ───────────────────────────────────────────────────────────

  Widget _buildMiscariTab() {
    if (_miscari.isEmpty) {
      return const Center(child: Text('Nicio miscare inregistrata.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _miscari.length,
        itemBuilder: (_, i) {
          final m = _miscari[i];
          final isIntrare = m.cantitate > 0;
          final color = isIntrare ? Colors.green : Colors.red;
          final icon = m.tip == 'ajustare'
              ? Icons.tune
              : isIntrare
                  ? Icons.arrow_downward
                  : Icons.arrow_upward;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 18),
            ),
            title: Text(m.productName,
                style: const TextStyle(fontWeight: FontWeight.w600,
                    fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.referintaNume.isNotEmpty)
                  Text(m.referintaNume, style: const TextStyle(fontSize: 11)),
                Text(
                  '${m.cantitateInainte.toStringAsFixed(1)} '
                  '→ ${m.cantitateAfter.toStringAsFixed(1)} ${m.unitate}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIntrare ? '+' : ''}${m.cantitate.toStringAsFixed(1)} ${m.unitate}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 13),
                ),
                Text(
                  '${m.createdAt.day.toString().padLeft(2, '0')}.'
                  '${m.createdAt.month.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── TAB 2 — Comandă ───────────────────────────────────────────────────────────

  Widget _buildComandaTab() {
    final toOrder = _items.where((i) => i.necesitaComanda).toList();
    if (toOrder.isEmpty) {
      return const Center(
          child: Text('Niciun produs nu necesita comanda. Stoc OK!'));
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: toOrder.length,
            itemBuilder: (_, i) {
              final item = toOrder[i];
              final recomandat = (item.pragComanda * 2 - item.cantitate)
                  .clamp(0.0, double.infinity);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item.productName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Stoc actual: ${item.cantitate.toStringAsFixed(1)} ${item.unitate}'),
                      if (item.furnizor.isNotEmpty)
                        Text('Furnizor: ${item.furnizor}',
                            style: const TextStyle(fontSize: 11)),
                      if (item.pretUnitarAchizitie > 0)
                        Text(
                            'Pret achizitie: ${item.pretUnitarAchizitie.toStringAsFixed(2)} RON/${item.unitate}',
                            style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+${recomandat.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.orange),
                      ),
                      Text(item.unitate,
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showComenziSumarDialog(toOrder),
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('Lista comanda'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Dialoguri ─────────────────────────────────────────────────────────────────

  Future<void> _showEditDialog(StocItem? existing) async {
    final uuid = const Uuid();
    final nameCtrl =
        TextEditingController(text: existing?.productName ?? '');
    final skuCtrl = TextEditingController(text: existing?.sku ?? '');
    final catCtrl =
        TextEditingController(text: existing?.categorie ?? '');
    final cantCtrl = TextEditingController(
        text: existing?.cantitate.toStringAsFixed(1) ?? '0');
    final pragMinCtrl = TextEditingController(
        text: existing?.pragMinim.toStringAsFixed(1) ?? '0');
    final pragCmdCtrl = TextEditingController(
        text: existing?.pragComanda.toStringAsFixed(1) ?? '0');
    final unitCtrl =
        TextEditingController(text: existing?.unitate ?? 'buc');
    final pretCtrl = TextEditingController(
        text: existing?.pretUnitarAchizitie.toStringAsFixed(2) ?? '0');
    final furnizorCtrl =
        TextEditingController(text: existing?.furnizor ?? '');

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(existing == null ? 'Adauga produs' : 'Editeaza produs'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Denumire produs *'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: skuCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'SKU / Cod'))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: catCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Categorie'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: cantCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Cantitate'))),
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 80,
                          child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: unitCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'UM'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: pragMinCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Prag minim'))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: TextField(
                              controller: pragCmdCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Prag comanda'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: pretCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Pret achizitie (RON)'))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: furnizorCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Furnizor'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx, false);
                  setState(() => _items.removeWhere((i) => i.id == existing.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Produs șters.')));
                  _repo.deleteStocItem(existing.id).catchError((e) {
                    if (mounted) _load();
                  });
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Sterge'),
              ),
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Anuleaza')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Salveaza')),
          ],
        ),
      );
      if (saved != true || !mounted) return;
      final name = nameCtrl.text.trim();
      if (name.isEmpty) return;
      final item = StocItem(
        id: existing?.id ?? uuid.v4(),
        productId: existing?.productId ?? uuid.v4(),
        productName: name,
        sku: skuCtrl.text.trim(),
        categorie: catCtrl.text.trim(),
        cantitate:
            double.tryParse(cantCtrl.text.replaceAll(',', '.')) ?? 0,
        pragMinim:
            double.tryParse(pragMinCtrl.text.replaceAll(',', '.')) ?? 0,
        pragComanda:
            double.tryParse(pragCmdCtrl.text.replaceAll(',', '.')) ?? 0,
        unitate: unitCtrl.text.trim().isEmpty ? 'buc' : unitCtrl.text.trim(),
        pretUnitarAchizitie:
            double.tryParse(pretCtrl.text.replaceAll(',', '.')) ?? 0,
        furnizor: furnizorCtrl.text.trim(),
        ultimaActualizare: DateTime.now(),
      );
      // Optimistic UI
      setState(() {
        final idx = _items.indexWhere((i) => i.id == item.id);
        if (idx >= 0) {
          _items = List.from(_items)..[idx] = item;
        } else {
          _items = [..._items, item];
        }
      });
      _repo.upsertStocItem(item).catchError((e) {
        if (mounted) _load();
      });
    } finally {
      nameCtrl.dispose();
      skuCtrl.dispose();
      catCtrl.dispose();
      cantCtrl.dispose();
      pragMinCtrl.dispose();
      pragCmdCtrl.dispose();
      unitCtrl.dispose();
      pretCtrl.dispose();
      furnizorCtrl.dispose();
    }
  }

  Future<void> _showMiscareDialog(StocItem item, String tip) async {
    final cantCtrl = TextEditingController();
    final notaCtrl = TextEditingController();
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
              tip == 'achizitie' ? 'Intrare stoc' : 'Iesire stoc (consum)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Produs: ${item.productName}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Stoc actual: ${item.cantitate.toStringAsFixed(1)} ${item.unitate}'),
              const SizedBox(height: 12),
              TextField(
                controller: cantCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText:
                        'Cantitate (${item.unitate})',
                    suffixText: item.unitate),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: notaCtrl,
                decoration: const InputDecoration(
                    labelText: 'Referinta / nota (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Anuleaza')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirma')),
          ],
        ),
      );
      if (saved != true || !mounted) return;
      final cant = double.tryParse(cantCtrl.text.replaceAll(',', '.')) ?? 0;
      if (cant <= 0) return;
      if (tip == 'achizitie') {
        await _repo.inregistreazaAchizitie(
            productId: item.productId, cantitate: cant);
      } else {
        await _repo.inregistreazaConsum(
          productId: item.productId,
          cantitate: cant,
          referintaId: '',
          referintaTip: 'manual',
          referintaNume: notaCtrl.text.trim(),
        );
      }
      _load();
    } finally {
      cantCtrl.dispose();
      notaCtrl.dispose();
    }
  }

  Future<void> _showImportDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importa din catalog'),
        content: const Text(
            'Doresti sa importi produsele din Catalogul de produse ca puncte '
            'de start pentru stoc?\n\nCantitate initiala: 0 (vei seta manual).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nu, adaug manual')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Da, importa')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import din catalog — disponibil curand.')),
    );
  }

  void _showComenziSumarDialog(List<StocItem> items) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lista de comanda'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                final recomandat =
                    (item.pragComanda * 2 - item.cantitate).clamp(0.0, 99999.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.productName)),
                      Text(
                          '${recomandat.toStringAsFixed(0)} ${item.unitate}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Inchide')),
        ],
      ),
    );
  }
}
