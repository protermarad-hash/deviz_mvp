import 'package:flutter/material.dart';

import '../offer_standard_catalog_models.dart';
import 'offer_commercial_clause_template_editor_dialog.dart';

class OfferCommercialClauseTemplatesDialog extends StatefulWidget {
  const OfferCommercialClauseTemplatesDialog({
    required this.items,
    required this.onSave,
  });

  final List<OfferCommercialClauseTemplate> items;
  final Future<void> Function(OfferCommercialClauseTemplate item) onSave;

  @override
  State<OfferCommercialClauseTemplatesDialog> createState() =>
      OfferCommercialClauseTemplatesDialogState();
}

class OfferCommercialClauseTemplatesDialogState
    extends State<OfferCommercialClauseTemplatesDialog> {
  bool _saving = false;

  Future<void> _editTemplate([OfferCommercialClauseTemplate? existing]) async {
    final saved = await showDialog<OfferCommercialClauseTemplate>(
      context: context,
      builder: (context) =>
          OfferCommercialClauseTemplateEditorDialog(existing: existing),
    );
    if (saved == null || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(saved);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [...widget.items]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return AlertDialog(
      title: const Text('Condiții comerciale standard'),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _editTemplate(),
                icon: const Icon(Icons.add),
                label: const Text('Adaugă'),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        'Nu există șabloane de condiții comerciale.',
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          title: Text(item.title),
                          subtitle: Text(
                            '${item.category.trim().isEmpty ? 'Fără categorie' : item.category.trim()}\n'
                            '${item.content.trim().isEmpty ? '-' : item.content.trim()}\n'
                            'Status: ${item.isActive ? 'Activ' : 'Inactiv'}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: 'Editează',
                            onPressed:
                                _saving ? null : () => _editTemplate(item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Închide'),
        ),
      ],
    );
  }
}
