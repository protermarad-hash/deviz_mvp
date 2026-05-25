import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'offer_acceptance_models.dart';

/// Dialog pentru editarea clauzelor formularului de acceptare ofertă.
/// Returnează lista actualizată sau null dacă utilizatorul anulează.
class OfferAcceptanceClausesDialog extends StatefulWidget {
  const OfferAcceptanceClausesDialog({
    super.key,
    required this.clauses,
  });

  final List<OfferAcceptanceClause> clauses;

  static Future<List<OfferAcceptanceClause>?> show(
    BuildContext context,
    List<OfferAcceptanceClause> clauses,
  ) {
    return showDialog<List<OfferAcceptanceClause>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OfferAcceptanceClausesDialog(clauses: clauses),
    );
  }

  @override
  State<OfferAcceptanceClausesDialog> createState() =>
      _OfferAcceptanceClausesDialogState();
}

class _OfferAcceptanceClausesDialogState
    extends State<OfferAcceptanceClausesDialog> {
  late List<OfferAcceptanceClause> _clauses;
  final _uuid = const Uuid();
  int? _editingIndex;

  // Controllere pentru editarea unei clauze
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _clauses = List.from(widget.clauses);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _startEdit(int index) {
    final clause = _clauses[index];
    _titleController.text = clause.title;
    _contentController.text = clause.content;
    setState(() => _editingIndex = index);
  }

  void _saveEdit() {
    if (_editingIndex == null) return;
    final updated = _clauses[_editingIndex!].copyWith(
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
    );
    setState(() {
      _clauses[_editingIndex!] = updated;
      _editingIndex = null;
    });
  }

  void _cancelEdit() {
    setState(() => _editingIndex = null);
  }

  void _toggleEnabled(int index) {
    setState(() {
      _clauses[index] = _clauses[index].copyWith(
        enabled: !_clauses[index].enabled,
      );
    });
  }

  void _addClause() {
    final newClause = OfferAcceptanceClause(
      id: _uuid.v4(),
      title: 'Clauză nouă',
      content: 'Descrieți clauza aici...',
      sortOrder: _clauses.length + 1,
    );
    setState(() {
      _clauses.add(newClause);
    });
    _startEdit(_clauses.length - 1);
  }

  void _deleteClause(int index) {
    setState(() {
      _clauses.removeAt(index);
      _editingIndex = null;
    });
  }

  void _moveUp(int index) {
    if (index == 0) return;
    setState(() {
      final temp = _clauses[index];
      _clauses[index] = _clauses[index - 1];
      _clauses[index - 1] = temp;
    });
  }

  void _moveDown(int index) {
    if (index >= _clauses.length - 1) return;
    setState(() {
      final temp = _clauses[index];
      _clauses[index] = _clauses[index + 1];
      _clauses[index + 1] = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 740),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.article_outlined,
                      color: cs.onPrimaryContainer, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Clauze Formular de Acceptare',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: cs.onPrimaryContainer),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Instrucțiune
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: cs.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Activează/dezactivează clauzele cu bifa. Apasă pe o clauză pentru a o edita.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.outline),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Lista clauze
            Flexible(
              child: _editingIndex != null
                  ? _buildEditor(cs)
                  : _buildClauseList(cs),
            ),

            const Divider(height: 1),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _addClause,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adaugă clauză'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Renunță'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_clauses),
                    child: const Text('Salvează clauzele'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClauseList(ColorScheme cs) {
    if (_clauses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.article_outlined, size: 48, color: cs.outline),
              const SizedBox(height: 12),
              Text(
                'Nicio clauză adăugată',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: cs.outline),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _addClause,
                child: const Text('Adaugă prima clauză'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _clauses.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, index) {
        final clause = _clauses[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Checkbox(
            value: clause.enabled,
            onChanged: (_) => _toggleEnabled(index),
          ),
          title: Text(
            clause.title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: clause.enabled ? null : cs.outline,
              decoration: clause.enabled ? null : TextDecoration.lineThrough,
            ),
          ),
          subtitle: Text(
            clause.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: clause.enabled
                  ? cs.onSurface.withValues(alpha: 0.6)
                  : cs.outline,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Mută sus',
                icon: const Icon(Icons.arrow_upward, size: 16),
                onPressed: index > 0 ? () => _moveUp(index) : null,
              ),
              IconButton(
                tooltip: 'Mută jos',
                icon: const Icon(Icons.arrow_downward, size: 16),
                onPressed:
                    index < _clauses.length - 1 ? () => _moveDown(index) : null,
              ),
              IconButton(
                tooltip: 'Editează',
                icon: const Icon(Icons.edit_outlined, size: 16),
                onPressed: () => _startEdit(index),
              ),
              IconButton(
                tooltip: 'Șterge',
                icon: Icon(Icons.delete_outline, size: 16, color: cs.error),
                onPressed: () => _deleteClause(index),
              ),
            ],
          ),
          onTap: () => _startEdit(index),
        );
      },
    );
  }

  Widget _buildEditor(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Editează clauza',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Titlu clauză',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              textCapitalization: TextCapitalization.sentences,
              controller: _contentController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                labelText: 'Conținut clauză',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _cancelEdit,
                child: const Text('Renunță'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saveEdit,
                child: const Text('Aplică'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
