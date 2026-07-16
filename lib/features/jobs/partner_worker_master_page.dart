import 'package:flutter/material.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import 'dialogs/partner_worker_master_dialog.dart';
import 'partner_worker_master_models.dart';
import 'partner_worker_master_repository.dart';

/// Pagină simplă de management pentru catalogul de muncitori parteneri,
/// reachable direct din fișa lucrării (Jobs) — fără să fie nevoie să treci
/// în alt modul pentru a adăuga/edita/dezactiva personal partener.
class PartnerWorkerMasterPage extends StatefulWidget {
  const PartnerWorkerMasterPage({
    super.key,
    required this.partnerId,
    required this.partnerName,
    required this.repository,
    this.onChanged,
  });

  final String partnerId;
  final String partnerName;
  final PartnerWorkerMasterRepository repository;

  /// Apelat de fiecare dată când lista se schimbă (adăugare/editare/ștergere),
  /// ca pagina apelantă (fișa lucrării) să-și poată reîmprospăta lista locală.
  final void Function(List<PartnerWorkerMaster> workers)? onChanged;

  @override
  State<PartnerWorkerMasterPage> createState() =>
      _PartnerWorkerMasterPageState();
}

class _PartnerWorkerMasterPageState extends State<PartnerWorkerMasterPage> {
  bool _loading = true;
  String? _error;
  List<PartnerWorkerMaster> _items = const <PartnerWorkerMaster>[];

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
      final all = await widget.repository.listPartnerWorkerMasters();
      final filtered = all
          .where((item) => item.partnerId == widget.partnerId)
          .toList(growable: false)
        ..sort((a, b) => a.fullName.toLowerCase().compareTo(
              b.fullName.toLowerCase(),
            ));
      if (!mounted) return;
      setState(() {
        _items = filtered;
        _error = null;
        _loading = false;
      });
      widget.onChanged?.call(_items);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addOrEdit({PartnerWorkerMaster? existing}) async {
    final result = await showPartnerWorkerMasterDialog(
      context,
      partnerId: widget.partnerId,
      onValidationError: _snack,
      existing: existing,
    );
    if (result == null) return;
    // Optimistic UI — actualizează local imediat, salvarea cloud e best-effort
    // în fundal (nu blochează UI).
    final next = [
      ..._items.where((item) => item.id != result.id),
      result,
    ]..sort((a, b) => a.fullName.toLowerCase().compareTo(
          b.fullName.toLowerCase(),
        ));
    if (mounted) setState(() => _items = next);
    widget.onChanged?.call(_items);
    widget.repository.upsertPartnerWorkerMaster(result).catchError((e) {
      _snack('Eroare la salvare: $e');
    });
  }

  Future<void> _toggleActive(PartnerWorkerMaster item) async {
    final updated = item.copyWith(active: !item.active, updatedAt: DateTime.now());
    final next = _items.map((w) => w.id == item.id ? updated : w).toList();
    if (mounted) setState(() => _items = next);
    widget.onChanged?.call(_items);
    widget.repository.upsertPartnerWorkerMaster(updated).catchError((e) {
      _snack('Eroare la salvare: $e');
    });
  }

  Future<void> _delete(PartnerWorkerMaster item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Șterge din catalog?'),
        content: Text(
          '${item.fullName} va fi șters definitiv din catalog. '
          'Alocările deja salvate pe lucrări nu sunt afectate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (mounted) {
      setState(() => _items = _items.where((w) => w.id != item.id).toList());
    }
    widget.onChanged?.call(_items);
    widget.repository.deletePartnerWorkerMaster(item.id).catchError((e) {
      _snack('Eroare la ștergere: $e');
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Catalog personal — ${widget.partnerName}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Adaugă'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (!FirebaseBootstrap.isOnline || _error != null)
                    Card(
                      color: Colors.orange.withValues(alpha: 0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              FirebaseBootstrap.isOnline
                                  ? 'Eroare la încărcare: $_error'
                                  : 'Fără conexiune — catalogul necesită internet.',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            FilledButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Reîncarcă din cloud'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_items.isEmpty && _error == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('Nu există muncitori salvați în catalog.'),
                      ),
                    )
                  else
                    ..._items.map((item) {
                      return Card(
                        child: ListTile(
                          title: Text(
                            item.fullName,
                            style: item.active
                                ? null
                                : const TextStyle(
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                          ),
                          subtitle: Text(
                            item.role.isEmpty ? '-' : item.role,
                          ),
                          trailing: Wrap(
                            spacing: 0,
                            children: [
                              Switch(
                                value: item.active,
                                onChanged: (_) => _toggleActive(item),
                              ),
                              IconButton(
                                tooltip: 'Editează',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _addOrEdit(existing: item),
                              ),
                              IconButton(
                                tooltip: 'Șterge',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(item),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }
}
