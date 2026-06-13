import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/help_content.dart';
import '../../core/widgets/help_button.dart';
import 'deviz_articol_template_models.dart';
import 'deviz_articol_template_repository.dart';

class DevizArticoleBazaPage extends StatefulWidget {
  const DevizArticoleBazaPage({super.key});

  @override
  State<DevizArticoleBazaPage> createState() => _DevizArticoleBazaPageState();
}

class _DevizArticoleBazaPageState extends State<DevizArticoleBazaPage> {
  final _repo = DevizArticolTemplateRepository();
  final _searchController = TextEditingController();

  List<DevizArticolTemplate> _allTemplates = const [];
  List<DevizArticolTemplate> _filtered = const [];
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _forceSyncToCloud() async {
    if (_loading || _syncing) return;
    setState(() => _syncing = true);
    try {
      final count = await _repo.forceSyncLocalToCloud();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sincronizat $count articole la cloud.')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _loadTemplates() async {
    setState(() => _loading = true);
    final templates = await _repo.listLocal();
    if (!mounted) return;
    final sorted = [...templates]
      ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    setState(() {
      _allTemplates = sorted;
      _loading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final q = _searchController.text;
    setState(() {
      _filtered = _repo.searchTemplates(q, _allTemplates);
    });
  }

  Future<void> _editTemplate(DevizArticolTemplate template) async {
    final result = await showDialog<DevizArticolTemplate>(
      context: context,
      builder: (ctx) => _EditTemplateDialog(template: template),
    );
    if (result == null || !mounted) return;
    // Optimistic UI
    setState(() {
      final idx = _allTemplates.indexWhere((t) => t.id == result.id);
      if (idx >= 0) {
        _allTemplates = List.from(_allTemplates)..[idx] = result;
      } else {
        _allTemplates = [..._allTemplates, result];
      }
      _applyFilter();
    });
    _repo.upsert(result).catchError((e) {
      if (mounted) _loadTemplates();
    });
  }

  Future<void> _deleteTemplate(DevizArticolTemplate template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ștergi articolul din bază?'),
        content: Text(
            'Articolul "${template.denumire}" va fi eliminat din baza proprie de norme.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    // Optimistic UI
    setState(() {
      _allTemplates =
          _allTemplates.where((t) => t.id != template.id).toList();
      _applyFilter();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Articol șters din baza proprie.')),
    );
    _repo.delete(template.id).catchError((e) {
      if (mounted) _loadTemplates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baza proprie de norme'),
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined),
            tooltip: 'Sincronizează la cloud',
            onPressed: (_loading || _syncing) ? null : _forceSyncToCloud,
          ),
          HelpButton(content: AppHelp.devizArticoleBaza),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Caută articol...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_fix_high,
                        size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(
                      _allTemplates.isEmpty
                          ? 'Nicio normă salvată încă.\nArticolele adăugate în devize\nse vor salva automat aici.'
                          : 'Niciun articol găsit.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final t = _filtered[index];
                  return _TemplateCard(
                    template: t,
                    onEdit: () => _editTemplate(t),
                    onDelete: () => _deleteTemplate(t),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });

  final DevizArticolTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = template;
    final dateFmt = DateFormat('dd.MM.yy');

    Widget priceChip(String label, double val) {
      if (val <= 0) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$label: ${val.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 11,
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.denumire,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                if (t.um.isNotEmpty)
                  Text(
                    t.um,
                    style: TextStyle(
                        color: cs.primary, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                priceChip('Mat', t.pretUnitarMat),
                priceChip('Man', t.pretUnitarMan),
                priceChip('Utilaj', t.pretUnitarUtilaj),
                priceChip('Transport', t.pretUnitarTransport),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.history, size: 14,
                    color: cs.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(
                  'Folosit de ${t.folositDeCateOri} ori • ultima: ${dateFmt.format(t.lastUpdated)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editează'),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline,
                      size: 16, color: cs.error),
                  label: Text('Șterge', style: TextStyle(color: cs.error)),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(color: cs.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditTemplateDialog extends StatefulWidget {
  const _EditTemplateDialog({required this.template});

  final DevizArticolTemplate template;

  @override
  State<_EditTemplateDialog> createState() => _EditTemplateDialogState();
}

class _EditTemplateDialogState extends State<_EditTemplateDialog> {
  late final TextEditingController _denumireCtrl;
  late final TextEditingController _umCtrl;
  late final TextEditingController _matCtrl;
  late final TextEditingController _manCtrl;
  late final TextEditingController _utilajCtrl;
  late final TextEditingController _transportCtrl;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _denumireCtrl = TextEditingController(text: t.denumire);
    _umCtrl = TextEditingController(text: t.um);
    _matCtrl =
        TextEditingController(text: t.pretUnitarMat.toStringAsFixed(2));
    _manCtrl =
        TextEditingController(text: t.pretUnitarMan.toStringAsFixed(2));
    _utilajCtrl =
        TextEditingController(text: t.pretUnitarUtilaj.toStringAsFixed(2));
    _transportCtrl =
        TextEditingController(text: t.pretUnitarTransport.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _denumireCtrl.dispose();
    _umCtrl.dispose();
    _matCtrl.dispose();
    _manCtrl.dispose();
    _utilajCtrl.dispose();
    _transportCtrl.dispose();
    super.dispose();
  }

  double _asDouble(String raw) {
    return double.tryParse(raw.replaceAll(',', '.').trim()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editează normă'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              textCapitalization: TextCapitalization.sentences,
              controller: _denumireCtrl,
              decoration: const InputDecoration(labelText: 'Denumire'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              textCapitalization: TextCapitalization.none,
              controller: _umCtrl,
              decoration:
                  const InputDecoration(labelText: 'Unitate de măsură (UM)'),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Prețuri unitare (RON/u)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _matCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Material'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _manCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Manoperă'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _utilajCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Utilaj'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _transportCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Transport'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (_) {
                final total = _asDouble(_matCtrl.text) +
                    _asDouble(_manCtrl.text) +
                    _asDouble(_utilajCtrl.text) +
                    _asDouble(_transportCtrl.text);
                return Text(
                  'Total unitar: ${total.toStringAsFixed(2)} RON/u',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: () {
            final updated = widget.template.copyWith(
              denumire: _denumireCtrl.text.trim(),
              um: _umCtrl.text.trim(),
              pretUnitarMat: _asDouble(_matCtrl.text),
              pretUnitarMan: _asDouble(_manCtrl.text),
              pretUnitarUtilaj: _asDouble(_utilajCtrl.text),
              pretUnitarTransport: _asDouble(_transportCtrl.text),
              lastUpdated: DateTime.now(),
            );
            Navigator.pop(context, updated);
          },
          child: const Text('Salvează'),
        ),
      ],
    );
  }
}
