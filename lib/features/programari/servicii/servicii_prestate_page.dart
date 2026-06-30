import 'package:flutter/material.dart';

import '../../../core/cloud/firebase_bootstrap.dart';
import 'firebase_serviciu_prestat_repository.dart';
import 'serviciu_prestat_models.dart';

/// Pagină de gestionare a catalogului de servicii prestate (admin-only).
///
/// Listă carduri (denumire + preț), FAB pentru serviciu nou, meniu per card
/// pentru editare / dezactivare (nu ștergere — păstrăm istoricul).
class ServiciiPrestatePage extends StatefulWidget {
  const ServiciiPrestatePage({super.key});

  @override
  State<ServiciiPrestatePage> createState() => _ServiciiPrestatePageState();
}

class _ServiciiPrestatePageState extends State<ServiciiPrestatePage> {
  final FirebaseServiciuPrestatRepository _repo =
      FirebaseServiciuPrestatRepository();

  List<ServiciuPrestat> _items = const <ServiciuPrestat>[];
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
    if (FirebaseBootstrap.onlineNotifier.value && _items.isEmpty && !_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final list = await _repo.listServicii();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor({ServiciuPrestat? existing}) async {
    final denumireCtrl = TextEditingController(text: existing?.denumire ?? '');
    final pretCtrl = TextEditingController(
      text: (existing?.pretSugerat ?? 0) > 0
          ? existing!.pretSugerat.toStringAsFixed(2)
          : '',
    );
    String moneda = existing?.moneda ?? 'RON';
    String? formError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Serviciu nou' : 'Editează serviciu'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: denumireCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Denumire serviciu',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: pretCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Preț sugerat',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: moneda,
                            decoration:
                                const InputDecoration(labelText: 'Monedă'),
                            items: const [
                              DropdownMenuItem(value: 'RON', child: Text('RON')),
                              DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                              DropdownMenuItem(value: 'USD', child: Text('USD')),
                            ],
                            onChanged: (v) =>
                                setDialogState(() => moneda = v ?? 'RON'),
                          ),
                        ),
                      ],
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        formError!,
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Anulează'),
                ),
                FilledButton(
                  onPressed: () {
                    final denumire = denumireCtrl.text.trim();
                    if (denumire.isEmpty) {
                      setDialogState(
                        () => formError = 'Denumirea este obligatorie.',
                      );
                      return;
                    }
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Salvează'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      denumireCtrl.dispose();
      pretCtrl.dispose();
      return;
    }

    final denumire = denumireCtrl.text.trim();
    final pret = double.tryParse(pretCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    denumireCtrl.dispose();
    pretCtrl.dispose();

    final now = DateTime.now();
    final toSave = existing == null
        ? ServiciuPrestat.nou(denumire: denumire, pretSugerat: pret, moneda: moneda)
        : existing.copyWith(
            denumire: denumire,
            pretSugerat: pret,
            moneda: moneda,
            updatedAt: now,
          );

    // Optimistic UI
    setState(() {
      final idx = _items.indexWhere((e) => e.id == toSave.id);
      if (idx >= 0) {
        _items = [..._items]..[idx] = toSave;
      } else {
        _items = [toSave, ..._items];
      }
    });
    _repo.saveServiciu(toSave).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare salvare: $e')),
        );
        _load();
      }
      return toSave;
    });
  }

  void _toggleActiv(ServiciuPrestat s) {
    final updated = s.copyWith(activ: !s.activ, updatedAt: DateTime.now());
    setState(() {
      final idx = _items.indexWhere((e) => e.id == s.id);
      if (idx >= 0) _items = [..._items]..[idx] = updated;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(updated.activ ? 'Serviciu reactivat.' : 'Serviciu dezactivat.'),
      ),
    );
    _repo.saveServiciu(updated).catchError((e) {
      if (mounted) _load();
      return updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicii Prestate'),
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
        label: const Text('Serviciu nou'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Niciun serviciu în catalog.\nApasă „Serviciu nou" pentru a adăuga.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => _buildCard(_items[i]),
                    ),
            ),
    );
  }

  Widget _buildCard(ServiciuPrestat s) {
    final pretLabel = s.pretSugerat > 0
        ? '${s.pretSugerat.toStringAsFixed(2)} ${s.moneda}'
        : 'Fără preț';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          Icons.design_services_outlined,
          color: s.activ
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).disabledColor,
        ),
        title: Text(
          s.denumire,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: s.activ ? null : TextDecoration.lineThrough,
            color: s.activ ? null : Theme.of(context).disabledColor,
          ),
        ),
        subtitle: Text(s.activ ? pretLabel : '$pretLabel · dezactivat'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _openEditor(existing: s);
            if (v == 'toggle') _toggleActiv(s);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editează')),
            PopupMenuItem(
              value: 'toggle',
              child: Text(s.activ ? 'Dezactivează' : 'Reactivează'),
            ),
          ],
        ),
      ),
    );
  }
}
