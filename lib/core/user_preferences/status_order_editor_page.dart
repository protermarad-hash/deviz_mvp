import 'package:flutter/material.dart';

import 'user_status_order_repository.dart';

/// Un grup de status afișabil în editorul de ordine (cheie stabilă + label +
/// culoare, refolosind culorile deja definite per modul — ex.
/// `_offerStatusBaseColor()` din `oferte_page.dart` sau `DevizTehnicStatus.color`
/// din `deviz_tehnic_models.dart:156-169`).
class StatusGroupOption {
  const StatusGroupOption({
    required this.key,
    required this.label,
    required this.color,
    this.icon = Icons.flag_outlined,
  });

  final String key;
  final String label;
  final Color color;
  final IconData icon;
}

/// Ecran comun de reordonare a grupurilor de status — folosit atât din
/// Oferte, cât și din Devize Tehnice, parametrizat cu `moduleId` (identifică
/// modulul în documentul Firestore `user_status_order/{uid}`) și lista de
/// grupuri posibile pentru acel modul.
///
/// Notă UI: regula proiectului de a adăuga autosearch pe dropdown-uri/liste
/// de selecție NU se aplică aici — acesta nu e un dropdown de selecție dintr-o
/// listă mare (ex. clienți, materiale), ci o listă fixă, mică (5-7 grupuri),
/// de REORDONAT prin drag & drop, nu de căutat.
class StatusOrderEditorPage extends StatelessWidget {
  const StatusOrderEditorPage({
    super.key,
    required this.moduleId,
    required this.moduleTitle,
    required this.options,
    required this.initialOrder,
  });

  final String moduleId;
  final String moduleTitle;
  final List<StatusGroupOption> options;
  final List<String> initialOrder;

  @override
  Widget build(BuildContext context) {
    return _StatusOrderEditorView(
      moduleId: moduleId,
      moduleTitle: moduleTitle,
      options: options,
      initialOrder: initialOrder,
    );
  }
}

class _StatusOrderEditorView extends StatefulWidget {
  const _StatusOrderEditorView({
    required this.moduleId,
    required this.moduleTitle,
    required this.options,
    required this.initialOrder,
  });

  final String moduleId;
  final String moduleTitle;
  final List<StatusGroupOption> options;
  final List<String> initialOrder;

  @override
  State<_StatusOrderEditorView> createState() =>
      _StatusOrderEditorViewState();
}

class _StatusOrderEditorViewState extends State<_StatusOrderEditorView> {
  final _repository = UserStatusOrderRepository();
  late List<String> _order;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _order = List<String>.from(widget.initialOrder);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repository.saveOrder(moduleId: widget.moduleId, order: _order);
      if (!mounted) return;
      Navigator.of(context).pop(_order);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare la salvare: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final byKey = {for (final o in widget.options) o.key: o};
    return Scaffold(
      appBar: AppBar(
        title: Text('Ordine status — ${widget.moduleTitle}'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvează'),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Trage grupurile ca să alegi ordinea în care apar în listă. '
              'Ordinea se salvează pentru contul tău și e vizibilă pe toate '
              'dispozitivele pe care ești logat.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: _order.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _order.removeAt(oldIndex);
                  _order.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final key = _order[index];
                final option = byKey[key];
                return Card(
                  key: ValueKey(key),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: (option?.color ?? Colors.grey)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      option?.icon ?? Icons.flag_outlined,
                      color: option?.color,
                    ),
                    title: Text(
                      option?.label ?? key,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
