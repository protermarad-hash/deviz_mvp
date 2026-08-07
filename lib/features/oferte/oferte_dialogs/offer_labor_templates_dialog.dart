import 'package:flutter/material.dart';

import '../offer_standard_catalog_models.dart';
import 'offer_labor_template_editor_dialog.dart';

class OfferLaborTemplatesDialog extends StatefulWidget {
  const OfferLaborTemplatesDialog({
    required this.items,
    required this.onSave,
    required this.onImportRecommended,
  });

  final List<OfferLaborTemplate> items;
  final Future<void> Function(OfferLaborTemplate item) onSave;
  final Future<int> Function() onImportRecommended;

  @override
  State<OfferLaborTemplatesDialog> createState() =>
      OfferLaborTemplatesDialogState();
}

class OfferLaborTemplatesDialogState
    extends State<OfferLaborTemplatesDialog> {
  bool _saving = false;

  Future<void> _editTemplate([OfferLaborTemplate? existing]) async {
    final saved = await showDialog<OfferLaborTemplate>(
      context: context,
      builder: (context) => OfferLaborTemplateEditorDialog(existing: existing),
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

  Future<void> _importRecommended() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onImportRecommended();
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
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return AlertDialog(
      title: const Text('Catalog manoperă standard'),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _importRecommended,
                    icon: const Icon(Icons.playlist_add_check_outlined),
                    label: const Text('Importă set recomandat'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => _editTemplate(),
                    icon: const Icon(Icons.add),
                    label: const Text('Adaugă'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: items.isEmpty
                  ? const Center(
                      child: Text('Nu există șabloane de manoperă standard.'),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            'Categorie: ${item.category.trim().isEmpty ? '-' : item.category.trim()}\n'
                            '${item.description.trim().isEmpty ? '-' : item.description.trim()}\n'
                            'UM: ${item.unit} • Cantitate implicită: ${item.defaultQuantity.toStringAsFixed(2)} • Preț unitar: ${item.defaultUnitPrice.toStringAsFixed(2)}\n'
                            'Incluse: ${item.includedServices.trim().isEmpty ? '-' : item.includedServices.trim()}\n'
                            'Sugestii produse: ${item.suggestedProductKeywords.trim().isEmpty ? '-' : item.suggestedProductKeywords.trim()}\n'
                            'Status: ${item.isActive ? 'Activ' : 'Inactiv'}',
                          ),
                          isThreeLine: false,
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
